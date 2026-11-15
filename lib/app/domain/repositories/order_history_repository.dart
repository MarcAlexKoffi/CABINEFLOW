import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';

abstract class OrderHistoryRepository {
  Future<List<QueueOrder>> fetchOrderHistory();

  Stream<List<QueueOrder>> watchOrderHistory();

  Future<QueueOrder> fetchOrderById({required String orderId});
}
