import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class OrdersRepository {
  Future<QueueOrder> createOrder({required CreateOrderRequest request});

  Future<QueueOrder> markPaymentRequestSent({required String orderId});

  Future<List<QueueOrder>> fetchPaymentTrackingOrders();

  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  });

  Future<List<QueueOrder>> fetchPaidQueue();

  Future<QueueOrder> assignToAgent({
    required String orderId,
    required String agentId,
    required String assignedByUserId,
  });

  Future<Map<String, int>> fetchActiveAssignmentCounts();

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
