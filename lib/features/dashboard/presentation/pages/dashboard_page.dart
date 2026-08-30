import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.dashboardRepository,
    this.onOpenOrders,
    this.onOpenMore,
    this.onLogout,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenMore;
  final VoidCallback? onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardViewModel _viewModel;
  late final SupportRequestRepository _supportRepository;
  StreamSubscription<List<SupportRequest>>? _supportSubscription;
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
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
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
          label: 'Mon espace administrateur',
          onTap: widget.onOpenMore!,
        ),
      if (widget.onOpenMore != null)
        IzyTelAccountAction(
          icon: Symbols.settings_rounded,
          label: 'Paramètres et administration',
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
                            onTap: widget.onOpenOrders,
                          ),
                          const Divider(),
                          _ActionRow(
                            icon: Symbols.inventory_2_rounded,
                            iconColor: IzyTelColors.primary,
                            title:
                                '${data.statistics.newRequests} commandes à affecter',
                            onTap: widget.onOpenOrders,
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
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'En cours',
                            value: data.statistics.inProgress.toString(),
                            color: IzyTelColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Terminées',
                            value: data.statistics.completed.toString(),
                            color: IzyTelColors.primary,
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
                                  _RecentActivityRow(order: order),
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
                'Bonjour ${user.name.split(' ').first} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: IzyTelTypeScale.title2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: IzyTelColors.textSecondary,
                  fontSize: IzyTelTypeScale.label,
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
              size: 38,
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
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E72EE), Color(0xFF1565E8)],
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x242563EB),
            blurRadius: 22,
            offset: Offset(0, 9),
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
                    color: Colors.white,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatCfaFull(amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontSize: IzyTelTypeScale.title1,
                    fontWeight: FontWeight.w700,
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
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${positive ? '+' : ''}${change.toStringAsFixed(1)}%  vs hier',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontSize: IzyTelTypeScale.micro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Symbols.wallet_rounded,
              color: Colors.white,
              size: IzyTelIconSize.navigation,
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
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: IzyTelIconSize.action),
            ),
            const SizedBox(width: 10),
            Expanded(
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
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 15,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: IzyTelTypeScale.title2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
    if (balance == null) return 'À configurer';
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
      radius: 15,
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withAlpha(16),
              borderRadius: BorderRadius.circular(8),
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
  const _RecentActivityRow({required this.order});

  final PriorityOrder order;

  @override
  Widget build(BuildContext context) {
    final bool confirmed = order.status == PriorityOrderStatus.ready;
    final Color color = confirmed ? IzyTelColors.success : IzyTelColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              confirmed
                  ? Symbols.wallet_rounded
                  : Symbols.assignment_turned_in_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmed ? 'Paiement confirmé' : order.operationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: IzyTelTypeScale.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textMuted,
                    fontSize: IzyTelTypeScale.micro,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            confirmed ? '+${formatCfa(order.amount)}' : order.actionLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: confirmed ? IzyTelColors.success : IzyTelColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: IzyTelTypeScale.micro,
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
