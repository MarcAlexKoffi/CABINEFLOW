import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';

abstract class CustomerOrderContextRepository {
  Future<void> registerContext({
    required CustomerOrderReceipt order,
    required CustomerOrderContextDraft context,
  });
}
