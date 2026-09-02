import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/failed_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/firestore_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:firebase_core/firebase_core.dart';
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

    _supportRepository = Firebase.apps.isNotEmpty
        ? FirestoreSupportRequestRepository()
        : FakeSupportRequestRepository();
    _supportSubscription = _supportRepository.watchNewRequests().listen((
      List<SupportRequest> requests,
    ) {
      if (!mounted) return;
      setState(() => _customerRequestsCount = requests.length);
    }, onError: (_) {});

    _refundRepository = Firebase.apps.isNotEmpty
        ? FirestoreRefundRepository()
        : FakeRefundRepository();
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
    }, onError: (_) {});

    final OrderHistoryRepository? history = widget.orderHistoryRepository;
    if (history != null) {
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
      }, onError: (_) {});
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
          'Commande ${newest.reference} échouée : intervention Admin requise.',
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
          label: 'Administration',
          onTap: widget.onOpenMore!,
        ),
      if (widget.onOpenMore != null)
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _Header(
                    user: widget.user,
                    dateLabel: _formatCurrentDate(),
                    onAvatarTap: _openAccountSheet,
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.isLoading && data == null)
                    const _LoadingState()
                  else if (_viewModel.errorMessage != null && data == null)
                    _ErrorState(
                      message: _viewModel.errorMessage!,
                      onRetry: _viewModel.loadDashboard,
                    )
                  else if (data != null) ...[
                    _RevenueHero(
                      amount: data.todayRevenue,
                      percentage: data.revenueChangePercentage,
                    ),
                    const SizedBox(height: 20),
                    IzyTelSectionHeader(
                      title: 'À faire maintenant',
                      actionLabel: 'Voir tout',
                      onAction: widget.onOpenOrders,
                    ),
                    const SizedBox(height: 8),
                    IzyTelSurface(
                      padding: EdgeInsets.zero,
                      radius: 16,
                      child: Column(
                        children: [
                          _ActionRow(
                            icon: Symbols.receipt_long_rounded,
                            iconColor: IzyTelColors.warning,
                            title:
                                '${data.statistics.paymentsToVerify} paiements à vérifier',
                            onTap: widget.onOpenPayments ?? widget.onOpenOrders,
                          ),
                          const Divider(),
                          _ActionRow(
                            icon: Symbols.warning_rounded,
                            iconColor: data.statistics.unassignedOrders > 0
                                ? IzyTelColors.warning
                                : IzyTelColors.textMuted,
                            title: data.statistics.unassignedOrders > 0
                                ? '${data.statistics.unassignedOrders} commande${data.statistics.unassignedOrders > 1 ? 's' : ''} sans agent à vérifier'
                                : 'Aucune commande sans agent',
                            onTap: widget.onOpenOrders,
                          ),
                          const Divider(),
                          _ActionRow(
                            icon: Symbols.error_rounded,
                            iconColor: _failedOrders.isEmpty
                                ? IzyTelColors.textMuted
                                : IzyTelColors.error,
                            title: _failedOrders.isEmpty
                                ? 'Commandes échouées'
                                : '${_failedOrders.length} commande${_failedOrders.length > 1 ? 's' : ''} échouée${_failedOrders.length > 1 ? 's' : ''} à traiter',
                            onTap: _openFailedOrdersCenter,
                          ),
                          const Divider(),
                          _ActionRow(
                            icon: Symbols.person_rounded,
                            iconColor: IzyTelColors.orange,
                            title: '$_customerRequestsCount demandes client',
                            onTap: widget.onOpenMore,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const IzyTelSectionHeader(title: 'Activité du jour'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Payées',
                            value: data.statistics.newRequests.toString(),
                            color: IzyTelColors.success,
                            icon: Symbols.receipt_long_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'En cours',
                            value: data.statistics.inProgress.toString(),
                            color: IzyTelColors.warning,
                            icon: Symbols.autorenew_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Terminées',
                            value: data.statistics.completed.toString(),
                            color: IzyTelColors.primary,
                            icon: Symbols.check_circle_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    IzyTelSectionHeader(
                      title: 'Disponibilité réseau',
                      actionLabel: 'Voir tout',
                      onAction: widget.onOpenMore,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _NetworkCard(
                            name: 'Orange',
                            asset: 'assets/brands/operators/orange_ci.png',
                            color: IzyTelColors.orange,
                            balance: _balance(data, ServiceChannel.orange),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NetworkCard(
                            name: 'MTN',
                            asset: 'assets/brands/operators/mtn_ci.png',
                            color: IzyTelColors.mtn,
                            balance: _balance(data, ServiceChannel.mtn),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NetworkCard(
                            name: 'Moov',
                            asset: 'assets/brands/operators/moov_africa_ci.png',
                            color: IzyTelColors.moov,
                            balance: _balance(data, ServiceChannel.moov),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const IzyTelSectionHeader(title: 'Activité récente'),
                    const SizedBox(height: 8),
                    if (data.priorityOrders.isEmpty)
                      const _EmptyRecentState()
                    else
                      IzyTelSurface(
                        padding: EdgeInsets.zero,
                        radius: 16,
                        child: Column(
                          children: List<Widget>.generate(
                            data.priorityOrders.take(2).length,
                            (int index) {
                              final PriorityOrder order =
                                  data.priorityOrders[index];
                              return Column(
                                children: [
                                  _RecentActivityRow(
                                    order: order,
                                    onTap: widget.orderHistoryRepository == null
                                        ? null
                                        : () => _openRecentOrder(order),
                                  ),
                                  if (index <
                                      data.priorityOrders.take(2).length - 1)
                                    const Divider(),
                                ],
                              );
                            },
                          ),
                        ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${user.name.split(' ').first}👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IzyTelAvatar(
              name: user.name,
              initialsOverride: user.name.trim().isEmpty
                  ? '?'
                  : user.name.trim().substring(0, 1),
              onTap: onAvatarTap,
              size: 44,
            ),
            const SizedBox(width: 2),
            const Icon(
              Symbols.keyboard_arrow_down_rounded,
              size: IzyTelIconSize.info,
              color: IzyTelColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({required this.amount, required this.percentage});
  final int amount;
  final double? percentage;

  @override
  Widget build(BuildContext context) {
    final double? change = percentage;
    final bool positive = (change ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B63F0), Color(0xFF3157E0)],
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: IzyTelColors.primary.withAlpha(36),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encaissements aujourd’hui',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatCfaFull(amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: IzyTelColors.surface,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                if (change != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: positive
                          ? IzyTelColors.success
                          : IzyTelColors.error,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${positive ? '+' : ''}${change.toStringAsFixed(1)}% vs hier',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: IzyTelColors.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: IzyTelColors.surface.withAlpha(28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Symbols.wallet_rounded,
              color: IzyTelColors.surface,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: IzyTelIconSize.action),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.textPrimary,
                  fontSize: IzyTelTypeScale.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: IzyTelColors.textMuted,
              size: IzyTelIconSize.action,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 17,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w500,
              color: IzyTelColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: IzyTelColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.name,
    required this.asset,
    required this.color,
    required this.balance,
  });

  final String name;
  final String asset;
  final Color color;
  final int? balance;

  String get _status {
    if (balance == null) return 'À configurer...';
    if (balance! <= 5000) return 'Faible';
    return 'Disponible';
  }

  Color get _statusColor {
    if (balance == null) return IzyTelColors.textMuted;
    if (balance! <= 5000) return IzyTelColors.warning;
    return IzyTelColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 17,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: IzyTelColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _statusColor,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.order, this.onTap});

  final PriorityOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool readyToHandle = order.status == PriorityOrderStatus.ready;
    final Color color = readyToHandle
        ? IzyTelColors.primary
        : IzyTelColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: IzyTelColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                readyToHandle
                    ? Symbols.assignment_turned_in_rounded
                    : Symbols.inventory_2_rounded,
                size: 18,
                color: IzyTelColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.operationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IzyTelColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              readyToHandle
                  ? 'Traiter'
                  : (order.actionLabel.isEmpty ? 'Ouvrir' : order.actionLabel),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecentState extends StatelessWidget {
  const _EmptyRecentState();

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 15,
      child: Row(
        children: [
          const Icon(Symbols.check_circle_rounded, color: IzyTelColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucune activité récente pour le moment.',
              style: Theme.of(context).textTheme.bodyMedium,
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
      padding: EdgeInsets.symmetric(vertical: 90),
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
      child: Column(
        children: [
          const Icon(
            Symbols.cloud_off_rounded,
            color: IzyTelColors.error,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
