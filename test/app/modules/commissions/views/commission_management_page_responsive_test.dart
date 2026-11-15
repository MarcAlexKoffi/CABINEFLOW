import 'package:cabine_flow/app/theme/app_theme.dart';
import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/data/repositories/fake_commission_repository.dart';
import 'package:cabine_flow/app/modules/commissions/views/commission_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la gestion des commissions reste rendable sur 320 x 568', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CommissionManagementPage(
          user: const AppUser(
            id: 'ADMIN-001',
            name: 'Marc Alex',
            phoneNumber: '+2250700000000',
            role: UserRole.administrator,
          ),
          repository: FakeCommissionRepository(),
          agentRepository: FakeAgentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commissions'), findsOneWidget);
    expect(find.text('Suivi des commissions des agents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
