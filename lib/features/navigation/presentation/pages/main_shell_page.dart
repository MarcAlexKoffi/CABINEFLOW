import 'dart:async';

import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_activity_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/more_page.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:cabine_flow/features/payments/presentation/pages/send_wave_link_page.dart';
import 'package:cabine_flow/features/payments/presentation/pages/payments_page.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/create_order_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.user,
    required this.dashboardRepository,
    required this.ordersRepository,
    required this.offerCatalogRepository,
    required this.adminOfferRepository,
    required this.paymentLinkRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final OrdersRepository ordersRepository;
  final OfferCatalogRepository offerCatalogRepository;
  final AdminOfferRepository adminOfferRepository;
  final PaymentLinkRepository paymentLinkRepository;
  final AgentRepository agentRepository;

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
    _automaticAssignmentDebounce?.cancel();
    if (immediate) {
      unawaited(_synchronizeAutomaticAssignmentBacklog());
      return;
    }
    _automaticAssignmentDebounce = Timer(
      const Duration(milliseconds: 180),
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
      debugPrintStack(
        label: '[AutoAssignment][backlog] stack',
        stackTrace: stackTrace,
      );
    } finally {
      _automaticAssignmentSyncRunning = false;
      if (_automaticAssignmentSyncPending) {
        _automaticAssignmentSyncPending = false;
        _scheduleAutomaticAssignmentSync();
      }
    }
  }

  void _handlePaymentConfirmed() {
    // Le repository tente déjà l'affectation juste après la confirmation.
    // Ce second déclencheur est volontaire : il rend le flux résilient à une
    // course Firestore ou à un profil agent qui vient d'être actualisé.
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
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openCreateOrderPage() async {
    final CreateOrderPageResult? result = await Navigator.of(context)
        .push<CreateOrderPageResult>(
          MaterialPageRoute<CreateOrderPageResult>(
            fullscreenDialog: true,
            builder: (BuildContext routeContext) {
              return CreateOrderPage(
                user: widget.user,
                ordersRepository: widget.ordersRepository,
                offerCatalogRepository: widget.offerCatalogRepository,
              );
            },
          ),
        );

    if (!mounted || result == null) {
      return;
    }

    if (!result.preparePayment) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Commande ${result.order.reference} enregistrée.'),
          ),
        );

      return;
    }

    final bool? paymentRequestWasSent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext routeContext) {
          return SendWaveLinkPage(
            order: result.order,
            ordersRepository: widget.ordersRepository,
            paymentLinkRepository: widget.paymentLinkRepository,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    final String message;

    if (paymentRequestWasSent == true) {
      message =
          'Le lien Wave de la commande ${result.order.reference} a été envoyé.';
    } else {
      message =
          'La commande ${result.order.reference} est enregistrée. Le lien Wave reste à envoyer.';
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _showCreateOrderButton {
    return _selectedIndex == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role == UserRole.agent) {
      return _AgentShell(
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        agentRepository: widget.agentRepository,
      );
    }

    final List<Widget> pages = [
      DashboardPage(
        user: widget.user,
        dashboardRepository: widget.dashboardRepository,
        onOpenOrders: _openOrdersTab,
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
      const FinancesPage(),
      MorePage(
        user: widget.user,
        adminOfferRepository: widget.adminOfferRepository,
        agentRepository: widget.agentRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _showCreateOrderButton
          ? FloatingActionButton(
              tooltip: 'Créer une commande',
              onPressed: _openCreateOrderPage,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      bottomNavigationBar: CabineBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }
}

class _AgentShell extends StatefulWidget {
  const _AgentShell({
    required this.user,
    required this.ordersRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;

  @override
  State<_AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<_AgentShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AgentOrdersPage(
            user: widget.user,
            ordersRepository: widget.ordersRepository,
            agentRepository: widget.agentRepository,
          ),
          AgentActivityPage(
            user: widget.user,
            repository: widget.agentRepository,
          ),
        ],
      ),
      bottomNavigationBar: _AgentBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          if (_selectedIndex == index) return;
          setState(() {
            _selectedIndex = index;
          });
        },
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
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      _AgentNavigationItem(
        label: 'Profil',
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts_rounded,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: Color(0x3343B5FF))),
        ),
        child: Row(
          children: List<Widget>.generate(items.length, (int index) {
            final item = items[index];
            final bool selected = selectedIndex == index;
            final Color color = selected
                ? AppColors.primary
                : AppColors.onSurfaceVariant;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onDestinationSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withAlpha(40)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 23,
                          color: color,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
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
