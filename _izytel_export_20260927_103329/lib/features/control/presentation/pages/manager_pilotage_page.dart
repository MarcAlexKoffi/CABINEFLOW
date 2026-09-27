import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/control/domain/models/control_snapshot.dart';
import 'package:cabine_flow/features/control/domain/repositories/control_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ManagerPilotagePage extends StatefulWidget {
  const ManagerPilotagePage({super.key, required this.repository});
  final ControlRepository repository;

  @override
  State<ManagerPilotagePage> createState() => _ManagerPilotagePageState();
}

class _ManagerPilotagePageState extends State<ManagerPilotagePage> {
  late Future<ControlSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchSnapshot();
  }

  Future<void> _refresh() async {
    final Future<ControlSnapshot> next = widget.repository.fetchSnapshot();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(title: const Text('Pilotage opérationnel')),
      body: FutureBuilder<ControlSnapshot>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ControlSnapshot> async) {
          if (async.connectionState == ConnectionState.waiting && !async.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (async.hasError || !async.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Symbols.cloud_off_rounded, size: 42, color: IzyTelColors.warning),
                    const SizedBox(height: 12),
                    const Text('Impossible de charger le pilotage Manager.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
                  ],
                ),
              ),
            );
          }
          final ControlSnapshot snapshot = async.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[IzyTelColors.primary, IzyTelColors.primaryStrong]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    const Text('Mon périmètre', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(
                      '${snapshot.stat('manager_zones')} zone(s) · ${snapshot.stat('manager_agents')} agent(s)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    const Text('Indicateurs opérationnels uniquement. Les finances sensibles restent réservées à l’Administrateur.', style: TextStyle(color: Colors.white70)),
                  ]),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                _MobileStats(snapshot: snapshot),
                const SizedBox(height: IzyTelSpacing.lg),
                Text('Agents — 30 jours', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...snapshot.agentPerformance.map((ControlAgentPerformance item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IzyTelSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: <Widget>[
                          const Icon(Symbols.badge_rounded, color: IzyTelColors.primary),
                          const SizedBox(width: 11),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text(item.agentName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('${item.completed}/${item.orders} terminées · ${item.failed} échecs · ${item.averageProcessingMinutes.toStringAsFixed(1)} min', style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12)),
                          ])),
                        ]),
                      ),
                    )),
                const SizedBox(height: IzyTelSpacing.md),
                Text('Activité récente', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...snapshot.activity.take(30).map((ControlActivityEvent event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IzyTelSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          const Icon(Symbols.history_rounded, color: IzyTelColors.primary, size: 21),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${event.domain}${event.reference.isEmpty ? '' : ' · ${event.reference}'}', style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12)),
                          ])),
                        ]),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MobileStats extends StatelessWidget {
  const _MobileStats({required this.snapshot});
  final ControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, IconData)> items = <(String, String, IconData)>[
      ('Aujourd’hui', snapshot.stat('today_orders').toString(), Symbols.receipt_long_rounded),
      ('Terminées', snapshot.stat('today_completed').toString(), Symbols.check_circle_rounded),
      ('Actives', snapshot.stat('active_orders').toString(), Symbols.pending_actions_rounded),
      ('Signalements', snapshot.stat('agent_issues_open').toString(), Symbols.report_problem_rounded),
    ];
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final double width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) => SizedBox(
              width: width,
              child: IzyTelSurface(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Icon(item.$3, color: IzyTelColors.primary),
                  const SizedBox(height: 10),
                  Text(item.$2, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(item.$1, style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12)),
                ]),
              ),
            )).toList(),
      );
    });
  }
}
