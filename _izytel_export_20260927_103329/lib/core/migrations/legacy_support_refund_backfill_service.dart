import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pont de migration ponctuel Firestore -> Supabase.
///
/// Il ne sert jamais de source opérationnelle : il copie uniquement les
/// anciens dossiers Support/Remboursements dans les nouvelles tables Supabase.
/// Les RPC d'import sont idempotentes, donc une reconnexion Admin peut relancer
/// ce service sans dupliquer les données ni écraser les transitions Supabase.
class LegacySupportRefundBackfillService {
  LegacySupportRefundBackfillService({
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabase ?? Supabase.instance.client;

  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;

  Future<void> run() async {
    if (!SupabaseBootstrap.isInitialized) return;
    try {
      await _importSupportRequests();
      await _importRefunds();
    } catch (error, stackTrace) {
      // Le backfill ne doit jamais empêcher l'ouverture du Back-office. Si la
      // migration SQL n'est pas encore appliquée, les repositories Supabase
      // afficheront leur état d'erreur normalement et le prochain login Admin
      // retentera la copie.
      IzyTelLog.backendError(
        'LegacySupportRefundBackfill',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _importSupportRequests() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('supportRequests')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      try {
        await _supabase.rpc(
          'izytel_import_legacy_support_request',
          params: <String, dynamic>{
            'p_payload': <String, dynamic>{
              'id': document.id,
              ..._jsonSafeMap(document.data()),
            },
          },
        );
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'LegacySupportBackfill.item',
          error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _importRefunds() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('refunds')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      try {
        await _supabase.rpc(
          'izytel_import_legacy_refund',
          params: <String, dynamic>{
            'p_payload': <String, dynamic>{
              'id': document.id,
              ..._jsonSafeMap(document.data()),
            },
          },
        );
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'LegacyRefundBackfill.item',
          error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> source) {
    return <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in source.entries)
        entry.key: _jsonSafe(entry.value),
    };
  }

  Object? _jsonSafe(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    return value;
  }
}
