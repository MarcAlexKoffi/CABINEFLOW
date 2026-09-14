import 'package:cabine_flow/backoffice/backoffice_app.dart';
import 'package:cabine_flow/backoffice/data/repositories/fake_backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _useDesktopViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

void main() {
  testWidgets('BO-1 ouvre le shell Administrateur et la page Utilisateurs', (
    WidgetTester tester,
  ) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      BackofficeApp(
        authRepository: FakeAuthRepository(),
        userRepository: const FakeBackofficeUserRepository(
          users: <BackofficeUserAccount>[
            BackofficeUserAccount(
              id: 'admin-1',
              name: 'Marc Alex',
              email: 'marc@cabineflow.app',
              phoneNumber: '0700000000',
              role: BackofficeAccountRole.administrator,
              isActive: true,
            ),
            BackofficeUserAccount(
              id: 'agent-1',
              name: 'Agent Test',
              email: 'agent@test.local',
              phoneNumber: '',
              role: BackofficeAccountRole.agent,
              isActive: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'marc@cabineflow.app');
    await tester.enterText(fields.at(1), '1234');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Gestion des utilisateurs'), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);

    await tester.ensureVisible(find.text('Ouvrir'));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Utilisateurs'), findsWidgets);
    expect(find.textContaining('Registre des comptes IzyTel'), findsOneWidget);
    expect(find.text('Marc Alex'), findsWidgets);
    expect(find.text('Agent Test'), findsWidgets);
  });

  testWidgets('BO-1 refuse un compte Agent', (WidgetTester tester) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      BackofficeApp(
        authRepository: FakeAuthRepository(),
        userRepository: const FakeBackofficeUserRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'agent@cabineflow.app');
    await tester.enterText(fields.at(1), '1234');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ce compte n’a pas accès au back-office'),
      findsOneWidget,
    );
  });
}
