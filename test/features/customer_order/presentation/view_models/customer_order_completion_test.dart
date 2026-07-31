import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'le récapitulatif, le paiement et la confirmation terminent le flux',
    () async {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Client test',
        whatsappInput: '07 00 00 00 00',
      );
      viewModel.selectService(CustomerService.unitTransfer);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.setTransferAmount(2000);
      viewModel.continueFromOffer();
      viewModel.saveBeneficiary(
        phoneInput: '05 12 34 56 78',
        confirmationInput: '05 12 34 56 78',
      );

      expect(viewModel.currentStep, 6);

      viewModel.continueFromSummary();
      expect(viewModel.currentStep, 7);

      final bool successful = await viewModel.declarePaymentAndSubmitOrder();

      expect(successful, isTrue);
      expect(viewModel.currentStep, 8);
      expect(viewModel.receipt, isNotNull);
      expect(
        viewModel.receipt?.status,
        CustomerOrderTrackingStatus.paymentDeclared,
      );

      viewModel.restart();

      expect(viewModel.currentStep, 1);
      expect(viewModel.receipt, isNull);
      expect(viewModel.draft.identity, isNull);
    },
  );
}
