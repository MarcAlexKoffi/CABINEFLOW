import 'dart:async';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/auth/auth_login_result.dart';
import 'package:cabine_flow/app/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/app/modules/auth/views/login_page.dart';
import 'package:cabine_flow/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AuthRepository {
  AuthLoginResult result = const AuthLoginResult.invalidCredentials();
  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async => result;
  @override
  Future<AuthLoginResult> refreshCurrentAccess() async => result;
  @override
  Future<void> logout() async {}
}

const user = AppUser(
  id: 'manager',
  name: 'Manager',
  phoneNumber: '',
  role: UserRole.manager,
);
void main() {
  const preferences = MethodChannel('com.izytel/session_preferences');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          preferences,
          (call) async => call.method == 'getRememberedSession'
              ? {'rememberMe': false, 'email': ''}
              : null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, null),
  );
  Future<void> show(WidgetTester tester, _Auth auth) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authRepository: auth),
        routes: {
          AppRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard')),
          AppRoutes.pendingAccount: (_) =>
              const Scaffold(body: Text('Pending')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'manager@example.invalid',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Se connecter');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  List<MethodCall> saves(WidgetTester tester) => tester.testTextInput.log
      .where(
        (c) =>
            c.method == 'TextInput.finishAutofillContext' &&
            c.arguments == true,
      )
      .toList();
  testWidgets(
    'successful login commits credentials before waiting for preferences',
    (tester) async {
      final auth = _Auth()..result = AuthLoginResult.authenticated(user);
      await show(tester, auth);
      final persisted = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(preferences, (call) async {
            if (call.method == 'clearRememberedSession') await persisted.future;
            return null;
          });
      tester.testTextInput.log.clear();
      final button = find.widgetWithText(FilledButton, 'Se connecter');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(saves(tester), hasLength(1));
      expect(find.text('Dashboard'), findsNothing);
      persisted.complete();
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(saves(tester), hasLength(1));
    },
  );
  testWidgets(
    'failed login keeps the autofill group and does not save invalid credentials',
    (tester) async {
      final auth = _Auth();
      await show(tester, auth);
      final state = tester.state(find.byKey(const ValueKey('login-autofill')));
      tester.testTextInput.log.clear();
      await submit(tester);
      expect(saves(tester), isEmpty);
      expect(
        tester.state(find.byKey(const ValueKey('login-autofill'))),
        same(state),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.pump();
      expect(
        tester.state(find.byKey(const ValueKey('login-autofill'))),
        same(state),
      );
      auth.result = AuthLoginResult.authenticated(user);
      await submit(tester);
      expect(saves(tester), hasLength(1));
    },
  );
  testWidgets(
    'valid new access awaiting activation also requests credential saving',
    (tester) async {
      final auth = _Auth()
        ..result = const AuthLoginResult.pendingActivation(
          profileName: 'New user',
          email: 'manager@example.invalid',
        );
      await show(tester, auth);
      tester.testTextInput.log.clear();
      await submit(tester);
      expect(find.text('Pending'), findsOneWidget);
      expect(saves(tester), hasLength(1));
    },
  );
}
