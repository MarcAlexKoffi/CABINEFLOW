import 'package:cabine_flow/features/support/domain/models/support_request.dart';

abstract class SupportRequestRepository {
  Future<SupportRequest> create({
    required String orderId,
    required String orderReference,
    required SupportRequestType type,
    required String description,
  });

  Stream<List<SupportRequest>> watchForOrder({required String orderId});

  Stream<List<SupportRequest>> watchNewRequests();

  Stream<List<SupportRequest>> watchAllRequests();

  Future<void> takeInCharge({
    required String requestId,
    required String staffId,
    required String staffName,
  });

  Future<void> resolve({
    required String requestId,
    required String staffId,
    required String staffName,
    required String resolutionNote,
  });

  Future<void> markCustomerNotified({required String requestId});

  Future<void> close({required String requestId});
}
