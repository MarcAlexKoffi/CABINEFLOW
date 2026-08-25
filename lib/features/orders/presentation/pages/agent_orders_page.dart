import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/material.dart';

class AgentOrdersPage extends StatefulWidget {
  const AgentOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;

  @override
  State<AgentOrdersPage> createState() => _AgentOrdersPageState();
}

class _AgentOrdersPageState extends State<AgentOrdersPage> {
  late final AgentOrdersViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
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
    _showMessage(
      success
          ? 'Commande ${order.reference} acceptée.'
          : _viewModel.errorMessage ?? 'Acceptation impossible.',
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _Header(user: widget.user),
                  const SizedBox(height: 22),
                  const Text(
                    'Mes commandes',
                    style: TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Retrouve uniquement les commandes qui te sont affectées.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _OrdersTabs(
                    selectedTab: _viewModel.selectedTab,
                    toAcceptCount: _viewModel.toAcceptCount,
                    inProgressCount: _viewModel.inProgressCount,
                    completedCount: _viewModel.completedCount,
                    onChanged: _viewModel.selectTab,
                  ),
                  const SizedBox(height: 18),
                  if (_viewModel.errorMessage != null) ...[
                    _MessageCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Une action n’a pas abouti',
                      message: _viewModel.errorMessage!,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_viewModel.isLoading && _viewModel.visibleOrders.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.visibleOrders.isEmpty)
                    _EmptyState(tab: _viewModel.selectedTab)
                  else
                    ..._viewModel.visibleOrders.map((QueueOrder order) {
                      final bool isBusy = _viewModel.busyOrderId == order.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AgentOrderCard(
                          order: order,
                          isBusy: isBusy,
                          showDecisionActions:
                              _viewModel.selectedTab == AgentOrdersTab.toAccept,
                          onAccept: () => _accept(order),
                          onRefuse: () => _refuse(order),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final String cleaned = user.name.trim();
    final String initial = cleaned.isEmpty ? '?' : cleaned[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withAlpha(35),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Espace Agent',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.receipt_long_rounded,
          color: AppColors.primaryContainer,
        ),
      ],
    );
  }
}

class _OrdersTabs extends StatelessWidget {
  const _OrdersTabs({
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'À accepter',
              count: toAcceptCount,
              color: AppColors.warning,
              isSelected: selectedTab == AgentOrdersTab.toAccept,
              onTap: () => onChanged(AgentOrdersTab.toAccept),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'En cours',
              count: inProgressCount,
              color: AppColors.primary,
              isSelected: selectedTab == AgentOrdersTab.inProgress,
              onTap: () => onChanged(AgentOrdersTab.inProgress),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Terminées',
              count: completedCount,
              color: AppColors.success,
              isSelected: selectedTab == AgentOrdersTab.completed,
              onTap: () => onChanged(AgentOrdersTab.completed),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(bottom: BorderSide(color: color, width: 3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? color : AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withAlpha(35)
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? color : AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _AgentOrderCard extends StatelessWidget {
  const _AgentOrderCard({
    required this.order,
    required this.isBusy,
    required this.showDecisionActions,
    required this.onAccept,
    required this.onRefuse,
  });

  final QueueOrder order;
  final bool isBusy;
  final bool showDecisionActions;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final Color accent = networkColor(order.network);

    // Important : le liseré réseau n'est pas dessiné avec un Border non
    // uniforme + borderRadius. Cette combinaison peut provoquer une erreur de
    // peinture et remplacer toute la carte par un ErrorWidget vide/sombre sur
    // l'appareil. Le liseré est donc un calque interne, tandis que la bordure
    // externe reste uniforme.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        networkLabel(order.network),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  order.offerLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Bénéficiaire : ${order.beneficiaryPhone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Info(
                        label: 'MONTANT',
                        value: formatCfa(order.amount),
                        valueColor: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Info(label: 'CLIENT', value: order.clientName),
                    ),
                  ],
                ),
                if (!showDecisionActions) ...[
                  const SizedBox(height: 12),
                  _StatusLine(order: order),
                ],
                if (showDecisionActions) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isBusy ? null : onRefuse,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: const Text('Refuser'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isBusy ? null : onAccept,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Text('Accepter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? AppColors.onBackground,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final bool acceptedReady =
        order.assignmentStatus == OrderAssignmentStatus.accepted &&
        order.status == QueueOrderStatus.paidReady;
    final Color color = acceptedReady
        ? AppColors.primary
        : orderStatusColor(order.status);
    final IconData icon = acceptedReady
        ? Icons.check_circle_outline_rounded
        : orderStatusIcon(order.status);
    final String label = acceptedReady
        ? 'Commande acceptée'
        : orderStatusLabel(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final AgentOrdersTab tab;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    late final IconData icon;

    switch (tab) {
      case AgentOrdersTab.toAccept:
        title = 'Aucune commande à accepter';
        message =
            'Les nouvelles commandes qui te sont affectées apparaîtront ici.';
        icon = Icons.inbox_outlined;
        break;
      case AgentOrdersTab.inProgress:
        title = 'Aucune commande en cours';
        message =
            'Une commande acceptée passera automatiquement dans cet onglet.';
        icon = Icons.autorenew_rounded;
        break;
      case AgentOrdersTab.completed:
        title = 'Aucune commande terminée';
        message = 'Les commandes clôturées apparaîtront ici.';
        icon = Icons.task_alt_rounded;
        break;
    }

    return _MessageCard(
      icon: icon,
      title: title,
      message: message,
      color: AppColors.primaryContainer,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
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
                    color: AppColors.onBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.reference} sera renvoyée dans le circuit de réaffectation.',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
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
            cursorColor: AppColors.primary,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w500,
            ),
            decoration: _darkAgentInputDecoration(
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
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onError,
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
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outlineVariant),
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

InputDecoration _darkAgentInputDecoration({
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  const BorderRadius radius = BorderRadius.all(Radius.circular(12));

  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceContainerHigh,
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    floatingLabelStyle: const TextStyle(color: AppColors.primaryContainer),
    hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    counterStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}
