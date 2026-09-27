import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_assignments_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_orders_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_payments_page.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _admin = AppUser(
  id: 'USR-001',
  name: 'Marc Alex',
  phoneNumber: '0700000000',
  role: UserRole.administrator,
);

Widget _testHost(Widget child) {
  return MaterialApp(
    theme: BackofficeTheme.light,
    home: Scaffold(
      backgroundColor: BackofficePalette.canvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 28, 30, 42),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> _mountOperationPage(
  WidgetTester tester,
  Widget page,
) async {
  await tester.pumpWidget(_testHost(page));
  // Les repositories fake emettent leur premier snapshot de facon asynchrone.
  // Des pumps bornes suffisent et evitent pumpAndSettle(), incompatible avec
  // les flux temps reel volontairement ouverts par les pages du back-office.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

Future<void> _disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('BO-2 affiche le module Commandes', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

    await _mountOperationPage(
      tester,
      BackofficeOrdersPage(
        user: _admin,
        repository: repository,
        onOpenAssignments: (_) {},
        onOpenPayments: () {},
      ),
    );

    expect(find.text('Centre des commandes'), findsOneWidget);
    await _disposePage(tester);
  });

  testWidgets('BO-2 affiche le module Paiements', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

    await _mountOperationPage(
      tester,
      BackofficePaymentsPage(
        user: _admin,
        ordersRepository: repository,
        onOpenOrders: () {},
      ),
    );

    expect(find.text('Centre de vérification des paiements'), findsOneWidget);
    await _disposePage(tester);
  });

  testWidgets('BO-2 affiche le module Affectations', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

    await _mountOperationPage(
      tester,
      BackofficeAssignmentsPage(
        user: _admin,
        ordersRepository: repository,
        agentRepository: FakeAgentRepository(),
      ),
    );

    expect(find.text('Pilotage des affectations'), findsOneWidget);
    await _disposePage(tester);
  });

  testWidgets('BO-2 affiche le module Commandes échouées', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeOrdersRepository repository = FakeOrdersRepository(isTest: true);

    await _mountOperationPage(
      tester,
      BackofficeFailedOrdersPage(
        user: _admin,
        ordersRepository: repository,
        historyRepository: repository,
        refundRepository: FakeRefundRepository(),
        onOpenAssignments: (_) {},
        onOpenRefunds: (_) {},
      ),
    );

    expect(find.text('Commandes échouées'), findsWidgets);
    await _disposePage(tester);
  });
}
