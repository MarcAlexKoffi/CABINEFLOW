import 'dart:async';
import 'dart:convert';

import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/data/repositories/fake_finance_operations_repository.dart';
import 'package:cabine_flow/app/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/finance/finance_operations_models.dart';
import 'package:cabine_flow/app/domain/entities/team/team_supervision_models.dart';
import 'package:cabine_flow/app/modules/finance/views/supplier_finance_page.dart';
import 'package:cabine_flow/app/modules/team/views/team_member_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const manager = AppUser(id: 'manager', name: 'Manager', phoneNumber: '', role: UserRole.manager);
Map<String, dynamic> detail(String firstName) => {
  'actorType': 'agent', 'actorId': 'agent',
  'profile': {'firebase_uid': 'agent', 'first_name': firstName, 'last_name': 'Agent'},
  'operations': {}, 'finance': {},
};

class _Teams implements SupabaseTeamSupervisionRepository {
  final events = StreamController<TeamMemberDetail>.broadcast();
  @override
  Stream<TeamMemberDetail> watchMemberDetail({required String actorType, required String actorId}) => events.stream;
  @override
  Future<TeamScopeSnapshot> fetchScope() async => TeamScopeSnapshot.fromMap({'role': 'manager', 'firebaseUid': 'manager'});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Finance extends FakeFinanceOperationsRepository {
  final events = StreamController<List<FinanceSupplier>>.broadcast();
  int watches = 0;
  @override
  Stream<List<FinanceSupplier>> watchSuppliers() { watches++; return events.stream; }
}

void main() {
  for (final code in ['P0001', '42501']) {
    test('agent optional-history error $code preserves only the known missing-plan case', () async {
      final client = SupabaseClient('https://fixture.supabase.co', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        accessToken: () async => 'fixture-token',
        httpClient: MockClient((request) async {
          final history = request.url.path.endsWith('izytel_team_member_activity_history');
          return http.Response(jsonEncode(history ? {'code': code, 'message': 'ECONOMIC_PLAN_NOT_FOUND', 'details': null, 'hint': null} : detail('Profil')), history ? 400 : 200,
            request: request, headers: {'content-type': 'application/json'});
        }));
      addTearDown(client.dispose);
      final result = SupabaseTeamSupervisionRepository(client: client).fetchMemberDetail(actorType: 'agent', actorId: 'agent');
      if (code == 'P0001') {
        final value = await result;
        expect(value.displayName, 'Profil Agent');
        expect(value.finance['activityHistory'], {'status': 'not_configured'});
      } else {
        await expectLater(result, throwsA(isA<PostgrestException>().having((e)=>e.code,'code','42501')));
      }
    });
  }

  testWidgets('an open agent detail receives the profile changed on another device', (tester) async {
    final teams = _Teams();
    await tester.pumpWidget(MaterialApp(home: TeamMemberDetailPage(viewer: manager, actorType: 'agent', actorId: 'agent', repository: teams)));
    teams.events.add(TeamMemberDetail.fromMap(detail('Ancien')));
    await tester.pumpAndSettle();
    expect(find.text('Ancien Agent'), findsOneWidget);
    teams.events.add(TeamMemberDetail.fromMap(detail('Nouveau')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau Agent'), findsOneWidget);
    expect(find.text('Ancien Agent'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(teams.events.close());
    await tester.pump();
  });

  testWidgets('suppliers survive a transient read error and recover without restarting the session', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final finance = _Finance();
    final now = DateTime(2026, 11, 17);
    final suppliers = [FinanceSupplier(id: 'supplier', name: 'Fournisseur test', phoneNumber: '', isActive: true, createdAt: now, createdBy: 'manager', createdByName: 'Manager', updatedAt: now)];
    await tester.pumpWidget(MaterialApp(home: SupplierFinancePage(user: manager, repository: finance, agentRepository: FakeAgentRepository())));
    finance.events.add(suppliers);
    await tester.pumpAndSettle();
    expect(find.text('Fournisseur test'), findsOneWidget);
    finance.events.addError(TimeoutException('fixture timeout'));
    await tester.pumpAndSettle();
    expect(find.text('Fournisseur test'), findsOneWidget);
    expect(find.text('Aucun fournisseur'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
    finance.events.add(suppliers);
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsNothing);
    finance.events.addError(const PostgrestException(message: 'DENIED', code: '42501'));
    await tester.pumpAndSettle();
    expect(find.text('Fournisseur test'), findsNothing);
    expect(find.text('Aucun fournisseur'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    finance.events.add(suppliers);
    await tester.pumpAndSettle();
    expect(finance.watches, 2);
    expect(find.text('Fournisseur test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(finance.events.close());
    await tester.pump();
  });
}
