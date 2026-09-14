import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/supabase_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:firebase_core/firebase_core.dart';

/// Source canonique Support : Supabase en production, Fake uniquement en test.
SupportRequestRepository createOperationalSupportRequestRepository() {
  if (SupabaseBootstrap.isInitialized) {
    return SupabaseSupportRequestRepository();
  }
  if (Firebase.apps.isEmpty) return FakeSupportRequestRepository();
  return const _UnavailableSupportRequestRepository();
}

class _UnavailableSupportRequestRepository implements SupportRequestRepository {
  const _UnavailableSupportRequestRepository();

  StateError get _error => StateError(
    'Supabase est indisponible. IzyTel ne bascule pas les demandes clients vers Firestore.',
  );

  @override
  Future<SupportRequest> create({
    required String orderId,
    required String orderReference,
    required SupportRequestType type,
    required String description,
  }) => Future<SupportRequest>.error(_error);

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) =>
      Stream<List<SupportRequest>>.error(_error);

  @override
  Stream<List<SupportRequest>> watchNewRequests() =>
      Stream<List<SupportRequest>>.error(_error);

  @override
  Stream<List<SupportRequest>> watchAllRequests() =>
      Stream<List<SupportRequest>>.error(_error);

  @override
  Future<void> takeInCharge({
    required String requestId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);

  @override
  Future<void> resolve({
    required String requestId,
    required String staffId,
    required String staffName,
    required String resolutionNote,
  }) => Future<void>.error(_error);

  @override
  Future<void> markCustomerNotified({
    required String requestId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);

  @override
  Future<void> close({
    required String requestId,
    required String staffId,
    required String staffName,
  }) => Future<void>.error(_error);
}
