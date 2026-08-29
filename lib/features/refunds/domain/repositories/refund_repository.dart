import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';

abstract class RefundRepository {
  Stream<List<RefundCase>> watchAll();

  Stream<RefundCase?> watchForOrder({required String orderId});

  Future<RefundCase> create({
    required RefundCreationRequest request,
    required String staffId,
    required String staffName,
  });

  Future<void> approve({
    required String orderId,
    required String staffId,
    required String staffName,
  });

  Future<void> reject({
    required String orderId,
    required String staffId,
    required String staffName,
    required String reason,
  });

  Future<void> markRefunded({
    required String orderId,
    required String staffId,
    required String staffName,
    required String refundReference,
  });

  Future<void> markCustomerNotified({
    required String orderId,
    required String staffId,
    required String staffName,
  });

  Future<void> reconcile({
    required String orderId,
    required String staffId,
    required String staffName,
  });
}
