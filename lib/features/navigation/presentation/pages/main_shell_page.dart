import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/more_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/payments/presentation/pages/payments_page.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.user,
    required this.dashboardRepository,
    required this.ordersRepository,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final OrdersRepository ordersRepository;

  @override
  State<MainShellPage> createState() {
    return _MainShellPageState();
  }
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardPage(
        user: widget.user,
        dashboardRepository: widget.dashboardRepository,
      ),
      OrdersPage(user: widget.user, ordersRepository: widget.ordersRepository),
      const PaymentsPage(),
      const FinancesPage(),
      const MorePage(),
    ];
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showCreateOrderMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Le formulaire de création d’une commande sera ajouté prochainement.',
          ),
        ),
      );
  }

  bool get _showCreateOrderButton {
    return _selectedIndex == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: _showCreateOrderButton
          ? FloatingActionButton(
              tooltip: 'Créer une commande',
              onPressed: _showCreateOrderMessage,
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
