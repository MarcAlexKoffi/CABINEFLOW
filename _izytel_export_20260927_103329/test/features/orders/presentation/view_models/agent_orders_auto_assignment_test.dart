import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'un agent ne prend plus lui-même une commande de la file automatique',
    () async {
      final FakeOrdersRepository orders = FakeOrdersRepository(isTest: true);
      final FakeAgentRepository agents = FakeAgentRepository();

      await agents.updateOwnOperations(
        agentId: 'AGENT-001',
        update: const AgentOperationalUpdate(
          availability: AgentAvailability.available,
          activeNetworks: <AgentNetwork>[AgentNetwork.orange, AgentNetwork.mtn],
          orangeCapacity: 35000,
          mtnCapacity: 18000,
          moovCapacity: 0,
        ),
      );

      final QueueOrder created = await orders.createOrder(
        request: const CreateOrderRequest(
          clientName: 'Client',
          clientWhatsappPhone: '0700000000',
          network: MobileNetwork.mtn,
          beneficiaryPhone: '0500000000',
          operationType: OrderOperationType.unitTransfer,
          offerLabel: 'Transfert',
          amount: 2000,
        ),
      );
      await orders.confirmPayment(
        orderId: created.id,
        paidAt: DateTime(2026, 8, 26, 10),
        paymentReference: 'PAY-003',
      );

      final AgentOrdersViewModel viewModel = AgentOrdersViewModel(
        agentId: 'AGENT-001',
        ordersRepository: orders,
        agentRepository: agents,
      );
      await viewModel.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Le round-robin est désormais décidé par le moteur staff unique.
      // L'application Agent ne concurrence plus cette décision.
      expect(viewModel.toAcceptOrders, isEmpty);
      expect(await orders.watchAutomaticAssignmentQueue().first, isNotEmpty);

      viewModel.dispose();
    },
  );
}
