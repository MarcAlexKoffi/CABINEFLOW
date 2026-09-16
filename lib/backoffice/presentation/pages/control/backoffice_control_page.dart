import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_charts.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/control/domain/models/control_snapshot.dart';
import 'package:cabine_flow/features/control/domain/repositories/control_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
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
        return Column(
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

class _StatisticsView extends StatefulWidget {
  const _StatisticsView({required this.snapshot});
  final ControlSnapshot snapshot;

  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView> {
  int _days = 30;

  ControlSnapshot get snapshot => widget.snapshot;

  List<ControlDailyTrend> get _trend {
    final List<ControlDailyTrend> sorted = snapshot.dailyTrend
        .where((ControlDailyTrend item) => item.date != null)
        .toList(growable: true)
      ..sort((ControlDailyTrend a, ControlDailyTrend b) => a.date!.compareTo(b.date!));
    if (sorted.length <= _days) return sorted;
    return sorted.sublist(sorted.length - _days);
  }

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

    final List<ControlDailyTrend> trend = _trend;
    final List<String> trendLabels = trend.map((ControlDailyTrend item) => _shortDate(item.date)).toList(growable: false);
    final List<BackofficeLineSeries> trendSeries = <BackofficeLineSeries>[
      BackofficeLineSeries(
        label: 'Commandes',
        values: trend.map((ControlDailyTrend item) => item.orders.toDouble()).toList(growable: false),
        color: BackofficePalette.primary,
      ),
      BackofficeLineSeries(
        label: 'Terminées',
        values: trend.map((ControlDailyTrend item) => item.completed.toDouble()).toList(growable: false),
        color: BackofficePalette.success,
      ),
      BackofficeLineSeries(
        label: 'Échecs',
        values: trend.map((ControlDailyTrend item) => item.failed.toDouble()).toList(growable: false),
        color: BackofficePalette.danger,
      ),
    ];

    final List<BackofficeDonutDatum> networkData = snapshot.networkBreakdown
        .map(
          (ControlNetworkMetric item) => BackofficeDonutDatum(
            label: _networkLabel(item.network),
            value: item.orders.toDouble(),
            color: _networkColor(item.network),
          ),
        )
        .toList(growable: false);

    final List<BackofficeDonutDatum> statusData = <BackofficeDonutDatum>[
      BackofficeDonutDatum(
        label: 'Terminées',
        value: snapshot.stat('completed_30d').toDouble(),
        color: BackofficePalette.success,
      ),
      BackofficeDonutDatum(
        label: 'Échouées',
        value: snapshot.stat('failed_30d').toDouble(),
        color: BackofficePalette.danger,
      ),
      BackofficeDonutDatum(
        label: 'Actives',
        value: snapshot.stat('active_orders').toDouble(),
        color: BackofficePalette.warning,
      ),
    ];

    final List<BackofficeBarDatum> agentCompleted = snapshot.agentPerformance
        .map(
          (ControlAgentPerformance item) => BackofficeBarDatum(
            label: item.agentName,
            value: item.completed.toDouble(),
            displayValue: '${item.completed}/${item.orders}',
            secondaryLabel: '${item.failed} échec${item.failed > 1 ? 's' : ''} • ${formatCfaFull(item.completedAmount)}',
            color: BackofficePalette.primary,
          ),
        )
        .toList(growable: false)
      ..sort((BackofficeBarDatum a, BackofficeBarDatum b) => b.value.compareTo(a.value));

    final List<BackofficeBarDatum> agentTime = snapshot.agentPerformance
        .where((ControlAgentPerformance item) => item.averageProcessingMinutes > 0)
        .map(
          (ControlAgentPerformance item) => BackofficeBarDatum(
            label: item.agentName,
            value: item.averageProcessingMinutes,
            displayValue: '${item.averageProcessingMinutes.toStringAsFixed(1)} min',
            secondaryLabel: '${item.completed} commande${item.completed > 1 ? 's' : ''} terminée${item.completed > 1 ? 's' : ''}',
            color: BackofficePalette.cyan,
          ),
        )
        .toList(growable: false)
      ..sort((BackofficeBarDatum a, BackofficeBarDatum b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const Widget heading = _SectionHeading(
              title: 'Statistiques opérationnelles',
              subtitle: 'Indicateurs canoniques Supabase et lecture visuelle de l’activité.',
            );
            final Widget selector = _PeriodSelector(
              days: _days,
              onChanged: (int value) => setState(() => _days = value),
            );
            if (constraints.maxWidth < 650) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  heading,
                  const SizedBox(height: 12),
                  selector,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Expanded(child: heading),
                const SizedBox(width: 16),
                selector,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 700 ? 3 : 2;
            final double width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map((_MetricData metric) => SizedBox(width: width, child: _MetricCard(metric: metric)))
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 18),
        _AnalyticsPanel(
          title: 'Évolution de l’activité',
          subtitle: 'Commandes créées, terminées et échouées sur les $_days derniers jours.',
          icon: Symbols.monitoring_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: const <Widget>[
                  _SeriesLegend(label: 'Commandes', color: BackofficePalette.primary),
                  _SeriesLegend(label: 'Terminées', color: BackofficePalette.success),
                  _SeriesLegend(label: 'Échecs', color: BackofficePalette.danger),
                ],
              ),
              const SizedBox(height: 8),
              BackofficeLineChart(labels: trendLabels, series: trendSeries, height: 300),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth < 920;
            final Widget networks = _AnalyticsPanel(
              title: 'Répartition par réseau',
              subtitle: 'Volume de commandes créées sur 30 jours.',
              icon: Symbols.cell_tower_rounded,
              child: _NetworkChartContent(
                data: networkData,
                metrics: snapshot.networkBreakdown,
              ),
            );
            final Widget statuses = _AnalyticsPanel(
              title: 'État des commandes',
              subtitle: 'Lecture immédiate des terminées, échecs et commandes actives.',
              icon: Symbols.donut_large_rounded,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget donut = Align(
                    alignment: Alignment.center,
                    child: BackofficeDonutChart(
                      data: statusData,
                      centerLabel: 'commandes',
                      centerValue: '${statusData.fold<double>(0, (double sum, BackofficeDonutDatum item) => sum + item.value).round()}',
                    ),
                  );
                  final Widget legend = BackofficeChartLegend(items: statusData);
                  if (constraints.maxWidth < 470) {
                    return Column(
                      children: <Widget>[
                        donut,
                        const SizedBox(height: 12),
                        legend,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: donut),
                      const SizedBox(width: 16),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
            );
            if (stacked) {
              return Column(
                children: <Widget>[
                  networks,
                  const SizedBox(height: 18),
                  statuses,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: networks),
                const SizedBox(width: 18),
                Expanded(child: statuses),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth < 920;
            final Widget volume = _AnalyticsPanel(
              title: 'Performance des Agents',
              subtitle: 'Commandes terminées sur 30 jours, sans score arbitraire.',
              icon: Symbols.groups_rounded,
              child: BackofficeHorizontalBarChart(data: agentCompleted, maxRows: 8),
            );
            final Widget speed = _AnalyticsPanel(
              title: 'Temps moyen de traitement',
              subtitle: 'Comparaison du délai moyen observé par Agent.',
              icon: Symbols.schedule_rounded,
              child: BackofficeHorizontalBarChart(data: agentTime, maxRows: 8),
            );
            if (stacked) {
              return Column(
                children: <Widget>[
                  volume,
                  const SizedBox(height: 18),
                  speed,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: volume),
                const SizedBox(width: 18),
                Expanded(child: speed),
              ],
            );
          },
        ),
        if (snapshot.auditAllowed) ...<Widget>[
          const SizedBox(height: 18),
          _AnalyticsPanel(
            title: 'Exposition financière Administrateur',
            subtitle: 'Données sensibles : ce bloc n’est jamais envoyé aux Managers.',
            icon: Symbols.account_balance_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final List<_MetricData> finance = <_MetricData>[
                      _MetricData('Créances clients', formatCfaFull(snapshot.finance('customer_receivables')), Symbols.request_quote_rounded),
                      _MetricData('Dette fournisseurs', formatCfaFull(snapshot.finance('supplier_debt')), Symbols.storefront_rounded),
                      _MetricData('Commissions dues', formatCfaFull(snapshot.finance('commission_debt')), Symbols.savings_rounded),
                      _MetricData('Remboursé sur 30 j', formatCfaFull(snapshot.finance('refund_amount_30d')), Symbols.currency_exchange_rounded),
                    ];
                    final int columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
                    final double width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: finance
                          .map((_MetricData metric) => SizedBox(width: width, child: _MetricCard(metric: metric)))
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 18),
                BackofficeHorizontalBarChart(
                  maxRows: 4,
                  data: <BackofficeBarDatum>[
                    BackofficeBarDatum(
                      label: 'Créances clients',
                      value: snapshot.finance('customer_receivables').toDouble(),
                      displayValue: formatCfaFull(snapshot.finance('customer_receivables')),
                      color: BackofficePalette.warning,
                    ),
                    BackofficeBarDatum(
                      label: 'Dette fournisseurs',
                      value: snapshot.finance('supplier_debt').toDouble(),
                      displayValue: formatCfaFull(snapshot.finance('supplier_debt')),
                      color: BackofficePalette.primaryStrong,
                    ),
                    BackofficeBarDatum(
                      label: 'Commissions dues',
                      value: snapshot.finance('commission_debt').toDouble(),
                      displayValue: formatCfaFull(snapshot.finance('commission_debt')),
                      color: BackofficePalette.cyan,
                    ),
                    BackofficeBarDatum(
                      label: 'Remboursements 30 j',
                      value: snapshot.finance('refund_amount_30d').toDouble(),
                      displayValue: formatCfaFull(snapshot.finance('refund_amount_30d')),
                      color: BackofficePalette.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PeriodButton(label: '7 jours', selected: days == 7, onTap: () => onChanged(7)),
          _PeriodButton(label: '30 jours', selected: days == 30, onTap: () => onChanged(30)),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? const <BoxShadow>[BoxShadow(color: Color(0x120F172A), blurRadius: 8, offset: Offset(0, 2))]
              : const <BoxShadow>[],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? BackofficePalette.primaryStrong : BackofficePalette.muted,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BackofficePalette.line),
        boxShadow: BackofficeShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BackofficePalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: BackofficePalette.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SeriesLegend extends StatelessWidget {
  const _SeriesLegend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.muted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _NetworkChartContent extends StatelessWidget {
  const _NetworkChartContent({required this.data, required this.metrics});

  final List<BackofficeDonutDatum> data;
  final List<ControlNetworkMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final int total = metrics.fold<int>(0, (int sum, ControlNetworkMetric item) => sum + item.orders);
    final Widget donut = Align(
      alignment: Alignment.center,
      child: BackofficeDonutChart(
        data: data,
        centerLabel: 'commandes',
        centerValue: '$total',
      ),
    );
    final Widget legend = Column(
      children: metrics.map((ControlNetworkMetric item) {
        final MobileNetwork? network = _network(item.network);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              if (network != null)
                IzyTelOperatorLogo(network: network, size: 34, borderRadius: 10)
              else
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BackofficePalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Symbols.cell_tower_rounded,
                    size: 18,
                    color: BackofficePalette.primary,
                  ),
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _networkLabel(item.network),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${item.completed} terminées • ${item.failed} échecs',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.orders}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 470) {
          return Column(
            children: <Widget>[
              donut,
              const SizedBox(height: 12),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: donut),
            const SizedBox(width: 14),
            Expanded(child: legend),
          ],
        );
      },
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


MobileNetwork? _network(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'orange' => MobileNetwork.orange,
    'mtn' => MobileNetwork.mtn,
    'moov' || 'moov africa' => MobileNetwork.moov,
    _ => null,
  };
}

String _networkLabel(String raw) => _network(raw)?.brandLabel ?? (raw.trim().isEmpty ? 'Autre' : raw.trim());

Color _networkColor(String raw) => _network(raw)?.brandColor ?? BackofficePalette.primary;

String _shortDate(DateTime? value) {
  if (value == null) return '—';
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}';
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Date inconnue';
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
