import 'dart:async';

import 'package:cabine_flow/features/customer_order/data/local/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_beneficiary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_confirmation_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_identification_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_network_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_offer_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_history_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_payment_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_service_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_summary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:flutter/material.dart';

class CustomerOrderFlowPage extends StatefulWidget {
  const CustomerOrderFlowPage({super.key});

  @override
  State<CustomerOrderFlowPage> createState() {
    return _CustomerOrderFlowPageState();
  }
}

class _CustomerOrderFlowPageState extends State<CustomerOrderFlowPage> {
  late final CustomerOrderViewModel _viewModel;
  bool _isShowingHistory = false;

  final CustomerOfferRepository _offerRepository =
      const FakeCustomerOfferRepository();

  final CustomerOrderRepository _orderRepository =
      FirestoreCustomerOrderRepository();

  final CustomerOrderSessionStore _sessionStore =
      BrowserCustomerOrderSessionStore();

  @override
  void initState() {
    super.initState();
    _viewModel = CustomerOrderViewModel(
      orderRepository: _orderRepository,
      sessionStore: _sessionStore,
    );
    unawaited(_viewModel.initialize());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openHistory() {
    setState(() {
      _isShowingHistory = true;
    });
  }

  void _closeHistory() {
    setState(() {
      _isShowingHistory = false;
    });
  }

  void _openOrder(CustomerOrderReceipt order) {
    _viewModel.resumeOrder(order);
    _closeHistory();
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
          child: _isShowingHistory
              ? CustomerOrderHistoryPage(
                  key: const ValueKey<String>('customer-history'),
                  viewModel: _viewModel,
                  onBack: _closeHistory,
                  onOpenOrder: _openOrder,
                )
              : _buildCurrentStep(),
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
          onResumeOrder: _openOrder,
        );

      case 2:
        return CustomerServicePage(
          key: const ValueKey<int>(2),
          viewModel: _viewModel,
        );

      case 3:
        return CustomerNetworkPage(
          key: const ValueKey<int>(3),
          viewModel: _viewModel,
        );

      case 4:
        return CustomerOfferPage(
          key: const ValueKey<int>(4),
          viewModel: _viewModel,
          offerRepository: _offerRepository,
        );

      case 5:
        return CustomerBeneficiaryPage(
          key: const ValueKey<int>(5),
          viewModel: _viewModel,
        );

      case 6:
        return CustomerSummaryPage(
          key: const ValueKey<int>(6),
          viewModel: _viewModel,
        );

      case 7:
        return CustomerPaymentPage(
          key: const ValueKey<int>(7),
          viewModel: _viewModel,
        );

      case 8:
        return CustomerConfirmationPage(
          key: const ValueKey<int>(8),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
        );

      default:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onResumeOrder: _openOrder,
        );
    }
  }
}
