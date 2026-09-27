import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_context_repository.dart';

class FakeCustomerOrderContextRepository
    implements CustomerOrderContextRepository {
  final Map<String, CustomerOrderContextDraft> contexts =
      <String, CustomerOrderContextDraft>{};

  @override
  Future<void> registerContext({
    required CustomerOrderReceipt order,
    required CustomerOrderContextDraft context,
  }) async {
    contexts[order.id] = context;
  }
}
