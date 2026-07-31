import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/presentation/pages/login_page.dart';
import 'package:cabine_flow/features/dashboard/data/repositories/fake_dashboard_repository.dart';
import 'package:cabine_flow/features/navigation/presentation/pages/main_shell_page.dart';
import 'package:cabine_flow/features/payments/data/repositories/wave_payment_link_repository.dart';
import 'package:cabine_flow/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_offer_catalog_repository.dart';

class CabineFlowApp extends StatelessWidget {
  const CabineFlowApp({super.key});

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
    const FakeAuthRepository authRepository = FakeAuthRepository();

    const FakeDashboardRepository dashboardRepository =
        FakeDashboardRepository();

    final FakeOrdersRepository ordersRepository = FakeOrdersRepository();

    const FakeOfferCatalogRepository offerCatalogRepository =
        FakeOfferCatalogRepository();

    const WavePaymentLinkRepository paymentLinkRepository =
        WavePaymentLinkRepository(linkBuilder: WavePaymentLinkBuilder());

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
                return const LoginPage(authRepository: authRepository);
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
                  dashboardRepository: dashboardRepository,
                  ordersRepository: ordersRepository,
                  offerCatalogRepository: offerCatalogRepository,
                  paymentLinkRepository: paymentLinkRepository,
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
