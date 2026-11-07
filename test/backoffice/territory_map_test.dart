import 'dart:async';
import 'dart:convert';
import 'package:cabine_flow/backoffice/data/repositories/fake_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_managers_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_zones_page.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_territory_map.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

const zones = [
  TerritoryZone(
    id: 'abj',
    name: 'Plateau',
    city: 'Abidjan',
    region: 'Lagunes',
    latitude: 5.32,
    longitude: -4.02,
    isActive: true,
    managerId: 'manager-test',
  ),
  TerritoryZone(
    id: 'yak',
    name: 'Centre',
    city: 'Yamoussoukro',
    region: 'Lacs',
    latitude: 6.82,
    longitude: -5.27,
    isActive: false,
  ),
  TerritoryZone(
    id: 'unset',
    name: 'Nord',
    city: 'Korhogo',
    region: 'Savanes',
    isActive: true,
  ),
];
const admin = AppUser(
  id: 'admin',
  name: 'Test Admin',
  phoneNumber: '',
  role: UserRole.administrator,
);

class NoProvisioningTerritory extends FakeTerritoryRepository {
  int syncCalls = 0;
  @override
  Future<int> syncManagersFromStaffRegistry() async {
    syncCalls++;
    throw StateError('MANAGED_ACCOUNT_SERVER_REQUIRED');
  }
}

class UnavailableAgents extends FakeAgentRepository {
  @override
  Stream<List<AgentDirectoryEntry>> watchAgents() =>
      Stream.error(StateError('Agent directory unavailable'));
}

class PendingAgents extends FakeAgentRepository {
  final controller = StreamController<List<AgentDirectoryEntry>>();
  @override
  Stream<List<AgentDirectoryEntry>> watchAgents() => controller.stream;
}

class ControlledZones extends NoProvisioningTerritory {
  final controller = StreamController<List<TerritoryZone>>();
  @override
  Stream<List<TerritoryZone>> watchZones() => controller.stream;
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Managers load without provisioning; Agent failure does not hide the registry',
    (tester) async {
      final repo = NoProvisioningTerritory();
      await mount(
        tester,
        SingleChildScrollView(
          child: BackofficeManagersPage(
            user: admin,
            territoryRepository: repo,
            agentRepository: UnavailableAgents(),
          ),
        ),
      );
      expect(repo.syncCalls, 0);
      expect(find.text('Managers indisponibles'), findsNothing);
      expect(find.text('Manager Test'), findsWidgets);
      expect(
        find.textContaining('Le registre territorial reste consultable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Zones load without provisioning even when the Agent directory fails',
    (tester) async {
      final repo = NoProvisioningTerritory();
      await mount(
        tester,
        SingleChildScrollView(
          child: BackofficeZonesPage(
            user: admin,
            territoryRepository: repo,
            agentRepository: UnavailableAgents(),
          ),
        ),
      );
      expect(repo.syncCalls, 0);
      expect(find.text('Zones indisponibles'), findsNothing);
      expect(find.byType(BackofficeTerritoryMap), findsOneWidget);
      expect(
        find.textContaining('Le registre territorial reste consultable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Territorial data does not wait for the optional Agent stream', (
    tester,
  ) async {
    final repo = NoProvisioningTerritory();
    final agents = PendingAgents();
    await mount(
      tester,
      SingleChildScrollView(
        child: BackofficeManagersPage(
          user: admin,
          territoryRepository: repo,
          agentRepository: agents,
        ),
      ),
    );
    expect(find.text('Manager Test'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 16));
    expect(
      find.textContaining('Le registre territorial reste consultable'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await agents.controller.close();
  });

  testWidgets(
    'Map search, filters, selection, coverage and camera controls agree',
    (tester) async {
      final managers = await FakeTerritoryRepository().fetchManagers();
      TerritoryZone? selection;
      await mount(
        tester,
        SingleChildScrollView(
          child: BackofficeTerritoryMap(
            zones: zones,
            managers: {for (final m in managers) m.firebaseUid: m},
            selectedId: null,
            onSelected: (z) => selection = z,
            tileProvider: TestTiles(),
          ),
        ),
      );
      final canvas = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = canvas.mapController!;
      final initialZoom = controller.camera.zoom;
      await tester.tap(find.byTooltip('Zoomer'));
      await tester.pump();
      expect(controller.camera.zoom, greaterThan(initialZoom));
      await tester.enterText(find.byType(TextField), 'Yamoussoukro');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        1,
      );
      await tester.tap(find.text('Centre'));
      await tester.pumpAndSettle();
      expect(selection?.id, 'yak');
      expect(controller.camera.center.latitude, closeTo(6.82, 0.05));
      await tester.tap(find.text('Couverture'));
      await tester.pump();
      expect(find.byType(CircleLayer), findsNothing);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actives'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        1,
      );
      await tester.enterText(find.byType(TextField), 'inconnue');
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucune zone ne correspond'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Map remains usable at 390px and supports a full-screen view', (
    tester,
  ) async {
    await mount(
      tester,
      SingleChildScrollView(
        child: BackofficeTerritoryMap(
          zones: zones,
          managers: const {},
          selectedId: null,
          onSelected: (_) {},
          tileProvider: TestTiles(),
        ),
      ),
      width: 390,
    );
    expect(find.byTooltip('Zoomer'), findsOneWidget);
    expect(find.text('Plateau'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The full-screen control opens a separate canvas with its own controller.
    await tester.tap(find.byTooltip('Agrandir la carte'));
    await tester.pump();
    expect(find.text('Cartographie territoriale'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Cartographie territoriale'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Position picker synchronizes typed coordinates and taps without remounting',
    (tester) async {
      final controller = MapController();
      LatLng? picked;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: 500,
            child: TerritoryMapCanvas(
              controller: controller,
              tileProvider: TestTiles(),
              position: picked,
              radiusKm: 15,
              onPositionPicked: (p) => setState(() => picked = p),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
      expect(
        tester
            .widget<CircleLayer>(find.byType(CircleLayer))
            .circles
            .single
            .radius,
        15000,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('Nearby markers offer every zone instead of hiding one', (
    tester,
  ) async {
    final nearby = [
      zones.first,
      const TerritoryZone(
        id: 'nearby',
        name: 'Voisine',
        city: 'Abidjan',
        region: 'Lagunes',
        isActive: true,
        latitude: 5.32001,
        longitude: -4.02001,
      ),
    ];
    TerritoryZone? selection;
    await mount(
      tester,
      SingleChildScrollView(
        child: BackofficeTerritoryMap(
          zones: nearby,
          managers: const {},
          selectedId: null,
          onSelected: (z) => selection = z,
          tileProvider: TestTiles(),
        ),
      ),
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      1,
    );
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Zones à proximité'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Voisine'));
    await tester.pumpAndSettle();
    expect(selection?.id, 'nearby');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'A refused refresh hides stale zones and a valid refresh restores them',
    (tester) async {
      final repo = ControlledZones();
      await mount(
        tester,
        SingleChildScrollView(
          child: BackofficeZonesPage(
            user: admin,
            territoryRepository: repo,
            agentRepository: UnavailableAgents(),
          ),
        ),
      );
      repo.controller.addError(
        const PostgrestException(message: 'forbidden', code: '42501'),
      );
      await tester.pump();
      expect(find.text('Zones indisponibles'), findsOneWidget);
      expect(find.byType(BackofficeTerritoryMap), findsNothing);
      repo.controller.add(await repo.fetchZones());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Zones indisponibles'), findsNothing);
      expect(find.byType(BackofficeTerritoryMap), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(repo.controller.close());
    },
  );

  testWidgets(
    'Editing the selected zone recentres the existing map controller',
    (tester) async {
      final controller = MapController();
      var selected = zones.first;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              TextButton(
                onPressed: () => setState(
                  () => selected = const TerritoryZone(
                    id: 'abj',
                    name: 'Plateau',
                    city: 'Abidjan',
                    region: 'Lagunes',
                    latitude: 6.5,
                    longitude: -5.1,
                    isActive: true,
                    coverageRadiusKm: 10,
                  ),
                ),
                child: const Text('Déplacer'),
              ),
              Expanded(
                child: TerritoryMapCanvas(
                  controller: controller,
                  zones: [selected],
                  selected: selected,
                  tileProvider: TestTiles(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Déplacer'));
      await tester.pumpAndSettle();
      expect(controller.camera.center.latitude, closeTo(6.5, 0.01));
      expect(controller.camera.center.longitude, closeTo(-5.1, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  test('Invalid and incomplete coordinates never become map markers', () {
    for (final pair in [
      [double.nan, 1.0],
      [91.0, 0.0],
      [0.0, double.infinity],
      [0.0, 181.0],
    ]) {
      expect(
        TerritoryZone(
          id: 'x',
          name: 'x',
          city: 'x',
          region: 'x',
          isActive: true,
          latitude: pair[0],
          longitude: pair[1],
        ).isPositioned,
        false,
      );
    }
    expect(zones.last.isPositioned, false);
    expect(zones.first.isPositioned, true);
  });
}
