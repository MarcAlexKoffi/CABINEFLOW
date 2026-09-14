import 'package:cabine_flow/backoffice/backoffice_app.dart';
import 'package:cabine_flow/backoffice/data/repositories/fake_backoffice_user_repository.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpNavigationFrame(WidgetTester tester) async {
  // BO-2 maintient volontairement plusieurs flux temps reel ouverts
  // (notifications + listes Operations). pumpAndSettle() n'est donc pas un
  // bon outil ici : il peut attendre indefiniment qu'aucune frame ne soit
  // planifiee. Pour ce test de navigation, deux frames bornees suffisent.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> _openNavigationItem(
  WidgetTester tester,
  String label,
) async {
  final Finder target = find.text(label);
  expect(target, findsWidgets);

  await tester.tap(target.first);
  await _pumpNavigationFrame(tester);
}

void main() {
  testWidgets('BO-2 ouvre les quatre modules Operations', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // BO-1 couvre deja le parcours de connexion. Ce test BO-2 ouvre une
    // session Admin avant le rendu afin de tester uniquement le shell et la
    // navigation des modules Operations.
    final FakeAuthRepository authRepository = FakeAuthRepository();
    final authResult = await authRepository.login(
      identifier: 'marc@cabineflow.app',
      password: '1234',
    );
    expect(authResult.isAuthenticated, isTrue);

    await tester.pumpWidget(
      BackofficeApp(
        authRepository: authRepository,
        userRepository: const FakeBackofficeUserRepository(),
        ordersRepository: FakeOrdersRepository(isTest: true),
        agentRepository: FakeAgentRepository(),
      ),
    );
    await _pumpNavigationFrame(tester);

    expect(find.text('Tableau de bord'), findsWidgets);

    await _openNavigationItem(tester, 'Commandes');
    expect(find.text('Centre des commandes'), findsOneWidget);

    await _openNavigationItem(tester, 'Paiements');
    expect(find.text('Centre de vérification des paiements'), findsOneWidget);

    await _openNavigationItem(tester, 'Affectations');
    expect(find.text('Pilotage des affectations'), findsOneWidget);

    await _openNavigationItem(tester, 'Commandes échouées');
    expect(find.text('Commandes échouées'), findsWidgets);

    // Force le dispose du shell afin d'annuler explicitement les abonnements
    // temps reel avant la fin du test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
