import 'dart:async';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_agent_recharge_history_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/agent_recharge_history_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/agent_recharge_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_order_detail_view.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentHistoryPage extends StatefulWidget {
  const AgentHistoryPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    this.agentRepository,
    this.rechargeHistoryRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;
  final AgentRechargeHistoryRepository? rechargeHistoryRepository;

  @override
  State<AgentHistoryPage> createState() => _AgentHistoryPageState();
}

class _AgentHistoryPageState extends State<AgentHistoryPage> {
  late final AgentOrdersViewModel _viewModel;
  late final AgentRechargeHistoryRepository? _rechargeRepository;
  final TextEditingController _rechargeSearchController =
      TextEditingController();
  Timer? _searchDebounce;
  String? _openedOrderId;
  int _tab = 0;

  List<SupplierRecharge> _recharges = const <SupplierRecharge>[];
  AgentRechargeHistorySummary _rechargeSummary =
      const AgentRechargeHistorySummary(
        totalCount: 0,
        totalReceived: 0,
        totalBonus: 0,
      );
  AgentRechargeHistoryFilter _rechargeFilter =
      const AgentRechargeHistoryFilter();
  AgentRechargeHistoryCursor? _rechargeCursor;
  AgentRechargeHistoryCursor? _nextRechargeCursor;
  final List<AgentRechargeHistoryCursor?> _rechargeBackStack =
      <AgentRechargeHistoryCursor?>[];
  bool _rechargesLoaded = false;
  bool _rechargesLoading = false;
  String? _rechargeError;
  int _rechargePage = 1;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
    );
    _rechargeRepository =
        widget.rechargeHistoryRepository ??
        (SupabaseBootstrap.isInitialized
            ? SupabaseAgentRechargeHistoryRepository()
            : null);
    _viewModel.start();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _rechargeSearchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _closeOpenedOrder() {
    if (_openedOrderId == null) return;
    setState(() => _openedOrderId = null);
  }

  void _selectTab(int value) {
    if (_tab == value) return;
    setState(() => _tab = value);
    if (value == 4 && !_rechargesLoaded && !_rechargesLoading) {
      unawaited(_loadRecharges(resetPagination: true));
    }
  }

  Future<void> _loadRecharges({bool resetPagination = false}) async {
    final AgentRechargeHistoryRepository? repository = _rechargeRepository;
    if (repository == null || _rechargesLoading) return;
    if (resetPagination) {
      _rechargeCursor = null;
      _nextRechargeCursor = null;
      _rechargeBackStack.clear();
      _rechargePage = 1;
    }
    setState(() {
      _rechargesLoading = true;
      _rechargeError = null;
    });
    try {
      final AgentRechargeHistoryPageData page = await repository.fetchPage(
        agentId: widget.user.id,
        cursor: _rechargeCursor,
        filter: _rechargeFilter,
        pageSize: 50,
      );
      final AgentRechargeHistorySummary summary = await repository.fetchSummary(
        agentId: widget.user.id,
        filter: _rechargeFilter,
      );
      if (!mounted) return;
      setState(() {
        _recharges = page.items;
        _nextRechargeCursor = page.nextCursor;
        _rechargeSummary = summary;
        _rechargesLoaded = true;
        _rechargesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rechargesLoading = false;
        _rechargeError = 'Impossible de charger les recharges pour le moment.';
      });
    }
  }

  Future<void> _nextRechargePage() async {
    final AgentRechargeHistoryCursor? next = _nextRechargeCursor;
    if (next == null || _rechargesLoading) return;
    _rechargeBackStack.add(_rechargeCursor);
    _rechargeCursor = next;
    _rechargePage++;
    await _loadRecharges();
  }

  Future<void> _previousRechargePage() async {
    if (_rechargeBackStack.isEmpty || _rechargesLoading) return;
    _rechargeCursor = _rechargeBackStack.removeLast();
    if (_rechargePage > 1) _rechargePage--;
    await _loadRecharges();
  }

  void _onRechargeSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _rechargeFilter = _rechargeFilter.copyWith(searchQuery: value.trim());
      unawaited(_loadRecharges(resetPagination: true));
    });
  }

  void _setRechargeNetwork(AgentNetwork? network) {
    _rechargeFilter = network == null
        ? _rechargeFilter.copyWith(clearNetwork: true)
        : _rechargeFilter.copyWith(network: network);
    unawaited(_loadRecharges(resetPagination: true));
  }

  Future<void> _pickRechargeDates() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _rechargeFilter.from != null && _rechargeFilter.to != null
          ? DateTimeRange(
              start: _rechargeFilter.from!,
              end: _rechargeFilter.to!,
            )
          : null,
    );
    if (range == null || !mounted) return;
    _rechargeFilter = _rechargeFilter.copyWith(
      from: DateTime(range.start.year, range.start.month, range.start.day),
      to: DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      ),
    );
    await _loadRecharges(resetPagination: true);
  }

  void _clearRechargeDates() {
    _rechargeFilter = _rechargeFilter.copyWith(clearFrom: true, clearTo: true);
    unawaited(_loadRecharges(resetPagination: true));
  }

  Widget _historyTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _tabBox('En cours', _viewModel.inProgressCount, 0),
          _tabBox('Réussies', _viewModel.successfulHistoryCount, 1),
          _tabBox('Échecs', _viewModel.failedCount, 2),
          _tabBox('Refus', _viewModel.refusedHistoryCount, 3),
          _tabBox('Recharges', _rechargeSummary.totalCount, 4),
        ],
      ),
    );
  }

  Widget _tabBox(String label, int count, int index) {
    return Padding(
      padding: EdgeInsets.only(right: index == 4 ? 0 : 6),
      child: SizedBox(
        width: label == 'Recharges' ? 122 : 108,
        child: _HistoryTab(
          label: label,
          count: count,
          selected: _tab == index,
          onTap: () => _selectTab(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openedOrderId == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _openedOrderId != null) _closeOpenedOrder();
      },
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (BuildContext context, Widget? child) {
              final String? openedId = _openedOrderId;
              if (openedId != null) {
                final QueueOrder? order = _viewModel.orderById(openedId);
                if (order != null) {
                  return AgentOrderDetailView(
                    user: widget.user,
                    order: order,
                    viewModel: _viewModel,
                    onBack: _closeOpenedOrder,
                  );
                }
              }

              final List<QueueOrder> orders = switch (_tab) {
                0 => _viewModel.inProgressOrders,
                1 => _viewModel.successfulHistoryOrders,
                2 => _viewModel.failedOrders,
                3 => _viewModel.refusedHistoryOrders,
                _ => const <QueueOrder>[],
              };

              return RefreshIndicator(
                onRefresh: _tab == 4
                    ? () => _loadRecharges(resetPagination: true)
                    : _viewModel.start,
                color: IzyTelColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: <Widget>[
                    Text(
                      'Historique',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: IzyTelTypeScale.title2,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.25,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Retrouve tes commandes et les recharges reçues sur tes capacités réseau.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.label,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _historyTabs(),
                    const SizedBox(height: 18),
                    if (_tab == 4)
                      ..._buildRechargeChildren(context)
                    else if (_viewModel.isLoading && orders.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (orders.isEmpty)
                      IzyTelSurface(
                        radius: IzyTelRadii.card,
                        child: Text(
                          _tab == 0
                              ? 'Aucune commande en cours.'
                              : _tab == 1
                              ? 'Aucune commande réussie.'
                              : _tab == 2
                              ? 'Aucun échec enregistré.'
                              : 'Aucun refus enregistré.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...orders.map(
                        (QueueOrder order) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HistoryOrderCard(
                            order: order,
                            isCompleted: _tab != 0,
                            onTap: () =>
                                setState(() => _openedOrderId = order.id),
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

  List<Widget> _buildRechargeChildren(BuildContext context) {
    if (_rechargeRepository == null) {
      return <Widget>[
        const IzyTelSurface(
          radius: IzyTelRadii.card,
          child: Text(
            'L’historique des recharges nécessite la connexion Supabase.',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return <Widget>[
      TextField(
        controller: _rechargeSearchController,
        onChanged: _onRechargeSearchChanged,
        decoration: InputDecoration(
          hintText: 'Rechercher fournisseur, référence ou note…',
          prefixIcon: const Icon(Symbols.search_rounded),
          suffixIcon: _rechargeSearchController.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _rechargeSearchController.clear();
                    _onRechargeSearchChanged('');
                    setState(() {});
                  },
                  icon: const Icon(Symbols.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _RechargeFilterChip(
              label: 'Tous',
              selected: _rechargeFilter.network == null,
              onTap: () => _setRechargeNetwork(null),
            ),
            for (final AgentNetwork network in AgentNetwork.values) ...<Widget>[
              const SizedBox(width: 6),
              _RechargeFilterChip(
                label: network.label,
                selected: _rechargeFilter.network == network,
                onTap: () => _setRechargeNetwork(network),
              ),
            ],
            const SizedBox(width: 6),
            _RechargeFilterChip(
              label: _rechargeFilter.from == null ? 'Dates' : 'Période active',
              selected: _rechargeFilter.from != null,
              icon: Symbols.calendar_month_rounded,
              onTap: _pickRechargeDates,
              onClear: _rechargeFilter.from == null
                  ? null
                  : _clearRechargeDates,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _RechargeSummaryCard(summary: _rechargeSummary),
      const SizedBox(height: 14),
      if (_rechargesLoading && !_rechargesLoaded)
        const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_rechargeError != null)
        IzyTelSurface(
          radius: IzyTelRadii.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_rechargeError!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _loadRecharges(),
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        )
      else if (_recharges.isEmpty)
        const IzyTelSurface(
          radius: IzyTelRadii.card,
          child: Text(
            'Aucune recharge ne correspond à ces critères.',
            textAlign: TextAlign.center,
          ),
        )
      else ...<Widget>[
        for (final SupplierRecharge recharge in _recharges)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RechargeHistoryCard(recharge: recharge),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _rechargeBackStack.isEmpty || _rechargesLoading
                    ? null
                    : _previousRechargePage,
                icon: const Icon(Symbols.chevron_left_rounded),
                label: const Text('Précédent'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Page $_rechargePage',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: FilledButton.icon(
                onPressed: _nextRechargeCursor == null || _rechargesLoading
                    ? null
                    : _nextRechargePage,
                icon: const Icon(Symbols.chevron_right_rounded),
                label: const Text('Suivant'),
              ),
            ),
          ],
        ),
      ],
    ];
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? IzyTelColors.primary : IzyTelColors.outline,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$label  $count',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? IzyTelColors.surface
                    : IzyTelColors.textSecondary,
                fontSize: IzyTelTypeScale.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RechargeFilterChip extends StatelessWidget {
  const _RechargeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onClear,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: icon == null ? null : Icon(icon, size: 17),
      label: Text(label),
      onPressed: onTap,
      deleteIcon: onClear == null
          ? null
          : const Icon(Symbols.close_rounded, size: 16),
      onDeleted: onClear,
      backgroundColor: selected
          ? IzyTelColors.primarySoft
          : IzyTelColors.surface,
      side: BorderSide(
        color: selected
            ? IzyTelColors.primary.withAlpha(90)
            : IzyTelColors.outline,
      ),
      labelStyle: TextStyle(
        color: selected ? IzyTelColors.primary : IzyTelColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RechargeSummaryCard extends StatelessWidget {
  const _RechargeSummaryCard({required this.summary});

  final AgentRechargeHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _summaryValue(context, 'Recharges', '${summary.totalCount}'),
          ),
          Container(width: 1, height: 40, color: IzyTelColors.outline),
          Expanded(
            child: _summaryValue(
              context,
              'Reçu',
              formatCfa(summary.totalReceived),
            ),
          ),
          Container(width: 1, height: 40, color: IzyTelColors.outline),
          Expanded(
            child: _summaryValue(
              context,
              'Bonus',
              formatCfa(summary.totalBonus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: IzyTelColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: IzyTelColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RechargeHistoryCard extends StatelessWidget {
  const _RechargeHistoryCard({required this.recharge});

  final SupplierRecharge recharge;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (recharge.network) {
      AgentNetwork.orange => IzyTelColors.orange,
      AgentNetwork.mtn => IzyTelColors.mtn,
      AgentNetwork.moov => IzyTelColors.moov,
    };
    return IzyTelSurface(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Symbols.add_card_rounded, color: accent, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recharge.network.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      recharge.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCfa(recharge.receivedAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Principal ${formatCfa(recharge.principalAmount)} · Bonus ${formatCfa(recharge.bonusAmount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatRechargeDate(recharge.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: IzyTelColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Capacité : ${formatCfa(recharge.capacityBefore)} → ${formatCfa(recharge.capacityAfter)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: IzyTelColors.textMuted),
          ),
          if (recharge.note?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              recharge.note!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatRechargeDate(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({
    required this.order,
    required this.isCompleted,
    required this.onTap,
  });

  final QueueOrder order;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (order.network) {
      MobileNetwork.orange => IzyTelColors.orange,
      MobileNetwork.mtn => IzyTelColors.mtn,
      MobileNetwork.moov => IzyTelColors.moov,
    };
    final (
      String statusLabel,
      Color statusColor,
    ) = order.assignmentStatus == OrderAssignmentStatus.refused
        ? ('Refusée', IzyTelColors.warning)
        : isCompleted
        ? switch (order.status) {
            QueueOrderStatus.failed => ('Échouée', IzyTelColors.error),
            QueueOrderStatus.refunded => ('Remboursée', IzyTelColors.success),
            _ => ('Réussie', IzyTelColors.success),
          }
        : switch (order.status) {
            QueueOrderStatus.onHold => ('En attente', IzyTelColors.warning),
            QueueOrderStatus.awaitingCustomerConfirmation => (
              'Réussie',
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
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(8),
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
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (order.status == QueueOrderStatus.failed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IzyTelColors.errorSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IzyTelColors.error.withAlpha(55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Motif : ${_failureReasonHistoryLabel(order.failureReason)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: IzyTelColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (order.observation?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      order.observation!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (order.assignmentStatus == OrderAssignmentStatus.refused &&
              order.lastAssignmentRefusalReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: IzyTelColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Motif : ${order.lastAssignmentRefusalReason!.trim()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IzyTelColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
                      fontSize: IzyTelTypeScale.cardTitle,
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
                const SizedBox(width: 2),
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

String _failureReasonHistoryLabel(OrderFailureReason? reason) {
  if (reason == null) return 'Non renseigné';
  return switch (reason) {
    OrderFailureReason.incorrectNumber => 'Numéro incorrect',
    OrderFailureReason.networkUnavailable => 'Réseau indisponible',
    OrderFailureReason.offerUnavailable => 'Offre indisponible',
    OrderFailureReason.insufficientBalance => 'Solde insuffisant',
    OrderFailureReason.technicalError => 'Erreur technique',
    OrderFailureReason.incorrectPayment => 'Paiement incorrect',
    OrderFailureReason.other => 'Autre',
  };
}
