import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/order_history_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.onBack,
    required this.onOpenOrder,
    this.initialSearchQuery = '',
    this.initialFilters = const OrderHistoryFilters(),
    this.openFiltersOnStart = false,
  });

  final AppUser user;
  final OrderHistoryRepository ordersRepository;
  final VoidCallback onBack;
  final void Function(
    QueueOrder order,
    String searchQuery,
    OrderHistoryFilters filters,
  )
  onOpenOrder;
  final String initialSearchQuery;
  final OrderHistoryFilters initialFilters;
  final bool openFiltersOnStart;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late final OrderHistoryViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _viewModel = OrderHistoryViewModel(
      ordersRepository: widget.ordersRepository,
      initialSearchQuery: widget.initialSearchQuery,
      initialFilters: widget.initialFilters,
    );
    _viewModel.startRealtime();

    if (widget.openFiltersOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFilters();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final OrderHistoryFilters? filters =
        await showModalBottomSheet<OrderHistoryFilters>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext sheetContext) {
            return _OrderHistoryFilterSheet(
              initialFilters: _viewModel.filters,
              operatorIds: _viewModel.operatorIds,
              currentUser: widget.user,
            );
          },
        );

    if (filters != null) _viewModel.applyFilters(filters);
  }

  void _clearSearch() {
    _searchController.clear();
    _viewModel.updateSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final List<QueueOrder> orders = _viewModel.visibleOrders;
        final int total = _viewModel.filteredOrders.length;

        return Scaffold(
          backgroundColor: IzyTelColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _HistoryTopBar(user: widget.user, onBack: widget.onBack),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _viewModel.loadHistory,
                    color: IzyTelColors.primary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        const IzyTelPageHeader(
                          title: 'Historique des commandes',
                          subtitle:
                              'Retrouve rapidement une ancienne transaction, puis ouvre son détail complet.',
                        ),
                        const SizedBox(height: IzyTelSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: IzyTelSearchField(
                                controller: _searchController,
                                hintText: 'Référence, client, numéro, offre…',
                                onChanged: _viewModel.updateSearchQuery,
                                onClear: _clearSearch,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FilterButton(
                              count: _viewModel.filters.activeFilterCount,
                              onTap: _openFilters,
                            ),
                          ],
                        ),
                        if (!_viewModel.filters.isEmpty) ...[
                          const SizedBox(height: IzyTelSpacing.sm),
                          _ActiveFilters(
                            filters: _viewModel.filters,
                            onChanged: _viewModel.applyFilters,
                            onClearAll: _viewModel.clearAllFilters,
                          ),
                        ],
                        const SizedBox(height: IzyTelSpacing.lg),
                        _HistorySummary(total: total),
                        const SizedBox(height: IzyTelSpacing.sm),
                        if (_viewModel.isLoading && !_viewModel.hasLoadedOrders)
                          const SizedBox(
                            height: 320,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_viewModel.errorMessage != null)
                          _HistoryErrorState(
                            message: _viewModel.errorMessage!,
                            onRetry: _viewModel.loadHistory,
                          )
                        else if (orders.isEmpty)
                          const _HistoryEmptyState()
                        else ...[
                          ...orders.map(
                            (QueueOrder order) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderHistoryCard(
                                order: order,
                                currentUser: widget.user,
                                onPressed: () {
                                  widget.onOpenOrder(
                                    order,
                                    _viewModel.searchQuery,
                                    _viewModel.filters,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_viewModel.canLoadMore) ...[
                            const SizedBox(height: 4),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _viewModel.loadMore,
                                icon: const Icon(
                                  Symbols.expand_more_rounded,
                                  size: 19,
                                ),
                                label: const Text('Charger plus'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTopBar extends StatelessWidget {
  const _HistoryTopBar({required this.user, required this.onBack});

  final AppUser user;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(bottom: BorderSide(color: IzyTelColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour aux commandes',
            onPressed: onBack,
            icon: const Icon(Symbols.arrow_back_rounded),
            color: IzyTelColors.textPrimary,
          ),
          const SizedBox(width: 2),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Symbols.history_rounded,
              color: IzyTelColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Historique',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IzyTelAvatar(name: user.name, size: 38),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filtres',
      child: SizedBox(
        width: 54,
        height: 52,
        child: Material(
          color: count > 0 ? IzyTelColors.primarySoft : IzyTelColors.surface,
          borderRadius: BorderRadius.circular(IzyTelRadii.input),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(IzyTelRadii.input),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(IzyTelRadii.input),
                border: Border.all(
                  color: count > 0
                      ? IzyTelColors.primary
                      : IzyTelColors.outlineStrong,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Symbols.tune_rounded,
                    color: count > 0
                        ? IzyTelColors.primary
                        : IzyTelColors.textSecondary,
                    size: 22,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: IzyTelColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$total commande${total > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: IzyTelColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(
          Symbols.swap_vert_rounded,
          color: IzyTelColors.primary,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          'Plus récentes',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: IzyTelColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({
    required this.order,
    required this.currentUser,
    required this.onPressed,
  });

  final QueueOrder order;
  final AppUser currentUser;
  final VoidCallback onPressed;

  String get operatorLabel {
    final String operatorId = order.takenByUserId?.trim() ?? '';
    if (operatorId.isEmpty) return 'Non attribuée';
    return operatorId == currentUser.id
        ? currentUser.name
        : compactOperatorLabel(operatorId);
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(order.status);
    final Color networkAccent = _networkColor(order.network);

    return IzyTelSurface(
      onTap: onPressed,
      radius: 16,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: networkAccent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 13, 13, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _NetworkLogo(network: order.network),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        networkLabel(order.network),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HistoryStatusPill(
                      label: _compactStatusLabel(order.status),
                      color: statusColor,
                      icon: _statusIcon(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.offerLabel.trim().isEmpty
                      ? operationTypeLabel(order.operationType)
                      : order.offerLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Symbols.phone_iphone_rounded,
                      size: 18,
                      color: IzyTelColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatIvorianPhone(order.beneficiaryPhone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.transactionNumber,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .1,
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatOrderDateTime(order.createdAt)} · $operatorLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: IzyTelColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 108),
                      child: Text(
                        order.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: IzyTelColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Symbols.chevron_right_rounded,
                      color: IzyTelColors.textMuted,
                      size: 19,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _networkSoftColor(network),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(_networkBrandAsset(network), fit: BoxFit.contain),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filters,
    required this.onChanged,
    required this.onClearAll,
  });

  final OrderHistoryFilters filters;
  final ValueChanged<OrderHistoryFilters> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[];

    if (filters.period != OrderHistoryPeriod.all) {
      chips.add(
        _FilterSummaryChip(
          label: historyPeriodLabel(filters.period),
          onDeleted: () {
            onChanged(filters.copyWith(period: OrderHistoryPeriod.all));
          },
        ),
      );
    }

    for (final OrderHistoryStateFilter state in filters.states) {
      chips.add(
        _FilterSummaryChip(
          label: historyStateLabel(state),
          onDeleted: () {
            final Set<OrderHistoryStateFilter> states =
                Set<OrderHistoryStateFilter>.from(filters.states)
                  ..remove(state);
            onChanged(filters.copyWith(states: states));
          },
        ),
      );
    }

    for (final MobileNetwork network in filters.networks) {
      chips.add(
        _FilterSummaryChip(
          label: networkLabel(network),
          accent: _networkColor(network),
          onDeleted: () {
            final Set<MobileNetwork> networks = Set<MobileNetwork>.from(
              filters.networks,
            )..remove(network);
            onChanged(filters.copyWith(networks: networks));
          },
        ),
      );
    }

    if (filters.minimumAmount != null || filters.maximumAmount != null) {
      final String minimum = filters.minimumAmount?.toString() ?? '0';
      final String maximum = filters.maximumAmount?.toString() ?? '∞';
      chips.add(
        _FilterSummaryChip(
          label: '$minimum–$maximum F',
          onDeleted: () {
            onChanged(
              filters.copyWith(
                clearMinimumAmount: true,
                clearMaximumAmount: true,
              ),
            );
          },
        ),
      );
    }

    if (filters.operatorId?.trim().isNotEmpty == true) {
      chips.add(
        _FilterSummaryChip(
          label: 'Op. ${compactOperatorLabel(filters.operatorId)}',
          onDeleted: () {
            onChanged(filters.copyWith(clearOperatorId: true));
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 7, runSpacing: 7, children: chips),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Symbols.filter_alt_off_rounded, size: 16),
          label: const Text('Effacer tous les filtres'),
        ),
      ],
    );
  }
}

class _FilterSummaryChip extends StatelessWidget {
  const _FilterSummaryChip({
    required this.label,
    required this.onDeleted,
    this.accent = IzyTelColors.primary,
  });

  final String label;
  final VoidCallback onDeleted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withAlpha(14),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 5, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withAlpha(45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Symbols.close_rounded, size: 14, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: IzyTelColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Symbols.history_toggle_off_rounded,
                size: 30,
                color: IzyTelColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucune commande trouvée',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Modifie la recherche ou les filtres pour afficher davantage de résultats.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      borderColor: IzyTelColors.error.withAlpha(75),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            const Icon(
              Symbols.cloud_off_rounded,
              size: 34,
              color: IzyTelColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryFilterSheet extends StatefulWidget {
  const _OrderHistoryFilterSheet({
    required this.initialFilters,
    required this.operatorIds,
    required this.currentUser,
  });

  final OrderHistoryFilters initialFilters;
  final List<String> operatorIds;
  final AppUser currentUser;

  @override
  State<_OrderHistoryFilterSheet> createState() =>
      _OrderHistoryFilterSheetState();
}

class _OrderHistoryFilterSheetState extends State<_OrderHistoryFilterSheet> {
  late OrderHistoryPeriod _period;
  late Set<OrderHistoryStateFilter> _states;
  late Set<MobileNetwork> _networks;
  late TextEditingController _minimumController;
  late TextEditingController _maximumController;
  String? _operatorId;

  @override
  void initState() {
    super.initState();
    final OrderHistoryFilters filters = widget.initialFilters;
    _period = filters.period;
    _states = Set<OrderHistoryStateFilter>.from(filters.states);
    _networks = Set<MobileNetwork>.from(filters.networks);
    _minimumController = TextEditingController(
      text: filters.minimumAmount?.toString() ?? '',
    );
    _maximumController = TextEditingController(
      text: filters.maximumAmount?.toString() ?? '',
    );
    _operatorId = filters.operatorId;
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _period = OrderHistoryPeriod.all;
      _states.clear();
      _networks.clear();
      _minimumController.clear();
      _maximumController.clear();
      _operatorId = null;
    });
  }

  void _apply() {
    final int? minimum = int.tryParse(
      _minimumController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final int? maximum = int.tryParse(
      _maximumController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    if (minimum != null && maximum != null && minimum > maximum) {
      IzyTelFeedback.show(
        context,
        'Le montant minimum dépasse le montant maximum.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }

    Navigator.of(context).pop(
      OrderHistoryFilters(
        period: _period,
        states: Set<OrderHistoryStateFilter>.unmodifiable(_states),
        networks: Set<MobileNetwork>.unmodifiable(_networks),
        minimumAmount: minimum,
        maximumAmount: maximum,
        operatorId: _operatorId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> effectiveOperatorIds = <String>{
      ...widget.operatorIds,
      if (_operatorId?.trim().isNotEmpty == true) _operatorId!,
    }.toList()..sort();

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double availableHeight =
        MediaQuery.sizeOf(context).height - keyboardInset;
    final double height = availableHeight * .90;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(10, 10, 10, keyboardInset),
      child: SizedBox(
        height: height,
        child: Material(
          color: IzyTelColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(IzyTelRadii.sheet),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 9),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: IzyTelColors.outlineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtres de l’historique',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Affiner les résultats sans perdre ta recherche.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: IzyTelColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FilterSectionLabel(
                        icon: Symbols.calendar_month_rounded,
                        text: 'Période',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OrderHistoryPeriod.values.map((period) {
                          return _ChoicePill(
                            label: historyPeriodLabel(period),
                            selected: _period == period,
                            onTap: () => setState(() => _period = period),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const _FilterSectionLabel(
                        icon: Symbols.fact_check_rounded,
                        text: 'État de la commande',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OrderHistoryStateFilter.values.map((state) {
                          final bool selected = _states.contains(state);
                          final Color color = _stateFilterColor(state);
                          return _ChoicePill(
                            label: historyStateLabel(state),
                            selected: selected,
                            accent: color,
                            onTap: () {
                              setState(() {
                                selected
                                    ? _states.remove(state)
                                    : _states.add(state);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const _FilterSectionLabel(
                        icon: Symbols.sim_card_rounded,
                        text: 'Réseau',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MobileNetwork.values.map((network) {
                          final bool selected = _networks.contains(network);
                          return _NetworkChoicePill(
                            network: network,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                selected
                                    ? _networks.remove(network)
                                    : _networks.add(network);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const _FilterSectionLabel(
                        icon: Symbols.payments_rounded,
                        text: 'Montant',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minimumController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minimum',
                                hintText: '0',
                                prefixText: 'F ',
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '—',
                              style: TextStyle(
                                color: IzyTelColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _maximumController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Maximum',
                                hintText: '∞',
                                prefixText: 'F ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _FilterSectionLabel(
                        icon: Symbols.person_rounded,
                        text: 'Opérateur responsable',
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _operatorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Tous les opérateurs',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les opérateurs'),
                          ),
                          ...effectiveOperatorIds.map((String operatorId) {
                            return DropdownMenuItem<String?>(
                              value: operatorId,
                              child: Text(
                                operatorId == widget.currentUser.id
                                    ? widget.currentUser.name
                                    : compactOperatorLabel(operatorId),
                              ),
                            );
                          }),
                        ],
                        onChanged: (String? value) {
                          setState(() => _operatorId = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Symbols.restart_alt_rounded, size: 18),
                        label: const Text('Réinitialiser'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _apply,
                        icon: const Icon(Symbols.check_rounded, size: 18),
                        label: const Text('Appliquer'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: IzyTelColors.primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: IzyTelColors.primary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: IzyTelColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = IzyTelColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : IzyTelColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : IzyTelColors.outlineStrong,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : IzyTelColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NetworkChoicePill extends StatelessWidget {
  const _NetworkChoicePill({
    required this.network,
    required this.selected,
    required this.onTap,
  });

  final MobileNetwork network;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _networkColor(network);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
        decoration: BoxDecoration(
          color: selected ? _networkSoftColor(network) : IzyTelColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : IzyTelColors.outlineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Image.asset(
                _networkBrandAsset(network),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              networkLabel(network),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? accent : IzyTelColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactStatusLabel(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.awaitingPayment:
      return 'Paiement attendu';
    case QueueOrderStatus.paymentToVerify:
      return 'À vérifier';
    case QueueOrderStatus.paidReady:
      return 'Prête à traiter';
    case QueueOrderStatus.inProgress:
      return 'En traitement';
    case QueueOrderStatus.onHold:
      return 'En attente';
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return 'Terminée';
    case QueueOrderStatus.failed:
      return 'Échouée';
    case QueueOrderStatus.expired:
      return 'Expirée';
    case QueueOrderStatus.cancelled:
      return 'Annulée';
    case QueueOrderStatus.refundPending:
      return 'Remboursement';
    case QueueOrderStatus.refunded:
      return 'Remboursée';
  }
}

Color _statusColor(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return IzyTelColors.success;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return IzyTelColors.error;
    case QueueOrderStatus.awaitingPayment:
    case QueueOrderStatus.paymentToVerify:
    case QueueOrderStatus.onHold:
    case QueueOrderStatus.expired:
    case QueueOrderStatus.refundPending:
      return IzyTelColors.warning;
    case QueueOrderStatus.paidReady:
    case QueueOrderStatus.inProgress:
      return IzyTelColors.primary;
  }
}

IconData _statusIcon(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return Symbols.check_circle_rounded;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return Symbols.cancel_rounded;
    case QueueOrderStatus.expired:
      return Symbols.timer_off_rounded;
    case QueueOrderStatus.refundPending:
      return Symbols.replay_rounded;
    case QueueOrderStatus.paidReady:
      return Symbols.inventory_2_rounded;
    case QueueOrderStatus.inProgress:
      return Symbols.autorenew_rounded;
    case QueueOrderStatus.awaitingPayment:
      return Symbols.account_balance_wallet_rounded;
    case QueueOrderStatus.paymentToVerify:
      return Symbols.fact_check_rounded;
    case QueueOrderStatus.onHold:
      return Symbols.pause_circle_rounded;
  }
}

Color _stateFilterColor(OrderHistoryStateFilter state) {
  switch (state) {
    case OrderHistoryStateFilter.active:
      return IzyTelColors.primary;
    case OrderHistoryStateFilter.completed:
      return IzyTelColors.success;
    case OrderHistoryStateFilter.failed:
      return IzyTelColors.error;
    case OrderHistoryStateFilter.expired:
      return IzyTelColors.warning;
  }
}

Color _networkColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return IzyTelColors.orange;
    case MobileNetwork.mtn:
      return IzyTelColors.mtnText;
    case MobileNetwork.moov:
      return IzyTelColors.moov;
  }
}

Color _networkSoftColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return IzyTelColors.orangeSoft;
    case MobileNetwork.mtn:
      return IzyTelColors.mtnSoft;
    case MobileNetwork.moov:
      return IzyTelColors.moovSoft;
  }
}

String _networkBrandAsset(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'assets/brands/operators/orange_ci.png';
    case MobileNetwork.mtn:
      return 'assets/brands/operators/mtn_ci.png';
    case MobileNetwork.moov:
      return 'assets/brands/operators/moov_africa_ci.png';
  }
}
