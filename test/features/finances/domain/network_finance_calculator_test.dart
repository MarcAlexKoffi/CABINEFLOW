import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/services/network_finance_calculator.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcule le disponible, l’engagé et les sorties par réseau', () {
    final DateTime now = DateTime(2026, 8, 30, 20);
    final List<AgentDirectoryEntry> agents = <AgentDirectoryEntry>[
      AgentDirectoryEntry(
        userId: 'agent-1',
        name: 'Agent Un',
        email: 'agent1@example.test',
        phoneNumber: '+2250100000000',
        isActive: true,
        profile: AgentProfile(
          userId: 'agent-1',
          agentCode: 'AG-001',
          availability: AgentAvailability.available,
          zoneIds: const <String>[],
          authorizedNetworks: const <AgentNetwork>[
            AgentNetwork.orange,
            AgentNetwork.mtn,
          ],
          activeNetworks: const <AgentNetwork>[
            AgentNetwork.orange,
            AgentNetwork.mtn,
          ],
          orangeCapacity: 50000,
          mtnCapacity: 25000,
          moovCapacity: 0,
          dailyTransactionLimit: 500000,
          maxTransactionsPerDay: 150,
        ),
      ),
    ];
    final List<QueueOrder> orders = <QueueOrder>[
      QueueOrder(
        id: 'order-1',
        reference: 'CF-20260830-AAA001',
        clientName: 'Client Test',
        clientWhatsappPhone: '+2250700000000',
        network: MobileNetwork.orange,
        beneficiaryPhone: '+2250700000001',
        operationType: OrderOperationType.unitTransfer,
        offerLabel: 'Transfert',
        amount: 5000,
        createdAt: now,
        status: QueueOrderStatus.inProgress,
        paymentStatus: OrderPaymentStatus.confirmed,
        assignedAgentId: 'agent-1',
        assignedAgentName: 'Agent Un',
        assignmentStatus: OrderAssignmentStatus.accepted,
      ),
      QueueOrder(
        id: 'order-2',
        reference: 'CF-20260830-AAA002',
        clientName: 'Client Test',
        clientWhatsappPhone: '+2250700000000',
        network: MobileNetwork.mtn,
        beneficiaryPhone: '+2250500000001',
        operationType: OrderOperationType.unitTransfer,
        offerLabel: 'Transfert',
        amount: 3000,
        createdAt: now,
        status: QueueOrderStatus.awaitingCustomerConfirmation,
        paymentStatus: OrderPaymentStatus.confirmed,
        assignedAgentId: 'agent-1',
        assignedAgentName: 'Agent Un',
        assignmentStatus: OrderAssignmentStatus.accepted,
      ),
    ];
    final List<NetworkTransaction> transactions = <NetworkTransaction>[
      NetworkTransaction(
        id: 'order_order-2',
        network: AgentNetwork.mtn,
        direction: NetworkTransactionDirection.outgoing,
        type: NetworkTransactionType.orderSuccess,
        amount: 3000,
        capacityBefore: 28000,
        capacityAfter: 25000,
        agentId: 'agent-1',
        agentName: 'Agent Un',
        orderId: 'order-2',
        orderReference: 'CF-20260830-AAA002',
        createdBy: 'agent-1',
        createdByRole: 'agent',
        createdAt: now,
      ),
    ];

    final Map<AgentNetwork, NetworkFundSnapshot> result =
        NetworkFinanceCalculator.calculate(
          agents: agents,
          orders: orders,
          transactions: transactions,
        );

    expect(result[AgentNetwork.orange]!.available, 50000);
    expect(result[AgentNetwork.orange]!.committed, 5000);
    expect(result[AgentNetwork.orange]!.totalOutgoing, 0);
    expect(result[AgentNetwork.mtn]!.available, 25000);
    expect(result[AgentNetwork.mtn]!.committed, 0);
    expect(result[AgentNetwork.mtn]!.totalOutgoing, 3000);
  });

  test('une vente à crédit affectée est comptée comme montant réseau engagé', () {
    final DateTime now = DateTime(2026, 8, 30, 20);
    final AgentDirectoryEntry agent = AgentDirectoryEntry(
      userId: 'agent-credit',
      name: 'Agent Crédit',
      email: 'credit@example.test',
      phoneNumber: '+2250100000000',
      isActive: true,
      profile: const AgentProfile(
        userId: 'agent-credit',
        agentCode: 'AG-CREDIT',
        availability: AgentAvailability.available,
        zoneIds: <String>[],
        authorizedNetworks: <AgentNetwork>[AgentNetwork.orange],
        activeNetworks: <AgentNetwork>[AgentNetwork.orange],
        orangeCapacity: 20000,
        mtnCapacity: 0,
        moovCapacity: 0,
        dailyTransactionLimit: 500000,
        maxTransactionsPerDay: 150,
      ),
    );
    final QueueOrder creditOrder = QueueOrder(
      id: 'credit-order',
      reference: 'IZY-CREDIT',
      clientName: 'Client Crédit',
      clientWhatsappPhone: '+2250700000000',
      network: MobileNetwork.orange,
      beneficiaryPhone: '+2250700000001',
      operationType: OrderOperationType.unitTransfer,
      offerLabel: 'Transfert',
      amount: 4000,
      createdAt: now,
      status: QueueOrderStatus.inProgress,
      paymentStatus: OrderPaymentStatus.credit,
      assignedAgentId: 'agent-credit',
      assignedAgentName: 'Agent Crédit',
      assignmentStatus: OrderAssignmentStatus.accepted,
    );

    final Map<AgentNetwork, NetworkFundSnapshot> result =
        NetworkFinanceCalculator.calculate(
          agents: <AgentDirectoryEntry>[agent],
          orders: <QueueOrder>[creditOrder],
          transactions: const <NetworkTransaction>[],
        );

    expect(result[AgentNetwork.orange]!.committed, 4000);
  });

  test('ignore les capacités des agents désactivés', () {
    final AgentDirectoryEntry inactive = AgentDirectoryEntry(
      userId: 'agent-off',
      name: 'Agent Off',
      email: '',
      phoneNumber: '',
      isActive: false,
      profile: const AgentProfile(
        userId: 'agent-off',
        agentCode: 'AG-OFF',
        availability: AgentAvailability.available,
        zoneIds: <String>[],
        authorizedNetworks: <AgentNetwork>[AgentNetwork.moov],
        activeNetworks: <AgentNetwork>[AgentNetwork.moov],
        orangeCapacity: 0,
        mtnCapacity: 0,
        moovCapacity: 99000,
        dailyTransactionLimit: 500000,
        maxTransactionsPerDay: 150,
      ),
    );

    final Map<AgentNetwork, NetworkFundSnapshot> result =
        NetworkFinanceCalculator.calculate(
          agents: <AgentDirectoryEntry>[inactive],
          orders: const <QueueOrder>[],
          transactions: const <NetworkTransaction>[],
        );

    expect(result[AgentNetwork.moov]!.available, 0);
  });
}
