import 'package:cabine_flow/features/navigation/presentation/widgets/izytel_mobile_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Retour depile d abord la sous-page du Navigator actif', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    int homeReturns = 0;
    int exits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: IzyTelMobileBackScope(
          activeNavigatorKey: navigatorKey,
          isHomeTab: false,
          onReturnHome: () => homeReturns++,
          onExit: () async { exits++; },
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('racine onglet')),
            ),
          ),
        ),
      ),
    );

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('sous-page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sous-page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('racine onglet'), findsOneWidget);
    expect(homeReturns, 0);
    expect(exits, 0);
  });

  testWidgets('Retour depuis une racine secondaire demande Accueil', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    int homeReturns = 0;
    int exits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: IzyTelMobileBackScope(
          activeNavigatorKey: navigatorKey,
          isHomeTab: false,
          onReturnHome: () => homeReturns++,
          onExit: () async { exits++; },
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('racine secondaire')),
            ),
          ),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(homeReturns, 1);
    expect(exits, 0);
  });

  testWidgets('Retour depuis Accueil racine quitte seulement a ce niveau', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    int homeReturns = 0;
    int exits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: IzyTelMobileBackScope(
          activeNavigatorKey: navigatorKey,
          isHomeTab: true,
          onReturnHome: () => homeReturns++,
          onExit: () async { exits++; },
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('accueil')),
            ),
          ),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(homeReturns, 0);
    expect(exits, 1);
  });
}
