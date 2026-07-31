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
  test('enregistre une déclaration de paiement avec une référence CF',
      () async {
    final FakeCustomerOrderRepository repository =
        FakeCustomerOrderRepository();

    final CustomerOrderDraft draft = CustomerOrderDraft(
      identity: CustomerIdentity(
        name: 'Alex',
        whatsappNumber: WhatsappPhoneNumber.parse(
          '07 00 00 00 00',
        ),
      ),
      service: CustomerService.unitTransfer,
      network: MobileNetwork.orange,
      amount: 2000,
      beneficiaryNumber: BeneficiaryPhoneNumber.parse(
        '05 12 34 56 78',
      ),
    );

    final CustomerOrderReceipt receipt =
        await repository.declarePayment(draft: draft);

    expect(receipt.reference, startsWith('CF-'));
    expect(
      receipt.status,
      CustomerOrderTrackingStatus.paymentDeclared,
    );
    expect(receipt.draft.amount, 2000);
  });
}
