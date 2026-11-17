import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/domain/entities/agents/agent_models.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/modules/backoffice/views/team/backoffice_agents_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Agents extends FakeAgentRepository {
  _Agents(List<String> zoneIds, {this.active = true})
    : agent = AgentDirectoryEntry(
        userId: 'agent-test',
        name: 'Agent de Test',
        email: 'agent@example.test',
        phoneNumber: '',
        isActive: true,
        profile: AgentProfile(
          userId: 'agent-test',
          agentCode: 'AG-TEST',
          availability: AgentAvailability.available,
          zoneIds: zoneIds,
          authorizedNetworks: const [AgentNetwork.orange],
          activeNetworks: const [],
          orangeCapacity: 1250,
          mtnCapacity: 0,
          moovCapacity: 0,
          dailyTransactionLimit: 5000000,
          maxTransactionsPerDay: 250,
        ),
      );
  final AgentDirectoryEntry agent;
  final bool active;
  AgentAdminUpdate? saved;
  @override
  Stream<List<AgentDirectoryEntry>> watchAgents() => Stream.value([agent]);
  @override
  Stream<List<AgentZone>> watchZones() => Stream.value([
    AgentZone(
      id: 'current-zone',
      name: 'Abidjan',
      city: 'Abidjan',
      region: 'Abidjan',
      isActive: active,
    ),
    const AgentZone(
      id: 'inactive-zone',
      name: 'Zone désactivée',
      city: '',
      region: '',
      isActive: false,
    ),
  ]);
  @override
  Future<void> saveAgentAdmin({
    required AgentDirectoryEntry agent,
    required AgentAdminUpdate update,
  }) async {
    saved = update;
  }
}

Future<void> _open(WidgetTester tester, _Agents repository) async {
  tester.view.physicalSize = const Size(1400, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BackofficeAgentsPage(
          user: const AppUser(
            id: 'admin',
            name: 'Admin',
              phoneNumber: '',
            role: UserRole.administrator,
          ),
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Agent de Test'));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'deleted zone IDs do not accompany the newly selected active zone',
    (tester) async {
      final repository = _Agents(['deleted-zone-a', 'deleted-zone-b']);
      await _open(tester, repository);
      expect(find.textContaining('anciennes zones'), findsOneWidget);
      final zone = find.widgetWithText(FilterChip, 'Abidjan, Abidjan');
      expect(tester.widget<FilterChip>(zone).selected, false);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNull);
      expect(
        find.text('Sélectionnez au moins une zone active pour cet Agent.'),
        findsOneWidget,
      );
      await tester.tap(zone);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repository.saved!.zoneIds, ['current-zone']);
      expect(repository.saved!.orangeCapacity, 1250);
      expect(repository.saved!.dailyTransactionLimit, 5000000);
      expect(repository.saved!.maxTransactionsPerDay, 250);
      await _finish(tester);
    },
  );

  testWidgets(
    'valid selection is preserved and inactive or deleted IDs are excluded',
    (tester) async {
      final repository = _Agents([
        'current-zone',
        'inactive-zone',
        'deleted-zone',
      ]);
      await _open(tester, repository);
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(FilterChip, 'Abidjan, Abidjan'),
            )
            .selected,
        true,
      );
      expect(find.widgetWithText(FilterChip, 'Zone désactivée'), findsNothing);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repository.saved!.zoneIds, ['current-zone']);
      await _finish(tester);
    },
  );

  testWidgets('no active zone blocks saving without assigning a replacement', (
    tester,
  ) async {
    final repository = _Agents(['deleted-zone'], active: false);
    await _open(tester, repository);
    expect(find.text('Aucune zone active disponible.'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
      await _finish(tester);
  });
}
