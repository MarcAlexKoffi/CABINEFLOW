import 'dart:async';

import 'package:cabine_flow/core/navigation/customer_web_history.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/customer_order/data/local/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/supabase_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_beneficiary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_catalog_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_confirmation_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_home_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_identification_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_network_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_offer_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_history_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_recovery_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_payment_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_service_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_summary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/support/data/repositories/operational_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/pages/customer_help_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

enum _CustomerSurface { home, order, catalog, history, help, recovery }

class CustomerOrderFlowPage extends StatefulWidget {
  const CustomerOrderFlowPage({super.key, this.offerRepository});

  final CustomerOfferRepository? offerRepository;

  @override
  State<CustomerOrderFlowPage> createState() => _CustomerOrderFlowPageState();
}

class _CustomerOrderFlowPageState extends State<CustomerOrderFlowPage> {
  late final CustomerOrderViewModel _viewModel;
  late final CustomerOfferRepository _offerRepository;
  late final SupportRequestRepository _supportRequestRepository;
  late final CustomerWebHistoryController _webHistory;

  final CustomerOrderRepository _orderRepository =
      FirestoreCustomerOrderRepository();
  final CustomerOrderSessionStore _sessionStore =
      BrowserCustomerOrderSessionStore();
  final List<CustomerWebHistoryEntry> _navigationStack =
      <CustomerWebHistoryEntry>[];

  _CustomerSurface _surface = _CustomerSurface.home;
  int _lastObservedStep = 1;
  bool _suppressHistoryRecording = false;

  @override
  void initState() {
    super.initState();
    _offerRepository =
        widget.offerRepository ??
        (Firebase.apps.isNotEmpty
            ? SupabaseBootstrap.isInitialized
                  ? SupabaseCustomerOfferRepository()
                  : FirestoreCustomerOfferRepository()
            : const FakeCustomerOfferRepository());
    _supportRequestRepository = createOperationalSupportRequestRepository();
    _viewModel = CustomerOrderViewModel(
      orderRepository: _orderRepository,
      sessionStore: _sessionStore,
    );
    _lastObservedStep = _viewModel.currentStep;
    _viewModel.addListener(_handleViewModelNavigationChanged);

    _webHistory = createCustomerWebHistory(onPop: _handleBrowserHistoryPop);
    final CustomerWebHistoryEntry initialEntry = _entryFor(
      _CustomerSurface.home,
    );
    _navigationStack.add(initialEntry);
    _webHistory.replace(initialEntry);

    unawaited(_viewModel.initialize());
  }

  @override
  void dispose() {
    _webHistory.dispose();
    _viewModel.removeListener(_handleViewModelNavigationChanged);
    _viewModel.dispose();
    super.dispose();
  }

  CustomerWebHistoryEntry _entryFor(
    _CustomerSurface surface, {
    int? step,
  }) {
    return CustomerWebHistoryEntry(
      location: surface.name,
      step: step ?? _viewModel.currentStep,
    );
  }

  _CustomerSurface _surfaceFromLocation(String location) {
    for (final _CustomerSurface item in _CustomerSurface.values) {
      if (item.name == location) {
        return item;
      }
    }
    return _CustomerSurface.home;
  }

  void _runWithoutHistory(VoidCallback action) {
    _suppressHistoryRecording = true;
    try {
      action();
    } finally {
      _lastObservedStep = _viewModel.currentStep;
      _suppressHistoryRecording = false;
    }
  }

  void _pushHistoryEntry(CustomerWebHistoryEntry entry) {
    if (_navigationStack.isNotEmpty &&
        _navigationStack.last.matches(entry)) {
      return;
    }
    _navigationStack.add(entry);
    _webHistory.push(entry);
  }

  void _navigateTo(_CustomerSurface surface) {
    final CustomerWebHistoryEntry entry = _entryFor(surface);
    if (_surface != surface) {
      setState(() => _surface = surface);
    }
    _pushHistoryEntry(entry);
  }

  void _openHome() => _navigateTo(_CustomerSurface.home);

  void _startOrder() {
    _runWithoutHistory(_viewModel.restart);
    _navigateTo(_CustomerSurface.order);
  }

  void _startServiceOrder(CustomerService service) {
    _runWithoutHistory(() {
      _viewModel.restart();
      _viewModel.selectService(service);
    });
    _navigateTo(_CustomerSurface.order);
  }

  void _startOfferOrder(CustomerOffer offer) {
    _runWithoutHistory(() {
      _viewModel.restart();
      final CustomerService service = offer.type == CustomerOfferType.internet
          ? CustomerService.internetSubscription
          : CustomerService.calls;
      _viewModel.selectService(service);
      _viewModel.selectNetwork(offer.network);
      _viewModel.selectOffer(offer);
    });
    _navigateTo(_CustomerSurface.order);
  }

  void _openHistory() => _navigateTo(_CustomerSurface.history);

  void _openHelp() => _navigateTo(_CustomerSurface.help);

  void _openRecovery() {
    _viewModel.clearRecoveryError();
    _navigateTo(_CustomerSurface.recovery);
  }

  void _openCatalog() => _navigateTo(_CustomerSurface.catalog);

  void _showRecoveredOrder() => _navigateTo(_CustomerSurface.order);

  void _openOrder(CustomerOrderReceipt order) {
    _runWithoutHistory(() => _viewModel.resumeOrder(order));
    _navigateTo(_CustomerSurface.order);
  }

  void _requestBack() {
    if (_navigationStack.length <= 1) {
      if (_surface != _CustomerSurface.home) {
        _replaceWithHome();
      }
      return;
    }

    if (_webHistory.supported) {
      _webHistory.back();
      return;
    }

    final CustomerWebHistoryEntry previous =
        _navigationStack[_navigationStack.length - 2];
    _restoreHistoryEntry(previous);
  }

  void _replaceWithHome() {
    final CustomerWebHistoryEntry home = _entryFor(_CustomerSurface.home);
    _navigationStack
      ..clear()
      ..add(home);
    _webHistory.replace(home);
    if (_surface != _CustomerSurface.home) {
      setState(() => _surface = _CustomerSurface.home);
    }
  }

  void _handleViewModelNavigationChanged() {
    final int currentStep = _viewModel.currentStep;
    final int previousStep = _lastObservedStep;
    _lastObservedStep = currentStep;

    if (_suppressHistoryRecording ||
        _surface != _CustomerSurface.order ||
        currentStep == previousStep) {
      return;
    }

    if (currentStep > previousStep) {
      _pushHistoryEntry(
        _entryFor(_CustomerSurface.order, step: currentStep),
      );
      return;
    }

    // Safety net for a legacy page that might still call viewModel.goBack()
    // directly. Keep browser history and the visible step aligned.
    if (_navigationStack.length > 1) {
      final CustomerWebHistoryEntry previous =
          _navigationStack[_navigationStack.length - 2];
      if (previous.location == _CustomerSurface.order.name &&
          previous.step == currentStep) {
        if (_webHistory.supported) {
          _webHistory.back();
        } else {
          _restoreHistoryEntry(previous);
        }
        return;
      }
    }

    final CustomerWebHistoryEntry current = _entryFor(
      _CustomerSurface.order,
      step: currentStep,
    );
    if (_navigationStack.isNotEmpty) {
      _navigationStack[_navigationStack.length - 1] = current;
    }
    _webHistory.replace(current);
  }

  void _handleBrowserHistoryPop(CustomerWebHistoryEntry? entry) {
    if (!mounted || entry == null) {
      return;
    }

    // A confirmed order is terminal. Browser back must never reopen the
    // payment form. Skip older order-step entries until the previous main
    // surface (history, home, offers, etc.) is reached.
    if (_surface == _CustomerSurface.order &&
        _viewModel.currentStep == CustomerOrderViewModel.totalSteps &&
        entry.location == _CustomerSurface.order.name &&
        entry.step < CustomerOrderViewModel.totalSteps) {
      _webHistory.back();
      return;
    }

    _restoreHistoryEntry(entry);
  }

  void _restoreHistoryEntry(CustomerWebHistoryEntry entry) {
    final _CustomerSurface target = _surfaceFromLocation(entry.location);

    int matchingIndex = -1;
    for (int index = _navigationStack.length - 1; index >= 0; index--) {
      if (_navigationStack[index].matches(entry)) {
        matchingIndex = index;
        break;
      }
    }
    if (matchingIndex >= 0) {
      _navigationStack.removeRange(matchingIndex + 1, _navigationStack.length);
    } else {
      _navigationStack.add(entry);
    }

    _suppressHistoryRecording = true;
    try {
      if (target == _CustomerSurface.order) {
        _viewModel.restoreNavigationStep(entry.step);
      }
      _lastObservedStep = _viewModel.currentStep;
      if (_surface != target && mounted) {
        setState(() => _surface = target);
      }
    } finally {
      _suppressHistoryRecording = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_surface) {
            _CustomerSurface.recovery => CustomerOrderRecoveryPage(
              key: const ValueKey<String>('customer-recovery'),
              viewModel: _viewModel,
              onBack: _requestBack,
              onRecovered: _showRecoveredOrder,
            ),
            _CustomerSurface.help => CustomerHelpPage(
              key: const ValueKey<String>('customer-help'),
              onBack: _requestBack,
              onOpenRecovery: _openRecovery,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
            ),
            _CustomerSurface.history => CustomerOrderHistoryPage(
              key: const ValueKey<String>('customer-history'),
              viewModel: _viewModel,
              onBack: _requestBack,
              onOpenOrder: _openOrder,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHelp: _openHelp,
            ),
            _CustomerSurface.catalog => CustomerCatalogPage(
              key: const ValueKey<String>('customer-catalog'),
              offerRepository: _offerRepository,
              onBack: _requestBack,
              onChooseOffer: _startOfferOrder,
              onStartOrder: _startOrder,
              onStartDirectTransfer: () =>
                  _startServiceOrder(CustomerService.unitTransfer),
              onOpenHome: _openHome,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
            ),
            _CustomerSurface.home => CustomerHomePage(
              key: const ValueKey<String>('customer-home'),
              offerRepository: _offerRepository,
              onStartOrder: _startOrder,
              onStartService: _startServiceOrder,
              onChooseOffer: _startOfferOrder,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
              onOpenRecovery: _openRecovery,
            ),
            _CustomerSurface.order => _buildCurrentStep(),
          },
        );
      },
    );
  }

  Widget _buildCurrentStep() {
    switch (_viewModel.currentStep) {
      case 1:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onOpenRecovery: _openRecovery,
          onResumeOrder: _openOrder,
          onBackToHome: _requestBack,
        );
      case 2:
        return CustomerServicePage(
          key: const ValueKey<int>(2),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 3:
        return CustomerNetworkPage(
          key: const ValueKey<int>(3),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 4:
        return CustomerOfferPage(
          key: const ValueKey<int>(4),
          viewModel: _viewModel,
          offerRepository: _offerRepository,
          onBack: _requestBack,
        );
      case 5:
        return CustomerBeneficiaryPage(
          key: const ValueKey<int>(5),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 6:
        return CustomerSummaryPage(
          key: const ValueKey<int>(6),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 7:
        return CustomerPaymentPage(
          key: const ValueKey<int>(7),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 8:
        return CustomerConfirmationPage(
          key: const ValueKey<int>(8),
          viewModel: _viewModel,
          onOpenHome: _openHome,
          onOpenOffers: _openCatalog,
          onOpenHistory: _openHistory,
          onOpenHelp: _openHelp,
          supportRequestRepository: _supportRequestRepository,
        );
      default:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onOpenRecovery: _openRecovery,
          onResumeOrder: _openOrder,
          onBackToHome: _requestBack,
        );
    }
  }
}
