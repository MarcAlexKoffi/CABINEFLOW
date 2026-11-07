import 'dart:async';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/features/orders/presentation/navigation/staff_order_navigation.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrderSupervisionPage extends StatefulWidget {
  const OrderSupervisionPage({
    super.key,
    required this.user,
    required this.repository,
    required this.historyRepository,
  });
  final AppUser user;
  final OrderSupervisionRepository repository;
  final OrderHistoryRepository historyRepository;
  @override
  State<OrderSupervisionPage> createState() => _OrderSupervisionPageState();
}

class _OrderSupervisionPageState extends State<OrderSupervisionPage>
    with WidgetsBindingObserver {
  StreamSubscription<OrderSupervisionSnapshot>? _subscription;
  OrderSupervisionSnapshot? _data;
  String? _error;
  String _filter = 'Toutes';
  bool _alerts = false, _loading = true, _opening = false;
  bool get _authorized => const [
    UserRole.administrator,
    UserRole.manager,
    UserRole.supervisor,
  ].contains(widget.user.role);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_authorized) {
      _subscription = widget.repository.watchSupervision().listen(
        _apply,
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _error =
                  'Les données de suivi n’ont pas pu être chargées. Réessayez dans un instant.';
              _loading = false;
            });
          }
        },
      );
    }
  }

  void _apply(OrderSupervisionSnapshot data) {
    if (mounted) {
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      _apply(await widget.repository.fetchSupervision());
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible d’actualiser la supervision.';
          _loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authorized) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _open(String id) async {
    if (_opening || _error != null) return;
    _opening = true;
    try {
      // The payload/order ID never authorizes access: re-read via the existing territorial repository.
      final order = await widget.historyRepository.fetchOrderById(orderId: id);
      if (!mounted) return;
      await StaffOrderNavigation.openOrderDetail(
        context: context,
        user: widget.user,
        repository: widget.historyRepository,
        order: order,
      );
    } catch (_) {
      if (mounted) {
        IzyTelFeedback.error(
          context,
          'Cette commande n’est plus accessible dans votre périmètre.',
        );
      }
    } finally {
      _opening = false;
    }
  }

  String _duration(Object? raw) {
    if (raw == null || _data == null) return 'Acceptation attendue';
    final elapsed = _data!.serverNow.difference(DateTime.parse(raw as String));
    final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
    return '$minutes min depuis acceptation';
  }

  String _status(Map<String, dynamic> row) {
    if (row['is_overdue'] == true) return 'En retard';
    if (row['assignment_state'] == 'assigned') return 'À accepter';
    return switch (row['order_status']) {
      'inProgress' => 'En cours',
      'onHold' => 'En attente',
      'failed' => 'Intervention',
      'completed' => 'Terminée',
      'paidReady' => 'Acceptée',
      _ => 'À suivre',
    };
  }

  Widget _badge(String text, bool warning) => IzyTelStatusPill(
    label: text,
    color: warning ? IzyTelColors.warning : IzyTelColors.primaryStrong,
  );

  Widget _surfaceCard({required Widget child, Color? borderColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: IzyTelSurface(radius: 16, borderColor: borderColor, child: child),
  );

  Widget _errorCard() => _surfaceCard(
    child: IzyTelEmptyState(
      icon: Symbols.sync_problem_rounded,
      title: 'Le suivi est indisponible',
      message: _error!,
      actionLabel: 'Réessayer',
      onAction: _refresh,
    ),
  );

  List<Map<String, dynamic>> get _rows {
    final rows = _data?.orders ?? const <Map<String, dynamic>>[];
    return rows
        .where(
          (r) => switch (_filter) {
            'Acceptées' =>
              r['assignment_state'] == 'accepted' &&
                  r['order_status'] == 'paidReady',
            'En cours' => const [
              'inProgress',
              'onHold',
            ].contains(r['order_status']),
            'En retard' => r['is_overdue'] == true,
            'Intervention' => r['order_status'] == 'failed',
            _ => true,
          },
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supervision')),
        body: const Center(child: Text('Accès Manager requis.')),
      );
    }
    final alerts = _data?.alerts ?? const <Map<String, dynamic>>[];
    final active = alerts.where((r) => r['state'] == 'active').length;
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text('Supervision'),
        actions: [
          IconButton(
            tooltip: _alerts ? 'Voir le suivi' : 'Voir les alertes',
            onPressed: () => setState(() => _alerts = !_alerts),
            icon: Badge(
              isLabelVisible: active > 0,
              label: Text(active.toString()),
              child: const Icon(Symbols.notifications_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refresh,
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(constraints.maxWidth > 760 ? 24 : 12),
            children: [
              Text(
                _alerts ? 'Alertes de prise en charge' : 'Suivi des commandes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: IzyTelTypeScale.title2,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Commandes de vos zones',
                style: TextStyle(
                  fontSize: IzyTelTypeScale.label,
                  color: IzyTelColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) _errorCard(),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _data == null)
                const SizedBox.shrink()
              else if (_alerts) ...[
                if (alerts.isEmpty && _error == null)
                  _empty('Aucune alerte de retard'),
                ...alerts.map(
                  (alert) => _surfaceCard(
                    borderColor: alert['state'] == 'active'
                        ? IzyTelColors.warning.withAlpha(64)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _badge(switch (alert['state']) {
                          'active' => 'Délai dépassé',
                          'obsolete' => 'Obsolète · réaffectée',
                          _ => 'Résolue · finalisée',
                        }, alert['state'] == 'active'),
                        const SizedBox(height: 12),
                        Text(
                          (alert['order_reference'] ?? alert['order_id'])
                              as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(alert['agent_name'] as String),
                        Text(
                          alert['state'] == 'active'
                              ? '${_duration(alert['accepted_at'])}${alert['order_status'] == null ? '' : ' · ${_status(alert)}'}'
                              : 'Le suivi de cette acceptation n’est plus actif.',
                          style: const TextStyle(
                            color: IzyTelColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: _error == null
                              ? () => _open(alert['order_id'] as String)
                              : null,
                          child: const Text('Ouvrir la commande →'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                if (active > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: IzyTelColors.warningSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          '$active commande(s) au-delà de cinq minutes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xff8f5100),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _alerts = true),
                          child: const Text('Voir les alertes'),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'Toutes',
                            'Acceptées',
                            'En cours',
                            'En retard',
                            'Intervention',
                          ]
                          .map(
                            (label) => IzyTelFilterPill(
                              label: label,
                              selected: _filter == label,
                              onTap: () => setState(() => _filter = label),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 20),
                if (_rows.isEmpty && _error == null)
                  _empty('Aucune commande dans cet état')
                else if (constraints.maxWidth >= 760)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth - 48,
                      ),
                      child: DataTable(
                        dataRowMinHeight: 64,
                        dataRowMaxHeight:
                            72.0 *
                            (MediaQuery.textScalerOf(context).scale(16) / 16)
                                .clamp(1.0, double.infinity)
                                .toDouble(),
                        columns: const [
                          DataColumn(label: Text('Commande')),
                          DataColumn(label: Text('Agent')),
                          DataColumn(label: Text('État')),
                          DataColumn(label: Text('Durée')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _rows
                            .map(
                              (r) => DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r['order_reference'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          formatCfa(
                                            (r['amount'] as num).toInt(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: IzyTelColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(r['assigned_agent_name'] as String),
                                  ),
                                  DataCell(
                                    _badge(_status(r), r['is_overdue'] == true),
                                  ),
                                  DataCell(Text(_duration(r['accepted_at']))),
                                  DataCell(
                                    TextButton(
                                      onPressed: _error == null
                                          ? () => _open(r['order_id'] as String)
                                          : null,
                                      child: const Text('Ouvrir →'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  )
                else
                  ..._rows.map(
                    (r) => _surfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                r['order_reference'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _badge(_status(r), r['is_overdue'] == true),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(r['assigned_agent_name'] as String),
                          Text(
                            r['offer_label'] as String,
                            style: const TextStyle(
                              color: IzyTelColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _duration(r['accepted_at']),
                            style: const TextStyle(fontSize: 13),
                          ),
                          TextButton(
                            onPressed: _error == null
                                ? () => _open(r['order_id'] as String)
                                : null,
                            child: const Text('Ouvrir la commande →'),
                          ),
                        ],
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

  Widget _empty(String title) => IzyTelEmptyState(
    icon: Symbols.inbox_rounded,
    title: title,
    message: _alerts
        ? 'Les alertes de vos commandes apparaîtront ici.'
        : 'Les commandes correspondant à ce filtre apparaîtront ici.',
  );
}
