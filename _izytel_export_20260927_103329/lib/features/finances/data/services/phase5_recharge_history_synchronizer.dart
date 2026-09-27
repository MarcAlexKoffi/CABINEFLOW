import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_history_repository.dart';
import 'package:cabine_flow/features/finances/data/services/phase5_consolidated_synchronizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Compatibilité avec l'ancien point d'entrée Phase 5A.
///
/// La reprise est désormais consolidée : appeler ce service exécute le
/// synchroniseur Phase 5 complet, afin qu'aucune partie financière n'évolue
/// séparément.
@Deprecated('Utiliser Phase5ConsolidatedSynchronizer')
class Phase5RechargeHistorySynchronizer {
  Phase5RechargeHistorySynchronizer({
    FirebaseFirestore? firestore,
    SupabasePhase5HistoryRepository? phase5Repository,
  }) : _delegate = Phase5ConsolidatedSynchronizer(
         firestore: firestore,
         syncRepository: phase5Repository,
       );

  static const int defaultBatchSize =
      Phase5ConsolidatedSynchronizer.defaultBatchSize;

  final Phase5ConsolidatedSynchronizer _delegate;

  Future<void> synchronize({int batchSize = defaultBatchSize}) =>
      _delegate.synchronize(batchSize: batchSize);
}
