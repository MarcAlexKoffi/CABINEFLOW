import 'dart:convert';
import 'package:cabine_flow/backoffice/data/repositories/backoffice_user_administration_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/firestore_backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_users_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

BackofficeUserAccount account(BackofficeAccountRole role, bool active) =>
    BackofficeUserAccount(
      id: 'uid',
      name: 'Name',
      email: 'real@example.test',
      phoneNumber: '01020304',
      role: role,
      isActive: active,
    );

class _RetryUserRepository implements BackofficeUserRepository {
  int calls = 0;

  @override
  Stream<List<BackofficeUserAccount>> watchUsers() {
    calls++;
    if (calls == 1) {
      return Stream<List<BackofficeUserAccount>>.error(
        const BackofficeUserRegistryException(
          source: BackofficeUserRegistrySource.firestore,
        ),
      );
    }
    return Stream<List<BackofficeUserAccount>>.value([
      account(BackofficeAccountRole.manager, true),
    ]);
  }
}

class _PartialSupabaseFailureRepository implements BackofficeUserRepository {
  @override
  Stream<List<BackofficeUserAccount>> watchUsers() =>
      Stream<List<BackofficeUserAccount>>.multi((controller) {
        controller.add([account(BackofficeAccountRole.administrator, true)]);
        controller.addError(
          const BackofficeUserRegistryException(
            source: BackofficeUserRegistrySource.supabase,
            partial: true,
          ),
        );
        controller.close();
      });
}

class _FakeUserAdministration implements BackofficeUserAdministration {
  @override
  Future<List<UserAdminZone>> loadZones() async => const [];

  @override
  Future<UserAdminDetails> loadDetails(BackofficeUserAccount user) async =>
      const UserAdminDetails();

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async => {};
}

void main() {
  testWidgets('partial Supabase error keeps the last Firestore users visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeUsersPage(
            currentUser: const AppUser(
              id: 'admin',
              name: 'Admin',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            repository: _PartialSupabaseFailureRepository(),
            administration: _FakeUserAdministration(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(
      find.textContaining('Le registre est partiellement indisponible'),
      findsOneWidget,
    );
    expect(find.text('Impossible de charger les utilisateurs.'), findsNothing);
  });

  testWidgets('retry recreates the users stream after a terminal error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _RetryUserRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeUsersPage(
            currentUser: const AppUser(
              id: 'admin',
              name: 'Admin',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            repository: repository,
            administration: _FakeUserAdministration(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de charger les utilisateurs.'),
      findsOneWidget,
    );
    expect(find.textContaining('registre Firestore'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Impossible de charger les utilisateurs.'), findsNothing);
  });

  test(
    'identity details come from authorized server and bind target UID',
    () async {
      final repository = BackofficeUserAdministrationRepository(
        tokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['action'], 'details');
          expect(body['uid'], 'uid');
          return http.Response(
            '{"ok":true,"account":{"uid":"uid","email":"auth@example.test"}}',
            200,
          );
        }),
      );
      final details = await repository.loadDetails(
        account(BackofficeAccountRole.administrator, true),
      );
      expect(details.email, 'auth@example.test');
    },
  );
  test(
    'administrative mutation uses current Firebase bearer and preserves request ID',
    () async {
      final commands = <Map<String, dynamic>>[];
      final repository = BackofficeUserAdministrationRepository(
        tokenProvider: () async => 'fresh-firebase-token',
        httpClient: MockClient((request) async {
          expect(
            request.headers['Authorization'],
            'Bearer fresh-firebase-token',
          );
          expect(request.url.path, '/functions/v1/izytel-user-admin');
          final body = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          commands.add(body);
          return http.Response(
            '{"ok":true,"uid":"uid","operationId":"operation-1"}',
            200,
          );
        }),
      );
      final command = {
        'action': 'update',
        'uid': 'uid',
        'requestId': 'request-stable-1234',
        'role': 'agent',
      };
      await repository.send(command);
      await repository.send(command);
      expect(commands, [command, command]);
    },
  );
  test('missing Firebase session never calls server', () async {
    var calls = 0;
    final repository = BackofficeUserAdministrationRepository(
      tokenProvider: () async => null,
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      repository.send({'action': 'create'}),
      throwsA(
        isA<UserAdminException>().having(
          (e) => e.code,
          'code',
          'AUTH_REQUIRED',
        ),
      ),
    );
    expect(calls, 0);
  });
  test('partial server operation surfaces repair reference', () async {
    final repository = BackofficeUserAdministrationRepository(
      tokenProvider: () async => 'token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"ok":false,"error":"OPERATION_REQUIRES_REPAIR","operationId":"operation-ref","requiresRepair":true}',
          409,
        ),
      ),
    );
    await expectLater(
      repository.send({'action': 'update'}),
      throwsA(
        isA<UserAdminException>()
            .having((e) => e.requiresRepair, 'repair', true)
            .having((e) => e.operationId, 'reference', 'operation-ref'),
      ),
    );
  });
  test('malformed response never appears as successful mutation', () async {
    final repository = BackofficeUserAdministrationRepository(
      tokenProvider: () async => 'token',
      httpClient: MockClient(
        (_) async => http.Response('gateway failure', 502),
      ),
    );
    await expectLater(
      repository.send({'action': 'create'}),
      throwsA(
        isA<UserAdminException>().having(
          (e) => e.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });
  test(
    'inactive historical partner does not override converted staff role',
    () {
      final merged = FirestoreBackofficeUserRepository.mergeAccounts(
        [account(BackofficeAccountRole.agent, true)],
        [account(BackofficeAccountRole.cabiniste, false)],
      );
      expect(merged.single.role, BackofficeAccountRole.agent);
      expect(merged.single.hasRoleConflict, false);
    },
  );
  test('two active populations are exposed as a role conflict', () {
    final merged = FirestoreBackofficeUserRepository.mergeAccounts(
      [account(BackofficeAccountRole.manager, true)],
      [account(BackofficeAccountRole.cabiniste, true)],
    );
    expect(merged.single.hasRoleConflict, true);
    expect(merged.single.statusLabel, 'Conflit de rôles');
  });
  test('partner remains canonical over pending historical staff', () {
    final merged = FirestoreBackofficeUserRepository.mergeAccounts(
      [account(BackofficeAccountRole.pending, false)],
      [account(BackofficeAccountRole.cabiniste, true)],
    );
    expect(merged.single.role, BackofficeAccountRole.cabiniste);
  });
}
