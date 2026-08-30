import 'package:cabine_flow/core/theme/izytel_colors.dart';
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
import 'package:flutter/material.dart';

class AgentOrdersPage extends StatefulWidget {
  const AgentOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    this.agentRepository,
    this.onOpenProfile,
    this.onLogout,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;

  @override
  State<AgentOrdersPage> createState() => _AgentOrdersPageState();
}

class _AgentOrdersPageState extends State<AgentOrdersPage> {
  late final AgentOrdersViewModel _viewModel;
  String? _openedOrderId;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openAccountMenu() {
    final AgentProfile? profile = _viewModel.agentProfile;
    showIzyTelAccountSheet(
      context: context,
      name: widget.user.name,
      role: profile == null
          ? 'Agent IzyTel'
          : 'Agent • ${profile.availability.label}',
      actions: <IzyTelAccountAction>[
        if (widget.onOpenProfile != null)
          IzyTelAccountAction(
            icon: Icons.person_outline_rounded,
            label: 'Mon profil',
            onTap: widget.onOpenProfile!,
          ),
        if (widget.onOpenProfile != null)
          IzyTelAccountAction(
            icon: Icons.insights_outlined,
            label: 'Mes performances et commissions',
            onTap: widget.onOpenProfile!,
          ),
        if (widget.onLogout != null)
          IzyTelAccountAction(
            icon: Icons.logout_rounded,
            label: 'Se déconnecter',
            destructive: true,
            onTap: widget.onLogout!,
          ),
      ],
    );
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

              final List<QueueOrder> queue = _viewModel.toAcceptOrders;
              final List<QueueOrder> inProgress = _viewModel.inProgressOrders;

              return RefreshIndicator(
                onRefresh: _viewModel.start,
                color: IzyTelColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                  children: [
                    _AgentHeader(
                      user: widget.user,
                      profile: _viewModel.agentProfile,
                      onAvatarTap: _openAccountMenu,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mes commandes',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AgentTabs(
                      selectedTab: _viewModel.selectedTab,
                      toAcceptCount: queue.length,
                      inProgressCount: inProgress.length,
                      completedCount: _viewModel.completedOrders.length,
                      onChanged: _viewModel.selectTab,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${queue.length} commande${queue.length > 1 ? 's' : ''} à traiter',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualiser',
                          onPressed: _viewModel.start,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.tune_rounded, size: 19),
                        ),
                      ],
                    ),
                    if (_viewModel.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      _AgentMessageCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Une action n’a pas abouti',
                        message: _viewModel.errorMessage!,
                        color: IzyTelColors.error,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_viewModel.isLoading && queue.isEmpty)
                      const SizedBox(
                        height: 280,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (queue.isEmpty)
                      const _AgentEmptyState(tab: AgentOrdersTab.toAccept)
                    else
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
                      }),
                    if (inProgress.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Commandes en cours',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${inProgress.length}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: IzyTelColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...inProgress.map(
                        (QueueOrder order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AgentInProgressTile(
                            order: order,
                            onTap: () => _openOrder(order),
                          ),
                        ),
                      ),
                    ],
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
    required this.onAvatarTap,
  });

  final AppUser user;
  final AgentProfile? profile;
  final VoidCallback onAvatarTap;

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
              width: 31,
              height: 31,
              child: Icon(
                Icons.notifications_none_rounded,
                size: 21,
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${user.name.split(' ').first} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
            IzyTelAvatar(name: user.name, onTap: onAvatarTap, size: 36),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: IzyTelColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _AgentTabs extends StatelessWidget {
  const _AgentTabs({
    required this.selectedTab,
    required this.toAcceptCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.onChanged,
  });

  final AgentOrdersTab selectedTab;
  final int toAcceptCount;
  final int inProgressCount;
  final int completedCount;
  final ValueChanged<AgentOrdersTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AgentTabChip(
            label: 'À accepter',
            count: toAcceptCount,
            selected: selectedTab == AgentOrdersTab.toAccept,
            onTap: () => onChanged(AgentOrdersTab.toAccept),
          ),
          const SizedBox(width: 8),
          _AgentTabChip(
            label: 'En cours',
            count: inProgressCount,
            selected: selectedTab == AgentOrdersTab.inProgress,
            onTap: () => onChanged(AgentOrdersTab.inProgress),
          ),
          const SizedBox(width: 8),
          _AgentTabChip(
            label: 'Terminées',
            count: completedCount,
            selected: selectedTab == AgentOrdersTab.completed,
            onTap: () => onChanged(AgentOrdersTab.completed),
          ),
        ],
      ),
    );
  }
}

class _AgentTabChip extends StatelessWidget {
  const _AgentTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IzyTelColors.primary : IzyTelColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? IzyTelColors.primary : IzyTelColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : IzyTelColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(38)
                      : IzyTelColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : IzyTelColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final Color network = networkColor(order.network);
    final bool first = queuePosition == 1;
    final Color priorityColor = first
        ? IzyTelColors.error
        : IzyTelColors.warning;

    return Material(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: first
                  ? IzyTelColors.error.withAlpha(115)
                  : IzyTelColors.outline,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (queuePosition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'PRIORITÉ $queuePosition',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: priorityColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _waitingLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: first
                          ? IzyTelColors.error
                          : IzyTelColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: network.withAlpha(16),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Image.asset(
                      networkAsset(order.network),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          networkLabel(order.network),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: IzyTelColors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.offerLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.beneficiaryPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatCfa(order.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: IzyTelColors.primaryStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: IzyTelStatusPill(
                  label: order.paymentStatus == OrderPaymentStatus.confirmed
                      ? 'Paiement confirmé'
                      : orderStatusLabel(order.status),
                  color: order.paymentStatus == OrderPaymentStatus.confirmed
                      ? IzyTelColors.success
                      : orderStatusColor(order.status),
                ),
              ),
              if (showDecisionActions) ...[
                const SizedBox(height: 11),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      isBusy ? 'Traitement...' : 'Accepter',
                      style: const TextStyle(fontSize: 10.5),
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
    return IzyTelSurface(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: networkColor(order.network).withAlpha(16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              networkAsset(order.network),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.offerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  order.beneficiaryPhone,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: IzyTelColors.textMuted,
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
      icon: Icons.inbox_outlined,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: IzyTelColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.reference} sera renvoyée dans le circuit de réaffectation.',
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 13,
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
