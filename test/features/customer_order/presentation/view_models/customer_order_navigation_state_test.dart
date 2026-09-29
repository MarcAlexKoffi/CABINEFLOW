import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('revenir dans le parcours conserve toutes les informations saisies', () {
    final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
      orderRepository: FakeCustomerOrderRepository(),
    );

    viewModel.saveIdentity(name: 'Client navigation');
    viewModel.selectService(CustomerService.unitTransfer);
    viewModel.continueFromService();
    viewModel.selectNetwork(MobileNetwork.orange);
    viewModel.continueFromNetwork();
    viewModel.setTransferAmount(2000);
    viewModel.continueFromOffer();
    viewModel.saveBeneficiary(
      phoneInput: '07 12 34 56 78',
      confirmationInput: '07 12 34 56 78',
    );

    expect(viewModel.currentStep, 6);
    expect(viewModel.draft.identity?.name, 'Client navigation');
    expect(viewModel.draft.service, CustomerService.unitTransfer);
    expect(viewModel.draft.network, MobileNetwork.orange);
    expect(viewModel.draft.amount, 2000);
    expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250712345678');

    viewModel.restoreNavigationStep(5);

    expect(viewModel.currentStep, 5);
    expect(viewModel.draft.identity?.name, 'Client navigation');
    expect(viewModel.draft.service, CustomerService.unitTransfer);
    expect(viewModel.draft.network, MobileNetwork.orange);
    expect(viewModel.draft.amount, 2000);
    expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250712345678');

    viewModel.restoreNavigationStep(6);

    expect(viewModel.currentStep, 6);
    expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250712345678');
  });
}
