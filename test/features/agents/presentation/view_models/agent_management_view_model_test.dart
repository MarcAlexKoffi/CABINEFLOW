import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_management_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtre les agents par réseau et disponibilité', () async {
    final FakeAgentRepository repository = FakeAgentRepository();
    final AgentManagementViewModel viewModel = AgentManagementViewModel(
      repository: repository,
    );

    await viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.agents, isNotEmpty);
    expect(viewModel.availableCount, 1);

    viewModel.setNetwork(AgentNetwork.orange);
    viewModel.setAvailability(AgentAvailability.available);

    expect(viewModel.filteredAgents, hasLength(1));
    expect(viewModel.filteredAgents.single.name, 'Koffi Kouassi');

    viewModel.setNetwork(AgentNetwork.moov);
    expect(viewModel.filteredAgents, isEmpty);

    viewModel.dispose();
  });

  test('active un compte en attente comme agent', () async {
    final FakeAgentRepository repository = FakeAgentRepository();
    final AgentManagementViewModel viewModel = AgentManagementViewModel(
      repository: repository,
    );

    await viewModel.start();
    await Future<void>.delayed(Duration.zero);
    final List<StaffAccountSummary> pending = await viewModel
        .loadPendingAccounts();

    expect(pending, isNotEmpty);
    await viewModel.activatePendingAccount(pending.first);
    await Future<void>.delayed(Duration.zero);

    expect(
      viewModel.agents.any((agent) => agent.userId == pending.first.userId),
      isTrue,
    );

    viewModel.dispose();
  });

  // WC9: l'actualisation manuelle doit etre ponctuelle et finir sans recreer
  // durablement l'etat de chargement du repertoire Manager.
  test('actualise le repertoire Agents sans spinner persistant', () async {
    final FakeAgentRepository repository = FakeAgentRepository();
    final AgentManagementViewModel viewModel = AgentManagementViewModel(
      repository: repository,
    );

    await viewModel.start();
    await viewModel.refresh();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.agents, isNotEmpty);
    expect(viewModel.zones, isNotEmpty);

    viewModel.dispose();
  });
}
