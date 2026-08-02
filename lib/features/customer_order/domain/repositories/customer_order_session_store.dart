import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';

abstract class CustomerOrderSessionStore {
  Future<CustomerOrderSession?> read();

  Future<void> save(CustomerOrderSession session);

  Future<void> clear();
}
