import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/frequent_beneficiary_contact.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contacts bénéficiaires fréquents', () {
    test('déduplique le couple nom + numéro et conserve les contacts distincts', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();

      await _createPaidOrder(
        repository,
        name: 'Marc Koffi',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );
      await _createPaidOrder(
        repository,
        name: 'Marc Koffi',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.mtn,
      );
      await _createPaidOrder(
        repository,
        name: 'Awa Touré',
        beneficiary: '05 11 22 33 44',
        network: MobileNetwork.moov,
      );

      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(viewModel, name: 'Client actuel');

      final List<FrequentBeneficiaryContact> contacts =
          viewModel.suggestedBeneficiaryContacts;
      expect(contacts, hasLength(2));
      expect(contacts.first.name, 'Marc Koffi');
      expect(contacts.first.phoneNumber.normalized, '+2250710203040');
      expect(contacts.first.usageCount, 2);
      expect(contacts.last.name, 'Awa Touré');
      expect(contacts.last.phoneNumber.normalized, '+2250511223344');
      expect(contacts.last.usageCount, 1);
      viewModel.dispose();
    });

    test('un même numéro avec deux noms reste deux contacts distincts', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();

      await _createPaidOrder(
        repository,
        name: 'Marc Koffi',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );
      await _createPaidOrder(
        repository,
        name: 'M. Koffi',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );

      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(viewModel, name: 'Client actuel');

      expect(viewModel.suggestedBeneficiaryContacts, hasLength(2));
      viewModel.dispose();
    });

    test('sélectionner un contact remplit le numéro sans avancer automatiquement', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();
      await _createPaidOrder(
        repository,
        name: 'Marc Koffi',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );

      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(viewModel, name: 'Client actuel');

      final int stepBefore = viewModel.currentStep;
      final FrequentBeneficiaryContact contact =
          viewModel.suggestedBeneficiaryContacts.single;
      viewModel.selectSuggestedBeneficiaryContact(
        contact: contact,
        isPortabilityConfirmed: true,
      );

      expect(viewModel.currentStep, stepBefore);
      expect(
        viewModel.draft.beneficiaryNumber?.normalized,
        contact.phoneNumber.normalized,
      );
      viewModel.dispose();
    });
  });
}

Future<void> _createPaidOrder(
  FakeCustomerOrderRepository repository, {
  required String name,
  required String beneficiary,
  required MobileNetwork network,
}) async {
  final String legacyPhone = network == MobileNetwork.orange
      ? '07 00 00 00 00'
      : network == MobileNetwork.mtn
          ? '05 00 00 00 00'
          : '01 00 00 00 00';
  final CustomerOrderReceipt created = await repository.createOrder(
    draft: CustomerOrderDraft(
      identity: CustomerIdentity(
        name: name,
        whatsappNumber: WhatsappPhoneNumber.parse(legacyPhone),
      ),
      service: CustomerService.unitTransfer,
      network: network,
      amount: 1000,
      beneficiaryNumber: BeneficiaryPhoneNumber.parse(beneficiary),
    ),
  );
  await repository.declarePayment(
    order: created,
    declaration: PaymentDeclaration.parse(
      waveAccountName: name,
      wavePayerPhoneInput: legacyPhone,
      approximatePaymentTime: '12:00',
    ),
  );
}

void _prepareBeneficiaryStep(
  CustomerOrderViewModel viewModel, {
  required String name,
}) {
  viewModel.saveIdentity(name: name);
  viewModel.selectService(CustomerService.unitTransfer);
  viewModel.continueFromService();
  viewModel.selectNetwork(MobileNetwork.orange);
  viewModel.continueFromNetwork();
  viewModel.setTransferAmount(1000);
  viewModel.continueFromOffer();
}
