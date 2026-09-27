import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/services/automatic_assignment_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AutomaticAssignmentSelector selector = AutomaticAssignmentSelector();

  QueueOrder order({
    String? lastRefusedAgentId,
    List<String> refusedAgentIds = const <String>[],
  }) => QueueOrder(
    id: 'order-1',
    reference: 'CF-20260826-TEST01',
    clientName: 'Test',
    clientWhatsappPhone: '+2250700000000',
    network: MobileNetwork.mtn,
    beneficiaryPhone: '+2250500000000',
    operationType: OrderOperationType.unitTransfer,
    offerLabel: 'Transfert',
    amount: 5000,
    createdAt: DateTime(2026, 8, 26, 10),
    paidAt: DateTime(2026, 8, 26, 10, 1),
    status: QueueOrderStatus.paidReady,
    paymentStatus: OrderPaymentStatus.confirmed,
    lastAssignmentRefusedAgentId: lastRefusedAgentId,
    autoAssignmentRefusedAgentIds: refusedAgentIds,
  );

  AutomaticAssignmentAgent agent({
    required String id,
    int active = 0,
    int todayCount = 0,
    int todayAmount = 0,
    int capacity = 20000,
    int reserved = 0,
    bool activeAccount = true,
    bool available = true,
    bool networkActive = true,
    int dailyLimit = 100000,
    int maxPerDay = 20,
    DateTime? lastAssignedAt,
  }) {
    return AutomaticAssignmentAgent(
      agentId: id,
      name: id,
      isActive: activeAccount,
      isAvailable: available,
      authorizedNetworks: const <MobileNetwork>{MobileNetwork.mtn},
      activeNetworks: networkActive
          ? const <MobileNetwork>{MobileNetwork.mtn}
          : const <MobileNetwork>{},
      orangeCapacity: 0,
      mtnCapacity: capacity,
      moovCapacity: 0,
      dailyTransactionLimit: dailyLimit,
      maxTransactionsPerDay: maxPerDay,
      activeAssignmentCount: active,
      orangeReservedAmount: 0,
      mtnReservedAmount: reserved,
      moovReservedAmount: 0,
      todayAssignmentCount: todayCount,
      todayAssignedAmount: todayAmount,
      lastAssignedAt: lastAssignedAt,
    );
  }

  test('à ancienneté égale, choisit l’agent éligible le moins chargé', () {
    final selected = selector.select(
      order: order(),
      agents: <AutomaticAssignmentAgent>[
        agent(id: 'A', active: 3),
        agent(id: 'B', active: 1),
        agent(id: 'C', active: 2),
      ],
    );

    expect(selected?.agentId, 'B');
  });

  test('exclut un agent indisponible, sans capacité ou hors limites', () {
    final selected = selector.select(
      order: order(),
      agents: <AutomaticAssignmentAgent>[
        agent(id: 'A', available: false),
        agent(id: 'B', capacity: 4000),
        agent(id: 'C', todayCount: 20),
        agent(id: 'D', todayAmount: 98000),
        agent(id: 'E'),
      ],
    );

    expect(selected?.agentId, 'E');
  });

  test('ne réattribue pas immédiatement au dernier agent ayant refusé', () {
    final selected = selector.select(
      order: order(lastRefusedAgentId: 'A'),
      agents: <AutomaticAssignmentAgent>[
        agent(id: 'A', active: 0),
        agent(id: 'B', active: 1),
      ],
    );

    expect(selected?.agentId, 'B');
  });

  test('départage les égalités par ancienneté de dernière affectation', () {
    final selected = selector.select(
      order: order(),
      agents: <AutomaticAssignmentAgent>[
        agent(
          id: 'A',
          active: 1,
          todayCount: 2,
          lastAssignedAt: DateTime(2026, 8, 26, 9, 30),
        ),
        agent(
          id: 'B',
          active: 1,
          todayCount: 2,
          lastAssignedAt: DateTime(2026, 8, 26, 8, 30),
        ),
      ],
    );

    expect(selected?.agentId, 'B');
  });

  test(
    'alterne vers l’agent le moins récemment affecté quand les deux sont aptes',
    () {
      final selected = selector.select(
        order: order(),
        agents: <AutomaticAssignmentAgent>[
          agent(
            id: 'A',
            active: 0,
            todayCount: 8,
            lastAssignedAt: DateTime(2026, 8, 26, 10, 5),
          ),
          agent(
            id: 'B',
            active: 4,
            todayCount: 5,
            lastAssignedAt: DateTime(2026, 8, 26, 10),
          ),
        ],
      );

      expect(selected?.agentId, 'B');
    },
  );

  test(
    'peut réutiliser le même agent si les autres agents ne sont pas aptes',
    () {
      final selected = selector.select(
        order: order(),
        agents: <AutomaticAssignmentAgent>[
          agent(
            id: 'A',
            active: 1,
            lastAssignedAt: DateTime(2026, 8, 26, 10, 5),
          ),
          agent(
            id: 'B',
            active: 0,
            available: false,
            lastAssignedAt: DateTime(2026, 8, 26, 9),
          ),
        ],
      );

      expect(selected?.agentId, 'A');
    },
  );

  test('réserve la capacité des commandes actives déjà affectées', () {
    final selected = selector.select(
      order: order(),
      agents: <AutomaticAssignmentAgent>[
        agent(id: 'A', capacity: 8000, reserved: 4000),
        agent(id: 'B', capacity: 6000, reserved: 0),
      ],
    );

    expect(selected?.agentId, 'B');
  });
  test('exclut tous les agents qui ont déjà refusé cette commande', () {
    final QueueOrder refusedByBoth = order(
      lastRefusedAgentId: 'B',
      refusedAgentIds: const <String>['A', 'B'],
    );

    final ranked = selector.rankEligible(
      order: refusedByBoth,
      agents: <AutomaticAssignmentAgent>[
        agent(id: 'A'),
        agent(id: 'B'),
      ],
    );

    expect(ranked, isEmpty);
    expect(
      selector.shouldRequireManualAssignment(
        order: refusedByBoth,
        agents: <AutomaticAssignmentAgent>[
          agent(id: 'A'),
          agent(id: 'B'),
        ],
      ),
      isTrue,
    );
  });

  test(
    'essaie un troisième agent apte avant de demander une affectation manuelle',
    () {
      final QueueOrder refusedByTwo = order(
        lastRefusedAgentId: 'B',
        refusedAgentIds: const <String>['A', 'B'],
      );
      final agents = <AutomaticAssignmentAgent>[
        agent(id: 'A'),
        agent(id: 'B'),
        agent(id: 'C'),
      ];

      expect(
        selector.select(order: refusedByTwo, agents: agents)?.agentId,
        'C',
      );
      expect(
        selector.shouldRequireManualAssignment(
          order: refusedByTwo,
          agents: agents,
        ),
        isFalse,
      );
    },
  );

  test('reste en attente si aucun agent ne serait actuellement apte', () {
    final QueueOrder refusedByOne = order(
      lastRefusedAgentId: 'A',
      refusedAgentIds: const <String>['A'],
    );
    final agents = <AutomaticAssignmentAgent>[
      agent(id: 'A', available: false),
      agent(id: 'B', capacity: 1000),
    ];

    expect(selector.rankEligible(order: refusedByOne, agents: agents), isEmpty);
    expect(
      selector.shouldRequireManualAssignment(
        order: refusedByOne,
        agents: agents,
      ),
      isFalse,
    );
  });
}
