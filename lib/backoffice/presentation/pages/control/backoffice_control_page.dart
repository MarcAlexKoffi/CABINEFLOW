import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/control/domain/models/control_snapshot.dart';
import 'package:cabine_flow/features/control/domain/repositories/control_repository.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum BackofficeControlModule { activity, audit, statistics }

class BackofficeControlPage extends StatefulWidget {
  const BackofficeControlPage({
    super.key,
    required this.user,
    required this.repository,
    required this.module,
  });

  final AppUser user;
  final ControlRepository repository;
  final BackofficeControlModule module;

  @override
  State<BackofficeControlPage> createState() => _BackofficeControlPageState();
}

class _BackofficeControlPageState extends State<BackofficeControlPage> {
  late Future<ControlSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchSnapshot();
  }

  @override
  void didUpdateWidget(covariant BackofficeControlPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module || oldWidget.repository != widget.repository) {
      _future = widget.repository.fetchSnapshot();
    }
  }

  void _reload() {
    setState(() => _future = widget.repository.fetchSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ControlSnapshot>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<ControlSnapshot> async) {
        if (async.connectionState == ConnectionState.waiting && !async.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (async.hasError || !async.hasData) {
          return _ControlError(onRetry: _reload);
        }
        final ControlSnapshot snapshot = async.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ScopeBanner(snapshot: snapshot, onRefresh: _reload),
              const SizedBox(height: 18),
              switch (widget.module) {
                BackofficeControlModule.activity => _ActivityView(snapshot: snapshot),
                BackofficeControlModule.audit => _AuditView(snapshot: snapshot),
                BackofficeControlModule.statistics => _StatisticsView(snapshot: snapshot),
              },
            ],
          ),
        );
      },
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.snapshot, required this.onRefresh});

  final ControlSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool managerScope = snapshot.scopeType == 'manager_territory';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            managerScope ? Symbols.location_on_rounded : Symbols.public_rounded,
            color: BackofficePalette.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              managerScope
                  ? 'Périmètre Manager : uniquement les zones et Agents supervisés.'
                  : 'Périmètre Administrateur : vue globale IzyTel.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BackofficePalette.ink,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: onRefresh,
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView({required this.snapshot});
  final ControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<ControlActivityEvent> events = snapshot.activity;
    if (events.isEmpty) {
      return const _EmptyCard(
        icon: Symbols.history_rounded,
        title: 'Aucune activité à afficher',
        subtitle: 'Le journal se remplira avec les événements opérationnels.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeading(
          title: 'Journal d’activité',
          subtitle: '${events.length} événements récents consolidés.',
        ),
        const SizedBox(height: 12),
        ...events.take(150).map((ControlActivityEvent event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventCard(event: event),
            )),
      ],
    );
  }
}

class _AuditView extends StatelessWidget {
  const _AuditView({required this.snapshot});
  final ControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.auditAllowed) {
      return const _EmptyCard(
        icon: Symbols.lock_rounded,
        title: 'Audit réservé à l’Administrateur',
        subtitle: 'Les Managers disposent du journal opérationnel et des statistiques de leur périmètre, sans accès à l’audit sensible.',
      );
    }
    if (snapshot.audit.isEmpty) {
      return const _EmptyCard(
        icon: Symbols.fact_check_rounded,
        title: 'Aucun événement d’audit',
        subtitle: 'Aucune modification auditée n’est disponible pour le moment.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeading(
          title: 'Audit / historique',
          subtitle: '${snapshot.audit.length} actions sensibles consolidées.',
        ),
        const SizedBox(height: 12),
        ...snapshot.audit.take(150).map((ControlAuditEvent event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BackofficePalette.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Symbols.fact_check_rounded, color: BackofficePalette.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${event.domain.toUpperCase()} · ${event.action}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${event.entityType} · ${event.entityId.isEmpty ? '—' : event.entityId}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_dateLabel(event.occurredAt)}${event.actorName.isEmpty ? '' : ' · ${event.actorName}'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _StatisticsView extends StatelessWidget {
  const _StatisticsView({required this.snapshot});
  final ControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<_MetricData> metrics = <_MetricData>[
      _MetricData('Commandes aujourd’hui', snapshot.stat('today_orders').toString(), Symbols.receipt_long_rounded),
      _MetricData('Terminées aujourd’hui', snapshot.stat('today_completed').toString(), Symbols.check_circle_rounded),
      _MetricData('Échecs aujourd’hui', snapshot.stat('today_failed').toString(), Symbols.error_rounded),
      _MetricData('Actives', snapshot.stat('active_orders').toString(), Symbols.pending_actions_rounded),
      _MetricData('Commandes sur 30 j', snapshot.stat('orders_30d').toString(), Symbols.calendar_month_rounded),
      _MetricData('Terminées sur 30 j', snapshot.stat('completed_30d').toString(), Symbols.done_all_rounded),
      _MetricData('Temps moyen', '${snapshot.statDouble('avg_processing_minutes_30d').toStringAsFixed(1)} min', Symbols.schedule_rounded),
      _MetricData('Signalements ouverts', snapshot.stat('agent_issues_open').toString(), Symbols.report_problem_rounded),
    ];

    if (snapshot.scopeType == 'manager_territory') {
      metrics.addAll(<_MetricData>[
        _MetricData('Zones supervisées', snapshot.stat('manager_zones').toString(), Symbols.map_rounded),
        _MetricData('Agents supervisés', snapshot.stat('manager_agents').toString(), Symbols.groups_rounded),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeading(
          title: 'Statistiques opérationnelles',
          subtitle: 'Indicateurs calculés côté Supabase sur les données canoniques.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 700 ? 3 : 2;
            final double width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics.map((_MetricData metric) => SizedBox(width: width, child: _MetricCard(metric: metric))).toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: 'Par réseau — 30 jours',
          subtitle: '${snapshot.networkBreakdown.length} réseaux observés.',
        ),
        const SizedBox(height: 10),
        ...snapshot.networkBreakdown.map((ControlNetworkMetric item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _NetworkRow(item: item),
            )),
        const SizedBox(height: 22),
        _SectionHeading(
          title: 'Performance Agents — 30 jours',
          subtitle: '${snapshot.agentPerformance.length} agents avec activité.',
        ),
        const SizedBox(height: 10),
        ...snapshot.agentPerformance.map((ControlAgentPerformance item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AgentRow(item: item),
            )),
        if (snapshot.auditAllowed) ...<Widget>[
          const SizedBox(height: 22),
          const _SectionHeading(
            title: 'Exposition financière Administrateur',
            subtitle: 'Ces indicateurs sensibles ne sont jamais envoyés aux Managers.',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final List<_MetricData> finance = <_MetricData>[
                _MetricData('Créances clients', formatCfaFull(snapshot.finance('customer_receivables')), Symbols.request_quote_rounded),
                _MetricData('Dette fournisseurs', formatCfaFull(snapshot.finance('supplier_debt')), Symbols.storefront_rounded),
                _MetricData('Commissions dues', formatCfaFull(snapshot.finance('commission_debt')), Symbols.savings_rounded),
                _MetricData('Remboursé sur 30 j', formatCfaFull(snapshot.finance('refund_amount_30d')), Symbols.currency_exchange_rounded),
              ];
              final int columns = constraints.maxWidth >= 900 ? 4 : 2;
              final double width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(spacing: 12, runSpacing: 12, children: finance.map((_MetricData metric) => SizedBox(width: width, child: _MetricCard(metric: metric))).toList());
            },
          ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BackofficePalette.muted)),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final ControlActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (event.severity) {
      'error' => BackofficePalette.danger,
      'warning' => BackofficePalette.warning,
      'success' => BackofficePalette.success,
      _ => BackofficePalette.primary,
    };
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
            child: Icon(Symbols.history_rounded, color: tone, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(event.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${event.domain}${event.reference.isEmpty ? '' : ' · ${event.reference}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateLabel(event.occurredAt)}${event.actorName.isEmpty ? '' : ' · ${event.actorName}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BackofficePalette.line), borderRadius: BorderRadius.circular(15)),
      child: Row(children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: BackofficePalette.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(metric.icon, color: BackofficePalette.primary),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(metric.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted)),
        ])),
      ]),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.item});
  final ControlNetworkMetric item;
  @override
  Widget build(BuildContext context) {
    return _DataRowCard(
      title: item.network.toUpperCase(),
      subtitle: '${item.orders} commandes · ${item.completed} terminées · ${item.failed} échecs',
      trailing: formatCfaFull(item.completedAmount),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.item});
  final ControlAgentPerformance item;
  @override
  Widget build(BuildContext context) {
    return _DataRowCard(
      title: item.agentName,
      subtitle: '${item.completed}/${item.orders} terminées · ${item.failed} échecs · ${item.averageProcessingMinutes.toStringAsFixed(1)} min',
      trailing: formatCfaFull(item.completedAmount),
    );
  }
}

class _DataRowCard extends StatelessWidget {
  const _DataRowCard({required this.title, required this.subtitle, required this.trailing});
  final String title;
  final String subtitle;
  final String trailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BackofficePalette.line), borderRadius: BorderRadius.circular(14)),
      child: Row(children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted)),
        ])),
        const SizedBox(width: 12),
        Text(trailing, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: BackofficePalette.primary)),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BackofficePalette.line), borderRadius: BorderRadius.circular(18)),
      child: Column(children: <Widget>[
        Icon(icon, size: 42, color: BackofficePalette.primary),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BackofficePalette.muted)),
      ]),
    );
  }
}

class _ControlError extends StatelessWidget {
  const _ControlError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BackofficePalette.line), borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Symbols.cloud_off_rounded, size: 42, color: BackofficePalette.primary),
            const SizedBox(height: 12),
            Text('Contrôle / Pilotage indisponible', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('Le snapshot Supabase ne peut pas être chargé pour le moment. Actualise après avoir vérifié la session.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BackofficePalette.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Symbols.refresh_rounded), label: const Text('Réessayer')),
          ]),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Date inconnue';
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
