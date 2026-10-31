import 'package:cabine_flow/features/navigation/presentation/widgets/izytel_mobile_back_scope.dart';
import 'package:cabine_flow/features/navigation/presentation/pages/main_shell_page.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/data/repositories/fake_commission_repository.dart';
import 'package:cabine_flow/features/dashboard/data/repositories/fake_dashboard_repository.dart';
import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/payments/data/repositories/wave_payment_link_repository.dart';
import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final role in [
    UserRole.agent,
    UserRole.manager,
    UserRole.administrator,
  ]) {
    testWidgets('shell $role: details, onglets, modales et sortie protegee', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final notifications = <bool>[];
      final root = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorKey: root,
          onNavigationNotification: (notification) {
            notifications.add(notification.canHandlePop);
            return true;
          },
          home: MainShellPage(
            user: AppUser(
              id: 'AGENT-001',
              name: 'Test',
              phoneNumber: '',
              role: role,
            ),
            authRepository: FakeAuthRepository(),
            dashboardRepository: const FakeDashboardRepository(),
            ordersRepository: FakeOrdersRepository(isTest: true),
            offerCatalogRepository: const FakeOfferCatalogRepository(),
            adminOfferRepository: FakeAdminOfferRepository(),
            paymentLinkRepository: const WavePaymentLinkRepository(
              linkBuilder: WavePaymentLinkBuilder(),
            ),
            agentRepository: FakeAgentRepository(),
            commissionRepository: FakeCommissionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prefix = switch (role) {
        UserRole.agent => 'agent',
        UserRole.manager => 'manager',
        _ => 'admin',
      };
      await tester.tap(find.byKey(ValueKey('$prefix-nav-commandes')));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).at(1),
      );
      // The first visible nested navigator belongs to the selected Orders tab.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('liste test')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail test')),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(ValueKey('$prefix-nav-accueil')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('$prefix-nav-commandes')));
        await tester.pumpAndSettle();
        expect(find.text('detail test'), findsOneWidget);
      }

      // A root modal consumes Back without touching the tab's detail.
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(title: Text('modale test')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('detail test'), findsOneWidget);
      expect(exits, 0);

      await _gestureMessage(tester, 'startBackGesture');
      await _gestureMessage(tester, 'cancelBackGesture');
      await tester.pump();
      expect(find.text('detail test'), findsOneWidget);
      await _gestureMessage(tester, 'startBackGesture');
      await _gestureMessage(tester, 'commitBackGesture');
      // Rapid duplicate callbacks must not consume the list as well.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('liste test'), findsOneWidget);
      expect(exits, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
      expect(notifications.last, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exits, 0);
      await tester.pump(const Duration(milliseconds: 300));
      // At Home, only the second deliberate Back can close the application.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(exits, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(exits, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('un navigateur imbrique vide ne rend pas Retour a Android', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final notifications = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        onNavigationNotification: (notification) {
          notifications.add(notification.canHandlePop);
          return true;
        },
        home: IzyTelMobileBackScope(
          activeNavigatorKey: navigator,
          isHomeTab: false,
          onReturnHome: () {},
          child: Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('onglet')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Also emitted by inactive IndexedStack navigators after route changes.
    const NavigationNotification(
      canHandlePop: false,
    ).dispatch(tester.element(find.text('onglet')));
    await tester.pump();
    expect(notifications.last, isTrue);
  });
}

Future<void> _gestureMessage(WidgetTester tester, String method) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        method,
        method == 'startBackGesture'
            ? <String, Object>{
                'touchOffset': <double>[5, 200],
                'progress': 0.0,
                'swipeEdge': 0,
              }
            : null,
      ),
    ),
    (_) {},
  );
}
