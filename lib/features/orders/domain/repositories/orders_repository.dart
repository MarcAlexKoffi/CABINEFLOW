import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class OrdersRepository {
  Future<List<QueueOrder>> fetchPaidQueue();

  Future<QueueOrder> takeCharge({
    required String orderId,
    required String operatorId,
  });
}
