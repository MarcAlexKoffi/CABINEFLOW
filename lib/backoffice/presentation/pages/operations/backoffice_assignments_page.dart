import 'dart:async';

import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_assignment_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _AssignmentScope { all, toAssign, assigned, manual }

class BackofficeAssignmentsPage extends StatefulWidget {
  const BackofficeAssignmentsPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.agentRepository,
    this.focusOrderId,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final String? focusOrderId;

  @override
  State<BackofficeAssignmentsPage> createState() => _BackofficeAssignmentsPageState();
}

class _BackofficeAssignmentsPageState extends State<BackofficeAssignmentsPage> {
  StreamSubscription<List<QueueOrder>>? _subscription;
  final TextEditingController _searchController = TextEditingController();
  List<QueueOrder> _orders = const <QueueOrder>[];
  bool _loading = true;
  String? _error;
  _AssignmentScope _scope = _AssignmentScope.toAssign;
  MobileNetwork? _network;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.ordersRepository.watchPaidQueue().listen(
      (List<QueueOrder> orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _loading = false;
          _error = null;
        });
        _openFocusedOrderIfNeeded();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Impossible de charger la file d’affectation.';
        });
      },
    );
  }

  Future<void> _refresh() async {
    try {
      final List<QueueOrder> orders = await widget.ordersRepository.fetchPaidQueue();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
      });
      _openFocusedOrderIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’actualiser les affectations.');
    }
  }

  bool _focusConsumed = false;

  void _openFocusedOrderIfNeeded() {
    if (_focusConsumed || widget.focusOrderId == null) return;
    QueueOrder? target;
    for (final QueueOrder order in _orders) {
      if (order.id == widget.focusOrderId) {
        target = order;
        break;
      }
    }
    if (target == null || target.isAssignedToAgent) return;
    _focusConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openAssignment(target!);
    });
  }

  @override
  void didUpdateWidget(covariant BackofficeAssignmentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusOrderId != widget.focusOrderId) {
      _focusConsumed = false;
      _openFocusedOrderIfNeeded();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<QueueOrder> get _visibleOrders {
    final String query = _searchController.text.trim().toLowerCase();
    Iterable<QueueOrder> result = _orders;
    if (_network != null) {
      result = result.where((QueueOrder order) => order.network == _network);
    }
    result = result.where((QueueOrder order) {
      switch (_scope) {
        case _AssignmentScope.all:
          return true;
        case _AssignmentScope.toAssign:
          return !order.isAssignedToAgent;
        case _AssignmentScope.assigned:
          return order.isAssignedToAgent;
        case _AssignmentScope.manual:
          return order.manualAssignmentRequired;
      }
    });
    if (query.isNotEmpty) {
      result = result.where((QueueOrder order) {
        final String haystack = <String>[
          order.reference,
          order.clientName,
          order.beneficiaryPhone,
          order.assignedAgentName ?? '',
          networkLabel(order.network),
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }
    return result.toList(growable: false);
  }

  int get _toAssignCount => _orders.where((QueueOrder order) => !order.isAssignedToAgent).length;
  int get _assignedCount => _orders.where((QueueOrder order) => order.isAssignedToAgent).length;
  int get _manualCount => _orders.where((QueueOrder order) => order.manualAssignmentRequired).length;

  Future<void> _openAssignment(QueueOrder order) async {
    final bool? assigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _AssignmentDialog(
          user: widget.user,
          order: order,
          ordersRepository: widget.ordersRepository,
          agentRepository: widget.agentRepository,
        );
      },
    );
    if (assigned == true && mounted) {
      IzyTelFeedback.success(
        context,
        '${order.reference} affectée avec succès.',
      );
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackofficePageIntro(
          eyebrow: 'Opérations / Affectations',
          title: 'Pilotage des affectations',
          description:
              'Visualise la file des commandes payées, repère celles qui nécessitent une affectation manuelle et assigne-les aux agents réellement éligibles.',
          icon: Symbols.assignment_ind_rounded,
          trailing: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ),
        const SizedBox(height: 16),
        _AssignmentMetrics(
          total: _orders.length,
          toAssign: _toAssignCount,
          assigned: _assignedCount,
          manual: _manualCount,
        ),
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 14),
        if (_error != null) ...<Widget>[
          BackofficeInlineError(message: _error!, onRetry: _refresh),
          const SizedBox(height: 14),
        ],
        if (_loading && _orders.isEmpty)
          const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
        else if (_visibleOrders.isEmpty)
          const BackofficeEmptyState(
            icon: Symbols.assignment_turned_in_rounded,
            title: 'Aucune affectation en attente',
            message: 'La file correspondante est vide pour le moment.',
          )
        else
          _AssignmentList(
            orders: _visibleOrders,
            onOpen: (QueueOrder order) => showBackofficeOrderDetails(context, order),
            onAssign: _openAssignment,
          ),
      ],
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 820;
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Référence, client, numéro ou agent',
              prefixIcon: Icon(Symbols.search_rounded),
            ),
          );
          final Widget scope = DropdownButtonFormField<_AssignmentScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: const <DropdownMenuItem<_AssignmentScope>>[
              DropdownMenuItem(value: _AssignmentScope.toAssign, child: Text('À affecter')),
              DropdownMenuItem(value: _AssignmentScope.assigned, child: Text('Affectées')),
              DropdownMenuItem(value: _AssignmentScope.manual, child: Text('Manuelles')),
              DropdownMenuItem(value: _AssignmentScope.all, child: Text('Toutes')),
            ],
            onChanged: (_AssignmentScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          final Widget network = DropdownButtonFormField<MobileNetwork?>(
            initialValue: _network,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Réseau'),
            items: const <DropdownMenuItem<MobileNetwork?>>[
              DropdownMenuItem(value: null, child: Text('Tous')),
              DropdownMenuItem(value: MobileNetwork.orange, child: Text('Orange')),
              DropdownMenuItem(value: MobileNetwork.mtn, child: Text('MTN')),
              DropdownMenuItem(value: MobileNetwork.moov, child: Text('Moov Africa')),
            ],
            onChanged: (MobileNetwork? value) => setState(() => _network = value),
          );
          if (compact) {
            return Column(
              children: <Widget>[
                search,
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(child: scope),
                    const SizedBox(width: 10),
                    Expanded(child: network),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 5, child: search),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: scope),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: network),
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentMetrics extends StatelessWidget {
  const _AssignmentMetrics({
    required this.total,
    required this.toAssign,
    required this.assigned,
    required this.manual,
  });

  final int total;
  final int toAssign;
  final int assigned;
  final int manual;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : constraints.maxWidth >= 700 ? 2 : 1;
        final double gap = 10;
        final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'File payée', value: '$total', caption: 'commandes à piloter', icon: Symbols.inventory_2_rounded),
          BackofficeMetricCard(label: 'À affecter', value: '$toAssign', caption: 'sans agent', icon: Symbols.person_add_rounded, emphasis: BackofficePalette.warning),
          BackofficeMetricCard(label: 'Affectées', value: '$assigned', caption: 'agent déjà choisi', icon: Symbols.verified_user_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Manuelles', value: '$manual', caption: 'intervention requise', icon: Symbols.front_hand_rounded, emphasis: BackofficePalette.primaryStrong),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _AssignmentList extends StatelessWidget {
  const _AssignmentList({required this.orders, required this.onOpen, required this.onAssign});

  final List<QueueOrder> orders;
  final ValueChanged<QueueOrder> onOpen;
  final ValueChanged<QueueOrder> onAssign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: orders.map((QueueOrder order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: backofficePanelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: Text(order.reference, style: Theme.of(context).textTheme.titleMedium)),
                          BackofficeNetworkBadge(network: order.network),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text('${order.clientName} • ${formatCfa(order.amount)}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          BackofficeStatusBadge(
                            label: order.isAssignedToAgent ? (order.assignedAgentName ?? 'Affectée') : 'Non affectée',
                            color: order.isAssignedToAgent ? BackofficePalette.success : BackofficePalette.warning,
                            icon: order.isAssignedToAgent ? Symbols.person_check_rounded : Symbols.person_add_rounded,
                          ),
                          if (order.manualAssignmentRequired)
                            const BackofficeStatusBadge(label: 'Manuelle requise', color: BackofficePalette.primaryStrong, icon: Symbols.front_hand_rounded),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(onPressed: () => onOpen(order), icon: const Icon(Symbols.visibility_rounded, size: 18), label: const Text('Détails')),
                          const SizedBox(width: 8),
                          if (!order.isAssignedToAgent)
                            FilledButton.icon(onPressed: () => onAssign(order), icon: const Icon(Symbols.assignment_ind_rounded, size: 18), label: const Text('Affecter')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }
        return BackofficeDesktopTable(
          columns: const <BackofficeTableColumnSpec>[
            BackofficeTableColumnSpec(label: 'ÉTAT', flex: 2),
            BackofficeTableColumnSpec(label: 'COMMANDE', flex: 2),
            BackofficeTableColumnSpec(label: 'CLIENT', flex: 2),
            BackofficeTableColumnSpec(
              label: 'MONTANT',
              flex: 1,
              alignment: Alignment.centerRight,
            ),
            BackofficeTableColumnSpec(label: 'AGENT / MODE', flex: 2),
            BackofficeTableColumnSpec(
              label: 'ACTION',
              flex: 2,
              alignment: Alignment.centerRight,
            ),
          ],
          rows: orders.map((QueueOrder order) {
            final bool needsAssignment = !order.isAssignedToAgent;
            final bool manual = order.manualAssignmentRequired;
            final Color stateColor = manual
                ? BackofficePalette.warning
                : needsAssignment
                ? BackofficePalette.primaryStrong
                : BackofficePalette.success;
            final String stateLabel = manual
                ? 'Manuelle requise'
                : needsAssignment
                ? 'À affecter'
                : 'Affectée';
            return BackofficeDesktopTableRow(
              onTap: () => onOpen(order),
              backgroundColor: manual
                  ? BackofficePalette.warning.withValues(alpha: .04)
                  : needsAssignment
                  ? BackofficePalette.primarySoft.withValues(alpha: .40)
                  : null,
              accentColor: manual
                  ? BackofficePalette.warning
                  : needsAssignment
                  ? BackofficePalette.primary
                  : null,
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: stateLabel,
                    color: stateColor,
                    icon: manual
                        ? Symbols.front_hand_rounded
                        : needsAssignment
                        ? Symbols.person_add_rounded
                        : Symbols.person_check_rounded,
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      BackofficeNetworkBadge(network: order.network),
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Text(
                    order.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 1,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCfa(order.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.assignedAgentName?.trim().isNotEmpty == true
                            ? order.assignedAgentName!
                            : 'Aucun agent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: needsAssignment
                              ? BackofficePalette.primaryStrong
                              : BackofficePalette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        manual
                            ? 'Affectation manuelle'
                            : order.assignmentMode == OrderAssignmentMode.manual
                            ? 'Manuelle'
                            : 'Automatique',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: needsAssignment
                      ? FilledButton.tonalIcon(
                          onPressed: () => onAssign(order),
                          icon: const Icon(Symbols.assignment_ind_rounded, size: 18),
                          label: const Text('Affecter'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => onOpen(order),
                          icon: const Icon(Symbols.visibility_rounded, size: 18),
                          label: const Text('Détails'),
                        ),
                ),
              ],
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({
    required this.user,
    required this.order,
    required this.ordersRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final QueueOrder order;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late final AgentAssignmentViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentAssignmentViewModel(
      order: widget.order,
      adminUserId: widget.user.id,
      isManager: widget.user.isManager,
      agentRepository: widget.agentRepository,
      ordersRepository: widget.ordersRepository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _assign(AgentAssignmentCandidate candidate) async {
    final bool success = await _viewModel.assign(candidate);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    IzyTelFeedback.error(
      context,
      _viewModel.errorMessage ?? 'Impossible d’affecter cette commande.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Container(
          decoration: backofficePanelDecoration(radius: 22, elevated: true),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: BackofficePalette.primarySoft, borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Symbols.assignment_ind_rounded, color: BackofficePalette.primary, fill: 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Affecter ${widget.order.reference}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 3),
                          Text('${networkLabel(widget.order.network)} • ${formatCfaFull(widget.order.amount)} • ${widget.order.clientName}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Symbols.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (BuildContext context, Widget? child) {
                    if (_viewModel.isLoading && _viewModel.candidates.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_viewModel.errorMessage != null && _viewModel.candidates.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: BackofficeInlineError(message: _viewModel.errorMessage!, onRetry: _viewModel.start),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: Text('Agents compatibles', style: Theme.of(context).textTheme.titleMedium)),
                            BackofficeStatusBadge(label: '${_viewModel.assignableCount} disponibles', color: BackofficePalette.primary, icon: Symbols.group_rounded),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_viewModel.errorMessage != null) ...<Widget>[
                          BackofficeInlineError(message: _viewModel.errorMessage!),
                          const SizedBox(height: 12),
                        ],
                        if (_viewModel.candidates.isEmpty)
                          const BackofficeEmptyState(icon: Symbols.group_off_rounded, title: 'Aucun agent compatible', message: 'Vérifie les réseaux, capacités et disponibilités des agents.')
                        else
                          ..._viewModel.candidates.map((AgentAssignmentCandidate candidate) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CandidateCard(
                              candidate: candidate,
                              processing: _viewModel.assigningAgentId == candidate.agent.userId,
                              onAssign: () => _assign(candidate),
                            ),
                          )),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.processing, required this.onAssign});

  final AgentAssignmentCandidate candidate;
  final bool processing;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final String zones = candidate.zones.isEmpty
        ? 'Aucune zone'
        : candidate.zones.map((zone) => zone.name).take(3).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: candidate.isAssignable ? Colors.white : BackofficePalette.surfaceAlt,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: candidate.isAssignable ? const Color(0xFFDCE7FF) : BackofficePalette.line),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 620;
          final Widget info = Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: BackofficePalette.primarySoft,
                child: Text(
                  candidate.agent.name.trim().isEmpty ? '?' : candidate.agent.name.trim().substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: BackofficePalette.primaryStrong, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(candidate.agent.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text('$zones • ${candidate.activeAssignments} affectation(s) active(s)', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          );
          final Widget capacity = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: <Widget>[
              Text(formatCfa(candidate.capacity), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BackofficePalette.primaryStrong)),
              const SizedBox(height: 3),
              Text(candidate.isAssignable ? 'capacité disponible' : (candidate.unavailableReason ?? 'Indisponible'), style: Theme.of(context).textTheme.bodySmall),
            ],
          );
          final Widget action = FilledButton.icon(
            onPressed: candidate.isAssignable && !processing ? onAssign : null,
            icon: processing
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Symbols.assignment_ind_rounded, size: 18),
            label: Text(candidate.isCurrentAssignment ? 'Affectée' : 'Affecter'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                info,
                const SizedBox(height: 12),
                capacity,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 5, child: info),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: capacity),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }
}
