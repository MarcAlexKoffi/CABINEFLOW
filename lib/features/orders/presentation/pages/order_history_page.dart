import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/order_history_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/material.dart';

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
        if (mounted) {
          _openFilters();
        }
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

    if (filters != null) {
      _viewModel.applyFilters(filters);
    }
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

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _HistoryTopBar(user: widget.user, onBack: widget.onBack),
              Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadHistory,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    children: [
                      const Text(
                        'Historique des commandes',
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Recherchez, filtrez et ouvrez les anciennes commandes.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _viewModel.updateSearchQuery,
                              style: const TextStyle(
                                color: AppColors.onBackground,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Référence, client, numéro, offre…',
                                hintStyle: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primaryContainer,
                                ),
                                suffixIcon: _viewModel.searchQuery.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'Effacer la recherche',
                                        onPressed: _clearSearch,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.surfaceContainer,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: BorderSide(
                                    color: AppColors.outlineVariant.withAlpha(
                                      90,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 54,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _openFilters,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.onBackground,
                                padding: EdgeInsets.zero,
                                side: BorderSide(
                                  color: _viewModel.filters.isEmpty
                                      ? AppColors.outlineVariant.withAlpha(100)
                                      : AppColors.primary,
                                ),
                                backgroundColor: AppColors.surfaceContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.tune_rounded),
                                  if (_viewModel.filters.activeFilterCount > 0)
                                    Positioned(
                                      right: -9,
                                      top: -11,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _viewModel.filters.activeFilterCount
                                              .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_viewModel.filters.isEmpty) ...[
                        const SizedBox(height: 13),
                        _ActiveFilters(
                          filters: _viewModel.filters,
                          onChanged: _viewModel.applyFilters,
                          onClearAll: _viewModel.clearAllFilters,
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (_viewModel.isLoading && !_viewModel.hasLoadedOrders)
                        const SizedBox(
                          height: 330,
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
                        Row(
                          children: [
                            Text(
                              '${_viewModel.filteredOrders.length} commande${_viewModel.filteredOrders.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.swap_vert_rounded,
                              color: AppColors.primaryContainer,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Plus récentes',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...orders.map((QueueOrder order) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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
                          );
                        }),
                        if (_viewModel.canLoadMore) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _viewModel.loadMore,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.onBackground,
                                side: BorderSide(
                                  color: AppColors.outlineVariant.withAlpha(90),
                                ),
                                backgroundColor: AppColors.surfaceContainer,
                              ),
                              icon: const Icon(
                                Icons.expand_more_rounded,
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
        );
      },
    );
  }
}

class _HistoryTopBar extends StatelessWidget {
  const _HistoryTopBar({required this.user, required this.onBack});

  final AppUser user;
  final VoidCallback onBack;

  String get initial {
    final String value = user.name.trim();
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour à la file',
            onPressed: onBack,
            color: AppColors.primaryContainer,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primaryContainer,
            size: 21,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'CabineFlow',
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(35),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withAlpha(150)),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
    if (operatorId.isEmpty) {
      return 'Non attribué';
    }
    return operatorId == currentUser.id
        ? currentUser.name
        : compactOperatorLabel(operatorId);
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = orderStatusColor(order.status);
    final Color mobileNetworkColor = networkColor(order.network);

    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.reference}',
                          style: const TextStyle(
                            color: AppColors.primaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatOrderDateTime(order.createdAt),
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withAlpha(110)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          orderStatusIcon(order.status),
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          orderStatusLabel(order.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                order.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${operationTypeLabel(order.operationType)} • ${formatIvorianPhone(order.beneficiaryPhone)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.outlineVariant.withAlpha(65)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: mobileNetworkColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: mobileNetworkColor.withAlpha(90),
                      ),
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
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Op. $operatorLabel',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCfa(order.amount),
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        const SizedBox(height: 6),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Effacer tous les filtres',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _FilterSummaryChip extends StatelessWidget {
  const _FilterSummaryChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 5, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(15),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(70)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 54,
            color: AppColors.onSurfaceVariant,
          ),
          SizedBox(height: 15),
          Text(
            'Aucune commande trouvée',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onBackground,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Modifiez la recherche ou les filtres pour afficher davantage de résultats.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
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
    return Container(
      height: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withAlpha(90)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 52,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
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

  InputDecoration _fieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
      ),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: AppColors.outlineVariant.withAlpha(80)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Le montant minimum dépasse le montant maximum.'),
          ),
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtres de l’historique',
                      style: TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FilterSectionLabel('Période'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<OrderHistoryPeriod>(
                      initialValue: _period,
                      dropdownColor: AppColors.surfaceContainerHighest,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 13,
                      ),
                      decoration: _fieldDecoration('Période'),
                      items: OrderHistoryPeriod.values.map((
                        OrderHistoryPeriod period,
                      ) {
                        return DropdownMenuItem<OrderHistoryPeriod>(
                          value: period,
                          child: Text(historyPeriodLabel(period)),
                        );
                      }).toList(),
                      onChanged: (OrderHistoryPeriod? value) {
                        if (value != null) {
                          setState(() => _period = value);
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    const _FilterSectionLabel('État de la commande'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: OrderHistoryStateFilter.values.map((
                        OrderHistoryStateFilter state,
                      ) {
                        final bool selected = _states.contains(state);
                        return FilterChip(
                          selected: selected,
                          showCheckmark: false,
                          label: Text(historyStateLabel(state)),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.primary.withAlpha(170),
                          backgroundColor: AppColors.surfaceContainerLow,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.outlineVariant.withAlpha(90),
                          ),
                          onSelected: (bool value) {
                            setState(() {
                              value
                                  ? _states.add(state)
                                  : _states.remove(state);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    const _FilterSectionLabel('Réseau'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MobileNetwork.values.map((
                        MobileNetwork network,
                      ) {
                        final bool selected = _networks.contains(network);
                        final Color color = networkColor(network);
                        return FilterChip(
                          selected: selected,
                          showCheckmark: false,
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(networkLabel(network)),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.onBackground
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: color.withAlpha(35),
                          backgroundColor: AppColors.surfaceContainerLow,
                          side: BorderSide(
                            color: selected
                                ? color
                                : AppColors.outlineVariant.withAlpha(90),
                          ),
                          onSelected: (bool value) {
                            setState(() {
                              value
                                  ? _networks.add(network)
                                  : _networks.remove(network);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    const _FilterSectionLabel('Montant (F CFA)'),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minimumController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: AppColors.onBackground,
                            ),
                            decoration: _fieldDecoration('Minimum'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 9),
                          child: Text(
                            '—',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maximumController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: AppColors.onBackground,
                            ),
                            decoration: _fieldDecoration('Maximum'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _FilterSectionLabel('Opérateur responsable'),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String?>(
                      initialValue: _operatorId,
                      dropdownColor: AppColors.surfaceContainerHighest,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 13,
                      ),
                      decoration: _fieldDecoration('Tous les opérateurs'),
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
            Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onBackground,
                        side: BorderSide(
                          color: AppColors.outlineVariant.withAlpha(100),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}
