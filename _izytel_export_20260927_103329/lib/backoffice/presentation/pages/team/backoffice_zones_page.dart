import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/migrations/legacy_territory_backfill_service.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

class BackofficeZonesPage extends StatefulWidget {
  const BackofficeZonesPage({
    super.key,
    required this.user,
    required this.agentRepository,
    required this.territoryRepository,
  });

  final AppUser user;
  final AgentRepository agentRepository;
  final TerritoryRepository territoryRepository;

  @override
  State<BackofficeZonesPage> createState() => _BackofficeZonesPageState();
}

class _BackofficeZonesPageState extends State<BackofficeZonesPage> {
  static const LatLng _coteDIvoireCenter = LatLng(7.54, -5.55);

  bool _loading = true;
  Object? _error;
  List<TerritoryZone> _zones = const <TerritoryZone>[];
  List<TerritoryManager> _managers = const <TerritoryManager>[];
  List<AgentDirectoryEntry> _agents = const <AgentDirectoryEntry>[];
  String? _selectedZoneId;
  StreamSubscription<List<TerritoryZone>>? _zoneSubscription;

  bool get _canManage => widget.user.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    _load();
    _listenToZones();
  }

  @override
  void dispose() {
    _zoneSubscription?.cancel();
    super.dispose();
  }

  void _listenToZones() {
    _zoneSubscription?.cancel();
    _zoneSubscription = widget.territoryRepository.watchZones().listen(
      (List<TerritoryZone> zones) {
        if (!mounted) return;
        setState(() {
          _zones = zones;
          _selectedZoneId = _selectedZoneId != null &&
                  zones.any((TerritoryZone zone) => zone.id == _selectedZoneId)
              ? _selectedZoneId
              : zones
                  .where((TerritoryZone zone) => zone.isPositioned)
                  .firstOrNull
                  ?.id;
          if (_loading && _managers.isNotEmpty) {
            _loading = false;
          }
        });
      },
      onError: (Object _) {
        // Le chargement HTTP de _load reste la source de repli.
        // Une panne Realtime ne doit jamais rendre la page indisponible.
      },
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<Object> data = await Future.wait<Object>(<Future<Object>>[
        widget.territoryRepository.fetchZones(),
        widget.territoryRepository.fetchManagers(),
        widget.agentRepository.watchAgents().first,
      ]);
      if (!mounted) return;
      final List<TerritoryZone> zones = data[0] as List<TerritoryZone>;
      setState(() {
        _zones = zones;
        _managers = data[1] as List<TerritoryManager>;
        _agents = data[2] as List<AgentDirectoryEntry>;
        _selectedZoneId = _selectedZoneId != null &&
                zones.any((TerritoryZone zone) => zone.id == _selectedZoneId)
            ? _selectedZoneId
            : zones.where((TerritoryZone zone) => zone.isPositioned).firstOrNull?.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return BackofficeEmptyState(
        icon: Symbols.map_rounded,
        title: 'Zones indisponibles',
        message: 'Impossible de charger l’organisation territoriale Supabase.',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Symbols.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      );
    }

    final Map<String, TerritoryManager> managerById = <String, TerritoryManager>{
      for (final TerritoryManager manager in _managers) manager.firebaseUid: manager,
    };
    final Map<String, _ZoneStats> statsByZone = _statsByZone();
    final List<TerritoryZone> positioned = _zones.where((TerritoryZone zone) => zone.isPositioned).toList(growable: false);
    final List<TerritoryZone> unpositioned = _zones.where((TerritoryZone zone) => !zone.isPositioned).toList(growable: false);
    final int activeZones = _zones.where((TerritoryZone zone) => zone.isActive).length;
    final int managedZones = _zones.where((TerritoryZone zone) => zone.managerId != null).length;
    final int totalCapacity = statsByZone.values.fold<int>(0, (int total, _ZoneStats item) => total + item.totalCapacity);
    final TerritoryZone? selected = _zoneById(_selectedZoneId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackofficePageIntro(
          eyebrow: 'Équipe / Zones & capacités',
          title: 'Cartographie territoriale IzyTel',
          description: 'Visualise les zones, leurs Managers, les Agents rattachés et les capacités Orange / MTN / Moov sur une carte OpenStreetMap.',
          icon: Symbols.map_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _load,
                icon: const Icon(Symbols.refresh_rounded),
              ),
              if (_canManage) ...<Widget>[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => _openZoneEditor(),
                  icon: const Icon(Symbols.add_location_alt_rounded),
                  label: const Text('Nouvelle zone'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _metrics(
          total: _zones.length,
          active: activeZones,
          managed: managedZones,
          positioned: positioned.length,
          totalCapacity: totalCapacity,
        ),
        const SizedBox(height: 14),
        if (_zones.isEmpty)
          BackofficeEmptyState(
            icon: Symbols.map_rounded,
            title: 'Aucune zone dans Supabase',
            message: 'La migration historique des zones s’exécute automatiquement une seule fois côté Administrateur. Actualise la page après la synchronisation.',
            action: _canManage
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _syncLegacyZones,
                        icon: const Icon(Symbols.sync_rounded),
                        label: const Text('Synchroniser les zones historiques'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openZoneEditor(),
                        icon: const Icon(Symbols.add_rounded),
                        label: const Text('Créer une zone'),
                      ),
                    ],
                  )
                : null,
          )
        else ...<Widget>[
          _mapPanel(positioned, managerById, statsByZone, selected),
          if (unpositioned.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _unpositionedPanel(unpositioned, managerById, statsByZone),
          ],
          const SizedBox(height: 14),
          _zoneDirectory(managerById, statsByZone),
        ],
      ],
    );
  }

  Widget _metrics({
    required int total,
    required int active,
    required int managed,
    required int positioned,
    required int totalCapacity,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180 ? 5 : constraints.maxWidth >= 760 ? 3 : 2;
        const double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'Zones', value: '$total', caption: '$active actives', icon: Symbols.map_rounded),
          BackofficeMetricCard(label: 'Positionnées', value: '$positioned', caption: '${total - positioned} à positionner', icon: Symbols.location_on_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'Avec Manager', value: '$managed', caption: '${total - managed} sans responsable', icon: Symbols.supervisor_account_rounded, emphasis: managed == total ? BackofficePalette.success : BackofficePalette.warning),
          BackofficeMetricCard(label: 'Agents zonés', value: '${_agents.where((AgentDirectoryEntry agent) => (agent.profile?.zoneIds ?? const <String>[]).isNotEmpty).length}', caption: 'avec périmètre', icon: Symbols.groups_rounded, emphasis: BackofficePalette.primaryStrong),
          BackofficeMetricCard(label: 'Capacité', value: formatCfa(totalCapacity), caption: 'solde télécom cumulé', icon: Symbols.account_balance_wallet_rounded, emphasis: BackofficePalette.success),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(growable: false),
        );
      },
    );
  }

  Widget _mapPanel(
    List<TerritoryZone> positioned,
    Map<String, TerritoryManager> managerById,
    Map<String, _ZoneStats> statsByZone,
    TerritoryZone? selected,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Carte opérationnelle', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('Clique sur un marqueur pour afficher la synthèse de la zone.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              BackofficeStatusBadge(
                label: positioned.isEmpty ? 'Aucune position' : '${positioned.length} positionnée${positioned.length > 1 ? 's' : ''}',
                color: positioned.isEmpty ? BackofficePalette.warning : BackofficePalette.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 430,
              child: Stack(
                children: <Widget>[
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: selected?.isPositioned == true
                          ? LatLng(selected!.latitude!, selected.longitude!)
                          : _coteDIvoireCenter,
                      initialZoom: selected?.isPositioned == true ? 9.5 : 6.2,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.izytel.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: positioned.map((TerritoryZone zone) {
                          final bool isSelected = zone.id == _selectedZoneId;
                          final TerritoryManager? manager = zone.managerId == null ? null : managerById[zone.managerId];
                          return Marker(
                            point: LatLng(zone.latitude!, zone.longitude!),
                            width: isSelected ? 58 : 48,
                            height: isSelected ? 58 : 48,
                            child: Tooltip(
                              message: '${zone.displayLabel}\n${manager?.displayName ?? 'Sans Manager'}',
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedZoneId = zone.id),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? BackofficePalette.primaryStrong : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: BackofficePalette.primaryStrong, width: isSelected ? 3 : 2),
                                    boxShadow: BackofficeShadows.panel,
                                  ),
                                  child: Icon(
                                    Symbols.location_on_rounded,
                                    fill: 1,
                                    color: isSelected ? Colors.white : BackofficePalette.primaryStrong,
                                    size: isSelected ? 31 : 27,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openOsmCopyright,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 12),
            _selectedZoneSummary(selected, managerById, statsByZone),
          ],
        ],
      ),
    );
  }

  Widget _selectedZoneSummary(
    TerritoryZone zone,
    Map<String, TerritoryManager> managerById,
    Map<String, _ZoneStats> statsByZone,
  ) {
    final TerritoryManager? manager = zone.managerId == null ? null : managerById[zone.managerId];
    final _ZoneStats stats = statsByZone[zone.id] ?? const _ZoneStats();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficePalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget title = Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(zone.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(<String>[zone.city, zone.region].where((String value) => value.trim().isNotEmpty).join(' • ')),
                  ],
                ),
              ),
              BackofficeStatusBadge(label: zone.isActive ? 'Active' : 'Inactive', color: zone.isActive ? BackofficePalette.success : BackofficePalette.muted),
            ],
          );
          final Widget info = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _infoChip(Symbols.supervisor_account_rounded, manager?.displayName ?? 'Sans Manager'),
              _infoChip(Symbols.groups_rounded, '${stats.agents} Agent${stats.agents > 1 ? 's' : ''}'),
              _infoChip(Symbols.circle_rounded, 'Orange ${formatCfa(stats.orange)}'),
              _infoChip(Symbols.circle_rounded, 'MTN ${formatCfa(stats.mtn)}'),
              _infoChip(Symbols.circle_rounded, 'Moov ${formatCfa(stats.moov)}'),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[title, const SizedBox(height: 10), info, if (_canManage) ...<Widget>[const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => _openZoneEditor(zone: zone), icon: const Icon(Symbols.edit_location_alt_rounded), label: const Text('Gérer')))] ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(flex: 3, child: title),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: info),
              if (_canManage) ...<Widget>[
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => _openZoneEditor(zone: zone), icon: const Icon(Symbols.edit_location_alt_rounded), label: const Text('Gérer')),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _unpositionedPanel(
    List<TerritoryZone> zones,
    Map<String, TerritoryManager> managerById,
    Map<String, _ZoneStats> statsByZone,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BackofficePalette.warning.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BackofficePalette.warning.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Symbols.location_off_rounded, color: BackofficePalette.warning),
              const SizedBox(width: 8),
              Expanded(child: Text('Zones à positionner', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              BackofficeStatusBadge(label: '${zones.length}', color: BackofficePalette.warning),
            ],
          ),
          const SizedBox(height: 10),
          Text('Ces zones restent opérationnelles pour les Agents, mais elles n’apparaissent pas encore sur la carte.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: zones.map((TerritoryZone zone) {
              final TerritoryManager? manager = zone.managerId == null ? null : managerById[zone.managerId];
              final _ZoneStats stats = statsByZone[zone.id] ?? const _ZoneStats();
              return Container(
                width: 310,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BackofficePalette.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(zone.displayLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(manager?.displayName ?? 'Sans Manager', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${stats.agents} Agent${stats.agents > 1 ? 's' : ''} • ${formatCfa(stats.totalCapacity)}', style: Theme.of(context).textTheme.bodySmall),
                    if (_canManage) ...<Widget>[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _openZoneEditor(zone: zone),
                          icon: const Icon(Symbols.add_location_alt_rounded),
                          label: const Text('Positionner'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _zoneDirectory(
    Map<String, TerritoryManager> managerById,
    Map<String, _ZoneStats> statsByZone,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Référentiel des zones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 1180 ? 3 : constraints.maxWidth >= 760 ? 2 : 1;
              const double gap = 12;
              final double cardWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _zones.map((TerritoryZone zone) {
                  return SizedBox(width: cardWidth, child: _zoneCard(zone, managerById, statsByZone));
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _zoneCard(
    TerritoryZone zone,
    Map<String, TerritoryManager> managerById,
    Map<String, _ZoneStats> statsByZone,
  ) {
    final TerritoryManager? manager = zone.managerId == null ? null : managerById[zone.managerId];
    final _ZoneStats stats = statsByZone[zone.id] ?? const _ZoneStats();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: zone.isPositioned ? BackofficePalette.primarySoft : BackofficePalette.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                child: Icon(zone.isPositioned ? Symbols.location_on_rounded : Symbols.location_off_rounded, color: zone.isPositioned ? BackofficePalette.primaryStrong : BackofficePalette.warning, fill: 1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(zone.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(<String>[zone.city, zone.region].where((String item) => item.trim().isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              BackofficeStatusBadge(label: zone.isActive ? 'Active' : 'Inactive', color: zone.isActive ? BackofficePalette.success : BackofficePalette.muted),
            ],
          ),
          const SizedBox(height: 12),
          _detailLine(Symbols.supervisor_account_rounded, 'Manager', manager?.displayName ?? 'Non attribué'),
          const SizedBox(height: 7),
          _detailLine(Symbols.groups_rounded, 'Agents', '${stats.agents}'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: _smallStat('Orange', formatCfa(stats.orange))),
              const SizedBox(width: 8),
              Expanded(child: _smallStat('MTN', formatCfa(stats.mtn))),
              const SizedBox(width: 8),
              Expanded(child: _smallStat('Moov', formatCfa(stats.moov))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  zone.isPositioned ? '${zone.latitude!.toStringAsFixed(5)}, ${zone.longitude!.toStringAsFixed(5)}' : 'À positionner',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zone.isPositioned ? BackofficePalette.muted : BackofficePalette.warning, fontWeight: FontWeight.w700),
                ),
              ),
              if (zone.isPositioned)
                TextButton(
                  onPressed: () => setState(() => _selectedZoneId = zone.id),
                  child: const Text('Voir carte'),
                ),
              if (_canManage)
                OutlinedButton(
                  onPressed: () => _openZoneEditor(zone: zone),
                  child: const Text('Gérer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: BackofficePalette.primaryStrong),
        const SizedBox(width: 7),
        Text('$label : ', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }

  Widget _smallStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(color: BackofficePalette.surfaceAlt, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, fontSize: 9)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: BackofficePalette.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: BackofficePalette.primaryStrong),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _openZoneEditor({TerritoryZone? zone}) async {
    if (!_canManage) return;
    final TextEditingController name = TextEditingController(text: zone?.name ?? '');
    final TextEditingController city = TextEditingController(text: zone?.city ?? '');
    final TextEditingController region = TextEditingController(text: zone?.region ?? '');
    final TextEditingController latitude = TextEditingController(text: zone?.latitude?.toStringAsFixed(6) ?? '');
    final TextEditingController longitude = TextEditingController(text: zone?.longitude?.toStringAsFixed(6) ?? '');
    String selectedManagerId = zone?.managerId ?? '';
    bool active = zone?.isActive ?? true;
    bool saving = false;
    double? lat = zone?.latitude;
    double? lng = zone?.longitude;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          void updateCoordinates(LatLng point) {
            setDialogState(() {
              lat = point.latitude;
              lng = point.longitude;
              latitude.text = point.latitude.toStringAsFixed(6);
              longitude.text = point.longitude.toStringAsFixed(6);
            });
          }

          return AlertDialog(
            title: Text(zone == null ? 'Nouvelle zone' : 'Gérer ${zone.name}'),
            content: SizedBox(
              width: 820,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _adaptiveFields(<Widget>[
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de la zone', floatingLabelBehavior: FloatingLabelBehavior.always)),
                      TextField(controller: city, decoration: const InputDecoration(labelText: 'Ville', floatingLabelBehavior: FloatingLabelBehavior.always)),
                      TextField(controller: region, decoration: const InputDecoration(labelText: 'Région / District', floatingLabelBehavior: FloatingLabelBehavior.always)),
                    ], breakpoint: 760),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedManagerId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Manager responsable', floatingLabelBehavior: FloatingLabelBehavior.always),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(value: '', child: Text('Aucun Manager')),
                        ..._managers
                            .where((TerritoryManager manager) => manager.canReceiveZone || manager.firebaseUid == selectedManagerId)
                            .map((TerritoryManager manager) => DropdownMenuItem<String>(value: manager.firebaseUid, child: Text(manager.displayName))),
                      ],
                      onChanged: (String? value) => setDialogState(() => selectedManagerId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _adaptiveFields(<Widget>[
                      TextField(
                        controller: latitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Latitude', floatingLabelBehavior: FloatingLabelBehavior.always),
                        onChanged: (String value) => setDialogState(() => lat = double.tryParse(value.replaceAll(',', '.'))),
                      ),
                      TextField(
                        controller: longitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Longitude', floatingLabelBehavior: FloatingLabelBehavior.always),
                        onChanged: (String value) => setDialogState(() => lng = double.tryParse(value.replaceAll(',', '.'))),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            lat = null;
                            lng = null;
                            latitude.clear();
                            longitude.clear();
                          });
                        },
                        icon: const Icon(Symbols.location_off_rounded),
                        label: const Text('Retirer la position'),
                      ),
                    ], breakpoint: 760),
                    const SizedBox(height: 10),
                    Text('Clique sur la carte pour positionner précisément la zone.', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 300,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: lat != null && lng != null ? LatLng(lat!, lng!) : _coteDIvoireCenter,
                            initialZoom: lat != null && lng != null ? 11 : 6.2,
                            minZoom: 5,
                            maxZoom: 18,
                            onTap: (_, LatLng point) => updateCoordinates(point),
                          ),
                          children: <Widget>[
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.izytel.app',
                              maxZoom: 19,
                            ),
                            if (lat != null && lng != null)
                              MarkerLayer(
                                markers: <Marker>[
                                  Marker(
                                    point: LatLng(lat!, lng!),
                                    width: 48,
                                    height: 48,
                                    child: const Icon(Symbols.location_on_rounded, size: 42, color: BackofficePalette.primaryStrong, fill: 1),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Zone active'),
                      subtitle: Text(active ? 'La zone peut être utilisée pour les affectations Agent.' : 'La zone est conservée mais désactivée.'),
                      value: active,
                      onChanged: (bool value) => setDialogState(() => active = value),
                    ),
                    if (zone != null) ...<Widget>[
                      const Divider(height: 28),
                      Text(
                        'HISTORIQUE TERRITORIAL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.faint,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _zoneAuditHistory(zone.id),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final String cleanName = name.text.trim();
                        final double? parsedLat = latitude.text.trim().isEmpty ? null : double.tryParse(latitude.text.trim().replaceAll(',', '.'));
                        final double? parsedLng = longitude.text.trim().isEmpty ? null : double.tryParse(longitude.text.trim().replaceAll(',', '.'));
                        if (cleanName.length < 2) {
                          IzyTelFeedback.error(dialogContext, 'Renseigne le nom de la zone.');
                          return;
                        }
                        if ((parsedLat == null) != (parsedLng == null)) {
                          IzyTelFeedback.error(dialogContext, 'Renseigne latitude et longitude ensemble, ou laisse les deux vides.');
                          return;
                        }
                        if (parsedLat != null && (parsedLat < -90 || parsedLat > 90 || parsedLng! < -180 || parsedLng > 180)) {
                          IzyTelFeedback.error(dialogContext, 'Les coordonnées saisies sont invalides.');
                          return;
                        }
                        setDialogState(() => saving = true);
                        final TerritoryZoneDraft draft = TerritoryZoneDraft(
                          name: cleanName,
                          city: city.text.trim(),
                          region: region.text.trim(),
                          latitude: parsedLat,
                          longitude: parsedLng,
                          managerId: selectedManagerId.isEmpty ? null : selectedManagerId,
                          isActive: active,
                        );
                        try {
                          final TerritoryZone saved = zone == null
                              ? await widget.territoryRepository.createZone(draft)
                              : await widget.territoryRepository.updateZone(zone: zone, update: draft);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          await _load();
                          if (!mounted) return;
                          setState(() => _selectedZoneId = saved.id);
                          IzyTelFeedback.success(this.context, zone == null ? 'Zone créée.' : 'Zone mise à jour.');
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          IzyTelFeedback.error(dialogContext, error.toString());
                          setDialogState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
    city.dispose();
    region.dispose();
    latitude.dispose();
    longitude.dispose();
  }

  Widget _zoneAuditHistory(String zoneId) {
    return FutureBuilder<List<TerritoryAuditEvent>>(
      future: widget.territoryRepository.fetchAuditEvents(
        entityType: 'zone',
        entityId: zoneId,
        limit: 8,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<TerritoryAuditEvent>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return Text(
            'Historique indisponible.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final List<TerritoryAuditEvent> events =
            snapshot.data ?? const <TerritoryAuditEvent>[];
        if (events.isEmpty) {
          return Text(
            'Aucune modification territoriale enregistrée.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          children: events.map((TerritoryAuditEvent event) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Symbols.history_rounded,
                    size: 18,
                    color: BackofficePalette.primaryStrong,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${event.actionLabel} • ${event.actorName} • ${_formatDate(event.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Non disponible';
    final DateTime local = value.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _adaptiveFields(
    List<Widget> fields, {
    double breakpoint = 620,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int index = 0; index < fields.length; index += 1) ...<Widget>[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < fields.length; index += 1) ...<Widget>[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Future<void> _syncLegacyZones() async {
    if (!_canManage) return;
    try {
      final int imported = await LegacyTerritoryBackfillService()
          .runIfNeeded(suppressErrors: false);
      await _load();
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        imported > 0
            ? '$imported zone${imported > 1 ? 's' : ''} historique${imported > 1 ? 's' : ''} synchronisée${imported > 1 ? 's' : ''}.'
            : 'Synchronisation des zones vérifiée.',
      );
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.toString());
    }
  }

  Map<String, _ZoneStats> _statsByZone() {
    final Map<String, _ZoneStats> result = <String, _ZoneStats>{};
    for (final TerritoryZone zone in _zones) {
      result[zone.id] = const _ZoneStats();
    }
    for (final AgentDirectoryEntry agent in _agents) {
      final AgentProfile? profile = agent.profile;
      if (profile == null) continue;
      for (final String zoneId in profile.zoneIds) {
        final _ZoneStats current = result[zoneId] ?? const _ZoneStats();
        result[zoneId] = _ZoneStats(
          agents: current.agents + 1,
          orange: current.orange + profile.orangeCapacity,
          mtn: current.mtn + profile.mtnCapacity,
          moov: current.moov + profile.moovCapacity,
        );
      }
    }
    return result;
  }

  TerritoryZone? _zoneById(String? id) {
    if (id == null) return null;
    for (final TerritoryZone zone in _zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  Future<void> _openOsmCopyright() async {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ZoneStats {
  const _ZoneStats({
    this.agents = 0,
    this.orange = 0,
    this.mtn = 0,
    this.moov = 0,
  });

  final int agents;
  final int orange;
  final int mtn;
  final int moov;

  int get totalCapacity => orange + mtn + moov;
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
