import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTerritoryRepository implements TerritoryRepository {
  SupabaseTerritoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String managersTable = 'manager_profiles';
  static const String zonesTable = 'territory_zones';
  static const Duration _fallbackPollInterval = Duration(seconds: 30);

  final SupabaseClient _client;

  @override
  Future<List<TerritoryManager>> fetchManagers() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(managersTable)
        .select()
        .order('display_name');
    return List<TerritoryManager>.unmodifiable(rows.map(_managerFromRow));
  }

  @override
  Future<List<TerritoryZone>> fetchZones() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(zonesTable)
        .select()
        .order('city')
        .order('name');
    return List<TerritoryZone>.unmodifiable(rows.map(_zoneFromRow));
  }

  @override
  Future<List<TerritoryAuditEvent>> fetchAuditEvents({
    required String entityType,
    required String entityId,
    int limit = 30,
  }) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('territory_audit_events')
        .select()
        .eq('entity_type', entityType.trim())
        .eq('entity_id', entityId.trim())
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100).toInt());
    return List<TerritoryAuditEvent>.unmodifiable(rows.map(_auditFromRow));
  }

  @override
  Stream<List<TerritoryZone>> watchZones() async* {
    List<TerritoryZone>? lastKnown;
    try {
      lastKnown = await fetchZones();
      yield lastKnown;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Territory.initial-zones',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    try {
      await for (final List<Map<String, dynamic>> rows in _client
          .from(zonesTable)
          .stream(primaryKey: const <String>['id'])
          .order('city')
          .order('name')) {
        final List<TerritoryZone> zones = rows
            .map(_zoneFromRow)
            .toList(growable: false);
        if (!_sameZones(lastKnown, zones)) {
          lastKnown = List<TerritoryZone>.unmodifiable(zones);
          yield lastKnown;
        }
      }
      return;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Territory.realtime-zones',
        error,
        stackTrace: stackTrace,
      );
    }

    while (true) {
      await Future<void>.delayed(_fallbackPollInterval);
      try {
        final List<TerritoryZone> zones = await fetchZones();
        if (!_sameZones(lastKnown, zones)) {
          lastKnown = zones;
          yield zones;
        }
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Territory.fallback-zones',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    }
  }

  @override
  Future<int> syncManagersFromStaffRegistry() async {
    final Object? raw = await _client.rpc('izytel_sync_manager_profiles');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  @override
  Future<TerritoryManager> saveManagerProfile({
    required TerritoryManager manager,
    required TerritoryManagerUpdate update,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_save_manager_profile',
      params: <String, dynamic>{
        'p_firebase_uid': manager.firebaseUid,
        'p_display_name': update.displayName.trim(),
        'p_email': update.email.trim(),
        'p_phone_number': update.phoneNumber.trim(),
        'p_secondary_phone': update.secondaryPhone.trim(),
        'p_city': update.city.trim(),
        'p_address': update.address.trim(),
        'p_notes': update.notes.trim(),
        'p_is_available': update.isAvailable,
      },
    );
    return _managerFromRpc(raw);
  }

  @override
  Future<TerritoryZone> createZone(TerritoryZoneDraft draft) async {
    final Object? raw = await _client.rpc(
      'izytel_create_territory_zone',
      params: <String, dynamic>{
        'p_name': draft.name.trim(),
        'p_city': draft.city.trim(),
        'p_region': draft.region.trim(),
        'p_latitude': draft.latitude,
        'p_longitude': draft.longitude,
        'p_manager_id': _nullable(draft.managerId),
        'p_is_active': draft.isActive,
      },
    );
    return _zoneFromRpc(raw);
  }

  @override
  Future<TerritoryZone> updateZone({
    required TerritoryZone zone,
    required TerritoryZoneDraft update,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_update_territory_zone',
      params: <String, dynamic>{
        'p_zone_id': zone.id,
        'p_name': update.name.trim(),
        'p_city': update.city.trim(),
        'p_region': update.region.trim(),
        'p_latitude': update.latitude,
        'p_longitude': update.longitude,
        'p_manager_id': _nullable(update.managerId),
        'p_is_active': update.isActive,
      },
    );
    return _zoneFromRpc(raw);
  }

  @override
  Future<bool> legacyZoneBackfillNeeded() async {
    final Object? raw = await _client.rpc('izytel_territory_backfill_needed');
    return raw == true || raw?.toString().toLowerCase() == 'true';
  }

  @override
  Future<bool> importLegacyZone({
    required String zoneId,
    required String name,
    required String city,
    required String region,
    required bool isActive,
  }) async {
    final Object? raw = await _client.rpc(
      'izytel_import_legacy_zone',
      params: <String, dynamic>{
        'p_zone_id': zoneId.trim(),
        'p_name': name.trim(),
        'p_city': city.trim(),
        'p_region': region.trim(),
        'p_is_active': isActive,
      },
    );
    return raw == true || raw?.toString().toLowerCase() == 'true';
  }

  @override
  Future<void> finishLegacyZoneBackfill(int importedCount) async {
    await _client.rpc(
      'izytel_finish_legacy_zone_backfill',
      params: <String, dynamic>{'p_imported_count': importedCount},
    );
  }

  TerritoryManager _managerFromRpc(Object? raw) {
    final Map<String, dynamic>? row = _map(raw);
    if (row == null) {
      throw StateError('Profil Manager Supabase invalide.');
    }
    return _managerFromRow(row);
  }

  TerritoryZone _zoneFromRpc(Object? raw) {
    final Map<String, dynamic>? row = _map(raw);
    if (row == null) {
      throw StateError('Zone Supabase invalide.');
    }
    return _zoneFromRow(row);
  }

  TerritoryManager _managerFromRow(Map<String, dynamic> row) {
    final String uid = _string(row['firebase_uid']);
    if (uid.isEmpty) {
      throw StateError('Manager Supabase sans UID.');
    }
    return TerritoryManager(
      firebaseUid: uid,
      displayName: _string(row['display_name'], fallback: 'Manager IzyTel'),
      email: _string(row['email']),
      phoneNumber: _string(row['phone_number']),
      secondaryPhone: _string(row['secondary_phone']),
      city: _string(row['city']),
      address: _string(row['address']),
      avatarPath: _nullableString(row['avatar_path']),
      notes: _string(row['notes']),
      accountActive: row['is_active'] == true,
      isAvailable: row['is_available'] != false,
      lastActivityAt: _date(row['last_activity_at']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  TerritoryAuditEvent _auditFromRow(Map<String, dynamic> row) {
    return TerritoryAuditEvent(
      id: _string(row['id']),
      entityType: _string(row['entity_type']),
      entityId: _string(row['entity_id']),
      action: _string(row['action']),
      actorUid: _string(row['actor_uid']),
      actorName: _string(row['actor_name'], fallback: 'Staff IzyTel'),
      actorRole: _string(row['actor_role'], fallback: 'staff'),
      createdAt: _date(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  TerritoryZone _zoneFromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    if (id.isEmpty) {
      throw StateError('Zone Supabase sans identifiant.');
    }
    return TerritoryZone(
      id: id,
      name: _string(row['name'], fallback: 'Zone IzyTel'),
      city: _string(row['city']),
      region: _string(row['region']),
      latitude: _double(row['latitude']),
      longitude: _double(row['longitude']),
      managerId: _nullableString(row['manager_id']),
      isActive: row['is_active'] == true,
      legacyFirestoreId: _nullableString(row['legacy_firestore_id']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  bool _sameZones(List<TerritoryZone>? left, List<TerritoryZone> right) {
    if (left == null || left.length != right.length) return false;
    for (int index = 0; index < left.length; index += 1) {
      final TerritoryZone a = left[index];
      final TerritoryZone b = right[index];
      if (a.id != b.id ||
          a.name != b.name ||
          a.city != b.city ||
          a.region != b.region ||
          a.latitude != b.latitude ||
          a.longitude != b.longitude ||
          a.managerId != b.managerId ||
          a.isActive != b.isActive ||
          a.updatedAt != b.updatedAt) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic>? _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) {
      final Object? first = raw.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  String _string(Object? value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? _nullable(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  double? _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
