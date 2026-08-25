import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retourne la capacité par réseau', () {
    const AgentProfile profile = AgentProfile(
      userId: 'A1',
      agentCode: 'AG-A1',
      availability: AgentAvailability.available,
      zoneIds: <String>[],
      authorizedNetworks: <AgentNetwork>[AgentNetwork.orange, AgentNetwork.mtn],
      activeNetworks: <AgentNetwork>[AgentNetwork.orange],
      orangeCapacity: 10000,
      mtnCapacity: 20000,
      moovCapacity: 30000,
      dailyTransactionLimit: 500000,
      maxTransactionsPerDay: 150,
    );

    expect(profile.capacityFor(AgentNetwork.orange), 10000);
    expect(profile.capacityFor(AgentNetwork.mtn), 20000);
    expect(profile.capacityFor(AgentNetwork.moov), 30000);
  });
}
