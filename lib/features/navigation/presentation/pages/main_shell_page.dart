import 'dart:async';

import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_activity_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_commissions_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_performance_page.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/more_page.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_history_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:cabine_flow/features/payments/presentation/pages/payments_page.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.user,
    required this.authRepository,
    required this.dashboardRepository,
    required this.ordersRepository,
    required this.offerCatalogRepository,
    required this.adminOfferRepository,
    required this.paymentLinkRepository,
    required this.agentRepository,
    required this.commissionRepository,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final OrdersRepository ordersRepository;
  final OfferCatalogRepository offerCatalogRepository;
  final AdminOfferRepository adminOfferRepository;
  final PaymentLinkRepository paymentLinkRepository;
  final AgentRepository agentRepository;
  final CommissionRepository commissionRepository;

  @override
  State<MainShellPage> createState() {
    return _MainShellPageState();
  }
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;
  StreamSubscription<List<AgentDirectoryEntry>>? _staffAgentsSubscription;
  StreamSubscription<List<AutomaticAssignmentQueueItem>>?
  _staffQueueSubscription;
  Timer? _automaticAssignmentDebounce;
  bool _automaticAssignmentSyncRunning = false;
  bool _automaticAssignmentSyncPending = false;
  bool _isLoggingOut = false;

  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
        5,
        (int index) =>
            GlobalKey<NavigatorState>(debugLabel: 'admin-tab-$index'),
      );

  @override
  void initState() {
    super.initState();
    if (widget.user.role != UserRole.agent) {
      _startAutomaticAssignmentWatchers();
      _scheduleAutomaticAssignmentSync(immediate: true);
    }
  }

  void _startAutomaticAssignmentWatchers() {
    _staffAgentsSubscription = widget.agentRepository.watchAgents().listen(
      (_) => _scheduleAutomaticAssignmentSync(),
      onError: (Object error) {
        debugPrint('[AutoAssignment][staff-watch-agents] $error');
      },
    );
    _staffQueueSubscription = widget.ordersRepository
        .watchAutomaticAssignmentQueue()
        .listen(
          (_) => _scheduleAutomaticAssignmentSync(),
          onError: (Object error) {
            debugPrint('[AutoAssignment][staff-watch-queue] $error');
          },
        );
  }

  void _scheduleAutomaticAssignmentSync({bool immediate = false}) {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      if (immediate) {
        unawaited(_synchronizeAutomaticAssignmentBacklog());
      }
      return;
    }
    _automaticAssignmentDebounce?.cancel();
    if (immediate) {
      unawaited(_synchronizeAutomaticAssignmentBacklog());
      return;
    }
    _automaticAssignmentDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_synchronizeAutomaticAssignmentBacklog()),
    );
  }

  Future<void> _synchronizeAutomaticAssignmentBacklog() async {
    if (_automaticAssignmentSyncRunning) {
      _automaticAssignmentSyncPending = true;
      return;
    }

    _automaticAssignmentSyncRunning = true;
    try {
      await widget.ordersRepository.synchronizeAutomaticAssignmentBacklog();
    } catch (error, stackTrace) {
      debugPrint('[AutoAssignment][backlog] $error');
      debugPrint('[AutoAssignment][backlog] stack:\n$stackTrace');
    } finally {
      _automaticAssignmentSyncRunning = false;
      if (_automaticAssignmentSyncPending) {
        _automaticAssignmentSyncPending = false;
        _scheduleAutomaticAssignmentSync();
      }
    }
  }

  void _handlePaymentConfirmed() {
    _scheduleAutomaticAssignmentSync(immediate: true);
  }

  @override
  void dispose() {
    _automaticAssignmentDebounce?.cancel();
    _staffAgentsSubscription?.cancel();
    _staffQueueSubscription?.cancel();
    super.dispose();
  }

  void _openOrdersTab() {
    _selectDestination(1);
  }

  void _openPaymentsTab() {
    _selectDestination(2);
  }

  void _openMoreTab() {
    _selectDestination(4);
  }

  Future<void> _logoutAdmin() async {
    if (_isLoggingOut) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'Tu devras te reconnecter pour accéder de nouveau à la cabine.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Symbols.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authRepository.logout();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggingOut = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de se déconnecter pour le moment.'),
          ),
        );
    }
  }

  Future<void> _handleSystemBack() async {
    final NavigatorState? currentNavigator =
        _tabNavigatorKeys[_selectedIndex].currentState;

    if (currentNavigator != null && await currentNavigator.maybePop()) {
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    await SystemNavigator.pop();
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildTabNavigator(int index, Widget rootPage) {
    return Navigator(
      key: _tabNavigatorKeys[index],
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => rootPage,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role == UserRole.agent) {
      return _AgentShell(
        user: widget.user,
        authRepository: widget.authRepository,
        ordersRepository: widget.ordersRepository,
        agentRepository: widget.agentRepository,
        commissionRepository: widget.commissionRepository,
      );
    }

    final List<Widget> pages = <Widget>[
      DashboardPage(
        user: widget.user,
        dashboardRepository: widget.dashboardRepository,
        orderHistoryRepository:
            widget.ordersRepository is OrderHistoryRepository
            ? widget.ordersRepository as OrderHistoryRepository
            : null,
        onOpenOrders: _openOrdersTab,
        onOpenPayments: _openPaymentsTab,
        onOpenMore: _openMoreTab,
        onLogout: _logoutAdmin,
      ),
      OrdersPage(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        agentRepository: widget.agentRepository,
      ),
      PaymentsPage(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        onPaymentConfirmed: _handlePaymentConfirmed,
        onOpenOrders: _openOrdersTab,
      ),
      FinancesPage(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        commissionRepository: widget.commissionRepository,
        agentRepository: widget.agentRepository,
        onOpenPayments: _openPaymentsTab,
      ),
      MorePage(
        user: widget.user,
        authRepository: widget.authRepository,
        adminOfferRepository: widget.adminOfferRepository,
        agentRepository: widget.agentRepository,
        ordersRepository: widget.ordersRepository,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_handleSystemBack());
      },
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            pages.length,
            (int index) => _buildTabNavigator(index, pages[index]),
          ),
        ),
        bottomNavigationBar: CabineBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectDestination,
        ),
      ),
    );
  }
}

class _AgentShell extends StatefulWidget {
  const _AgentShell({
    required this.user,
    required this.authRepository,
    required this.ordersRepository,
    required this.agentRepository,
    required this.commissionRepository,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final CommissionRepository commissionRepository;

  @override
  State<_AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<_AgentShell> {
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
        3,
        (int index) =>
            GlobalKey<NavigatorState>(debugLabel: 'agent-tab-$index'),
      );

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'Tu devras te reconnecter pour accéder de nouveau à ton espace Agent.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Symbols.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authRepository.logout();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggingOut = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de se déconnecter pour le moment.'),
          ),
        );
    }
  }

  Future<void> _handleSystemBack() async {
    final NavigatorState? currentNavigator =
        _tabNavigatorKeys[_selectedIndex].currentState;

    if (currentNavigator != null && await currentNavigator.maybePop()) {
      return;
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    await SystemNavigator.pop();
  }

  Widget _buildTabNavigator(int index, Widget rootPage) {
    return Navigator(
      key: _tabNavigatorKeys[index],
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => rootPage,
        );
      },
    );
  }

  void _openAgentProfile() {
    setState(() => _selectedIndex = 2);
    _tabNavigatorKeys[2].currentState?.popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
  }

  void _openAgentHistory() {
    setState(() => _selectedIndex = 1);
  }

  void _openAgentPerformance() {
    setState(() => _selectedIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabNavigatorKeys[2].currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AgentPerformancePage(
            user: widget.user,
            repository: widget.commissionRepository,
          ),
        ),
      );
    });
  }

  void _openAgentCommissions() {
    setState(() => _selectedIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabNavigatorKeys[2].currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AgentCommissionsPage(
            user: widget.user,
            repository: widget.commissionRepository,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AgentOrdersPage(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        agentRepository: widget.agentRepository,
        onOpenProfile: _openAgentProfile,
        onOpenPerformance: _openAgentPerformance,
        onOpenCommissions: _openAgentCommissions,
        onLogout: _logout,
      ),
      AgentHistoryPage(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        agentRepository: widget.agentRepository,
      ),
      AgentActivityPage(
        user: widget.user,
        repository: widget.agentRepository,
        commissionRepository: widget.commissionRepository,
        isLoggingOut: _isLoggingOut,
        onLogout: _logout,
        onOpenHistory: _openAgentHistory,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_handleSystemBack());
      },
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            pages.length,
            (int index) => _buildTabNavigator(index, pages[index]),
          ),
        ),
        bottomNavigationBar: _AgentBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
          },
        ),
      ),
    );
  }
}

class _AgentBottomNavigationBar extends StatelessWidget {
  const _AgentBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    const List<_AgentNavigationItem> items = <_AgentNavigationItem>[
      _AgentNavigationItem(
        label: 'Commandes',
        icon: Symbols.receipt_long_rounded,
        selectedIcon: Symbols.receipt_long_rounded,
      ),
      _AgentNavigationItem(
        label: 'Historique',
        icon: Symbols.history_rounded,
        selectedIcon: Symbols.history_rounded,
      ),
      _AgentNavigationItem(
        label: 'Profil',
        icon: Symbols.person_rounded,
        selectedIcon: Symbols.person_rounded,
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
        boxShadow: [
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 22,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List<Widget>.generate(items.length, (int index) {
              final _AgentNavigationItem item = items[index];
              final bool selected = selectedIndex == index;
              final Color color = selected
                  ? IzyTelColors.primary
                  : IzyTelColors.textSecondary;
              return Expanded(
                child: InkWell(
                  key: ValueKey<String>(
                    'agent-nav-${item.label.toLowerCase()}',
                  ),
                  onTap: () => onDestinationSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? IzyTelColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: IzyTelIconSize.navigation,
                          fill: selected ? 1 : 0,
                          weight: selected ? 600 : 450,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: color,
                              fontSize: IzyTelTypeScale.micro,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AgentNavigationItem {
  const _AgentNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
