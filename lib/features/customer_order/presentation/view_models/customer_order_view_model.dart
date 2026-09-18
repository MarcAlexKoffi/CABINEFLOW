import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

class CustomerOrderViewModel extends ChangeNotifier {
  static const int totalSteps = 8;

  CustomerOrderViewModel({
    required CustomerOrderRepository orderRepository,
    CustomerOrderSessionStore? sessionStore,
  }) : _orderRepository = orderRepository,
       _sessionStore = sessionStore ?? _NoopCustomerOrderSessionStore();

  final CustomerOrderRepository _orderRepository;
  final CustomerOrderSessionStore _sessionStore;

  CustomerOrderDraft _draft = const CustomerOrderDraft();
  CustomerOrderReceipt? _receipt;
  int _currentStep = 1;
  bool _isSubmitting = false;
  bool _paymentLinkWasOpened = false;
  String? _submissionErrorMessage;
  String? _trackingErrorMessage;
  StreamSubscription<CustomerOrderReceipt>? _trackingSubscription;
  StreamSubscription<List<CustomerOrderReceipt>>? _historySubscription;
  Timer? _expirationTimer;
  List<CustomerOrderReceipt> _customerOrders = <CustomerOrderReceipt>[];
  CustomerOrderSession? _savedSession;
  bool _isLoadingHistory = false;
  bool _isHistoryInitialized = false;
  bool _hasAttemptedAutomaticRestore = false;
  String? _historyErrorMessage;
  bool _isRecoveringOrder = false;
  String? _recoveryErrorMessage;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

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
  bool get isRecoveringOrder => _isRecoveringOrder;
  String? get recoveryErrorMessage => _recoveryErrorMessage;
  static const int beneficiarySuggestionMinimumOrders = 2;

  List<BeneficiaryPhoneNumber> get suggestedBeneficiaryNumbers {
    final CustomerIdentity? identity = _draft.identity;
    final MobileNetwork? network = _draft.network;
    if (identity == null || network == null) {
      return const <BeneficiaryPhoneNumber>[];
    }

    final Map<String, int> counts = <String, int>{};
    final Map<String, BeneficiaryPhoneNumber> numbers =
        <String, BeneficiaryPhoneNumber>{};
    final Map<String, DateTime> lastUsedAt = <String, DateTime>{};

    for (final CustomerOrderReceipt order in _customerOrders) {
      final CustomerIdentity? orderIdentity = order.draft.identity;
      final BeneficiaryPhoneNumber? beneficiary = order.draft.beneficiaryNumber;
      if (orderIdentity == null ||
          beneficiary == null ||
          order.draft.network != network ||
          orderIdentity.whatsappNumber.normalized !=
              identity.whatsappNumber.normalized ||
          !_countsForBeneficiarySuggestion(order)) {
        continue;
      }

      final String key = beneficiary.normalized;
      counts[key] = (counts[key] ?? 0) + 1;
      numbers[key] = beneficiary;
      final DateTime? previousDate = lastUsedAt[key];
      if (previousDate == null || order.createdAt.isAfter(previousDate)) {
        lastUsedAt[key] = order.createdAt;
      }
    }

    final List<String> eligible = counts.keys
        .where(
          (String key) => counts[key]! >= beneficiarySuggestionMinimumOrders,
        )
        .toList(growable: false);
    eligible.sort((String first, String second) {
      final int byCount = counts[second]!.compareTo(counts[first]!);
      if (byCount != 0) {
        return byCount;
      }
      return lastUsedAt[second]!.compareTo(lastUsedAt[first]!);
    });

    return List<BeneficiaryPhoneNumber>.unmodifiable(
      eligible.map((String key) => numbers[key]!).take(3),
    );
  }

  bool _countsForBeneficiarySuggestion(CustomerOrderReceipt order) {
    if (order.status == QueueOrderStatus.cancelled ||
        order.status == QueueOrderStatus.expired) {
      return false;
    }

    return order.paymentStatus == OrderPaymentStatus.declared ||
        order.paymentStatus == OrderPaymentStatus.confirmed ||
        order.paymentStatus == OrderPaymentStatus.credit ||
        order.status == QueueOrderStatus.paidReady ||
        order.status == QueueOrderStatus.inProgress ||
        order.status == QueueOrderStatus.onHold ||
        order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        order.status == QueueOrderStatus.completed ||
        order.status == QueueOrderStatus.failed ||
        order.status == QueueOrderStatus.refundPending ||
        order.status == QueueOrderStatus.refunded;
  }

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
  }

  Future<void> reloadHistory() async {
    await _historySubscription?.cancel();
    _historySubscription = null;
    await _subscribeToHistory(readSavedSession: false);
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

    // Le document peut appartenir à l'UID anonyme d'un autre appareil.
    // Dans ce cas, la référence + le WhatsApp mémorisés localement permettent
    // de restaurer l'accès limité accordé par la Phase 10B.
    unawaited(_restoreRecoveredSession(session));
  }

  Future<void> _restoreRecoveredSession(CustomerOrderSession session) async {
    try {
      final CustomerOrderReceipt order = await _orderRepository.recoverOrder(
        reference: session.reference,
        whatsappInput: session.whatsappPhone,
      );
      if (_receipt != null) {
        return;
      }
      _applyRecoveredOrder(order, rememberLocally: false);
      _replaceOrderInHistory(order);
      notifyListeners();
    } on Object {
      // Une restauration automatique silencieuse ne doit pas afficher une
      // erreur au démarrage. Le client peut toujours ouvrir l'écran 10B.
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

  void _applyRecoveredOrder(
    CustomerOrderReceipt order, {
    required bool rememberLocally,
  }) {
    _receipt = order;
    _draft = order.draft;
    _submissionErrorMessage = null;
    _trackingErrorMessage = null;
    _paymentLinkWasOpened = false;

    // 10B donne un accès de suivi à la commande, pas le droit de modifier le
    // paiement d'une commande créée avec l'UID anonyme d'un autre appareil.
    _currentStep = 8;
    _startOrderTracking(order);

    if (rememberLocally) {
      unawaited(_rememberOrder(order));
    }
  }

  Future<bool> recoverOrder({
    required String reference,
    required String whatsappInput,
  }) async {
    if (_isRecoveringOrder) {
      return false;
    }

    _isRecoveringOrder = true;
    _recoveryErrorMessage = null;
    notifyListeners();

    try {
      final CustomerOrderReceipt recoveredOrder = await _orderRepository
          .recoverOrder(reference: reference, whatsappInput: whatsappInput);
      _applyRecoveredOrder(recoveredOrder, rememberLocally: true);
      _replaceOrderInHistory(recoveredOrder);
      return true;
    } on Object catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerOrder.recover',
        error,
        stackTrace: stackTrace,
      );
      // Toujours rester volontairement neutre : ne jamais révéler si la
      // référence existe avec un autre numéro WhatsApp.
      _recoveryErrorMessage =
          'Commande introuvable ou informations incorrectes. Vérifiez la référence et le numéro WhatsApp saisis.';
      return false;
    } finally {
      _isRecoveringOrder = false;
      notifyListeners();
    }
  }

  Future<bool> recoverOrderByDetails({
    required MobileNetwork network,
    required CustomerService service,
    required String beneficiaryInput,
  }) async {
    if (_isRecoveringOrder) {
      return false;
    }

    _isRecoveringOrder = true;
    _recoveryErrorMessage = null;
    notifyListeners();

    try {
      final CustomerOrderReceipt recoveredOrder = await _orderRepository
          .findCustomerOrder(
            network: network,
            service: service,
            beneficiaryInput: beneficiaryInput,
          );
      _applyResumedOrder(recoveredOrder, rememberLocally: true);
      _replaceOrderInHistory(recoveredOrder);
      return true;
    } on Object catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerOrder.recover-by-details',
        error,
        stackTrace: stackTrace,
      );
      _recoveryErrorMessage =
          'Commande introuvable. Vérifiez le réseau, le type de commande et le numéro bénéficiaire.';
      return false;
    } finally {
      _isRecoveringOrder = false;
      notifyListeners();
    }
  }

  void clearRecoveryError() {
    if (_recoveryErrorMessage == null) {
      return;
    }
    _recoveryErrorMessage = null;
    notifyListeners();
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

    _currentStep = _nextStepAfterIdentity();
    notifyListeners();
  }

  int _nextStepAfterIdentity() {
    if (_draft.service == null) {
      return 2;
    }
    if (_draft.network == null) {
      return 3;
    }
    if (!canContinueFromOffer) {
      return 4;
    }
    return 5;
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

  /// Garde la sélection en cours cohérente avec le catalogue temps réel.
  ///
  /// Une offre suspendue disparaît immédiatement de la sélection. Une offre
  /// modifiée (prix/libellé/détails) remplace la copie devenue obsolète avant
  /// que le client puisse poursuivre la commande.
  void reconcileCatalogOffers(List<CustomerOffer> offers) {
    final CustomerOffer? current = _draft.offer;
    if (current == null || _draft.usesCustomOffer) {
      return;
    }

    CustomerOffer? latest;
    for (final CustomerOffer offer in offers) {
      if (offer.id == current.id) {
        latest = offer;
        break;
      }
    }

    if (latest == null) {
      _draft = _draft.copyWith(clearOffer: true, clearAmount: true);
      notifyListeners();
      return;
    }

    final bool changed =
        current.network != latest.network ||
        current.type != latest.type ||
        current.title != latest.title ||
        current.catalogLabel != latest.catalogLabel ||
        current.amount != latest.amount ||
        current.badgeLabel != latest.badgeLabel ||
        !listEquals(current.details, latest.details);
    if (!changed) {
      return;
    }

    _draft = _draft.copyWith(
      offer: latest,
      amount: latest.amount,
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

  void selectSuggestedBeneficiary({
    required BeneficiaryPhoneNumber beneficiary,
    bool isPortabilityConfirmed = false,
  }) {
    if (!isPortabilityConfirmed &&
        _draft.network != null &&
        beneficiary.expectedNetwork != null &&
        beneficiary.expectedNetwork != _draft.network) {
      throw const FormatException('PORTABILITY_REQUIRED');
    }

    _draft = _draft.copyWith(beneficiaryNumber: beneficiary);
    _currentStep = 6;
    notifyListeners();
  }

  void saveBeneficiary({
    required String phoneInput,
    String? confirmationInput,
    bool isPortabilityConfirmed = false,
  }) {
    final BeneficiaryPhoneNumber beneficiary = BeneficiaryPhoneNumber.parse(
      phoneInput,
    );

    if (confirmationInput != null && confirmationInput.trim().isNotEmpty) {
      final BeneficiaryPhoneNumber confirmation = BeneficiaryPhoneNumber.parse(
        confirmationInput,
      );
      if (beneficiary.normalized != confirmation.normalized) {
        throw const FormatException(
          'Les deux numéros bénéficiaires ne correspondent pas.',
        );
      }
    }

    if (!isPortabilityConfirmed &&
        _draft.network != null &&
        beneficiary.expectedNetwork != null &&
        beneficiary.expectedNetwork != _draft.network) {
      throw const FormatException('PORTABILITY_REQUIRED');
    }

    _draft = _draft.copyWith(beneficiaryNumber: beneficiary);
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
      await _rememberOrder(createdOrder);
      _startOrderTracking(createdOrder);
      _currentStep = 7;
      return true;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerOrder.create',
        error,
        stackTrace: stackTrace,
      );

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
        order.paymentStatus != OrderPaymentStatus.credit &&
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

  /// Restores a previously visited step when the browser history moves back
  /// or forward. This does not replay business actions; it only restores the
  /// already-built local draft/navigation state.
  void restoreNavigationStep(int step) {
    if (step < 1 || step > totalSteps || step == _currentStep) {
      return;
    }

    _currentStep = step;
    notifyListeners();
  }

  void restart() {
    unawaited(_trackingSubscription?.cancel());
    _trackingSubscription = null;
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _draft = const CustomerOrderDraft();
    _receipt = null;
    _currentStep = 1;
    _isSubmitting = false;
    _paymentLinkWasOpened = false;
    _submissionErrorMessage = null;
    _trackingErrorMessage = null;
    _recoveryErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expirationTimer?.cancel();
    unawaited(_trackingSubscription?.cancel());
    unawaited(_historySubscription?.cancel());
    super.dispose();
  }

  bool get _isDraftComplete {
    return _draft.identity != null &&
        _draft.service != null &&
        _draft.network != null &&
        _draft.selectedOfferLabel != null &&
        _draft.beneficiaryNumber != null;
  }
}

class _NoopCustomerOrderSessionStore implements CustomerOrderSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<CustomerOrderSession?> read() async => null;

  @override
  Future<void> save(CustomerOrderSession session) async {}
}
