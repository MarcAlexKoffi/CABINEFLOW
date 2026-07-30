import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class OrdersRepository {
  Future<List<QueueOrder>> fetchPaidQueue();

  Future<QueueOrder> takeCharge({
    required String orderId,
    required String operatorId,
  });

  Future<QueueOrder> markSuccessful({required String orderId});

  Future<QueueOrder> markFailed({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  });

  Future<QueueOrder> putOnHold({required String orderId});

  Future<QueueOrder> completeCustomerConfirmation({
    required String orderId,
    required bool messageSent,
  });
}
