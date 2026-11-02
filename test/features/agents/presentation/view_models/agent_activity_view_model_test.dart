import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_activity_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'agent change sa disponibilité et ses réseaux sans changer le stock',
    () async {
      final FakeAgentRepository repository = FakeAgentRepository();
      final AgentActivityViewModel viewModel = AgentActivityViewModel(
        agentId: 'AGENT-001',
        repository: repository,
      );

      await viewModel.start();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.profile?.availability, AgentAvailability.available);
      final initialStock = viewModel.profile!.orangeCapacity;

      expect(
        await viewModel.setAvailability(AgentAvailability.unavailable),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.profile?.availability, AgentAvailability.unavailable);

      expect(await viewModel.toggleNetwork(AgentNetwork.orange, false), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(
        viewModel.profile?.activeNetworks,
        isNot(contains(AgentNetwork.orange)),
      );
      expect(viewModel.profile?.orangeCapacity, initialStock);

      viewModel.dispose();
    },
  );

  test('agent signale un problème', () async {
    final FakeAgentRepository repository = FakeAgentRepository();
    final AgentActivityViewModel viewModel = AgentActivityViewModel(
      agentId: 'AGENT-001',
      repository: repository,
    );

    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    final bool success = await viewModel.reportIssue(
      const AgentIssueDraft(
        type: 'network',
        network: AgentNetwork.orange,
        description: 'Réseau Orange indisponible.',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(success, isTrue);
    expect(viewModel.issues, isNotEmpty);
    expect(viewModel.issues.first.status, 'open');

    viewModel.dispose();
  });
}
