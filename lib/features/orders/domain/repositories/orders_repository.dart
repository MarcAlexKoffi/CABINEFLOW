import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
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

  Stream<List<QueueOrder>> watchAssignedOrders({required String agentId});

  Future<QueueOrder> acceptAgentAssignment({
    required String orderId,
    required String agentId,
  });

  Future<QueueOrder> refuseAgentAssignment({
    required String orderId,
    required String agentId,
    required String reason,
  });

  Future<QueueOrder> startAgentProcessing({
    required String orderId,
    required String agentId,
  });

  Future<QueueOrder> resumeAgentProcessing({
    required String orderId,
    required String agentId,
  });

  Future<OrderProof?> fetchOrderProof({required String orderId});

  Future<OrderProof> saveOrderProof({
    required String orderId,
    required String orderReference,
    required String agentId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  });

  Future<QueueOrder> markAgentSuccessful({
    required String orderId,
    required String agentId,
  });

  Future<QueueOrder> markAgentFailed({
    required String orderId,
    required String agentId,
    required OrderFailureReason reason,
    String? observation,
  });

  Future<QueueOrder> putAgentOnHold({
    required String orderId,
    required String agentId,
    required String reason,
  });

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
