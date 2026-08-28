import 'package:cabine_flow/core/theme/customer_app_theme.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le menu mobile ouvre un vrai drawer opaque', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CustomerAppTheme.light,
        home: IzyTelShell(
          showBackButton: false,
          showMenuButton: true,
          drawer: const Drawer(
            backgroundColor: Colors.white,
            child: SafeArea(child: Text('Menu IzyTel')),
          ),
          child: const SizedBox.expand(child: Text('Accueil')),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Menu IzyTel'), findsOneWidget);
    final Drawer drawer = tester.widget<Drawer>(find.byType(Drawer));
    expect(drawer.backgroundColor, Colors.white);
  });
}
