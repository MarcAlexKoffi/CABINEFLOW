import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QueueOrder order({int amount = 2000}) {
    return QueueOrder(
      id: 'order-1',
      reference: 'CF-20260827-TEST01',
      clientName: 'Client test',
      clientWhatsappPhone: '+2250707070707',
      network: MobileNetwork.mtn,
      beneficiaryPhone: '+2250505050505',
      operationType: OrderOperationType.unitTransfer,
      offerLabel: 'Transfert d’unités',
      amount: amount,
      createdAt: DateTime.utc(2026, 8, 27),
      status: QueueOrderStatus.paidReady,
      paymentStatus: OrderPaymentStatus.confirmed,
    );
  }

  AutomaticAssignmentAgent agent({
    int dailyTransactionLimit = 0,
    int maxTransactionsPerDay = 0,
    int todayAssignmentCount = 0,
    int todayAssignedAmount = 0,
  }) {
    return AutomaticAssignmentAgent(
      agentId: 'agent-1',
      name: 'Agent test',
      isActive: true,
      isAvailable: true,
      authorizedNetworks: const <MobileNetwork>{MobileNetwork.mtn},
      activeNetworks: const <MobileNetwork>{MobileNetwork.mtn},
      orangeCapacity: 0,
      mtnCapacity: 50000,
      moovCapacity: 0,
      dailyTransactionLimit: dailyTransactionLimit,
      maxTransactionsPerDay: maxTransactionsPerDay,
      activeAssignmentCount: 0,
      orangeReservedAmount: 0,
      mtnReservedAmount: 0,
      moovReservedAmount: 0,
      todayAssignmentCount: todayAssignmentCount,
      todayAssignedAmount: todayAssignedAmount,
    );
  }

  test('0 daily limits mean no configured limit for legacy profiles', () {
    final AutomaticAssignmentAgent candidate = agent();

    expect(candidate.ineligibilityReason(order: order()), isNull);
    expect(candidate.canReceive(order: order()), isTrue);
  });

  test('configured daily count limit is still enforced', () {
    final AutomaticAssignmentAgent candidate = agent(
      maxTransactionsPerDay: 5,
      todayAssignmentCount: 5,
    );

    expect(
      candidate.ineligibilityReason(order: order()),
      'daily-count-limit-reached',
    );
  });

  test('configured daily amount limit is still enforced', () {
    final AutomaticAssignmentAgent candidate = agent(
      dailyTransactionLimit: 10000,
      todayAssignedAmount: 9000,
    );

    expect(
      candidate.ineligibilityReason(order: order(amount: 2000)),
      'daily-amount-limit-reached',
    );
  });
}
