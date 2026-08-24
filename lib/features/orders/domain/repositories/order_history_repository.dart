import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class OrderHistoryRepository {
  Future<List<QueueOrder>> fetchOrderHistory();

  Future<QueueOrder> fetchOrderById({required String orderId});
}
