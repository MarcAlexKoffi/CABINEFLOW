import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/manager_profile_avatar.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/failed_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/refunds/data/repositories/operational_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/operational_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.dashboardRepository,
    this.orderHistoryRepository,
    this.ordersRepository,
    this.agentRepository,
    this.onOpenOrders,
    this.onOpenPayments,
    this.onOpenNetwork,
    this.onOpenMore,
    this.onLogout,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final OrderHistoryRepository? orderHistoryRepository;
  final OrdersRepository? ordersRepository;
  final AgentRepository? agentRepository;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenNetwork;
  final VoidCallback? onOpenMore;
  final VoidCallback? onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardViewModel _viewModel;
  late final SupportRequestRepository _supportRepository;
  late final RefundRepository _refundRepository;
  StreamSubscription<List<SupportRequest>>? _supportSubscription;
  StreamSubscription<List<RefundCase>>? _refundSubscription;
  StreamSubscription<List<QueueOrder>>? _failedOrdersSubscription;
  List<QueueOrder> _rawFailedOrders = const <QueueOrder>[];
  List<QueueOrder> _failedOrders = const <QueueOrder>[];
  Set<String> _handledFailureOrderIds = <String>{};
  final Set<String> _seenFailedOrderIds = <String>{};
  bool _hasReceivedFailureSnapshot = false;
  int _customerRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel(
      dashboardRepository: widget.dashboardRepository,
    );
    _viewModel.startRealtime();

    _supportRepository = createOperationalSupportRequestRepository();
    _supportSubscription = _supportRepository.watchNewRequests().listen((
      List<SupportRequest> requests,
    ) {
      if (!mounted) return;
      setState(() => _customerRequestsCount = requests.length);
    }, onError: (Object error, StackTrace stackTrace) {
      IzyTelLog.backendError(
        'Dashboard.support-watch',
        error,
        stackTrace: stackTrace,
      );
    });

    _refundRepository = createOperationalRefundRepository();
    // Les remboursements operationnels vivent maintenant dans Supabase.
    // Seuls les profils autorises a les gerer ouvrent ce listener financier.
    if (widget.user.permissions.canManageRefunds) {
      _refundSubscription = _refundRepository.watchAll().listen((
        List<RefundCase> refunds,
      ) {
        if (!mounted) return;
        _handledFailureOrderIds = refunds
            .where(
              (RefundCase refund) =>
                  refund.status == RefundStatus.refunded ||
                  refund.status == RefundStatus.reconciled,
            )
            .map((RefundCase refund) => refund.orderId)
            .toSet();
        _refreshVisibleFailedOrders(notifyNewFailures: false);
      }, onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'Dashboard.refund-watch',
          error,
          stackTrace: stackTrace,
        );
      });
    }

    final OrderHistoryRepository? history = widget.orderHistoryRepository;
    // Les échecs sont une action exclusivement Administrateur. Le Manager ne
    // doit pas voir tout l'historique des anciens échecs comme des tâches
    // actuelles à réaffecter.
    if (history != null && widget.user.permissions.canManageFailedOrders) {
      _failedOrdersSubscription = history.watchOrderHistory().listen((
        List<QueueOrder> orders,
      ) {
        if (!mounted) return;
        _rawFailedOrders =
            orders
                .where(
                  (QueueOrder order) => order.status == QueueOrderStatus.failed,
                )
                .toList(growable: false)
              ..sort((QueueOrder first, QueueOrder second) {
                final DateTime firstDate = first.completedAt ?? first.createdAt;
                final DateTime secondDate =
                    second.completedAt ?? second.createdAt;
                return secondDate.compareTo(firstDate);
              });
        _refreshVisibleFailedOrders(notifyNewFailures: true);
      }, onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError(
          'Dashboard.failed-orders-watch',
          error,
          stackTrace: stackTrace,
        );
      });
    }
  }

  void _refreshVisibleFailedOrders({required bool notifyNewFailures}) {
    if (!mounted) return;
    final List<QueueOrder> visible = _rawFailedOrders
        .where(
          (QueueOrder order) => !_handledFailureOrderIds.contains(order.id),
        )
        .toList(growable: false);
    final List<QueueOrder> newlyFailed =
        notifyNewFailures && _hasReceivedFailureSnapshot
        ? visible
              .where(
                (QueueOrder order) => !_seenFailedOrderIds.contains(order.id),
              )
              .toList(growable: false)
        : const <QueueOrder>[];

    _seenFailedOrderIds
      ..clear()
      ..addAll(visible.map((QueueOrder order) => order.id));
    if (notifyNewFailures) {
      _hasReceivedFailureSnapshot = true;
    }
    setState(() => _failedOrders = List<QueueOrder>.unmodifiable(visible));

    if (newlyFailed.isNotEmpty) {
      final QueueOrder newest = newlyFailed.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        IzyTelFeedback.show(
          context,
          widget.user.permissions.canManageFailedOrders
              ? 'Commande ${newest.reference} échouée : intervention requise.'
              : 'Commande ${newest.reference} échouée : intervention Admin requise.',
          tone: IzyTelFeedbackTone.error,
        );
      });
    }
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _refundSubscription?.cancel();
    _failedOrdersSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openRecentOrder(PriorityOrder order) async {
    final OrderHistoryRepository? repository = widget.orderHistoryRepository;
    if (repository == null) return;
    final String orderId = order.orderId;
    if (orderId.trim().isEmpty) return;
    final loaded = await repository.fetchOrderById(orderId: orderId);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return OrderDetailPage(
            user: widget.user,
            initialOrder: loaded,
            ordersRepository: repository,
            onBack: () => Navigator.of(context).pop(),
            onOpenCustomerHistory: (_) {},
          );
        },
      ),
    );
  }

  Future<void> _openFailedOrdersCenter() async {
    if (!widget.user.permissions.canManageFailedOrders) {
      IzyTelFeedback.show(
        context,
        'La réaffectation d’une commande échouée et les remboursements restent réservés à l’Administrateur.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }
    final OrderHistoryRepository? history = widget.orderHistoryRepository;
    final OrdersRepository? orders = widget.ordersRepository;
    final AgentRepository? agents = widget.agentRepository;
    if (history == null || orders == null || agents == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FailedOrdersPage(
          user: widget.user,
          ordersRepository: orders,
          orderHistoryRepository: history,
          agentRepository: agents,
        ),
      ),
    );
  }

  String _formatCurrentDate() {
    const List<String> months = <String>[
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    const List<String> days = <String>[
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final DateTime date = DateTime.now();
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int? _balance(DashboardData data, ServiceChannel channel) {
    for (final AccountBalance balance in data.balances) {
      if (balance.channel == channel) return balance.amount;
    }
    return null;
  }

  void _openAccountSheet() {
    final List<IzyTelAccountAction> actions = <IzyTelAccountAction>[
      if (widget.onOpenMore != null)
        IzyTelAccountAction(
          icon: Symbols.person_rounded,
          label: widget.user.isManager ? 'Espace Manager' : 'Administration',
          onTap: widget.onOpenMore!,
        ),
      if (widget.onOpenMore != null &&
          widget.user.permissions.canProcessSupportRequests)
        IzyTelAccountAction(
          icon: Symbols.notifications_rounded,
          label: 'Demandes & notifications',
          onTap: widget.onOpenMore!,
        ),
      if (widget.onLogout != null)
        IzyTelAccountAction(
          icon: Symbols.logout_rounded,
          label: 'Se déconnecter',
          destructive: true,
          onTap: widget.onLogout!,
        ),
    ];

    showIzyTelAccountSheet(
      context: context,
      name: widget.user.name,
      role: widget.user.roleLabel,
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final DashboardData? data = _viewModel.dashboardData;

        return Scaffold(
          backgroundColor: IzyTelColors.background,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _viewModel.loadDashboard,
              color: IzyTelColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: <Widget>[
                  _Header(
                    user: widget.user,
                    dateLabel: _formatCurrentDate(),
                    onAvatarTap: _openAccountSheet,
                  ),
                  const SizedBox(height: 18),
                  if (_viewModel.isLoading && data == null)
                    const _LoadingState()
                  else if (_viewModel.errorMessage != null && data == null)
                    _ErrorState(
                      message: _viewModel.errorMessage!,
                      onRetry: _viewModel.loadDashboard,
                    )
                  else if (data != null) ...<Widget>[
                    if (_viewModel.errorMessage != null) ...<Widget>[
                      _PartialDataBanner(message: _viewModel.errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    _OverviewCard(data: data),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Priorités',
                      subtitle: 'Les actions qui demandent ton attention maintenant.',
                    ),
                    const SizedBox(height: 10),
                    _QuickActionsGrid(
                      children: <Widget>[
                        _QuickActionTile(
                          icon: Symbols.receipt_long_rounded,
                          count: data.statistics.paymentsToVerify,
                          title: 'Paiements',
                          subtitle: 'à vérifier',
                          tone: IzyTelColors.warning,
                          onTap: widget.onOpenPayments ?? widget.onOpenOrders,
                        ),
                        _QuickActionTile(
                          icon: Symbols.person_rounded,
                          count: data.statistics.unassignedOrders,
                          title: 'Sans agent',
                          subtitle: 'sans agent à vérifier',
                          tone: IzyTelColors.warning,
                          onTap: widget.onOpenOrders,
                        ),
                        if (widget.user.permissions.canManageFailedOrders)
                          _QuickActionTile(
                            icon: Symbols.error_rounded,
                            count: _failedOrders.length,
                            title: 'Échecs',
                            subtitle: 'à traiter',
                            tone: IzyTelColors.error,
                            onTap: _openFailedOrdersCenter,
                          ),
                        _QuickActionTile(
                          icon: Symbols.support_agent_rounded,
                          count: _customerRequestsCount,
                          title: 'Demandes client',
                          subtitle: 'à consulter',
                          tone: IzyTelColors.primary,
                          onTap: widget.user.permissions.canViewSupportRequests
                              ? widget.onOpenMore
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Activité du jour',
                      subtitle: 'Synchronisée avec les statuts opérationnels Supabase.',
                    ),
                    const SizedBox(height: 10),
                    _DailyActivityCard(
                      paid: data.statistics.newRequests,
                      inProgress: data.statistics.inProgress,
                      completed: data.statistics.completed,
                      onTap: widget.onOpenOrders,
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'Capacités disponibles',
                      subtitle:
                          'Solde réellement disponible chez les agents actifs, réservations déduites.',
                      actionLabel: widget.onOpenNetwork == null ? null : 'Gérer',
                      onAction: widget.onOpenNetwork,
                    ),
                    const SizedBox(height: 10),
                    _NetworkCapacityPanel(
                      orange: _balance(data, ServiceChannel.orange),
                      mtn: _balance(data, ServiceChannel.mtn),
                      moov: _balance(data, ServiceChannel.moov),
                      onTap: widget.onOpenNetwork,
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'À traiter en priorité',
                      subtitle: data.priorityOrders.isEmpty
                          ? 'Aucune commande active prioritaire.'
                          : 'Les commandes les plus urgentes selon leur état actuel.',
                      actionLabel: data.priorityOrders.isEmpty ? null : 'Toutes',
                      onAction: data.priorityOrders.isEmpty
                          ? null
                          : widget.onOpenOrders,
                    ),
                    const SizedBox(height: 10),
                    if (data.priorityOrders.isEmpty)
                      const _EmptyRecentState()
                    else
                      _PriorityOrdersPanel(
                        orders: data.priorityOrders.take(3).toList(growable: false),
                        onOpen: widget.orderHistoryRepository == null
                            ? null
                            : _openRecentOrder,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.dateLabel,
    required this.onAvatarTap,
  });

  final AppUser user;
  final String dateLabel;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final List<String> nameParts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final String firstName = nameParts.isEmpty ? user.name : nameParts.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Bonjour $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: IzyTelTypeScale.title2,
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: IzyTelColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      user.roleLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IzyTelColors.primaryStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (user.isManager)
          ManagerProfileAvatar(
            user: user,
            size: 46,
            onTap: onAvatarTap,
          )
        else
          IzyTelAvatar(
            name: user.name,
            size: 46,
            onTap: onAvatarTap,
          ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B63F0), Color(0xFF3157E0)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: IzyTelColors.primary.withAlpha(42),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Encaissements aujourd’hui',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(205),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatCfaFull(data.todayRevenue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _RevenueTrend(percentage: data.revenueChangePercentage),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(38)),
                ),
                child: const Icon(
                  Symbols.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(height: 1, color: Colors.white.withAlpha(38)),
          const SizedBox(height: 15),
          Row(
            children: <Widget>[
              Expanded(
                child: _OverviewMetric(
                  icon: Symbols.inbox_rounded,
                  value: data.ordersToProcess.toString(),
                  label: 'À traiter',
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: Colors.white.withAlpha(42),
              ),
              Expanded(
                child: _OverviewMetric(
                  icon: Symbols.schedule_rounded,
                  value: _waitLabel(data.averageWaitingMinutes),
                  label: 'Attente moyenne',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _waitLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int remaining = minutes % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  }
}

class _RevenueTrend extends StatelessWidget {
  const _RevenueTrend({required this.percentage});

  final double? percentage;

  @override
  Widget build(BuildContext context) {
    final double? value = percentage;
    final bool positive = (value ?? 0) > 0;
    final bool negative = (value ?? 0) < 0;
    final IconData icon = value == null
        ? Symbols.horizontal_rule_rounded
        : positive
        ? Symbols.trending_up_rounded
        : negative
        ? Symbols.trending_down_rounded
        : Symbols.trending_flat_rounded;
    final String label = value == null
        ? 'Pas de base comparable hier'
        : '${positive ? '+' : ''}${value.toStringAsFixed(1)}% vs hier';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withAlpha(190),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: IzyTelTypeScale.title3,
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IzyTelColors.textSecondary,
                  fontSize: IzyTelTypeScale.micro,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((Widget child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color effectiveTone = count == 0 ? IzyTelColors.textMuted : tone;
    return IzyTelSurface(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveTone.withAlpha(20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: effectiveTone),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: IzyTelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.micro,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyActivityCard extends StatelessWidget {
  const _DailyActivityCard({
    required this.paid,
    required this.inProgress,
    required this.completed,
    this.onTap,
  });

  final int paid;
  final int inProgress;
  final int completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _DailyMetric(
              label: 'Payées',
              value: paid,
              icon: Symbols.receipt_long_rounded,
              color: IzyTelColors.success,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _DailyMetric(
              label: 'En cours',
              value: inProgress,
              icon: Symbols.autorenew_rounded,
              color: IzyTelColors.warning,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _DailyMetric(
              label: 'Terminées',
              value: completed,
              icon: Symbols.check_circle_rounded,
              color: IzyTelColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMetric extends StatelessWidget {
  const _DailyMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 7),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: IzyTelColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: IzyTelColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      color: IzyTelColors.outline,
    );
  }
}

class _NetworkCapacityPanel extends StatelessWidget {
  const _NetworkCapacityPanel({
    required this.orange,
    required this.mtn,
    required this.moov,
    this.onTap,
  });

  final int? orange;
  final int? mtn;
  final int? moov;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _NetworkCapacityRow(
            name: 'Orange',
            asset: 'assets/brands/operators/orange_ci.png',
            amount: orange,
            tone: IzyTelColors.orange,
          ),
          const Divider(height: 1),
          _NetworkCapacityRow(
            name: 'MTN',
            asset: 'assets/brands/operators/mtn_ci.png',
            amount: mtn,
            tone: IzyTelColors.mtnText,
          ),
          const Divider(height: 1),
          _NetworkCapacityRow(
            name: 'Moov Africa',
            asset: 'assets/brands/operators/moov_africa_ci.png',
            amount: moov,
            tone: IzyTelColors.moov,
          ),
        ],
      ),
    );
  }
}

class _NetworkCapacityRow extends StatelessWidget {
  const _NetworkCapacityRow({
    required this.name,
    required this.asset,
    required this.amount,
    required this.tone,
  });

  final String name;
  final String asset;
  final int? amount;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final bool available = amount != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tone.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: IzyTelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available ? 'Disponible immédiatement' : 'Synchronisation…',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            available ? formatCfa(amount!) : '—',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: available ? tone : IzyTelColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityOrdersPanel extends StatelessWidget {
  const _PriorityOrdersPanel({required this.orders, this.onOpen});

  final List<PriorityOrder> orders;
  final ValueChanged<PriorityOrder>? onOpen;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        children: List<Widget>.generate(orders.length, (int index) {
          final PriorityOrder order = orders[index];
          return Column(
            children: <Widget>[
              _PriorityOrderRow(
                order: order,
                onTap: onOpen == null ? null : () => onOpen!(order),
              ),
              if (index < orders.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _PriorityOrderRow extends StatelessWidget {
  const _PriorityOrderRow({required this.order, this.onTap});

  final PriorityOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ({String asset, Color tone}) brand = _brand(order.channel);
    final ({String label, Color color}) status = _status(order.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: brand.tone.withAlpha(16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(brand.asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    order.operationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: IzyTelColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          order.phoneNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: IzyTelColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCfa(order.amount),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: IzyTelColors.primaryStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  IzyTelStatusPill(label: status.label, color: status.color),
                ],
              ),
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static ({String asset, Color tone}) _brand(ServiceChannel channel) {
    switch (channel) {
      case ServiceChannel.orange:
        return (
          asset: 'assets/brands/operators/orange_ci.png',
          tone: IzyTelColors.orange,
        );
      case ServiceChannel.mtn:
        return (
          asset: 'assets/brands/operators/mtn_ci.png',
          tone: IzyTelColors.mtnText,
        );
      case ServiceChannel.moov:
        return (
          asset: 'assets/brands/operators/moov_africa_ci.png',
          tone: IzyTelColors.moov,
        );
      case ServiceChannel.wave:
        return (
          asset: 'assets/images/wave_logo.png',
          tone: IzyTelColors.wave,
        );
    }
  }

  static ({String label, Color color}) _status(PriorityOrderStatus status) {
    switch (status) {
      case PriorityOrderStatus.urgent:
        return (label: 'Urgente', color: IzyTelColors.error);
      case PriorityOrderStatus.pendingVerification:
        return (label: 'Paiement à vérifier', color: IzyTelColors.warning);
      case PriorityOrderStatus.ready:
        return (label: 'Prête à traiter', color: IzyTelColors.primary);
      case PriorityOrderStatus.inProgress:
        return (label: 'En traitement', color: IzyTelColors.success);
    }
  }
}

class _PartialDataBanner extends StatelessWidget {
  const _PartialDataBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IzyTelColors.warning.withAlpha(45)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Symbols.info_rounded,
            size: 18,
            color: IzyTelColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentState extends StatelessWidget {
  const _EmptyRecentState();

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 18,
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: IzyTelColors.successSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Symbols.check_circle_rounded,
              color: IzyTelColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rien d’urgent pour le moment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: IzyTelColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 70),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 18,
      child: Column(
        children: <Widget>[
          const Icon(
            Symbols.cloud_off_rounded,
            size: 34,
            color: IzyTelColors.error,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
