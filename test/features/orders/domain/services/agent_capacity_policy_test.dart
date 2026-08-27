import 'package:cabine_flow/features/orders/domain/services/agent_capacity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentCapacityPolicy.remainingAfterSuccess', () {
    test('déduit exactement le montant de l’opération', () {
      expect(
        AgentCapacityPolicy.remainingAfterSuccess(
          currentCapacity: 50000,
          operationAmount: 3000,
        ),
        47000,
      );
    });

    test('ne produit jamais une capacité négative', () {
      expect(
        AgentCapacityPolicy.remainingAfterSuccess(
          currentCapacity: 500,
          operationAmount: 1000,
        ),
        0,
      );
    });

    test('un montant nul ne modifie pas la capacité', () {
      expect(
        AgentCapacityPolicy.remainingAfterSuccess(
          currentCapacity: 12000,
          operationAmount: 0,
        ),
        12000,
      );
    });
  });
}
