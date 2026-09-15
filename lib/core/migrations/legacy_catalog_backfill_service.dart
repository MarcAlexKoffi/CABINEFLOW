import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/offers/data/models/firestore_offer_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Migration ponctuelle Firestore `offers` -> Supabase `catalog_offers`.
///
/// Aucune écriture métier nouvelle n'est faite dans Firestore. Le document
/// historique n'est lu que pour reprendre l'existant et son identifiant.
class LegacyCatalogBackfillService {
  LegacyCatalogBackfillService({
    FirebaseFirestore? firestore,
    SupabaseClient? client,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? Supabase.instance.client;

  final FirebaseFirestore _firestore;
  final SupabaseClient _client;

  Future<int> runIfNeeded() async {
    if (!SupabaseBootstrap.isInitialized) {
      return 0;
    }
    try {
      return await _run(force: false);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'LegacyCatalogBackfillService.Auto',
        error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<int> synchronizeNow() {
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('Supabase n’est pas initialisé.');
    }
    return _run(force: true);
  }

  Future<int> _run({required bool force}) async {
    if (!force) {
      final dynamic needed = await _client.rpc('izytel_catalog_backfill_needed');
      if (needed != true) {
        return 0;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('offers').get();
    int imported = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();
      final FirestoreOfferData? parsed = FirestoreOfferData.tryParse(
        id: document.id,
        data: data,
      );
      if (parsed == null) {
        IzyTelLog.debug(
          '[CatalogBackfill] Offre Firestore ignorée car invalide: ${document.id}',
        );
        continue;
      }

      final dynamic result = await _client.rpc(
        'izytel_import_legacy_catalog_offer',
        params: <String, dynamic>{
          'p_offer_id': document.id,
          'p_payload': _jsonMap(data),
        },
      );
      if (result == true) {
        imported += 1;
      }
    }

    await _client.rpc(
      'izytel_finish_catalog_backfill',
      params: <String, dynamic>{'p_imported_count': imported},
    );
    return imported;
  }

  Map<String, dynamic> _jsonMap(Map<String, dynamic> source) {
    return source.map(
      (String key, dynamic value) => MapEntry<String, dynamic>(
        key,
        _jsonValue(value),
      ),
    );
  }

  dynamic _jsonValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is List) {
      return value.map<dynamic>(_jsonValue).toList(growable: false);
    }
    if (value is Map<Object?, Object?>) {
      final Map<String, dynamic> result = <String, dynamic>{};
      value.forEach((Object? key, Object? nested) {
        result[key.toString()] = _jsonValue(nested);
      });
      return result;
    }
    return value;
  }
}
