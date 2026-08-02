import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';

abstract class CustomerOrderRepository {
  Future<CustomerOrderReceipt> createOrder({required CustomerOrderDraft draft});

  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderReceipt order,
  });

  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  });
}
