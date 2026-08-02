import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'crée la commande avant Wave puis déclare le paiement séparément',
    () async {
      final FakeCustomerOrderRepository repository =
          FakeCustomerOrderRepository();
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: repository,
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

      final bool orderCreated = await viewModel
          .createOrderAndContinueToPayment();

      expect(orderCreated, isTrue);
      expect(viewModel.currentStep, 7);
      expect(viewModel.receipt, isNotNull);
      expect(viewModel.receipt?.status, QueueOrderStatus.awaitingPayment);
      expect(viewModel.receipt?.paymentStatus, OrderPaymentStatus.notDeclared);

      final bool paymentDeclared = await viewModel.declarePayment();

      expect(paymentDeclared, isTrue);
      expect(viewModel.currentStep, 8);
      expect(viewModel.receipt?.status, QueueOrderStatus.paymentToVerify);
      expect(viewModel.receipt?.paymentStatus, OrderPaymentStatus.declared);

      final currentReceipt = viewModel.receipt!;
      repository.simulateOrderUpdate(
        currentReceipt.copyWith(
          status: QueueOrderStatus.paidReady,
          paymentStatus: OrderPaymentStatus.confirmed,
          paymentConfirmedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.receipt?.status, QueueOrderStatus.paidReady);
      expect(viewModel.receipt?.paymentStatus, OrderPaymentStatus.confirmed);

      viewModel.restart();

      expect(viewModel.currentStep, 1);
      expect(viewModel.receipt, isNull);
      expect(viewModel.draft.identity, isNull);
    },
  );
}
