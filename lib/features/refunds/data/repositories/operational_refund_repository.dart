import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/supabase_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:firebase_core/firebase_core.dart';

/// Construit la source opérationnelle de remboursements.
///
/// En production, aucune nouvelle écriture ne retombe sur Firestore. Le Fake
/// reste réservé aux tests/environnements sans Firebase.
RefundRepository createOperationalRefundRepository() {
  if (SupabaseBootstrap.isInitialized) return SupabaseRefundRepository();
  if (Firebase.apps.isEmpty) return FakeRefundRepository();
  return const _UnavailableRefundRepository();
}

class _UnavailableRefundRepository implements RefundRepository {
  const _UnavailableRefundRepository();

  StateError get _error => StateError(
    'Supabase est indisponible. IzyTel ne bascule pas les remboursements vers Firestore.',
  );

  @override
  Stream<List<RefundCase>> watchAll() => Stream<List<RefundCase>>.error(_error);

  @override
  Stream<RefundCase?> watchForOrder({required String orderId}) =>
      Stream<RefundCase?>.error(_error);

  @override
  Future<RefundCase> create({
    required RefundCreationRequest request,
    required String staffId,
    required String staffName,
  }) => Future<RefundCase>.error(_error);

  @override
  Future<void> approve({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);

  @override
  Future<void> reject({
    required String orderId,
    required String staffId,
    required String staffName,
    required String reason,
  }) => Future<void>.error(_error);

  @override
  Future<void> markRefunded({
    required String orderId,
    required String staffId,
    required String staffName,
    required String refundReference,
  }) => Future<void>.error(_error);

  @override
  Future<void> markCustomerNotified({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);

  @override
  Future<void> reconcile({
    required String orderId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);
}
