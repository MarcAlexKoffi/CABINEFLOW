import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crée la commande avant la déclaration du paiement', () async {
    final FakeCustomerOrderRepository repository =
        FakeCustomerOrderRepository();

    final CustomerOrderDraft draft = CustomerOrderDraft(
      identity: CustomerIdentity(
        name: 'Alex',
        whatsappNumber: WhatsappPhoneNumber.parse('07 00 00 00 00'),
      ),
      service: CustomerService.unitTransfer,
      network: MobileNetwork.orange,
      amount: 2000,
      beneficiaryNumber: BeneficiaryPhoneNumber.parse('05 12 34 56 78'),
    );

    final CustomerOrderReceipt createdOrder = await repository.createOrder(
      draft: draft,
    );

    expect(createdOrder.reference, startsWith('CF-'));
    expect(createdOrder.status, QueueOrderStatus.awaitingPayment);
    expect(createdOrder.paymentStatus, OrderPaymentStatus.notDeclared);
    expect(createdOrder.paymentDeclaredAt, isNull);

    final CustomerOrderReceipt declaredOrder = await repository.declarePayment(
      order: createdOrder,
    );

    expect(declaredOrder.status, QueueOrderStatus.paymentToVerify);
    expect(declaredOrder.paymentStatus, OrderPaymentStatus.declared);
    expect(declaredOrder.paymentDeclaredAt, isNotNull);
    expect(declaredOrder.draft.amount, 2000);
  });
}
