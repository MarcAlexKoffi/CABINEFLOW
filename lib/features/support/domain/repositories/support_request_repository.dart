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
}
