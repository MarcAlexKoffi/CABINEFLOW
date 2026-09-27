import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';

class BrowserCustomerOrderSessionStore implements CustomerOrderSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<CustomerOrderSession?> read() async => null;

  @override
  Future<void> save(CustomerOrderSession session) async {}
}
