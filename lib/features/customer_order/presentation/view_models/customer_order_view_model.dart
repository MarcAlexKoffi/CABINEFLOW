import 'dart:async';

import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

class CustomerOrderViewModel extends ChangeNotifier {
  static const int totalSteps = 8;

  CustomerOrderViewModel({required CustomerOrderRepository orderRepository})
    : _orderRepository = orderRepository;

  final CustomerOrderRepository _orderRepository;

  CustomerOrderDraft _draft = const CustomerOrderDraft();
  CustomerOrderReceipt? _receipt;
  int _currentStep = 1;
  bool _isSubmitting = false;
  bool _paymentLinkWasOpened = false;
  String? _submissionErrorMessage;
  String? _trackingErrorMessage;
  StreamSubscription<CustomerOrderReceipt>? _trackingSubscription;

  CustomerOrderDraft get draft => _draft;
  CustomerOrderReceipt? get receipt => _receipt;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  bool get paymentLinkWasOpened => _paymentLinkWasOpened;
  bool get hasCreatedOrder => _receipt != null;
  String? get submissionErrorMessage => _submissionErrorMessage;
  String? get trackingErrorMessage => _trackingErrorMessage;

  bool get canGoBack => _currentStep > 1 && _currentStep < 8;
  bool get canContinueFromService => _draft.service != null;
  bool get canContinueFromNetwork => _draft.network != null;
  bool get canContinueFromBeneficiary => _draft.beneficiaryNumber != null;
  bool get isUsingCustomOffer => _draft.usesCustomOffer;

  bool get canContinueFromOffer {
    switch (_draft.service) {
      case CustomerService.unitTransfer:
        return (_draft.amount ?? 0) > 0;

      case CustomerService.internetSubscription:
      case CustomerService.calls:
        if (_draft.usesCustomOffer) {
          return (_draft.customOfferLabel?.trim().length ?? 0) >= 3 &&
              (_draft.amount ?? 0) > 0;
        }

        return _draft.offer != null && _draft.amount == _draft.offer!.amount;

      case null:
        return false;
    }
  }

  void saveIdentity({required String name, required String whatsappInput}) {
    final WhatsappPhoneNumber whatsappNumber = WhatsappPhoneNumber.parse(
      whatsappInput,
    );

    _draft = _draft.copyWith(
      identity: CustomerIdentity(
        name: name.trim(),
        whatsappNumber: whatsappNumber,
      ),
    );

    _currentStep = 2;
    notifyListeners();
  }

  void selectService(CustomerService service) {
    if (_draft.service == service) {
      return;
    }

    _draft = _draft.copyWith(
      service: service,
      clearNetwork: true,
      clearOffer: true,
      clearCustomOfferLabel: true,
      clearAmount: true,
      clearBeneficiaryNumber: true,
    );
    notifyListeners();
  }

  void continueFromService() {
    if (!canContinueFromService) {
      return;
    }

    _currentStep = 3;
    notifyListeners();
  }

  void selectNetwork(MobileNetwork network) {
    if (_draft.network == network) {
      return;
    }

    _draft = _draft.copyWith(
      network: network,
      clearOffer: true,
      clearCustomOfferLabel: true,
      clearAmount: true,
      clearBeneficiaryNumber: true,
    );
    notifyListeners();
  }

  void continueFromNetwork() {
    if (!canContinueFromNetwork) {
      return;
    }

    _currentStep = 4;
    notifyListeners();
  }

  void setTransferAmount(int? amount) {
    if (_draft.service != CustomerService.unitTransfer) {
      return;
    }

    if (_draft.amount == amount &&
        _draft.offer == null &&
        !_draft.usesCustomOffer) {
      return;
    }

    _draft = _draft.copyWith(
      amount: amount,
      clearAmount: amount == null,
      clearOffer: true,
      clearCustomOfferLabel: true,
    );
    notifyListeners();
  }

  void useCustomOffer({String label = '', int? amount}) {
    if (_draft.service == CustomerService.unitTransfer ||
        _draft.service == null ||
        _draft.network == null) {
      return;
    }

    _draft = _draft.copyWith(
      customOfferLabel: label,
      amount: amount,
      clearAmount: amount == null,
      clearOffer: true,
    );
    notifyListeners();
  }

  void updateCustomOffer({required String label, required int? amount}) {
    if (_draft.service == CustomerService.unitTransfer ||
        !_draft.usesCustomOffer) {
      return;
    }

    final String normalizedLabel = label.replaceAll(RegExp(r'\s+'), ' ');

    if (_draft.customOfferLabel == normalizedLabel && _draft.amount == amount) {
      return;
    }

    _draft = _draft.copyWith(
      customOfferLabel: normalizedLabel,
      amount: amount,
      clearAmount: amount == null,
      clearOffer: true,
    );
    notifyListeners();
  }

  void selectOffer(CustomerOffer offer) {
    final CustomerService? service = _draft.service;
    final MobileNetwork? network = _draft.network;

    if (service == null || network == null) {
      return;
    }

    final CustomerOfferType? expectedType = switch (service) {
      CustomerService.internetSubscription => CustomerOfferType.internet,
      CustomerService.calls => CustomerOfferType.calls,
      CustomerService.unitTransfer => null,
    };

    if (expectedType == null) {
      return;
    }

    if (offer.network != network || offer.type != expectedType) {
      return;
    }

    if (_draft.offer?.id == offer.id &&
        _draft.amount == offer.amount &&
        !_draft.usesCustomOffer) {
      return;
    }

    _draft = _draft.copyWith(
      offer: offer,
      amount: offer.amount,
      clearCustomOfferLabel: true,
    );
    notifyListeners();
  }

  void continueFromOffer() {
    if (!canContinueFromOffer) {
      return;
    }

    _currentStep = 5;
    notifyListeners();
  }

  void saveBeneficiary({
    required String phoneInput,
    required String confirmationInput,
  }) {
    final BeneficiaryPhoneNumber beneficiaryNumber =
        BeneficiaryPhoneNumber.parse(phoneInput);

    final BeneficiaryPhoneNumber confirmationNumber =
        BeneficiaryPhoneNumber.parse(confirmationInput);

    if (beneficiaryNumber.normalized != confirmationNumber.normalized) {
      throw const FormatException(
        'Les deux numéros bénéficiaires ne correspondent pas.',
      );
    }

    _draft = _draft.copyWith(beneficiaryNumber: beneficiaryNumber);

    _currentStep = 6;
    notifyListeners();
  }

  Future<bool> createOrderAndContinueToPayment() async {
    if (_isSubmitting || !_isDraftComplete) {
      return false;
    }

    if (_receipt != null) {
      _submissionErrorMessage = null;
      _currentStep = 7;
      notifyListeners();
      return true;
    }

    _isSubmitting = true;
    _submissionErrorMessage = null;
    notifyListeners();

    try {
      final CustomerOrderReceipt createdOrder = await _orderRepository
          .createOrder(draft: _draft);
      _receipt = createdOrder;
      _startOrderTracking(createdOrder);
      _currentStep = 7;
      return true;
    } catch (error) {
      _submissionErrorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible de créer la commande avant le paiement.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void markPaymentLinkOpened() {
    if (_paymentLinkWasOpened) {
      return;
    }

    _paymentLinkWasOpened = true;
    notifyListeners();
  }

  Future<bool> declarePayment({
    required String waveAccountName,
    required String wavePayerPhoneInput,
    required String approximatePaymentTime,
    String? declaredWaveReference,
  }) async {
    final CustomerOrderReceipt? currentOrder = _receipt;

    if (_isSubmitting || currentOrder == null) {
      return false;
    }

    if (currentOrder.isPaymentDeclared) {
      _currentStep = 8;
      notifyListeners();
      return true;
    }

    _isSubmitting = true;
    _submissionErrorMessage = null;
    notifyListeners();

    try {
      final PaymentDeclaration declaration = PaymentDeclaration.parse(
        waveAccountName: waveAccountName,
        wavePayerPhoneInput: wavePayerPhoneInput,
        approximatePaymentTime: approximatePaymentTime,
        declaredWaveReference: declaredWaveReference,
      );

      _receipt = await _orderRepository.declarePayment(
        order: currentOrder,
        declaration: declaration,
      );
      _currentStep = 8;
      return true;
    } catch (error) {
      _submissionErrorMessage = switch (error) {
        FormatException exception => exception.message.toString(),
        StateError exception => exception.message.toString(),
        _ => 'Impossible d’enregistrer la déclaration de paiement.',
      };
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _startOrderTracking(CustomerOrderReceipt order) {
    unawaited(_trackingSubscription?.cancel());
    _trackingErrorMessage = null;

    _trackingSubscription = _orderRepository.watchOrder(order: order).listen(
      (CustomerOrderReceipt updatedOrder) {
        _receipt = updatedOrder;
        _trackingErrorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _trackingErrorMessage =
            'Le suivi en temps réel est momentanément indisponible.';
        notifyListeners();
      },
    );
  }

  void goBack() {
    if (!canGoBack) {
      return;
    }

    _currentStep--;
    notifyListeners();
  }

  void restart() {
    unawaited(_trackingSubscription?.cancel());
    _trackingSubscription = null;
    _draft = const CustomerOrderDraft();
    _receipt = null;
    _currentStep = 1;
    _isSubmitting = false;
    _paymentLinkWasOpened = false;
    _submissionErrorMessage = null;
    _trackingErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_trackingSubscription?.cancel());
    super.dispose();
  }

  bool get _isDraftComplete {
    return _draft.identity != null &&
        _draft.service != null &&
        _draft.network != null &&
        _draft.selectedOfferLabel != null &&
        (_draft.amount ?? 0) > 0 &&
        _draft.beneficiaryNumber != null;
  }
}
