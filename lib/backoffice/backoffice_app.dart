import 'dart:async';

import 'package:cabine_flow/backoffice/data/repositories/fake_backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/firestore_backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/fake_territory_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:cabine_flow/features/control/data/repositories/supabase_control_repository.dart';
import 'package:cabine_flow/features/control/domain/repositories/control_repository.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_login_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_shell_page.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/migrations/legacy_territory_backfill_service.dart';
import 'package:cabine_flow/core/migrations/legacy_catalog_backfill_service.dart';
import 'package:cabine_flow/core/migrations/legacy_finance_backfill_service.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/data/repositories/firestore_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/data/repositories/firestore_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/data/repositories/supabase_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/hybrid_orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/operational_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/operational_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({
    super.key,
    this.authRepository,
    this.userRepository,
    this.ordersRepository,
    this.agentRepository,
    this.territoryRepository,
    this.supportRepository,
    this.refundRepository,
    this.adminOfferRepository,
    this.financeRepository,
    this.controlRepository,
  });

  final AuthRepository? authRepository;
  final BackofficeUserRepository? userRepository;
  final OrdersRepository? ordersRepository;
  final AgentRepository? agentRepository;
  final TerritoryRepository? territoryRepository;
  final SupportRequestRepository? supportRepository;
  final RefundRepository? refundRepository;
  final AdminOfferRepository? adminOfferRepository;
  final BackofficeFinanceRepository? financeRepository;
  final ControlRepository? controlRepository;

  @override
  Widget build(BuildContext context) {
    final bool firebaseReady = Firebase.apps.isNotEmpty;
    final AuthRepository effectiveAuth =
        authRepository ??
        (firebaseReady ? FirebaseAuthRepository() : FakeAuthRepository());
    final BackofficeUserRepository effectiveUsers =
        userRepository ??
        (firebaseReady
            ? FirestoreBackofficeUserRepository()
            : const FakeBackofficeUserRepository());
    final OrdersRepository effectiveOrders =
        ordersRepository ??
        (firebaseReady
            ? SupabaseBootstrap.isInitialized
                  ? HybridOrdersRepository()
                  : FirestoreOrdersRepository()
            : FakeOrdersRepository(isTest: true));
    final AgentRepository effectiveAgents =
        agentRepository ??
        (firebaseReady ? FirestoreAgentRepository() : FakeAgentRepository());
    final TerritoryRepository effectiveTerritory =
        territoryRepository ??
        (SupabaseBootstrap.isInitialized
            ? SupabaseTerritoryRepository()
            : FakeTerritoryRepository());
    final SupportRequestRepository effectiveSupport =
        supportRepository ?? createOperationalSupportRequestRepository();
    final RefundRepository effectiveRefunds =
        refundRepository ?? createOperationalRefundRepository();
    final AdminOfferRepository effectiveOffers =
        adminOfferRepository ??
        (SupabaseBootstrap.isInitialized
            ? SupabaseAdminOfferRepository()
            : firebaseReady
            ? FirestoreAdminOfferRepository()
            : FakeAdminOfferRepository());
    final BackofficeFinanceRepository? effectiveFinance =
        financeRepository ??
        (SupabaseBootstrap.isInitialized
            ? SupabaseBackofficeFinanceRepository()
            : null);
    final ControlRepository? effectiveControl =
        controlRepository ??
        (SupabaseBootstrap.isInitialized
            ? SupabaseControlRepository()
            : null);

    return MaterialApp(
      title: 'IzyTel Back-office',
      debugShowCheckedModeBanner: false,
      theme: BackofficeTheme.light,
      darkTheme: BackofficeTheme.light,
      themeMode: ThemeMode.light,
      home: _BackofficeAccessGate(
        authRepository: effectiveAuth,
        userRepository: effectiveUsers,
        ordersRepository: effectiveOrders,
        agentRepository: effectiveAgents,
        territoryRepository: effectiveTerritory,
        supportRepository: effectiveSupport,
        refundRepository: effectiveRefunds,
        adminOfferRepository: effectiveOffers,
        financeRepository: effectiveFinance,
        controlRepository: effectiveControl,
      ),
    );
  }
}

class _BackofficeAccessGate extends StatefulWidget {
  const _BackofficeAccessGate({
    required this.authRepository,
    required this.userRepository,
    required this.ordersRepository,
    required this.agentRepository,
    required this.territoryRepository,
    required this.supportRepository,
    required this.refundRepository,
    required this.adminOfferRepository,
    required this.financeRepository,
    required this.controlRepository,
  });

  final AuthRepository authRepository;
  final BackofficeUserRepository userRepository;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final TerritoryRepository territoryRepository;
  final SupportRequestRepository supportRepository;
  final RefundRepository refundRepository;
  final AdminOfferRepository adminOfferRepository;
  final BackofficeFinanceRepository? financeRepository;
  final ControlRepository? controlRepository;

  @override
  State<_BackofficeAccessGate> createState() => _BackofficeAccessGateState();
}

class _BackofficeAccessGateState extends State<_BackofficeAccessGate> {
  bool _loading = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }


  Future<void> _restoreSession() async {
    final AuthLoginResult result = await widget.authRepository
        .refreshCurrentAccess();
    if (!mounted) return;

    final AppUser? resolved = result.user;
    if (result.isAuthenticated &&
        resolved != null &&
        _canAccessBackoffice(resolved)) {
      setState(() {
        _user = resolved;
        _loading = false;
      });
      if (resolved.role == UserRole.administrator &&
          SupabaseBootstrap.isInitialized) {
        unawaited(LegacyTerritoryBackfillService().runIfNeeded());
        unawaited(LegacyCatalogBackfillService().runIfNeeded());
        unawaited(LegacyFinanceBackfillService().runIfNeeded());
      }
      return;
    }

    if (result.isAuthenticated && resolved != null) {
      await widget.authRepository.logout();
    }

    if (!mounted) return;
    setState(() {
      _user = null;
      _loading = false;
    });
  }

  bool _canAccessBackoffice(AppUser user) {
    return user.role == UserRole.administrator ||
        user.role == UserRole.manager ||
        user.role == UserRole.supervisor;
  }

  void _handleAuthenticated(AppUser user) {
    if (!_canAccessBackoffice(user)) return;
    setState(() => _user = user);
    if (user.role == UserRole.administrator &&
        SupabaseBootstrap.isInitialized) {
      unawaited(LegacyTerritoryBackfillService().runIfNeeded());
      unawaited(LegacyCatalogBackfillService().runIfNeeded());
      unawaited(LegacyFinanceBackfillService().runIfNeeded());
    }
  }

  Future<void> _logout() async {
    await widget.authRepository.logout();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _BackofficeLoadingPage();
    }

    final AppUser? user = _user;
    if (user == null) {
      return BackofficeLoginPage(
        authRepository: widget.authRepository,
        onAuthenticated: _handleAuthenticated,
      );
    }

    return BackofficeShellPage(
      user: user,
      userRepository: widget.userRepository,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
      territoryRepository: widget.territoryRepository,
      supportRepository: widget.supportRepository,
      refundRepository: widget.refundRepository,
      adminOfferRepository: widget.adminOfferRepository,
      financeRepository: widget.financeRepository,
      controlRepository: widget.controlRepository,
      onLogout: _logout,
    );
  }
}

class _BackofficeLoadingPage extends StatelessWidget {
  const _BackofficeLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BackofficePalette.canvas,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: BackofficePalette.primary.withValues(alpha: .06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                color: BackofficePalette.cyan.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BackofficePalette.line),
                borderRadius: BorderRadius.circular(22),
                boxShadow: BackofficeShadows.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BackofficePalette.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const IzyTelBrandMark(size: 52),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'IzyTel Back-office',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BackofficePalette.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Préparation de votre espace de travail',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
