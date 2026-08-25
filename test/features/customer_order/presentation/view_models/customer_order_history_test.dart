import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySessionStore implements CustomerOrderSessionStore {
  CustomerOrderSession? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<CustomerOrderSession?> read() async => value;

  @override
  Future<void> save(CustomerOrderSession session) async {
    value = session;
  }
}

void main() {
  test('restaure une commande en cours dans le même navigateur', () async {
    final FakeCustomerOrderRepository repository =
        FakeCustomerOrderRepository();
    final _MemorySessionStore sessionStore = _MemorySessionStore();

    final CustomerOrderViewModel firstViewModel = CustomerOrderViewModel(
      orderRepository: repository,
      sessionStore: sessionStore,
    );

    await firstViewModel.initialize();
    await Future<void>.delayed(Duration.zero);

    firstViewModel.saveIdentity(
      name: 'Client test',
      whatsappInput: '07 00 00 00 00',
    );
    firstViewModel.selectService(CustomerService.unitTransfer);
    firstViewModel.continueFromService();
    firstViewModel.selectNetwork(MobileNetwork.orange);
    firstViewModel.continueFromNetwork();
    firstViewModel.setTransferAmount(3000);
    firstViewModel.continueFromOffer();
    firstViewModel.saveBeneficiary(
      phoneInput: '05 12 34 56 78',
      confirmationInput: '05 12 34 56 78',
    );

    final bool created = await firstViewModel.createOrderAndContinueToPayment();

    expect(created, isTrue);
    expect(sessionStore.value, isNotNull);

    final CustomerOrderViewModel restoredViewModel = CustomerOrderViewModel(
      orderRepository: repository,
      sessionStore: sessionStore,
    );

    await restoredViewModel.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(restoredViewModel.customerOrders, hasLength(1));
    expect(restoredViewModel.activeOrder, isNotNull);
    expect(
      restoredViewModel.activeOrder?.reference,
      firstViewModel.receipt?.reference,
    );

    // La restauration est automatique dès que la commande sauvegardée est
    // retrouvée dans l'historique Firestore.
    expect(restoredViewModel.currentStep, 7);
    expect(
      restoredViewModel.receipt?.paymentStatus,
      OrderPaymentStatus.notDeclared,
    );
  });
}
