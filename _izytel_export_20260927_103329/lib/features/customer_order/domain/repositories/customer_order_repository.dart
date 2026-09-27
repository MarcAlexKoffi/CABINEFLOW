import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class CustomerOrderRepository {
  Future<CustomerOrderReceipt> createOrder({required CustomerOrderDraft draft});

  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderReceipt order,
    required PaymentDeclaration declaration,
  });

  Future<CustomerOrderReceipt> synchronizeExpiration({
    required CustomerOrderReceipt order,
  });

  Future<CustomerOrderReceipt> recoverOrder({
    required String reference,
    required String whatsappInput,
  });

  Future<CustomerOrderReceipt> recoverOrderByCode({
    required String reference,
    required String recoveryCodeInput,
  });

  Future<CustomerOrderReceipt> findCustomerOrder({
    required MobileNetwork network,
    required CustomerService service,
    required String beneficiaryInput,
  });

  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  });

  Stream<List<CustomerOrderReceipt>> watchCustomerOrders();
}
