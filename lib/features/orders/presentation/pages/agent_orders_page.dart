import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_order_detail_view.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentOrdersPage extends StatefulWidget {
  const AgentOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    this.agentRepository,
    this.onOpenProfile,
    this.onOpenPerformance,
    this.onOpenCommissions,
    this.onLogout,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenPerformance;
  final VoidCallback? onOpenCommissions;
  final VoidCallback? onLogout;

  @override
  State<AgentOrdersPage> createState() => _AgentOrdersPageState();
}

class _AgentOrdersPageState extends State<AgentOrdersPage> {
  Timer? _clockTimer;
  late final AgentOrdersViewModel _viewModel;
  String? _openedOrderId;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _viewModel = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _accept(QueueOrder order) async {
    final bool success = await _viewModel.accept(order);
    if (!mounted) return;

    if (!success) {
      _showMessage(_viewModel.errorMessage ?? 'Acceptation impossible.');
      return;
    }

    final QueueOrder? acceptedOrder = _viewModel.orderById(order.id);
    bool started = false;
    if (acceptedOrder != null) {
      started = await _viewModel.startProcessing(acceptedOrder);
    }
    if (!mounted) return;

    setState(() {
      _openedOrderId = order.id;
    });
    _showMessage(
      started
          ? 'Commande ${order.reference} acceptée. Traitement démarré.'
          : 'Commande ${order.reference} acceptée. Ouvre le détail pour démarrer le traitement.',
    );
  }

  Future<void> _refuse(QueueOrder order) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RefusalReasonSheet(reference: order.reference),
    );

    if (reason == null || !mounted) return;
    if (!mounted) return;

    final bool success = await _viewModel.refuse(order, reason);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Commande ${order.reference} refusée et renvoyée pour réaffectation.'
          : _viewModel.errorMessage ?? 'Refus impossible.',
    );
  }

  void _openOrder(QueueOrder order) {
    setState(() {
      _openedOrderId = order.id;
    });
  }

  void _closeOrderDetail() {
    if (_openedOrderId == null) return;
    setState(() {
      _openedOrderId = null;
    });
  }

  void _showMessage(String message) {
    IzyTelFeedback.show(context, message);
  }

  void _openAccountMenu() {
    final AgentProfile? profile = _viewModel.agentProfile;
    showIzyTelAccountSheet(
      context: context,
      name: _viewModel.personalProfile?.displayName.isNotEmpty == true
          ? _viewModel.personalProfile!.displayName
          : widget.user.name,
      role: profile == null
          ? 'Agent IzyTel'
          : 'Agent • ${profile.availability.label}',
      actions: <IzyTelAccountAction>[
        if (widget.onOpenProfile != null)
          IzyTelAccountAction(
            icon: Symbols.person_rounded,
            label: 'Mon profil',
            onTap: widget.onOpenProfile!,
          ),
        if (widget.onOpenPerformance != null)
          IzyTelAccountAction(
            icon: Symbols.insights_rounded,
            label: 'Mes performances',
            onTap: widget.onOpenPerformance!,
          ),
        if (widget.onOpenCommissions != null)
          IzyTelAccountAction(
            icon: Symbols.account_balance_wallet_rounded,
            label: 'Mes commissions',
            onTap: widget.onOpenCommissions!,
          ),
        if (widget.onLogout != null)
          IzyTelAccountAction(
            icon: Symbols.logout_rounded,
            label: 'Se déconnecter',
            destructive: true,
            onTap: widget.onLogout!,
          ),
      ],
      avatarImageUrl: _viewModel.avatarUrl,
    );
  }

  Future<void> _openQueueModeMenu() async {
    final AgentOrdersTab? selected = await showModalBottomSheet<AgentOrdersTab>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Symbols.inbox_rounded),
                title: const Text('À accepter'),
                trailing: Text('${_viewModel.toAcceptCount}'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(AgentOrdersTab.toAccept),
              ),
              ListTile(
                leading: const Icon(Symbols.autorenew_rounded),
                title: const Text('En cours'),
                trailing: Text('${_viewModel.inProgressCount}'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(AgentOrdersTab.inProgress),
              ),
              ListTile(
                leading: const Icon(Symbols.check_circle_rounded),
                title: const Text('Terminées'),
                trailing: Text('${_viewModel.completedCount}'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(AgentOrdersTab.completed),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) _viewModel.selectTab(selected);
  }

  String _queueHeading(int count) {
    switch (_viewModel.selectedTab) {
      case AgentOrdersTab.toAccept:
        return '$count commande${count > 1 ? 's' : ''} à traiter';
      case AgentOrdersTab.inProgress:
        return '$count commande${count > 1 ? 's' : ''} en cours';
      case AgentOrdersTab.completed:
        return '$count commande${count > 1 ? 's' : ''} terminée${count > 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openedOrderId == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _openedOrderId != null) {
          _closeOrderDetail();
        }
      },
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (_, _) {
              final String? openedOrderId = _openedOrderId;
              if (openedOrderId != null) {
                final QueueOrder? openedOrder = _viewModel.orderById(
                  openedOrderId,
                );
                if (openedOrder != null) {
                  return AgentOrderDetailView(
                    user: widget.user,
                    order: openedOrder,
                    viewModel: _viewModel,
                    onBack: _closeOrderDetail,
                  );
                }
              }

              final List<QueueOrder> queue = _viewModel.visibleOrders;
              final AgentOrdersTab selectedTab = _viewModel.selectedTab;

              return RefreshIndicator(
                onRefresh: _viewModel.start,
                color: IzyTelColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  children: [
                    _AgentHeader(
                      user: widget.user,
                      profile: _viewModel.agentProfile,
                      personalProfile: _viewModel.personalProfile,
                      avatarUrl: _viewModel.avatarUrl,
                      onAvatarTap: _openAccountMenu,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _queueHeading(queue.length),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: IzyTelTypeScale.title2,
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.25,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Afficher une autre file',
                          onPressed: _openQueueModeMenu,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Symbols.tune_rounded,
                            size: IzyTelIconSize.action,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_viewModel.errorMessage != null) ...[
                      _AgentMessageCard(
                        icon: Symbols.error_rounded,
                        title: 'Impossible de charger la file',
                        message: _viewModel.errorMessage!,
                        color: IzyTelColors.error,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_viewModel.isLoading && queue.isEmpty)
                      const SizedBox(
                        height: 280,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (queue.isEmpty)
                      _AgentEmptyState(tab: selectedTab)
                    else if (selectedTab == AgentOrdersTab.toAccept)
                      ...List<Widget>.generate(queue.length, (int index) {
                        final QueueOrder order = queue[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PremiumAgentOrderCard(
                            order: order,
                            isBusy: _viewModel.busyOrderId == order.id,
                            queuePosition: index + 1,
                            showDecisionActions: true,
                            onAccept: () => _accept(order),
                            onRefuse: () => _refuse(order),
                            onOpen: () => _openOrder(order),
                          ),
                        );
                      })
                    else
                      ...queue.map(
                        (QueueOrder order) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AgentInProgressTile(
                            order: order,
                            onTap: () => _openOrder(order),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.user,
    required this.profile,
    required this.personalProfile,
    required this.avatarUrl,
    required this.onAvatarTap,
  });

  final AppUser user;
  final AgentProfile? profile;
  final AgentPersonalProfile? personalProfile;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  String get _displayName {
    final String candidate = personalProfile?.displayName.trim() ?? '';
    return candidate.isEmpty ? user.name : candidate;
  }

  @override
  Widget build(BuildContext context) {
    final bool available = profile?.availability == AgentAvailability.available;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                Symbols.notifications_rounded,
                size: IzyTelIconSize.action,
                color: IzyTelColors.textPrimary,
              ),
            ),
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: IzyTelColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${_displayName.split(' ').first} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: IzyTelTypeScale.title3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: available
                          ? IzyTelColors.success
                          : IzyTelColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile?.availability.label ?? 'Profil Agent',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: available
                          ? IzyTelColors.textPrimary
                          : IzyTelColors.textSecondary,
                      fontSize: IzyTelTypeScale.micro,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IzyTelAvatar(
              name: _displayName,
              imageUrl: avatarUrl,
              onTap: onAvatarTap,
              size: 38,
            ),
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

class _PremiumAgentOrderCard extends StatelessWidget {
  const _PremiumAgentOrderCard({
    required this.order,
    required this.isBusy,
    required this.queuePosition,
    required this.showDecisionActions,
    required this.onAccept,
    required this.onRefuse,
    required this.onOpen,
  });

  final QueueOrder order;
  final bool isBusy;
  final int? queuePosition;
  final bool showDecisionActions;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onOpen;

  Duration get _waiting {
    final DateTime since =
        order.paymentConfirmedAt ??
        order.paidAt ??
        order.assignedAt ??
        order.createdAt;
    final Duration value = DateTime.now().difference(since);
    return value.isNegative ? Duration.zero : value;
  }

  String get _waitingLabel {
    final Duration wait = _waiting;
    if (wait.inHours > 0) {
      return 'Depuis ${wait.inHours} h ${wait.inMinutes.remainder(60)} min';
    }
    return 'Depuis ${wait.inMinutes} min';
  }

  Color get _priorityColor {
    return switch (queuePosition ?? 3) {
      1 => IzyTelColors.error,
      2 => IzyTelColors.warning,
      _ => IzyTelColors.primary,
    };
  }

  Color get _networkColor => switch (order.network) {
    MobileNetwork.orange => IzyTelColors.orange,
    MobileNetwork.mtn => IzyTelColors.mtn,
    MobileNetwork.moov => IzyTelColors.moov,
  };

  @override
  Widget build(BuildContext context) {
    final Color priorityColor = _priorityColor;
    final bool isCritical = queuePosition == 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: priorityColor.withAlpha(isCritical ? 125 : 70),
            ),
            boxShadow: const [
              BoxShadow(
                color: IzyTelColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (queuePosition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'PRIORITÉ $queuePosition',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: priorityColor,
                              fontSize: IzyTelTypeScale.micro,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _waitingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isCritical
                                  ? IzyTelColors.error
                                  : IzyTelColors.textMuted,
                              fontSize: IzyTelTypeScale.micro,
                              fontWeight: isCritical
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _networkColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Image.asset(
                      networkAsset(order.network),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          networkLabel(order.network),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: IzyTelColors.textPrimary,
                                fontSize: IzyTelTypeScale.label,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.offerLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: IzyTelColors.textPrimary,
                                fontSize: IzyTelTypeScale.cardTitle,
                                height: 1.20,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      formatIvorianPhone(order.beneficiaryPhone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontSize: IzyTelTypeScale.transactionNumber,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .08,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatCfa(order.amount),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: IzyTelColors.primaryStrong,
                      fontSize: IzyTelTypeScale.money,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: IzyTelStatusPill(
                  label: order.isCreditSale
                      ? 'Crédit autorisé'
                      : (order.paymentStatus == OrderPaymentStatus.confirmed
                            ? 'Paiement confirmé'
                            : orderStatusLabel(order.status)),
                  color: order.isCreditSale
                      ? IzyTelColors.warning
                      : (order.paymentStatus == OrderPaymentStatus.confirmed
                            ? IzyTelColors.success
                            : switch (order.status) {
                                QueueOrderStatus.completed ||
                                QueueOrderStatus.refunded =>
                                  IzyTelColors.success,
                                QueueOrderStatus.failed ||
                                QueueOrderStatus.cancelled =>
                                  IzyTelColors.error,
                                QueueOrderStatus.onHold ||
                                QueueOrderStatus.refundPending =>
                                  IzyTelColors.warning,
                                _ => IzyTelColors.primary,
                              }),
                ),
              ),
              if (showDecisionActions) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onAccept,
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: IzyTelColors.surface,
                            ),
                          )
                        : const Icon(
                            Symbols.check_rounded,
                            size: IzyTelIconSize.info,
                          ),
                    label: Text(
                      isBusy ? 'Traitement...' : 'Accepter',
                      style: const TextStyle(
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentInProgressTile extends StatelessWidget {
  const _AgentInProgressTile({required this.order, required this.onTap});

  final QueueOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (order.network) {
      MobileNetwork.orange => IzyTelColors.orange,
      MobileNetwork.mtn => IzyTelColors.mtn,
      MobileNetwork.moov => IzyTelColors.moov,
    };
    final (String statusLabel, Color statusColor) = switch (order.status) {
      QueueOrderStatus.completed => ('Terminée', IzyTelColors.success),
      QueueOrderStatus.failed => ('Échouée', IzyTelColors.error),
      QueueOrderStatus.refunded => ('Remboursée', IzyTelColors.success),
      QueueOrderStatus.onHold => ('En attente', IzyTelColors.warning),
      QueueOrderStatus.awaitingCustomerConfirmation => (
        'Terminée',
        IzyTelColors.success,
      ),
      _ => ('En traitement', IzyTelColors.primary),
    };

    return IzyTelSurface(
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Image.asset(
                  networkAsset(order.network),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  networkLabel(order.network),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IzyTelStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.offerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.title3,
              height: 1.18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.phone_iphone_rounded,
                  size: IzyTelIconSize.info,
                  color: IzyTelColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    formatIvorianPhone(order.beneficiaryPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.title3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCfa(order.amount),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.primaryStrong,
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Symbols.chevron_right_rounded,
                  size: IzyTelIconSize.action,
                  color: IzyTelColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentEmptyState extends StatelessWidget {
  const _AgentEmptyState({required this.tab});
  final AgentOrdersTab tab;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    switch (tab) {
      case AgentOrdersTab.toAccept:
        title = 'Aucune commande à accepter';
        message = 'Les nouvelles commandes affectées apparaîtront ici.';
        break;
      case AgentOrdersTab.inProgress:
        title = 'Aucune commande en cours';
        message =
            'Une commande acceptée apparaîtra ici pendant son traitement.';
        break;
      case AgentOrdersTab.completed:
        title = 'Aucune commande terminée';
        message = 'Tes dernières opérations terminées apparaîtront ici.';
        break;
    }
    return _AgentMessageCard(
      icon: Symbols.inbox_rounded,
      title: title,
      message: message,
      color: IzyTelColors.primary,
    );
  }
}

class _AgentMessageCard extends StatelessWidget {
  const _AgentMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RefusalReasonSheet extends StatefulWidget {
  const _RefusalReasonSheet({required this.reference});

  final String reference;

  @override
  State<_RefusalReasonSheet> createState() => _RefusalReasonSheetState();
}

class _RefusalReasonSheetState extends State<_RefusalReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < 3) {
      setState(() {
        _error = 'Précise la raison du refus.';
      });
      return;
    }
    if (value.length > 500) {
      setState(() {
        _error = 'Le motif ne doit pas dépasser 500 caractères.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return _AgentOrdersBottomSheetContainer(
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Refuser la commande',
                  style: TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.title2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.close_rounded),
                color: IzyTelColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.reference} sera renvoyée dans le circuit de réaffectation.',
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            cursorColor: IzyTelColors.primary,
            style: const TextStyle(
              color: IzyTelColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: _agentInputDecoration(
              labelText: 'Motif du refus',
              hintText: 'Ex. capacité insuffisante ou réseau indisponible…',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error == null) return;
              setState(() {
                _error = null;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: IzyTelColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmer le refus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentOrdersBottomSheetContainer extends StatelessWidget {
  const _AgentOrdersBottomSheetContainer({
    required this.child,
    required this.bottomInset,
  });

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Container(
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

InputDecoration _agentInputDecoration({
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  const BorderRadius radius = BorderRadius.all(Radius.circular(12));

  return InputDecoration(
    filled: true,
    fillColor: IzyTelColors.surfaceMuted,
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    labelStyle: const TextStyle(color: IzyTelColors.textSecondary),
    floatingLabelStyle: const TextStyle(color: IzyTelColors.primary),
    hintStyle: const TextStyle(color: IzyTelColors.textSecondary),
    counterStyle: const TextStyle(color: IzyTelColors.textSecondary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.outline),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.outline),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.primary, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.error, width: 1.5),
    ),
  );
}
