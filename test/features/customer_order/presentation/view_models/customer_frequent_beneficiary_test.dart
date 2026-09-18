import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Raccourcis bénéficiaires fréquents', () {
    test('le numéro apparaît seulement à partir de la troisième commande', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();
      const String whatsapp = '05 00 00 00 00';
      const String beneficiary = '07 10 20 30 40';

      await _createPaidOrder(
        repository,
        whatsapp: whatsapp,
        beneficiary: beneficiary,
        network: MobileNetwork.orange,
      );

      CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(
        viewModel,
        whatsapp: whatsapp,
        network: MobileNetwork.orange,
      );

      expect(viewModel.suggestedBeneficiaryNumbers, isEmpty);
      viewModel.dispose();

      await _createPaidOrder(
        repository,
        whatsapp: whatsapp,
        beneficiary: beneficiary,
        network: MobileNetwork.orange,
      );

      viewModel = CustomerOrderViewModel(orderRepository: repository);
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(
        viewModel,
        whatsapp: whatsapp,
        network: MobileNetwork.orange,
      );

      expect(viewModel.suggestedBeneficiaryNumbers, hasLength(1));
      expect(
        viewModel.suggestedBeneficiaryNumbers.single.normalized,
        '+2250710203040',
      );
      viewModel.dispose();
    });

    test('une autre identité ou un autre réseau ne déclenche pas la suggestion', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();

      await _createPaidOrder(
        repository,
        whatsapp: '05 00 00 00 00',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );
      await _createPaidOrder(
        repository,
        whatsapp: '01 00 00 00 00',
        beneficiary: '07 10 20 30 40',
        network: MobileNetwork.orange,
      );
      await _createPaidOrder(
        repository,
        whatsapp: '05 00 00 00 00',
        beneficiary: '05 10 20 30 40',
        network: MobileNetwork.mtn,
      );

      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(
        viewModel,
        whatsapp: '05 00 00 00 00',
        network: MobileNetwork.orange,
      );

      expect(viewModel.suggestedBeneficiaryNumbers, isEmpty);
      viewModel.dispose();
    });

    test('un numéro suggéré peut être sélectionné sans double confirmation', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();
      for (int index = 0; index < 2; index++) {
        await _createPaidOrder(
          repository,
          whatsapp: '05 00 00 00 00',
          beneficiary: '07 10 20 30 40',
          network: MobileNetwork.orange,
        );
      }

      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );
      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _prepareBeneficiaryStep(
        viewModel,
        whatsapp: '05 00 00 00 00',
        network: MobileNetwork.orange,
      );

      final BeneficiaryPhoneNumber suggestion =
          viewModel.suggestedBeneficiaryNumbers.single;
      viewModel.selectSuggestedBeneficiary(beneficiary: suggestion);

      expect(viewModel.currentStep, 6);
      expect(viewModel.draft.beneficiaryNumber?.normalized, suggestion.normalized);
      viewModel.dispose();
    });
  });
}

Future<void> _createPaidOrder(
  FakeCustomerOrderRepository repository, {
  required String whatsapp,
  required String beneficiary,
  required MobileNetwork network,
}) async {
  final CustomerOrderReceipt created = await repository.createOrder(
    draft: CustomerOrderDraft(
      identity: CustomerIdentity(
        name: 'Client test',
        whatsappNumber: WhatsappPhoneNumber.parse(whatsapp),
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
      waveAccountName: 'Client test',
      wavePayerPhoneInput: whatsapp,
      approximatePaymentTime: '12:00',
    ),
  );
}

void _prepareBeneficiaryStep(
  CustomerOrderViewModel viewModel, {
  required String whatsapp,
  required MobileNetwork network,
}) {
  viewModel.saveIdentity(name: 'Client test', whatsappInput: whatsapp);
  viewModel.selectService(CustomerService.unitTransfer);
  viewModel.continueFromService();
  viewModel.selectNetwork(network);
  viewModel.continueFromNetwork();
  viewModel.setTransferAmount(1000);
  viewModel.continueFromOffer();
}
