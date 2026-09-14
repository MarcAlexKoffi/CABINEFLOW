import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeZonesPage extends StatefulWidget {
  const BackofficeZonesPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<BackofficeZonesPage> createState() => _BackofficeZonesPageState();
}

class _BackofficeZonesPageState extends State<BackofficeZonesPage> {
  late final Stream<List<AgentZone>> _zonesStream;
  late final Stream<List<AgentDirectoryEntry>> _agentsStream;

  @override
  void initState() {
    super.initState();
    _zonesStream = widget.repository.watchZones();
    _agentsStream = widget.repository.watchAgents();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgentZone>>(
      stream: _zonesStream,
      builder: (BuildContext context, AsyncSnapshot<List<AgentZone>> zonesSnapshot) {
        if (zonesSnapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.map_rounded,
            title: 'Zones indisponibles',
            message: 'Impossible de charger la cartographie opérationnelle.',
          );
        }
        if (!zonesSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<AgentDirectoryEntry>>(
          stream: _agentsStream,
          builder: (BuildContext context, AsyncSnapshot<List<AgentDirectoryEntry>> agentsSnapshot) {
            final List<AgentZone> zones = zonesSnapshot.data!;
            final List<AgentDirectoryEntry> agents = agentsSnapshot.data ?? const <AgentDirectoryEntry>[];
            final int activeZones = zones.where((AgentZone zone) => zone.isActive).length;
            final int assignedAgents = agents.where((AgentDirectoryEntry agent) => (agent.profile?.zoneIds ?? const <String>[]).isNotEmpty).length;
            final int totalCapacity = agents.fold<int>(0, (int total, AgentDirectoryEntry agent) {
              final AgentProfile? p = agent.profile;
              if (p == null) return total;
              return total + p.orangeCapacity + p.mtnCapacity + p.moovCapacity;
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BackofficePageIntro(
                  eyebrow: 'Équipe / Zones & capacités',
                  title: 'Cartographie opérationnelle',
                  description: 'Visualise la couverture des Agents par zone et la capacité télécom disponible avant d’ajouter de nouveaux périmètres.',
                  icon: Symbols.map_rounded,
                  trailing: widget.user.permissions.canManageAgents
                      ? FilledButton.icon(
                          onPressed: _createZone,
                          icon: const Icon(Symbols.add_rounded),
                          label: const Text('Nouvelle zone'),
                        )
                      : null,
                ),
                const SizedBox(height: 18),
                _metrics(total: zones.length, active: activeZones, assignedAgents: assignedAgents, totalCapacity: totalCapacity),
                const SizedBox(height: 14),
                if (zones.isEmpty)
                  BackofficeEmptyState(
                    icon: Symbols.map_rounded,
                    title: 'Aucune zone configurée',
                    message: widget.user.permissions.canManageAgents
                        ? 'Crée la première zone pour structurer l’affectation géographique des Agents.'
                        : 'Aucune zone n’est encore disponible dans le référentiel.',
                    action: widget.user.permissions.canManageAgents
                        ? FilledButton.icon(onPressed: _createZone, icon: const Icon(Symbols.add_rounded), label: const Text('Créer une zone'))
                        : null,
                  )
                else
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final int columns = constraints.maxWidth >= 1180 ? 3 : constraints.maxWidth >= 760 ? 2 : 1;
                      final double gap = 12;
                      final double cardWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: zones.map((AgentZone zone) => SizedBox(width: cardWidth, child: _zoneCard(zone, agents))).toList(growable: false),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _metrics({required int total, required int active, required int assignedAgents, required int totalCapacity}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        const double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'Zones', value: '$total', caption: '$active actives', icon: Symbols.map_rounded),
          BackofficeMetricCard(label: 'Agents zonés', value: '$assignedAgents', caption: 'avec périmètre attribué', icon: Symbols.location_on_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Capacité', value: formatCfa(totalCapacity), caption: 'solde télécom cumulé', icon: Symbols.account_balance_wallet_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'Couverture', value: total == 0 ? '0' : (assignedAgents / total).toStringAsFixed(1), caption: 'agents / zone en moyenne', icon: Symbols.insights_rounded, emphasis: BackofficePalette.primaryStrong),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList());
      },
    );
  }

  Widget _zoneCard(AgentZone zone, List<AgentDirectoryEntry> agents) {
    final List<AgentDirectoryEntry> assigned = agents.where((AgentDirectoryEntry agent) => agent.profile?.zoneIds.contains(zone.id) == true).toList(growable: false);
    int orange = 0;
    int mtn = 0;
    int moov = 0;
    for (final AgentDirectoryEntry agent in assigned) {
      orange += agent.profile?.orangeCapacity ?? 0;
      mtn += agent.profile?.mtnCapacity ?? 0;
      moov += agent.profile?.moovCapacity ?? 0;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: BackofficePalette.primarySoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Symbols.location_on_rounded, color: BackofficePalette.primaryStrong, fill: 1)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(zone.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(<String>[zone.city, zone.region].where((String item) => item.trim().isNotEmpty).join(' • '), style: Theme.of(context).textTheme.bodySmall),
          ])),
          BackofficeStatusBadge(label: zone.isActive ? 'Active' : 'Inactive', color: zone.isActive ? BackofficePalette.success : BackofficePalette.muted),
        ]),
        const SizedBox(height: 14),
        Row(children: <Widget>[
          Expanded(child: _smallStat('Agents', '${assigned.length}')),
          const SizedBox(width: 8),
          Expanded(child: _smallStat('Orange', formatCfa(orange))),
        ]),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          Expanded(child: _smallStat('MTN', formatCfa(mtn))),
          const SizedBox(width: 8),
          Expanded(child: _smallStat('Moov', formatCfa(moov))),
        ]),
        if (assigned.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text('Agents : ${assigned.take(3).map((AgentDirectoryEntry agent) => agent.name).join(', ')}${assigned.length > 3 ? ' +${assigned.length - 3}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }

  Widget _smallStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: BackofficePalette.surfaceAlt, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Future<void> _createZone() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController city = TextEditingController();
    final TextEditingController region = TextEditingController();
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Créer une zone'),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom de la zone')),
              const SizedBox(height: 10),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'Ville')),
              const SizedBox(height: 10),
              TextField(controller: region, decoration: const InputDecoration(labelText: 'Région')),
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (name.text.trim().length < 2) return;
                setDialogState(() => saving = true);
                try {
                  await widget.repository.createZone(name: name.text.trim(), city: city.text.trim(), region: region.text.trim());
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Zone créée.')));
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(error.toString())));
                  setDialogState(() => saving = false);
                }
              },
              child: Text(saving ? 'Création…' : 'Créer'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    city.dispose();
    region.dispose();
  }
}
