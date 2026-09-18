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
  group('Phase 10B - récupération autre appareil', () {
    test(
      'une récupération réussie ouvre directement le suivi en étape 8',
      () async {
        final FakeCustomerOrderRepository repository =
            FakeCustomerOrderRepository(now: () => DateTime(2026, 8, 27, 15));
        final CustomerOrderReceipt created = await repository.createOrder(
          draft: CustomerOrderDraft(
            identity: CustomerIdentity(
              name: 'Koffi',
              whatsappNumber: WhatsappPhoneNumber.parse('07 00 00 00 10'),
            ),
            service: CustomerService.unitTransfer,
            network: MobileNetwork.orange,
            amount: 1000,
            beneficiaryNumber: BeneficiaryPhoneNumber.parse('05 00 00 00 10'),
          ),
        );
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: repository,
        );

        final bool recovered = await viewModel.recoverOrder(
          reference: created.reference,
          whatsappInput: '07 00 00 00 10',
        );

        expect(recovered, isTrue);
        expect(viewModel.currentStep, 8);
        expect(viewModel.receipt?.id, created.id);
        expect(viewModel.paymentLinkWasOpened, isFalse);
        expect(viewModel.recoveryErrorMessage, isNull);

        viewModel.dispose();
      },
    );

    test(
      'retrouve une commande avec réseau, type et numéro bénéficiaire',
      () async {
        final FakeCustomerOrderRepository repository =
            FakeCustomerOrderRepository();
        final CustomerOrderReceipt created = await repository.createOrder(
          draft: CustomerOrderDraft(
            identity: CustomerIdentity(
              name: 'Koffi',
              whatsappNumber: WhatsappPhoneNumber.parse('07 00 00 00 10'),
            ),
            service: CustomerService.calls,
            network: MobileNetwork.orange,
            customOfferLabel: 'Souscription appel Orange',
            amount: 1000,
            beneficiaryNumber: BeneficiaryPhoneNumber.parse('07 11 22 33 44'),
          ),
        );
        await repository.declarePayment(
          order: created,
          declaration: PaymentDeclaration.parse(
            waveAccountName: 'Koffi',
            wavePayerPhoneInput: '07 00 00 00 10',
            approximatePaymentTime: '15:00',
          ),
        );
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: repository,
        );

        final bool recovered = await viewModel.recoverOrderByDetails(
          network: MobileNetwork.orange,
          service: CustomerService.calls,
          beneficiaryInput: '07 11 22 33 44',
        );

        expect(recovered, isTrue);
        expect(viewModel.currentStep, 8);
        expect(viewModel.receipt?.id, created.id);
        expect(viewModel.recoveryErrorMessage, isNull);
        viewModel.dispose();
      },
    );

    test('une mauvaise combinaison affiche toujours le message neutre', () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository(now: () => DateTime(2026, 8, 27, 15));
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
      );

      final bool recovered = await viewModel.recoverOrder(
        reference: 'CF-20260827-ABC123',
        whatsappInput: '07 00 00 00 10',
      );

      expect(recovered, isFalse);
      expect(
        viewModel.recoveryErrorMessage,
        'Commande introuvable ou informations incorrectes. Vérifiez la référence et le numéro WhatsApp saisis.',
      );

      viewModel.dispose();
    });
  });
}
