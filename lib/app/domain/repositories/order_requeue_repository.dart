import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';

abstract interface class OrderRequeueRepository {
  Future<QueueOrder> returnOrderToQueue({
    required String orderId,
    required String reason,
  });
  Future<void> verifyOrderNotExecuted({
    required String orderId,
    required String reason,
    required int assignmentVersion,
  });
}

abstract interface class OrderExecutionAuthorizationRepository {
  Future<QueueOrder> authorizeAgentExecution(QueueOrder order);
}
