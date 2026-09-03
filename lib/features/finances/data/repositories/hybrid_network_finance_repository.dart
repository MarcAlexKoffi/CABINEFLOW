import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';

/// Phase 5 : l'historique réseau est lu exclusivement dans le registre
/// Supabase. Le dépôt Firestore est conservé dans la signature uniquement pour
/// compatibilité d'injection des anciens tests et sera retiré avec le domaine
/// Commandes post-handoff.
class HybridNetworkFinanceRepository implements NetworkFinanceRepository {
  HybridNetworkFinanceRepository({
    SupabasePhase5FinanceRepository? phase5Repository,
  }) : _phase5 = phase5Repository ?? SupabasePhase5FinanceRepository();

  final SupabasePhase5FinanceRepository _phase5;

  @override
  Stream<List<NetworkTransaction>> watchTransactions() =>
      _phase5.watchNetworkMovements();
}
