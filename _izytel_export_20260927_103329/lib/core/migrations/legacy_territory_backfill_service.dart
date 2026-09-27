import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration ponctuelle des anciennes zones Firestore vers Supabase.
///
/// Le service ne sert jamais de source opérationnelle : il conserve seulement
/// les identifiants historiques pour que les `zone_ids` déjà présents dans les
/// profils Agents restent valides après le cutover Supabase.
class LegacyTerritoryBackfillService {
  LegacyTerritoryBackfillService({
    FirebaseFirestore? firestore,
    SupabaseTerritoryRepository? territoryRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _territoryRepository =
           territoryRepository ?? SupabaseTerritoryRepository();

  final FirebaseFirestore _firestore;
  final SupabaseTerritoryRepository _territoryRepository;

  Future<int> runIfNeeded({bool suppressErrors = true}) async {
    try {
      final bool needed = await _territoryRepository.legacyZoneBackfillNeeded();
      if (!needed) return 0;

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('zones').get();
      int imported = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final bool inserted = await _territoryRepository.importLegacyZone(
          zoneId: document.id,
          name: _string(data['name'], fallback: 'Zone IzyTel'),
          city: _string(data['city']),
          region: _string(data['region']),
          isActive: data['isActive'] != false,
        );
        if (inserted) imported += 1;
      }
      await _territoryRepository.finishLegacyZoneBackfill(imported);
      IzyTelLog.debug('Territory.backfill-complete');
      return imported;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Territory.backfill',
        error,
        stackTrace: stackTrace,
      );
      if (!suppressErrors) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      return 0;
    }
  }

  String _string(Object? value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
