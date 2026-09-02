import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSupplierRegistryRepository {
  SupabaseSupplierRegistryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String tableName = 'finance_suppliers';
  static const Duration _pollInterval = Duration(seconds: 4);

  final SupabaseClient _client;

  Stream<List<FinanceSupplier>> watchSuppliers() async* {
    List<FinanceSupplier>? lastSuccessful;

    while (true) {
      try {
        final List<FinanceSupplier> suppliers = await fetchSuppliers();
        lastSuccessful = suppliers;
        yield suppliers;
      } catch (error, stackTrace) {
        debugPrint('[SupabaseSuppliers][watch] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<List<FinanceSupplier>> fetchSuppliers({
    bool includeDeleted = false,
  }) async {
    final List<Map<String, dynamic>> rows = includeDeleted
        ? await _client.from(tableName).select()
        : await _client.from(tableName).select().eq('is_deleted', false);

    final List<FinanceSupplier> suppliers =
        rows
            .map(_supplierFromRow)
            .whereType<FinanceSupplier>()
            .toList(growable: false)
          ..sort((FinanceSupplier a, FinanceSupplier b) {
            if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return List<FinanceSupplier>.unmodifiable(suppliers);
  }

  Future<FinanceSupplier?> getSupplier(String supplierId) async {
    final String id = supplierId.trim();
    if (id.isEmpty) return null;
    final List<Map<String, dynamic>> rows = await _client
        .from(tableName)
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    final Map<String, dynamic> row = rows.first;
    if (row['is_deleted'] == true) return null;
    return _supplierFromRow(row);
  }

  Future<void> importLegacySuppliers(List<FinanceSupplier> suppliers) async {
    if (suppliers.isEmpty) return;

    final String uid = _currentUid();
    final String actorName = _currentDisplayName();
    final List<Map<String, dynamic>> existingRows = await _client
        .from(tableName)
        .select('id');
    final Set<String> existingIds = existingRows
        .map((Map<String, dynamic> row) => _string(row['id']))
        .where((String value) => value.isNotEmpty)
        .toSet();

    for (final FinanceSupplier supplier in suppliers) {
      if (existingIds.contains(supplier.id)) continue;
      await _client.from(tableName).insert(<String, dynamic>{
        'id': supplier.id,
        'name': supplier.name.trim(),
        'phone_number': supplier.phoneNumber.trim(),
        'note': _nullable(supplier.note),
        'is_active': supplier.isActive,
        'is_deleted': false,
        'created_by_uid': uid,
        'created_by_name': actorName,
        'updated_by_uid': uid,
        'updated_by_name': actorName,
        'legacy_created_by_uid': _nullable(supplier.createdBy),
        'legacy_created_by_name': _nullable(supplier.createdByName),
        'legacy_created_at': supplier.createdAt.toUtc().toIso8601String(),
      });
    }
  }

  Future<String> createSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String uid = _currentUid();
    if (uid != staffId.trim()) {
      throw StateError(
        'La session Firebase ne correspond pas à l’administrateur actif.',
      );
    }
    final String id = supplierId.trim();
    final String cleanedName = name.trim();
    if (id.isEmpty) throw ArgumentError('Identifiant fournisseur invalide.');
    if (cleanedName.length < 2) {
      throw ArgumentError('Le nom du fournisseur est requis.');
    }

    await _client.from(tableName).insert(<String, dynamic>{
      'id': id,
      'name': cleanedName,
      'phone_number': phoneNumber.trim(),
      'note': _nullable(note),
      'is_active': true,
      'is_deleted': false,
      'created_by_uid': uid,
      'created_by_name': staffName.trim(),
      'updated_by_uid': uid,
      'updated_by_name': staffName.trim(),
    });
    return id;
  }

  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    _requireSameFirebaseUser(staffId);
    final String cleanedName = name.trim();
    if (cleanedName.length < 2) {
      throw ArgumentError('Le nom du fournisseur est requis.');
    }
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'name': cleanedName,
          'phone_number': phoneNumber.trim(),
          'note': _nullable(note),
          'updated_by_name': staffName.trim(),
        })
        .eq('id', supplierId.trim())
        .eq('is_deleted', false);
  }

  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) async {
    _requireSameFirebaseUser(staffId);
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'is_active': isActive,
          'updated_by_name': staffName.trim(),
        })
        .eq('id', supplierId.trim())
        .eq('is_deleted', false);
  }

  Future<void> softDeleteSupplier({
    required String supplierId,
    required String staffId,
    required String staffName,
  }) async {
    _requireSameFirebaseUser(staffId);
    await _client
        .from(tableName)
        .update(<String, dynamic>{
          'is_active': false,
          'is_deleted': true,
          'updated_by_name': staffName.trim(),
        })
        .eq('id', supplierId.trim())
        .eq('is_deleted', false);
  }

  Future<void> hideSupplierAfterMirrorFailure({
    required String supplierId,
    required String staffId,
    required String staffName,
  }) {
    return softDeleteSupplier(
      supplierId: supplierId,
      staffId: staffId,
      staffName: staffName,
    );
  }

  FinanceSupplier? _supplierFromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final String name = _string(row['name']);
    final DateTime? createdAt =
        _date(row['legacy_created_at']) ?? _date(row['created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (id.isEmpty || name.isEmpty || createdAt == null || updatedAt == null) {
      return null;
    }

    return FinanceSupplier(
      id: id,
      name: name,
      phoneNumber: _string(row['phone_number']),
      isActive: row['is_active'] == true && row['is_deleted'] != true,
      note: _nullable(row['note']),
      createdAt: createdAt,
      createdBy: _string(
        row['legacy_created_by_uid'],
        fallback: _string(row['created_by_uid']),
      ),
      createdByName: _string(
        row['legacy_created_by_name'],
        fallback: _string(row['created_by_name']),
      ),
      updatedAt: updatedAt,
    );
  }

  String _currentUid() {
    final String uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) throw StateError('Aucune session Firebase active.');
    return uid;
  }

  String _currentDisplayName() {
    final String value = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim();
    return value.isEmpty ? 'Migration Firebase' : value;
  }

  void _requireSameFirebaseUser(String staffId) {
    final String uid = _currentUid();
    if (uid != staffId.trim()) {
      throw StateError(
        'La session Firebase ne correspond pas à l’administrateur actif.',
      );
    }
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final String text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(Object? value) {
    final String text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
