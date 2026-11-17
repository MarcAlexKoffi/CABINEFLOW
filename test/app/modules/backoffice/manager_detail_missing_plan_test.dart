import 'dart:convert';
import 'package:cabine_flow/app/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/modules/team/views/team_member_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Fixture {
  _Fixture({
    String? errorCode = 'P0001',
    String message = 'MANAGER_COMPENSATION_PLAN_NOT_FOUND',
  }) {
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      accessToken: () async => 'synthetic-token',
      httpClient: MockClient((request) async {
        final rpc = request.url.pathSegments.last;
        calls.add(rpc);
        if (rpc == 'izytel_manager_compensation_preview' && errorCode != null) {
          return http.Response(
            jsonEncode({
              'code': errorCode,
              'message': message,
              'details': null,
              'hint': null,
            }),
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final value = switch (rpc) {
          'izytel_team_member_detail' => {
            'actorType': 'manager',
            'actorId': 'fixture-manager',
            'profile': {
              'firebase_uid': 'fixture-manager',
              'first_name': 'Manager',
              'last_name': 'Test',
            },
            'operations': {
              'managerProfile': {'is_active': true},
              'zoneIds': [],
            },
            'finance': {
              'managerCompensationAccount': {'earned_total': 1000},
            },
          },
          'izytel_team_scope_snapshot' => {
            'role': 'admin',
            'firebaseUid': 'admin',
            'zones': [],
          },
          'izytel_manager_compensation_history' => history,
          'izytel_manager_compensation_preview' => preview,
          _ => throw StateError('Unexpected RPC: $rpc'),
        };
        return http.Response(
          jsonEncode(value),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseTeamSupervisionRepository(client: client);
  }
  final calls = <String>[];
  late final SupabaseClient client;
  late final SupabaseTeamSupervisionRepository repository;
  final history = {
    'account': {'earnedTotal': 1000, 'paidTotal': 200, 'balanceDue': 800},
    'periods': [],
    'payouts': [],
  };
  final preview = {
    'plan': {'status': 'active', 'planCode': 'test-plan'},
    'projection': {'theoreticalTotalAmount': 2500},
  };
}

void main() {
  test(
    'missing plan preserves the Manager profile and existing financial history without writes',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.client.dispose);
      final detail = await fixture.repository.fetchMemberDetail(
        actorType: 'manager',
        actorId: 'fixture-manager',
      );
      expect(detail.displayName, 'Manager Test');
      expect(detail.finance['managerCompensationAccount'], {
        'earned_total': 1000,
      });
      expect(detail.finance['compensationPreview'], {
        'status': 'not_configured',
      });
      expect(detail.finance['compensationHistory'], fixture.history);
      expect(
        fixture.calls,
        unorderedEquals([
          'izytel_team_member_detail',
          'izytel_manager_compensation_preview',
          'izytel_manager_compensation_history',
        ]),
      );
    },
  );

  test('an existing plan keeps its original preview', () async {
    final fixture = _Fixture(errorCode: null);
    addTearDown(fixture.client.dispose);
    final detail = await fixture.repository.fetchMemberDetail(
      actorType: 'manager',
      actorId: 'fixture-manager',
    );
    expect(detail.finance['compensationPreview'], fixture.preview);
  });

  for (final error in [
    (code: '42501', message: 'MANAGER_COMPENSATION_PLAN_NOT_FOUND'),
    (code: 'P0001', message: 'UNRELATED_ERROR'),
  ]) {
    test(
      'other server errors remain visible: ${error.code} ${error.message}',
      () async {
        final fixture = _Fixture(errorCode: error.code, message: error.message);
        addTearDown(fixture.client.dispose);
        await expectLater(
          fixture.repository.fetchMemberDetail(
            actorType: 'manager',
            actorId: 'fixture-manager',
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', error.code),
          ),
        );
      },
    );
  }

  testWidgets(
    'Manager detail and history remain accessible without a plan or a close-period action',
    (tester) async {
      // The SDK owns a JSON isolate; create/dispose it on the real async clock.
      final fixture = (await tester.runAsync(() async => _Fixture()))!;
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TeamMemberDetailPage(
            viewer: const AppUser(
              id: 'admin',
              name: 'Admin',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            actorType: 'manager',
            actorId: 'fixture-manager',
            repository: fixture.repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manager Test'), findsOneWidget);
      expect(find.text('Plan de rémunération non configuré'), findsOneWidget);
      expect(
        find.text('Impossible de charger les informations détaillées.'),
        findsNothing,
      );
      expect(find.text('Clôturer un mois terminé'), findsNothing);
      expect(find.text('Rémunération théorique'), findsNothing);
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();
      expect(find.text('Historique de rémunération'), findsOneWidget);
      expect(
        find.text('Aucune clôture mensuelle Manager enregistrée.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.client.dispose);
    },
  );
}
