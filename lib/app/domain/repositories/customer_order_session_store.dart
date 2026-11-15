import 'package:cabine_flow/app/domain/entities/customer/customer_order_session.dart';

abstract class CustomerOrderSessionStore {
  Future<CustomerOrderSession?> read();

  Future<void> save(CustomerOrderSession session);

  Future<void> clear();
}
