import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';

abstract class CustomerOrderRepository {
  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderDraft draft,
  });
}
