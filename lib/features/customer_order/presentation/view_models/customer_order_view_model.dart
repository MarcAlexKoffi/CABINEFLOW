import 'dart:async';

import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_beneficiary_target.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_profile.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

class CustomerOrderViewModel extends ChangeNotifier {
  static const int totalSteps = 8;

  CustomerOrderViewModel({
    required CustomerOrderRepository orderRepository,
    CustomerOrderSessionStore? sessionStore,
    CustomerProfileRepository? profileRepository,
  }) : _orderRepository = orderRepository,
       _sessionStore = sessionStore ?? _NoopCustomerOrderSessionStore(),
       _profileRepository =
           profileRepository ?? _NoopCustomerProfileRepository();

  final CustomerOrderRepository _orderRepository;
  final CustomerOrderSessionStore _sessionStore;
  final CustomerProfileRepository _profileRepository;

  CustomerOrderDraft _draft = const CustomerOrderDraft();
  CustomerOrderReceipt? _receipt;
  int _currentStep = 1;
  bool _isSubmitting = false;
  bool _paymentLinkWasOpened = false;
  String? _submissionErrorMessage;
  String? _trackingErrorMessage;
  StreamSubscription<CustomerOrderReceipt>? _trackingSubscription;
  StreamSubscription<List<CustomerOrderReceipt>>? _historySubscription;
  StreamSubscription<CustomerProfile?>? _profileSubscription;
  Timer? _expirationTimer;
  List<CustomerOrderReceipt> _customerOrders = <CustomerOrderReceipt>[];
  CustomerOrderSession? _savedSession;
  bool _isLoadingHistory = false;
  bool _isHistoryInitialized = false;
  bool _hasAttemptedAutomaticRestore = false;
  String? _historyErrorMessage;
  CustomerProfile? _customerProfile;
  CustomerBeneficiaryTarget _beneficiaryTarget = CustomerBeneficiaryTarget.self;
  bool _isLoadingCustomerProfile = false;
  String? _customerProfileErrorMessage;

  CustomerOrderDraft get draft => _draft;
  CustomerOrderReceipt? get receipt => _receipt;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  bool get paymentLinkWasOpened => _paymentLinkWasOpened;
  bool get hasCreatedOrder => _receipt != null;
  String? get submissionErrorMessage => _submissionErrorMessage;
  String? get trackingErrorMessage => _trackingErrorMessage;
  List<CustomerOrderReceipt> get customerOrders =>
      List<CustomerOrderReceipt>.unmodifiable(_customerOrders);
  bool get isLoadingHistory => _isLoadingHistory;
  String? get historyErrorMessage => _historyErrorMessage;
  CustomerBeneficiaryTarget get beneficiaryTarget => _beneficiaryTarget;
  bool get isLoadingCustomerProfile => _isLoadingCustomerProfile;
  String? get customerProfileErrorMessage => _customerProfileErrorMessage;

  BeneficiaryPhoneNumber? get defaultBeneficiaryNumber {
    final CustomerIdentity? identity = _draft.identity;
    final CustomerProfile? profile = _customerProfile;

    if (identity == null ||
        profile == null ||
        !profile.matchesIdentity(identity)) {
      return null;
    }

    return profile.defaultBeneficiaryPhone;
  }

  bool get hasDefaultBeneficiaryForCurrentIdentity =>
      defaultBeneficiaryNumber != null;

  CustomerOrderReceipt? get activeOrder {
    final CustomerOrderSession? session = _savedSession;

    if (session != null) {
      for (final CustomerOrderReceipt order in _customerOrders) {
        if (order.id == session.orderId && _isResumableOrder(order)) {
          return order;
        }
      }
    }

    for (final CustomerOrderReceipt order in _customerOrders) {
      if (_isActiveOrder(order)) {
        return order;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    if (_isHistoryInitialized) {
      return;
    }

    _isHistoryInitialized = true;
    await _subscribeToHistory(readSavedSession: true);
    await _subscribeToCustomerProfile();
  }

  Future<void> reloadHistory() async {
    await _historySubscription?.cancel();
    _historySubscription = null;
    await _subscribeToHistory(readSavedSession: false);
  }

  Future<void> _subscribeToCustomerProfile() async {
    _isLoadingCustomerProfile = true;
    _customerProfileErrorMessage = null;
    notifyListeners();

    try {
      await _profileSubscription?.cancel();
      _profileSubscription = _profileRepository.watchCurrentProfile().listen(
        (CustomerProfile? profile) {
          _customerProfile = profile;
          _isLoadingCustomerProfile = false;
          _customerProfileErrorMessage = null;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[CustomerProfile][watch] ERROR $error');
          debugPrint('[CustomerProfile][watch] STACK:\n$stackTrace');
          _customerProfile = null;
          _isLoadingCustomerProfile = false;
          _customerProfileErrorMessage =
              'Votre numéro habituel n’a pas pu être chargé. Vous pouvez le saisir ci-dessous.';
          notifyListeners();
        },
      );
    } on Object catch (error, stackTrace) {
      debugPrint('[CustomerProfile][watch] ERROR $error');
      debugPrint('[CustomerProfile][watch] STACK:\n$stackTrace');
      _customerProfile = null;
      _isLoadingCustomerProfile = false;
      _customerProfileErrorMessage =
          'Votre numéro habituel n’a pas pu être chargé. Vous pouvez le saisir ci-dessous.';
      notifyListeners();
    }
  }

  Future<void> _subscribeToHistory({required bool readSavedSession}) async {
    _isLoadingHistory = true;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      if (readSavedSession) {
        _savedSession = await _sessionStore.read();
      }

      _historySubscription = _orderRepository.watchCustomerOrders().listen(
        (List<CustomerOrderReceipt> orders) {
          _customerOrders = List<CustomerOrderReceipt>.of(orders);
          _isLoadingHistory = false;
          _historyErrorMessage = null;

          final CustomerOrderReceipt? currentOrder = _receipt;
          if (currentOrder != null) {
            for (final CustomerOrderReceipt order in orders) {
              if (order.id == currentOrder.id) {
                _receipt = order;
                _draft = order.draft;
                break;
              }
            }
          } else {
            _restoreSavedActiveOrderOnce(orders);
          }

          notifyListeners();
        },
        onError: (Object error) {
          _isLoadingHistory = false;
          _historyErrorMessage =
              'Impossible de charger vos commandes pour le moment.';
          notifyListeners();
        },
      );
    } on Object {
      _isLoadingHistory = false;
      _historyErrorMessage = 'Impossible de restaurer votre dernière commande.';
      notifyListeners();
    }
  }

  void resumeOrder(CustomerOrderReceipt order) {
    _applyResumedOrder(order, rememberLocally: true);
    notifyListeners();
  }

  void _restoreSavedActiveOrderOnce(List<CustomerOrderReceipt> orders) {
    if (_hasAttemptedAutomaticRestore) {
      return;
    }

    _hasAttemptedAutomaticRestore = true;
    final CustomerOrderSession? session = _savedSession;

    if (session == null) {
      return;
    }

    for (final CustomerOrderReceipt order in orders) {
      if (order.id == session.orderId && _isResumableOrder(order)) {
        _applyResumedOrder(order, rememberLocally: false);
        return;
      }
    }
  }

  void _applyResumedOrder(
    CustomerOrderReceipt order, {
    required bool rememberLocally,
  }) {
    _receipt = order;
    _draft = order.draft;
    _submissionErrorMessage = null;
    _trackingErrorMessage = null;
    final bool canStillDeclarePayment =
        (order.status == QueueOrderStatus.awaitingPayment &&
            order.paymentStatus == OrderPaymentStatus.notDeclared) ||
        (order.status == QueueOrderStatus.expired &&
            (order.paymentStatus == OrderPaymentStatus.expired ||
                order.paymentStatus == OrderPaymentStatus.notDeclared));
    _paymentLinkWasOpened = canStillDeclarePayment;
    _currentStep = canStillDeclarePayment ? 7 : 8;
    _startOrderTracking(order);

    if (rememberLocally) {
      unawaited(_rememberOrder(order));
    }
  }

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
    final String? previousWhatsapp = _draft.identity?.whatsappNumber.normalized;
    final bool identityChanged =
        previousWhatsapp != null &&
        previousWhatsapp != whatsappNumber.normalized;

    _draft = _draft.copyWith(
      identity: CustomerIdentity(
        name: name.trim(),
        whatsappNumber: whatsappNumber,
      ),
      clearBeneficiaryNumber: identityChanged,
    );

    if (identityChanged) {
      _beneficiaryTarget = CustomerBeneficiaryTarget.self;
    }

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

  void selectBeneficiaryTarget(CustomerBeneficiaryTarget target) {
    if (_beneficiaryTarget == target) {
      return;
    }

    _beneficiaryTarget = target;
    _draft = _draft.copyWith(clearBeneficiaryNumber: true);
    notifyListeners();
  }

  void useSavedBeneficiaryForMe() {
    final BeneficiaryPhoneNumber? beneficiary = defaultBeneficiaryNumber;

    if (beneficiary == null) {
      return;
    }

    _beneficiaryTarget = CustomerBeneficiaryTarget.self;
    _draft = _draft.copyWith(beneficiaryNumber: beneficiary);
    _currentStep = 6;
    notifyListeners();
  }

  void saveBeneficiaryForMe({
    required String phoneInput,
    required String confirmationInput,
  }) {
    final BeneficiaryPhoneNumber beneficiary = _parseConfirmedBeneficiary(
      phoneInput: phoneInput,
      confirmationInput: confirmationInput,
    );
    final CustomerIdentity? identity = _draft.identity;

    if (identity == null) {
      throw StateError(
        'Identifiez-vous avant de choisir votre numéro habituel.',
      );
    }

    _beneficiaryTarget = CustomerBeneficiaryTarget.self;
    _draft = _draft.copyWith(beneficiaryNumber: beneficiary);
    _customerProfile = CustomerProfile(
      name: identity.name,
      whatsappPhone: identity.whatsappNumber,
      defaultBeneficiaryPhone: beneficiary,
    );
    _currentStep = 6;
    notifyListeners();

    unawaited(
      _persistDefaultBeneficiary(identity: identity, beneficiary: beneficiary),
    );
  }

  void saveBeneficiary({
    required String phoneInput,
    required String confirmationInput,
  }) {
    final BeneficiaryPhoneNumber beneficiary = _parseConfirmedBeneficiary(
      phoneInput: phoneInput,
      confirmationInput: confirmationInput,
    );

    _beneficiaryTarget = CustomerBeneficiaryTarget.other;
    _draft = _draft.copyWith(beneficiaryNumber: beneficiary);
    _currentStep = 6;
    notifyListeners();
  }

  BeneficiaryPhoneNumber _parseConfirmedBeneficiary({
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

    return beneficiaryNumber;
  }

  Future<void> _persistDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiary,
  }) async {
    try {
      await _profileRepository.saveDefaultBeneficiary(
        identity: identity,
        beneficiaryPhone: beneficiary,
      );
      _customerProfileErrorMessage = null;
    } on Object catch (error, stackTrace) {
      // La mémorisation est un confort : une erreur ne doit jamais bloquer la
      // commande qui contient déjà le bon beneficiaryPhone dans le brouillon.
      debugPrint('[CustomerProfile][save] ERROR $error');
      debugPrint('[CustomerProfile][save] STACK:\n$stackTrace');
      _customerProfileErrorMessage =
          'Votre commande peut continuer, mais le numéro habituel n’a pas pu être mémorisé.';
    }

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
      await _rememberOrder(createdOrder);
      _startOrderTracking(createdOrder);
      _currentStep = 7;
      return true;
    } catch (error, stackTrace) {
      debugPrint('[CustomerOrder][create] ERROR type=${error.runtimeType}');
      debugPrint('[CustomerOrder][create] ERROR $error');
      debugPrint('[CustomerOrder][create] STACK:\n$stackTrace');

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
    _scheduleExpiration(order);

    _trackingSubscription = _orderRepository
        .watchOrder(order: order)
        .listen(
          (CustomerOrderReceipt updatedOrder) {
            _receipt = updatedOrder;
            _draft = updatedOrder.draft;
            _trackingErrorMessage = null;

            if (updatedOrder.status == QueueOrderStatus.expired &&
                updatedOrder.paymentStatus == OrderPaymentStatus.declared) {
              _currentStep = 8;
            }

            _scheduleExpiration(updatedOrder);
            _replaceOrderInHistory(updatedOrder);
            notifyListeners();
          },
          onError: (Object error) {
            _trackingErrorMessage =
                'Le suivi en temps réel est momentanément indisponible.';
            notifyListeners();
          },
        );
  }

  void _scheduleExpiration(CustomerOrderReceipt order) {
    _expirationTimer?.cancel();
    _expirationTimer = null;

    final bool canExpire =
        order.paymentStatus != OrderPaymentStatus.confirmed &&
        (order.status == QueueOrderStatus.awaitingPayment ||
            order.status == QueueOrderStatus.paymentToVerify);

    if (!canExpire) {
      return;
    }

    final Duration remaining = order.expiresAt.toUtc().difference(
      DateTime.now().toUtc(),
    );

    if (remaining <= Duration.zero) {
      unawaited(_synchronizeCurrentOrderExpiration(order));
      return;
    }

    _expirationTimer = Timer(remaining, () {
      unawaited(_synchronizeCurrentOrderExpiration(order));
    });
  }

  Future<void> _synchronizeCurrentOrderExpiration(
    CustomerOrderReceipt order,
  ) async {
    try {
      final CustomerOrderReceipt synchronizedOrder = await _orderRepository
          .synchronizeExpiration(order: order);

      if (_receipt?.id != synchronizedOrder.id) {
        return;
      }

      _receipt = synchronizedOrder;
      _draft = synchronizedOrder.draft;

      if (synchronizedOrder.status == QueueOrderStatus.expired &&
          synchronizedOrder.paymentStatus == OrderPaymentStatus.declared) {
        _currentStep = 8;
      }

      _replaceOrderInHistory(synchronizedOrder);
      notifyListeners();
    } on Object {
      _trackingErrorMessage =
          'Impossible d’actualiser automatiquement l’expiration.';
      notifyListeners();
    }
  }

  Future<void> _rememberOrder(CustomerOrderReceipt order) async {
    final CustomerOrderSession session = CustomerOrderSession(
      orderId: order.id,
      reference: order.reference,
      whatsappPhone: order.draft.identity!.whatsappNumber.normalized,
    );

    _savedSession = session;

    try {
      await _sessionStore.save(session);
    } on Object {
      // Firestore remains the source of truth if browser storage is unavailable.
    }
  }

  void _replaceOrderInHistory(CustomerOrderReceipt updatedOrder) {
    final int index = _customerOrders.indexWhere(
      (CustomerOrderReceipt order) => order.id == updatedOrder.id,
    );

    if (index < 0) {
      _customerOrders = <CustomerOrderReceipt>[
        updatedOrder,
        ..._customerOrders,
      ];
    } else {
      final List<CustomerOrderReceipt> updatedOrders =
          List<CustomerOrderReceipt>.of(_customerOrders);
      updatedOrders[index] = updatedOrder;
      _customerOrders = updatedOrders;
    }

    _customerOrders.sort(
      (CustomerOrderReceipt first, CustomerOrderReceipt second) =>
          second.createdAt.compareTo(first.createdAt),
    );
  }

  bool _isActiveOrder(CustomerOrderReceipt order) {
    switch (order.status) {
      case QueueOrderStatus.awaitingPayment:
      case QueueOrderStatus.paymentToVerify:
      case QueueOrderStatus.paidReady:
      case QueueOrderStatus.inProgress:
      case QueueOrderStatus.onHold:
      case QueueOrderStatus.awaitingCustomerConfirmation:
      case QueueOrderStatus.refundPending:
        return true;
      case QueueOrderStatus.expired:
      case QueueOrderStatus.completed:
      case QueueOrderStatus.failed:
      case QueueOrderStatus.cancelled:
      case QueueOrderStatus.refunded:
        return false;
    }
  }

  bool _isResumableOrder(CustomerOrderReceipt order) {
    return _isActiveOrder(order) || order.status == QueueOrderStatus.expired;
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
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _draft = const CustomerOrderDraft();
    _receipt = null;
    _beneficiaryTarget = CustomerBeneficiaryTarget.self;
    _currentStep = 1;
    _isSubmitting = false;
    _paymentLinkWasOpened = false;
    _submissionErrorMessage = null;
    _trackingErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    unawaited(_trackingSubscription?.cancel());
    unawaited(_historySubscription?.cancel());
    unawaited(_profileSubscription?.cancel());
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

class _NoopCustomerProfileRepository implements CustomerProfileRepository {
  @override
  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  }) async {}

  @override
  Stream<CustomerProfile?> watchCurrentProfile() =>
      Stream<CustomerProfile?>.value(null);
}

class _NoopCustomerOrderSessionStore implements CustomerOrderSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<CustomerOrderSession?> read() async => null;

  @override
  Future<void> save(CustomerOrderSession session) async {}
}
