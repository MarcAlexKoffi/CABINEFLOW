import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';

class FakeTerritoryRepository implements TerritoryRepository {
  FakeTerritoryRepository()
    : _managers = <TerritoryManager>[
        TerritoryManager(
          firebaseUid: 'manager-test',
          displayName: 'Manager Test',
          email: 'manager@izytel.test',
          phoneNumber: '+2250000000000',
          secondaryPhone: '',
          city: 'Abidjan',
          address: '',
          notes: '',
          accountActive: true,
          isAvailable: true,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      ],
      _zones = <TerritoryZone>[
        TerritoryZone(
          id: 'zone-1',
          name: 'Zone 1',
          city: 'Abidjan',
          region: 'Abidjan',
          latitude: 5.3599517,
          longitude: -4.0082563,
          managerId: 'manager-test',
          isActive: true,
        ),
      ];

  List<TerritoryManager> _managers;
  List<TerritoryZone> _zones;

  @override
  Future<List<TerritoryManager>> fetchManagers() async =>
      List<TerritoryManager>.unmodifiable(_managers);

  @override
  Future<List<TerritoryZone>> fetchZones() async =>
      List<TerritoryZone>.unmodifiable(_zones);

  @override
  Future<List<TerritoryAuditEvent>> fetchAuditEvents({
    required String entityType,
    required String entityId,
    int limit = 30,
  }) async => const <TerritoryAuditEvent>[];

  @override
  Stream<List<TerritoryZone>> watchZones() async* {
    yield List<TerritoryZone>.unmodifiable(_zones);
  }

  @override
  Future<int> syncManagersFromStaffRegistry() async => _managers.length;

  @override
  Future<TerritoryManager> saveManagerProfile({
    required TerritoryManager manager,
    required TerritoryManagerUpdate update,
  }) async {
    final TerritoryManager saved = TerritoryManager(
      firebaseUid: manager.firebaseUid,
      displayName: update.displayName,
      email: update.email,
      phoneNumber: update.phoneNumber,
      secondaryPhone: update.secondaryPhone,
      city: update.city,
      address: update.address,
      notes: update.notes,
      accountActive: manager.accountActive,
      isAvailable: update.isAvailable,
      avatarPath: manager.avatarPath,
      lastActivityAt: manager.lastActivityAt,
      createdAt: manager.createdAt,
      updatedAt: DateTime.now(),
    );
    _managers = _managers
        .map((TerritoryManager item) =>
            item.firebaseUid == manager.firebaseUid ? saved : item)
        .toList(growable: false);
    return saved;
  }

  @override
  Future<TerritoryZone> createZone(TerritoryZoneDraft draft) async {
    final TerritoryZone zone = TerritoryZone(
      id: 'zone-${_zones.length + 1}',
      name: draft.name,
      city: draft.city,
      region: draft.region,
      latitude: draft.latitude,
      longitude: draft.longitude,
      managerId: draft.managerId,
      isActive: draft.isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _zones = <TerritoryZone>[..._zones, zone];
    return zone;
  }

  @override
  Future<TerritoryZone> updateZone({
    required TerritoryZone zone,
    required TerritoryZoneDraft update,
  }) async {
    final TerritoryZone saved = TerritoryZone(
      id: zone.id,
      name: update.name,
      city: update.city,
      region: update.region,
      latitude: update.latitude,
      longitude: update.longitude,
      managerId: update.managerId,
      isActive: update.isActive,
      legacyFirestoreId: zone.legacyFirestoreId,
      createdAt: zone.createdAt,
      updatedAt: DateTime.now(),
    );
    _zones = _zones
        .map((TerritoryZone item) => item.id == zone.id ? saved : item)
        .toList(growable: false);
    return saved;
  }

  @override
  Future<bool> legacyZoneBackfillNeeded() async => false;

  @override
  Future<bool> importLegacyZone({
    required String zoneId,
    required String name,
    required String city,
    required String region,
    required bool isActive,
  }) async => false;

  @override
  Future<void> finishLegacyZoneBackfill(int importedCount) async {}
}
