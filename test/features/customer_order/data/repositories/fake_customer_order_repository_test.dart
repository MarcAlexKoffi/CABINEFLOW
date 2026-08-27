import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
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

    final PaymentDeclaration declaration = PaymentDeclaration.parse(
      waveAccountName: 'Alex Koffi',
      wavePayerPhoneInput: '07 00 00 00 00',
      approximatePaymentTime: '18:42',
      declaredWaveReference: 'WAVE-TEST-001',
    );

    final CustomerOrderReceipt declaredOrder = await repository.declarePayment(
      order: createdOrder,
      declaration: declaration,
    );

    expect(declaredOrder.status, QueueOrderStatus.paymentToVerify);
    expect(declaredOrder.paymentStatus, OrderPaymentStatus.declared);
    expect(declaredOrder.paymentDeclaredAt, isNotNull);
    expect(declaredOrder.paymentDeclaration?.waveAccountName, 'Alex Koffi');
    expect(
      declaredOrder.paymentDeclaration?.wavePayerPhone.normalized,
      '+2250700000000',
    );
    expect(declaredOrder.paymentDeclaration?.approximatePaymentTime, '18:42');
    expect(
      declaredOrder.paymentDeclaration?.declaredWaveReference,
      'WAVE-TEST-001',
    );
    expect(declaredOrder.draft.amount, 2000);
  });

  test(
    'retrouve uniquement la commande correspondant à la référence et au WhatsApp',
    () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository(now: () => DateTime(2026, 8, 27, 14));
      final CustomerOrderDraft draft = CustomerOrderDraft(
        identity: CustomerIdentity(
          name: 'Mariam',
          whatsappNumber: WhatsappPhoneNumber.parse('07 12 34 56 78'),
        ),
        service: CustomerService.unitTransfer,
        network: MobileNetwork.mtn,
        amount: 1500,
        beneficiaryNumber: BeneficiaryPhoneNumber.parse('05 11 22 33 44'),
      );
      final CustomerOrderReceipt created = await repository.createOrder(
        draft: draft,
      );

      final CustomerOrderReceipt recovered = await repository.recoverOrder(
        reference: created.reference.toLowerCase(),
        whatsappInput: '+225 07 12 34 56 78',
      );

      expect(recovered.id, created.id);
      await expectLater(
        repository.recoverOrder(
          reference: created.reference,
          whatsappInput: '05 00 00 00 00',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}
