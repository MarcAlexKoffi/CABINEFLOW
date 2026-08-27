import 'dart:async';

import 'package:cabine_flow/features/customer_order/data/local/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_beneficiary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_confirmation_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_identification_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_network_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_offer_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_history_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_recovery_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_payment_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_service_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_summary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class CustomerOrderFlowPage extends StatefulWidget {
  const CustomerOrderFlowPage({super.key, this.offerRepository});

  final CustomerOfferRepository? offerRepository;

  @override
  State<CustomerOrderFlowPage> createState() {
    return _CustomerOrderFlowPageState();
  }
}

class _CustomerOrderFlowPageState extends State<CustomerOrderFlowPage> {
  late final CustomerOrderViewModel _viewModel;
  bool _isShowingHistory = false;
  bool _isShowingRecovery = false;

  late final CustomerOfferRepository _offerRepository;
  late final CustomerProfileRepository _profileRepository;
  late final SupportRequestRepository _supportRequestRepository;

  final CustomerOrderRepository _orderRepository =
      FirestoreCustomerOrderRepository();

  final CustomerOrderSessionStore _sessionStore =
      BrowserCustomerOrderSessionStore();

  @override
  void initState() {
    super.initState();
    _offerRepository =
        widget.offerRepository ??
        (Firebase.apps.isNotEmpty
            ? FirestoreCustomerOfferRepository()
            : const FakeCustomerOfferRepository());
    _profileRepository = Firebase.apps.isNotEmpty
        ? FirestoreCustomerProfileRepository()
        : FakeCustomerProfileRepository();
    _supportRequestRepository = Firebase.apps.isNotEmpty
        ? FirestoreSupportRequestRepository()
        : FakeSupportRequestRepository();
    _viewModel = CustomerOrderViewModel(
      orderRepository: _orderRepository,
      sessionStore: _sessionStore,
      profileRepository: _profileRepository,
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

  void _openRecovery() {
    _viewModel.clearRecoveryError();
    setState(() {
      _isShowingRecovery = true;
    });
  }

  void _closeRecovery() {
    setState(() {
      _isShowingRecovery = false;
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
          child: _isShowingRecovery
              ? CustomerOrderRecoveryPage(
                  key: const ValueKey<String>('customer-recovery'),
                  viewModel: _viewModel,
                  onBack: _closeRecovery,
                  onRecovered: _closeRecovery,
                )
              : _isShowingHistory
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
          onOpenRecovery: _openRecovery,
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
          supportRequestRepository: _supportRequestRepository,
        );

      default:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onOpenRecovery: _openRecovery,
          onResumeOrder: _openOrder,
        );
    }
  }
}
