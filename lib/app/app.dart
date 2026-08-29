import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/data/repositories/firestore_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/pages/login_page.dart';
import 'package:cabine_flow/features/auth/presentation/pages/pending_account_page.dart';
import 'package:cabine_flow/features/dashboard/data/repositories/fake_dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/data/repositories/firestore_dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/navigation/presentation/pages/main_shell_page.dart';
import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/data/repositories/firestore_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/firestore_offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/payments/data/repositories/wave_payment_link_repository.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:cabine_flow/features/splash/presentation/pages/splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class CabineFlowApp extends StatelessWidget {
  const CabineFlowApp({
    super.key,
    this.authRepository,
    this.dashboardRepository,
    this.ordersRepository,
    this.offerCatalogRepository,
    this.adminOfferRepository,
    this.paymentLinkRepository,
    this.agentRepository,
  });

  final AuthRepository? authRepository;
  final DashboardRepository? dashboardRepository;
  final OrdersRepository? ordersRepository;
  final OfferCatalogRepository? offerCatalogRepository;
  final AdminOfferRepository? adminOfferRepository;
  final PaymentLinkRepository? paymentLinkRepository;
  final AgentRepository? agentRepository;

  Route<dynamic> _createErrorRoute() {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return const Scaffold(
          body: Center(child: Text('Impossible d’ouvrir cette page.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirebaseInitialized = Firebase.apps.isNotEmpty;

    final AuthRepository effectiveAuthRepository =
        authRepository ??
        (isFirebaseInitialized
            ? FirebaseAuthRepository()
            : FakeAuthRepository());

    final DashboardRepository effectiveDashboardRepository =
        dashboardRepository ??
        (isFirebaseInitialized
            ? FirestoreDashboardRepository()
            : const FakeDashboardRepository());

    final OrdersRepository effectiveOrdersRepository =
        ordersRepository ??
        (isFirebaseInitialized
            ? FirestoreOrdersRepository()
            : FakeOrdersRepository());

    final OfferCatalogRepository effectiveOfferCatalogRepository =
        offerCatalogRepository ??
        (isFirebaseInitialized
            ? FirestoreOfferCatalogRepository()
            : const FakeOfferCatalogRepository());

    final AdminOfferRepository effectiveAdminOfferRepository =
        adminOfferRepository ??
        (isFirebaseInitialized
            ? FirestoreAdminOfferRepository()
            : FakeAdminOfferRepository());

    final PaymentLinkRepository effectivePaymentLinkRepository =
        paymentLinkRepository ??
        const WavePaymentLinkRepository(linkBuilder: WavePaymentLinkBuilder());

    final AgentRepository effectiveAgentRepository =
        agentRepository ??
        (isFirebaseInitialized
            ? FirestoreAgentRepository()
            : FakeAgentRepository());

    return MaterialApp(
      title: 'CabineFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                return const SplashPage();
              },
            );

          case AppRoutes.login:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                return LoginPage(authRepository: effectiveAuthRepository);
              },
            );

          case AppRoutes.pendingAccount:
            final Object? arguments = settings.arguments;

            if (arguments is! AuthLoginResult ||
                !arguments.requiresAccessScreen) {
              return _createErrorRoute();
            }

            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                return PendingAccountPage(
                  authRepository: effectiveAuthRepository,
                  initialResult: arguments,
                );
              },
            );

          case AppRoutes.dashboard:
            final Object? arguments = settings.arguments;

            if (arguments is! AppUser) {
              return _createErrorRoute();
            }

            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                return MainShellPage(
                  user: arguments,
                  authRepository: effectiveAuthRepository,
                  dashboardRepository: effectiveDashboardRepository,
                  ordersRepository: effectiveOrdersRepository,
                  offerCatalogRepository: effectiveOfferCatalogRepository,
                  adminOfferRepository: effectiveAdminOfferRepository,
                  paymentLinkRepository: effectivePaymentLinkRepository,
                  agentRepository: effectiveAgentRepository,
                );
              },
            );

          default:
            return _createErrorRoute();
        }
      },
    );
  }
}
