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
  late DateTime now;
  late FakeCustomerOrderRepository repository;
  late CustomerOrderDraft draft;

  setUp(() {
    now = DateTime.utc(2026, 8, 3, 8);
    repository = FakeCustomerOrderRepository(now: () => now);
    draft = CustomerOrderDraft(
      identity: CustomerIdentity(
        name: 'Client test',
        whatsappNumber: WhatsappPhoneNumber.parse('07 00 00 00 00'),
      ),
      service: CustomerService.unitTransfer,
      network: MobileNetwork.orange,
      amount: 3000,
      beneficiaryNumber: BeneficiaryPhoneNumber.parse('05 12 34 56 78'),
    );
  });

  test(
    'expire automatiquement une commande non déclarée après six heures',
    () async {
      final CustomerOrderReceipt createdOrder = await repository.createOrder(
        draft: draft,
      );

      now = now.add(const Duration(hours: 6, minutes: 1));

      final CustomerOrderReceipt expiredOrder = await repository
          .synchronizeExpiration(order: createdOrder);

      expect(expiredOrder.status, QueueOrderStatus.expired);
      expect(expiredOrder.paymentStatus, OrderPaymentStatus.expired);
      expect(expiredOrder.expiredAt, now);
    },
  );

  test(
    'classe un paiement déclaré tardivement comme paiement à examiner',
    () async {
      final CustomerOrderReceipt createdOrder = await repository.createOrder(
        draft: draft,
      );

      now = now.add(const Duration(hours: 6, minutes: 1));
      final CustomerOrderReceipt expiredOrder = await repository
          .synchronizeExpiration(order: createdOrder);

      final PaymentDeclaration declaration = PaymentDeclaration.parse(
        waveAccountName: 'Client test',
        wavePayerPhoneInput: '07 00 00 00 00',
        approximatePaymentTime: '13:58',
        declaredWaveReference: 'LATE-001',
      );

      final CustomerOrderReceipt lateDeclaredOrder = await repository
          .declarePayment(order: expiredOrder, declaration: declaration);

      expect(lateDeclaredOrder.status, QueueOrderStatus.expired);
      expect(lateDeclaredOrder.paymentStatus, OrderPaymentStatus.declared);
      expect(lateDeclaredOrder.hasPaymentToReviewAfterExpiration, isTrue);
    },
  );

  test(
    'expire aussi une déclaration non confirmée avant la fin du délai',
    () async {
      final CustomerOrderReceipt createdOrder = await repository.createOrder(
        draft: draft,
      );

      now = now.add(const Duration(hours: 2));
      final CustomerOrderReceipt declaredOrder = await repository
          .declarePayment(
            order: createdOrder,
            declaration: PaymentDeclaration.parse(
              waveAccountName: 'Client test',
              wavePayerPhoneInput: '07 00 00 00 00',
              approximatePaymentTime: '10:00',
            ),
          );

      now = DateTime.utc(2026, 8, 3, 14, 1);
      final CustomerOrderReceipt expiredOrder = await repository
          .synchronizeExpiration(order: declaredOrder);

      expect(expiredOrder.status, QueueOrderStatus.expired);
      expect(expiredOrder.paymentStatus, OrderPaymentStatus.declared);
      expect(expiredOrder.hasPaymentToReviewAfterExpiration, isTrue);
    },
  );
}
