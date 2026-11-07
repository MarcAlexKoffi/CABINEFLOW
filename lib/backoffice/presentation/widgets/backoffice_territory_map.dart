import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

/// A local directory search: no address, account or location is sent to a geocoder.
class BackofficeTerritoryMap extends StatefulWidget {
  const BackofficeTerritoryMap({
    super.key,
    required this.zones,
    required this.managers,
    required this.selectedId,
    required this.onSelected,
    this.expanded = false,
    this.tileProvider,
  });
  final List<TerritoryZone> zones;
  final Map<String, TerritoryManager> managers;
  final String? selectedId;
  final ValueChanged<TerritoryZone> onSelected;
  final bool expanded;
  final TileProvider? tileProvider;

  @override
  State<BackofficeTerritoryMap> createState() => _BackofficeTerritoryMapState();
}

enum _ZoneFilter { all, active, withoutManager }

class _BackofficeTerritoryMapState extends State<BackofficeTerritoryMap> {
  final _map = MapController();
  final _search = TextEditingController();
  _ZoneFilter _filter = _ZoneFilter.all;
  String? _selected;
  bool _coverage = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  void didUpdateWidget(BackofficeTerritoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _selected) {
      _selected = widget.selectedId;
      // A directory action also clears filters that would hide the selection.
      _search.clear();
      _filter = _ZoneFilter.all;
    }
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    super.dispose();
  }

  List<TerritoryZone> get _visible {
    final query = _search.text.trim().toLowerCase();
    return widget.zones
        .where((z) {
          final manager = widget.managers[z.managerId]?.displayName ?? '';
          return ('${z.name} ${z.city} ${z.region} $manager'
                  .toLowerCase()
                  .contains(query)) &&
              (_filter != _ZoneFilter.active || z.isActive) &&
              (_filter != _ZoneFilter.withoutManager || z.managerId == null);
        })
        .toList(growable: false);
  }

  void _select(TerritoryZone zone) {
    setState(() => _selected = zone.id);
    if (zone.isPositioned) {
      _map.move(LatLng(zone.latitude!, zone.longitude!), _map.camera.zoom);
    }
    widget.onSelected(zone);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final positioned = visible.where((z) => z.isPositioned).toList();
    final selected = visible.where((z) => z.id == _selected).firstOrNull;
    return Container(
      decoration: backofficePanelDecoration(elevated: true),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.map_rounded,
                color: BackofficePalette.primaryStrong,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carte des zones',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${positioned.length} sur ${visible.length} zones positionnées',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!widget.expanded)
                IconButton(
                  tooltip: 'Agrandir la carte',
                  icon: const Icon(Symbols.open_in_full_rounded),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog.fullscreen(
                      child: Scaffold(
                        appBar: AppBar(
                          title: const Text('Cartographie territoriale'),
                          leading: IconButton(
                            tooltip: 'Fermer la carte',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        body: Padding(
                          padding: const EdgeInsets.all(16),
                          child: BackofficeTerritoryMap(
                            zones: widget.zones,
                            managers: widget.managers,
                            selectedId: _selected,
                            onSelected: _select,
                            expanded: true,
                            tileProvider: widget.tileProvider,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher une zone, une ville ou un Manager',
              prefixIcon: const Icon(Symbols.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final item in _ZoneFilter.values)
                ChoiceChip(
                  label: Text(switch (item) {
                    _ZoneFilter.all => 'Toutes',
                    _ZoneFilter.active => 'Actives',
                    _ZoneFilter.withoutManager => 'Sans Manager',
                  }),
                  selected: _filter == item,
                  onSelected: (_) => setState(() => _filter = item),
                ),
              FilterChip(
                showCheckmark: false,
                label: const Text('Couverture'),
                avatar: const Icon(Symbols.radar_rounded, size: 18),
                selected: _coverage,
                onSelected: (value) => setState(() => _coverage = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ExpandedOrSized(
            expanded: widget.expanded,
            height: 480,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final directory = _directory(visible);
                final canvas = TerritoryMapCanvas(
                  controller: _map,
                  zones: positioned,
                  selected: selected,
                  showCoverage: _coverage,
                  onSelected: _select,
                  tileProvider: widget.tileProvider,
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 270, child: directory),
                          const SizedBox(width: 14),
                          Expanded(child: canvas),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: canvas),
                          const SizedBox(height: 10),
                          SizedBox(height: 135, child: directory),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _directory(List<TerritoryZone> zones) {
    if (zones.isEmpty) {
      return const Center(
        child: Text(
          'Aucune zone ne correspond à ces filtres.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      key: const PageStorageKey('territory-map-directory'),
      itemCount: zones.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final zone = zones[index];
        final selected = zone.id == _selected;
        return Material(
          color: selected
              ? BackofficePalette.primarySoft
              : BackofficePalette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _select(zone),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    zone.isPositioned
                        ? Symbols.location_on_rounded
                        : Symbols.location_off_rounded,
                    color: zone.isActive
                        ? BackofficePalette.primaryStrong
                        : BackofficePalette.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${zone.city}${zone.isActive ? '' : ' · Inactive'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          widget.managers[zone.managerId]?.displayName ??
                              'Sans Manager',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!zone.isPositioned)
                          const Text(
                            'À positionner',
                            style: TextStyle(
                              color: BackofficePalette.warning,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: BackofficePalette.primaryStrong,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shared by the operational map and the zone position editor.
class TerritoryMapCanvas extends StatefulWidget {
  const TerritoryMapCanvas({
    super.key,
    this.controller,
    this.zones = const [],
    this.selected,
    this.showCoverage = true,
    this.onSelected,
    this.onPositionPicked,
    this.position,
    this.radiusKm = 50,
    this.tileProvider,
  });
  final MapController? controller;
  final List<TerritoryZone> zones;
  final TerritoryZone? selected;
  final bool showCoverage;
  final ValueChanged<TerritoryZone>? onSelected;
  final ValueChanged<LatLng>? onPositionPicked;
  final LatLng? position;
  final double radiusKm;
  final TileProvider? tileProvider;

  @override
  State<TerritoryMapCanvas> createState() => _TerritoryMapCanvasState();
}

class _TerritoryMapCanvasState extends State<TerritoryMapCanvas> {
  late final MapController _controller = widget.controller ?? MapController();
  bool _ready = false;
  bool _wheel = false;
  bool _tileError = false;
  int _tilesRevision = 0;
  bool get _picking => widget.onPositionPicked != null;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TerritoryMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (widget.position != oldWidget.position && widget.position != null) {
      _controller.move(
        widget.position!,
        _controller.camera.zoom < 10 ? 11 : _controller.camera.zoom,
      );
    } else if (widget.selected?.id != oldWidget.selected?.id ||
        widget.selected?.latitude != oldWidget.selected?.latitude ||
        widget.selected?.longitude != oldWidget.selected?.longitude ||
        widget.selected?.coverageRadiusKm !=
            oldWidget.selected?.coverageRadiusKm ||
        widget.showCoverage != oldWidget.showCoverage) {
      if (widget.selected?.isPositioned == true) {
        _focus(widget.selected!);
      } else {
        _fit();
      }
    } else if (widget.zones.map((z) => z.id).join('|') !=
        oldWidget.zones.map((z) => z.id).join('|')) {
      _fit();
    }
  }

  void _focus(TerritoryZone zone) {
    final center = LatLng(zone.latitude!, zone.longitude!);
    if (!widget.showCoverage) {
      _controller.move(center, 12);
      return;
    }
    final distance = const Distance();
    final radius = zone.coverageRadiusKm * 1000;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          distance.offset(center, radius, 0),
          distance.offset(center, radius, 90),
          distance.offset(center, radius, 180),
          distance.offset(center, radius, 270),
        ],
        padding: const EdgeInsets.all(50),
        maxZoom: 13,
      ),
    );
  }

  void _fit() {
    if (!_ready) return;
    if (_picking && widget.position != null) {
      _controller.move(widget.position!, 11);
      return;
    }
    final points = <LatLng>[];
    for (final zone in widget.zones.where((z) => z.isPositioned)) {
      final center = LatLng(zone.latitude!, zone.longitude!);
      points.add(center);
      if (widget.showCoverage) {
        for (final bearing in [0.0, 90.0, 180.0, 270.0]) {
          points.add(
            const Distance().offset(
              center,
              zone.coverageRadiusKm * 1000,
              bearing,
            ),
          );
        }
      }
    }
    if (points.isEmpty) {
      _controller.move(const LatLng(7.54, -5.55), 6.2);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(55),
        maxZoom: points.length == 1 ? 10 : 12,
      ),
    );
  }

  void _zoom(double delta) {
    if (_ready) {
      _controller.move(
        _controller.camera.center,
        (_controller.camera.zoom + delta).clamp(4, 18),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final zones = [...widget.zones]
      ..sort(
        (a, b) => a.id == selected?.id
            ? 1
            : b.id == selected?.id
            ? -1
            : 0,
      );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.position ?? const LatLng(7.54, -5.55),
              initialZoom: widget.position == null ? 6.2 : 11,
              minZoom: 4,
              maxZoom: 18,
              backgroundColor: const Color(0xFFE8EEF3),
              interactionOptions: InteractionOptions(
                flags:
                    InteractiveFlag.all &
                    ~InteractiveFlag.rotate &
                    (_wheel
                        ? InteractiveFlag.all
                        : ~InteractiveFlag.scrollWheelZoom),
              ),
              onMapReady: () {
                _ready = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fit();
                });
              },
              onTap: _picking
                  ? (_, point) => widget.onPositionPicked!(point)
                  : null,
            ),
            children: [
              TileLayer(
                key: ValueKey(_tilesRevision),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.izytel.app',
                maxNativeZoom: 19,
                tileProvider: widget.tileProvider,
                errorTileCallback: (_, _, _) {
                  if (_tileError) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _tileError = true);
                  });
                },
              ),
              if (widget.showCoverage)
                CircleLayer(
                  circles: [
                    for (final zone in zones)
                      CircleMarker(
                        point: LatLng(zone.latitude!, zone.longitude!),
                        radius: zone.coverageRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color:
                            (zone.isActive
                                    ? BackofficePalette.primary
                                    : BackofficePalette.muted)
                                .withValues(
                                  alpha: zone.id == selected?.id ? .12 : .05,
                                ),
                        borderColor:
                            (zone.isActive
                                    ? BackofficePalette.primary
                                    : BackofficePalette.muted)
                                .withValues(alpha: .55),
                        borderStrokeWidth: 1.5,
                      ),
                    if (_picking && widget.position != null)
                      CircleMarker(
                        point: widget.position!,
                        radius: widget.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: BackofficePalette.primary.withValues(alpha: .12),
                        borderColor: BackofficePalette.primary,
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
              Scalebar(
                alignment: Alignment.bottomRight,
                padding: EdgeInsets.only(right: 12, bottom: 40),
                textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: BackofficePalette.ink,
                ),
              ),
              _TerritoryMarkers(
                zones: zones,
                selectedId: selected?.id,
                onSelected: widget.onSelected,
                pickingPosition: _picking ? widget.position : null,
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoomer',
                    onPressed: () => _zoom(1),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Dézoomer',
                    onPressed: () => _zoom(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: _picking
                        ? 'Recentrer la position'
                        : 'Voir toutes les zones filtrées',
                    onPressed: _fit,
                    icon: const Icon(Symbols.center_focus_strong_rounded),
                  ),
                  IconButton(
                    tooltip: _wheel
                        ? 'Désactiver le zoom à la molette'
                        : 'Activer le zoom à la molette',
                    isSelected: _wheel,
                    onPressed: () => setState(() => _wheel = !_wheel),
                    icon: const Icon(Symbols.mouse_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_tileError)
            Positioned(
              left: 10,
              right: 68,
              top: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Fond de carte indisponible',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _tileError = false;
                          _tilesRevision++;
                        }),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.zones.isEmpty && !_picking)
            Positioned(
              left: 12,
              bottom: 50,
              right: 68,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Aucune zone positionnée pour cette recherche.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Material(
              color: Colors.white.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nearby markers share a chooser rather than hiding each other at country scale.
class _TerritoryMarkers extends StatelessWidget {
  const _TerritoryMarkers({
    required this.zones,
    required this.selectedId,
    this.onSelected,
    this.pickingPosition,
  });
  final List<TerritoryZone> zones;
  final String? selectedId;
  final ValueChanged<TerritoryZone>? onSelected;
  final LatLng? pickingPosition;

  void _choose(BuildContext context, List<TerritoryZone> group) {
    if (group.length == 1) {
      onSelected?.call(group.single);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Zones à proximité',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final zone in group)
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(zone.name),
                        subtitle: Text(
                          '${zone.city}${zone.isActive ? '' : ' · Inactive'}',
                        ),
                        trailing: zone.id == selectedId
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onSelected?.call(zone);
                        },
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

  Widget _button(BuildContext context, List<TerritoryZone> group) {
    final selected = group.any((z) => z.id == selectedId);
    final foreground = selected
        ? Colors.white
        : group.every((z) => !z.isActive)
        ? BackofficePalette.muted
        : BackofficePalette.primaryStrong;
    return Tooltip(
      message: group
          .map((z) => '${z.name} · ${z.city}${z.isActive ? '' : ' · Inactive'}')
          .join('\n'),
      child: Material(
        color: selected ? BackofficePalette.primaryStrong : Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _choose(context, group),
          child: Center(
            child: group.length > 1
                ? Text(
                    '${group.length}',
                    semanticsLabel: '${group.length} zones proches',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: foreground,
                    ),
                  )
                : Icon(Icons.location_on, color: foreground),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final groups = <List<TerritoryZone>>[];
    for (final zone in zones) {
      final point = camera.projectAtZoom(
        LatLng(zone.latitude!, zone.longitude!),
      );
      final group = groups.where((g) {
        final anchor = camera.projectAtZoom(
          LatLng(g.first.latitude!, g.first.longitude!),
        );
        return (point - anchor).distance < 48;
      }).firstOrNull;
      if (group == null) {
        groups.add([zone]);
      } else {
        group.add(zone);
      }
    }
    return MarkerLayer(
      markers: [
        for (final group in groups)
          Marker(
            point: LatLng(group.first.latitude!, group.first.longitude!),
            width: 44,
            height: 48,
            child: _button(context, group),
          ),
        if (pickingPosition != null)
          Marker(
            point: pickingPosition!,
            width: 48,
            height: 48,
            child: const Icon(
              Icons.location_pin,
              size: 44,
              color: BackofficePalette.primaryStrong,
            ),
          ),
      ],
    );
  }
}

class ExpandedOrSized extends StatelessWidget {
  const ExpandedOrSized({
    super.key,
    required this.expanded,
    required this.height,
    required this.child,
  });
  final bool expanded;
  final double height;
  final Widget child;
  @override
  Widget build(BuildContext context) => expanded
      ? Expanded(child: child)
      : SizedBox(height: height, child: child);
}
