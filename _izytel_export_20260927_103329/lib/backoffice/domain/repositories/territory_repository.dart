import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';

abstract class TerritoryRepository {
  Future<List<TerritoryManager>> fetchManagers();

  Future<List<TerritoryZone>> fetchZones();

  Future<List<TerritoryAuditEvent>> fetchAuditEvents({
    required String entityType,
    required String entityId,
    int limit = 30,
  });

  Stream<List<TerritoryZone>> watchZones();

  Future<int> syncManagersFromStaffRegistry();

  Future<TerritoryManager> saveManagerProfile({
    required TerritoryManager manager,
    required TerritoryManagerUpdate update,
  });

  Future<TerritoryZone> createZone(TerritoryZoneDraft draft);

  Future<TerritoryZone> updateZone({
    required TerritoryZone zone,
    required TerritoryZoneDraft update,
  });

  Future<bool> legacyZoneBackfillNeeded();

  Future<bool> importLegacyZone({
    required String zoneId,
    required String name,
    required String city,
    required String region,
    required bool isActive,
  });

  Future<void> finishLegacyZoneBackfill(int importedCount);
}
