import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finances_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/more_page.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
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
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final OrdersRepository ordersRepository;
  final OfferCatalogRepository offerCatalogRepository;
  final AdminOfferRepository adminOfferRepository;
  final PaymentLinkRepository paymentLinkRepository;

  @override
  State<MainShellPage> createState() {
    return _MainShellPageState();
  }
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;

  int _ordersPageVersion = 0;
  int _paymentsPageVersion = 0;

  void _handlePaymentConfirmed() {
    setState(() {
      _ordersPageVersion++;
    });
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

    setState(() {
      _paymentsPageVersion++;
    });

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

    if (paymentRequestWasSent == true) {
      setState(() {
        _paymentsPageVersion++;
      });
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
    final List<Widget> pages = [
      DashboardPage(
        user: widget.user,
        dashboardRepository: widget.dashboardRepository,
        onOpenOrders: _openOrdersTab,
      ),
      OrdersPage(
        key: ValueKey<int>(_ordersPageVersion),
        user: widget.user,
        ordersRepository: widget.ordersRepository,
      ),
      PaymentsPage(
        key: ValueKey<int>(_paymentsPageVersion),
        user: widget.user,
        ordersRepository: widget.ordersRepository,
        paymentLinkRepository: widget.paymentLinkRepository,
        onPaymentConfirmed: _handlePaymentConfirmed,
        onOpenOrders: _openOrdersTab,
      ),
      const FinancesPage(),
      MorePage(
        user: widget.user,
        adminOfferRepository: widget.adminOfferRepository,
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
