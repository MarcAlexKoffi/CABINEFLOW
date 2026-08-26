import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/order_event.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/services/order_expiration_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreCustomerOrderRepository implements CustomerOrderRepository {
  FirestoreCustomerOrderRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const Duration paymentValidity = Duration(hours: 6);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  Future<User>? _anonymousCustomerFuture;

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return _firestore.collection('orders');
  }

  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    return _firestore.collection('orderEvents');
  }

  @override
  Future<CustomerOrderReceipt> createOrder({
    required CustomerOrderDraft draft,
  }) async {
    _validateDraft(draft);

    final User customer = await _ensureAnonymousCustomer();
    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc();

    final DateTime now = DateTime.now();
    final DateTime expiresAt = now.add(paymentValidity);
    final String reference = _buildReference(
      date: now,
      documentId: document.id,
    );

    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.orderCreated;
    final Map<String, dynamic> orderData = _buildOrderData(
      draft: draft,
      customerUid: customer.uid,
      reference: reference,
      expiresAt: expiresAt,
    )..addAll(_auditLinkData(eventRef: eventRef, type: eventType));

    final WriteBatch batch = _firestore.batch();
    batch.set(document, orderData);
    batch.set(
      eventRef,
      _eventDocumentData(
        orderId: document.id,
        orderReference: reference,
        type: eventType,
        actorId: customer.uid,
        actorRole: 'customer',
        metadata: <String, dynamic>{
          'source': OrderSource.customerWeb.name,
          'network': draft.network!.name,
          'amount': draft.amount,
        },
      ),
    );
    await batch.commit();

    return CustomerOrderReceipt(
      id: document.id,
      reference: reference,
      draft: draft,
      createdAt: now,
      expiresAt: expiresAt,
      status: QueueOrderStatus.awaitingPayment,
      paymentStatus: OrderPaymentStatus.notDeclared,
    );
  }

  @override
  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderReceipt order,
    required PaymentDeclaration declaration,
  }) async {
    final User customer = await _ensureAnonymousCustomer();
    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc(order.id);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.paymentDeclared;
    final DateTime declaredAt = DateTime.now();

    return _firestore.runTransaction<CustomerOrderReceipt>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(document);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      if (data['customerAuthUid'] != customer.uid) {
        throw StateError('Vous ne pouvez pas modifier cette commande.');
      }

      final QueueOrderStatus currentStatus = _readOrderStatus(data['status']);
      final OrderPaymentStatus currentPaymentStatus = _readPaymentStatus(
        data['paymentStatus'],
      );

      if ((currentStatus == QueueOrderStatus.paymentToVerify ||
              currentStatus == QueueOrderStatus.expired) &&
          currentPaymentStatus == OrderPaymentStatus.declared) {
        return _receiptFromData(fallbackOrder: order, data: data);
      }

      final bool canDeclareBeforeExpiration =
          currentStatus == QueueOrderStatus.awaitingPayment &&
          currentPaymentStatus == OrderPaymentStatus.notDeclared;
      final bool canDeclareAfterExpiration =
          currentStatus == QueueOrderStatus.expired &&
          (currentPaymentStatus == OrderPaymentStatus.expired ||
              currentPaymentStatus == OrderPaymentStatus.notDeclared);

      if (!canDeclareBeforeExpiration && !canDeclareAfterExpiration) {
        throw StateError(
          'Le paiement de cette commande a déjà été déclaré ou son statut a changé.',
        );
      }

      final DateTime expiresAt =
          _readDate(data['expiresAt']) ?? order.expiresAt;
      final bool declaredAfterExpiration =
          currentStatus == QueueOrderStatus.expired ||
          !declaredAt.toUtc().isBefore(expiresAt.toUtc());
      final QueueOrderStatus nextStatus = declaredAfterExpiration
          ? QueueOrderStatus.expired
          : QueueOrderStatus.paymentToVerify;
      final Map<String, dynamic> update = <String, dynamic>{
        'status': nextStatus.name,
        'paymentStatus': OrderPaymentStatus.declared.name,
        'paymentDeclaredAt': FieldValue.serverTimestamp(),
        'paymentPayerName': declaration.waveAccountName,
        'paymentPayerPhone': declaration.wavePayerPhone.normalized,
        'paymentApproximateTime': declaration.approximatePaymentTime,
        'paymentDeclaredReference': declaration.declaredWaveReference,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      };

      if (declaredAfterExpiration && data['expiredAt'] == null) {
        update['expiredAt'] = FieldValue.serverTimestamp();
      }

      transaction.update(document, update);
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actorId: customer.uid,
          actorRole: 'customer',
        ),
      );

      return order.copyWith(
        status: nextStatus,
        paymentStatus: OrderPaymentStatus.declared,
        paymentDeclaredAt: declaredAt,
        paymentDeclaration: declaration,
        expiredAt: declaredAfterExpiration
            ? order.expiredAt ?? declaredAt
            : order.expiredAt,
      );
    });
  }

  @override
  Future<CustomerOrderReceipt> synchronizeExpiration({
    required CustomerOrderReceipt order,
  }) {
    return _synchronizeExpirationIfNeeded(order);
  }

  @override
  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  }) {
    return _ordersCollection.doc(order.id).snapshots().asyncMap((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande suivie est introuvable.');
      }

      final CustomerOrderReceipt currentOrder = _receiptFromData(
        fallbackOrder: order,
        data: data,
      );

      return _synchronizeExpirationIfNeeded(currentOrder);
    });
  }

  @override
  Stream<List<CustomerOrderReceipt>> watchCustomerOrders() async* {
    final User customer = await _ensureAnonymousCustomer();

    yield* _ordersCollection
        .where('customerAuthUid', isEqualTo: customer.uid)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<CustomerOrderReceipt> orders = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
                return _receiptFromDocument(
                  id: document.id,
                  data: document.data(),
                );
              })
              .whereType<CustomerOrderReceipt>()
              .toList();

          final List<CustomerOrderReceipt> synchronizedOrders =
              await Future.wait(orders.map(_synchronizeExpirationIfNeeded));

          synchronizedOrders.sort((
            CustomerOrderReceipt first,
            CustomerOrderReceipt second,
          ) {
            return second.createdAt.compareTo(first.createdAt);
          });

          return synchronizedOrders;
        });
  }

  Future<CustomerOrderReceipt> _synchronizeExpirationIfNeeded(
    CustomerOrderReceipt order,
  ) async {
    final DateTime now = DateTime.now();

    if (!OrderExpirationPolicy.shouldExpire(
      status: order.status,
      paymentStatus: order.paymentStatus,
      expiresAt: order.expiresAt,
      now: now,
    )) {
      return order;
    }

    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc(order.id);

    return _firestore.runTransaction<CustomerOrderReceipt>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(document);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande suivie est introuvable.');
      }

      final CustomerOrderReceipt currentOrder = _receiptFromData(
        fallbackOrder: order,
        data: data,
      );
      final DateTime transactionTime = DateTime.now();

      if (!OrderExpirationPolicy.shouldExpire(
        status: currentOrder.status,
        paymentStatus: currentOrder.paymentStatus,
        expiresAt: currentOrder.expiresAt,
        now: transactionTime,
      )) {
        return currentOrder;
      }

      final OrderPaymentStatus expiredPaymentStatus =
          OrderExpirationPolicy.paymentStatusAfterExpiration(
            currentOrder.paymentStatus,
          );

      transaction.update(document, <String, dynamic>{
        'status': QueueOrderStatus.expired.name,
        'paymentStatus': expiredPaymentStatus.name,
        'expiredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return currentOrder.copyWith(
        status: QueueOrderStatus.expired,
        paymentStatus: expiredPaymentStatus,
        expiredAt: transactionTime,
      );
    });
  }

  Future<User> _ensureAnonymousCustomer() {
    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser != null) {
      return Future<User>.value(currentUser);
    }

    // Plusieurs appels peuvent arriver presque simultanément au démarrage
    // (historique, création de commande, suivi). Ils doivent tous partager la
    // même tentative afin de ne jamais créer deux utilisateurs anonymes.
    return _anonymousCustomerFuture ??= _resolveAnonymousCustomer()
        .whenComplete(() {
          _anonymousCustomerFuture = null;
        });
  }

  Future<User> _resolveAnonymousCustomer() async {
    // Firebase Auth restaure sa session de façon asynchrone sur le Web. Il faut
    // attendre le premier état résolu avant de conclure qu'aucun client
    // anonyme n'existe encore.
    final User? restoredUser = await _firebaseAuth.authStateChanges().first;

    if (restoredUser != null) {
      return restoredUser;
    }

    final UserCredential credential = await _firebaseAuth.signInAnonymously();
    final User? signedInUser = credential.user;

    if (signedInUser == null) {
      throw StateError('Impossible de créer la session temporaire du client.');
    }

    return signedInUser;
  }

  Map<String, dynamic> _auditLinkData({
    required DocumentReference<Map<String, dynamic>> eventRef,
    required OrderEventType type,
  }) {
    return <String, dynamic>{
      'lastEventId': eventRef.id,
      'lastEventType': type.value,
      'lastEventAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _eventDocumentData({
    required String orderId,
    required String orderReference,
    required OrderEventType type,
    required String actorId,
    required String actorRole,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'orderId': orderId,
      'orderReference': orderReference,
      'type': type.value,
      'actorId': actorId,
      'actorRole': actorRole,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }

  Map<String, dynamic> _buildOrderData({
    required CustomerOrderDraft draft,
    required String customerUid,
    required String reference,
    required DateTime expiresAt,
  }) {
    final String offerLabel = draft.selectedOfferLabel!;

    return <String, dynamic>{
      'schemaVersion': 1,
      'reference': reference,
      'source': OrderSource.customerWeb.name,
      'customerAuthUid': customerUid,
      'clientName': draft.identity!.name,
      'clientWhatsappPhone': draft.identity!.whatsappNumber.normalized,
      'service': draft.service!.name,
      'network': draft.network!.name,
      'operationType': _operationTypeValue(draft),
      'offerId': draft.offer?.id,
      'offerLabel': offerLabel,
      'isCustomOffer': draft.usesCustomOffer,
      'amount': draft.amount,
      'beneficiaryPhone': draft.beneficiaryNumber!.normalized,
      'status': QueueOrderStatus.awaitingPayment.name,
      'paymentStatus': OrderPaymentStatus.notDeclared.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'paymentRequestSentAt': null,
      'paymentDeclaredAt': null,
      'paymentPayerName': null,
      'paymentPayerPhone': null,
      'paymentApproximateTime': null,
      'paymentDeclaredReference': null,
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
      'expiredAt': null,
      'paymentConfirmedAt': null,
      'paidAt': null,
      'paymentReference': null,
      'originalWhatsappMessage': null,
      'internalNotes': null,
      'takenByUserId': null,
      'takenAt': null,
      'completedAt': null,
      'failureReason': null,
      'observation': null,
      'customerConfirmationStatus': CustomerConfirmationStatus.pending.name,
      'customerConfirmationCompletedAt': null,
    };
  }

  CustomerOrderReceipt _receiptFromData({
    required CustomerOrderReceipt fallbackOrder,
    required Map<String, dynamic> data,
  }) {
    return _receiptFromDocument(id: fallbackOrder.id, data: data) ??
        fallbackOrder;
  }

  CustomerOrderReceipt? _receiptFromDocument({
    required String id,
    required Map<String, dynamic> data,
  }) {
    try {
      final CustomerService service = CustomerService.values.firstWhere(
        (CustomerService item) => item.name == data['service'],
      );
      final MobileNetwork network = MobileNetwork.values.firstWhere(
        (MobileNetwork item) => item.name == data['network'],
      );
      final String clientName = _readString(data['clientName'])!;
      final WhatsappPhoneNumber whatsappNumber = WhatsappPhoneNumber.parse(
        _readString(data['clientWhatsappPhone'])!,
      );
      final BeneficiaryPhoneNumber beneficiaryNumber =
          BeneficiaryPhoneNumber.parse(_readString(data['beneficiaryPhone'])!);
      final String offerLabel =
          _readString(data['offerLabel']) ?? service.label;
      final int amount = _readInt(data['amount']);
      final DateTime createdAt = _readDate(data['createdAt']) ?? DateTime.now();
      final DateTime expiresAt =
          _readDate(data['expiresAt']) ?? createdAt.add(paymentValidity);
      final String? failureReason = _readNullableString(data['failureReason']);
      final String? observation = _readNullableString(data['observation']);

      final CustomerOrderDraft draft = CustomerOrderDraft(
        identity: CustomerIdentity(
          name: clientName,
          whatsappNumber: whatsappNumber,
        ),
        service: service,
        network: network,
        customOfferLabel: service == CustomerService.unitTransfer
            ? null
            : offerLabel,
        amount: amount,
        beneficiaryNumber: beneficiaryNumber,
      );

      return CustomerOrderReceipt(
        id: id,
        reference: _readString(data['reference']) ?? id,
        draft: draft,
        createdAt: createdAt,
        expiresAt: expiresAt,
        paymentDeclaredAt: _readDate(data['paymentDeclaredAt']),
        paymentDeclaration: _readPaymentDeclaration(data),
        paymentConfirmedAt: _readDate(data['paymentConfirmedAt']),
        expiredAt: _readDate(data['expiredAt']),
        processingStartedAt: _readDate(data['takenAt']),
        completedAt: _readDate(data['completedAt']),
        status: _readOrderStatus(data['status']),
        paymentStatus: _readPaymentStatus(data['paymentStatus']),
        failureMessage: observation ?? failureReason,
      );
    } on Object {
      return null;
    }
  }

  PaymentDeclaration? _readPaymentDeclaration(Map<String, dynamic> data) {
    final String? payerName = _readNullableString(data['paymentPayerName']);
    final String? payerPhone = _readNullableString(data['paymentPayerPhone']);
    final String? approximateTime = _readNullableString(
      data['paymentApproximateTime'],
    );

    if (payerName == null || payerPhone == null || approximateTime == null) {
      return null;
    }

    try {
      return PaymentDeclaration.parse(
        waveAccountName: payerName,
        wavePayerPhoneInput: payerPhone,
        approximatePaymentTime: approximateTime,
        declaredWaveReference: _readNullableString(
          data['paymentDeclaredReference'],
        ),
      );
    } on FormatException {
      return null;
    }
  }

  String _operationTypeValue(CustomerOrderDraft draft) {
    switch (draft.service!) {
      case CustomerService.unitTransfer:
        return OrderOperationType.unitTransfer.name;

      case CustomerService.internetSubscription:
        return OrderOperationType.internetSubscription.name;

      case CustomerService.calls:
        final bool isMixedOffer =
            draft.offer?.badgeLabel?.toLowerCase() == 'mixte';

        return isMixedOffer
            ? OrderOperationType.mixedBundle.name
            : OrderOperationType.callBundle.name;
    }
  }

  QueueOrderStatus _readOrderStatus(Object? value) {
    return QueueOrderStatus.values.firstWhere(
      (QueueOrderStatus item) => item.name == value,
      orElse: () => QueueOrderStatus.awaitingPayment,
    );
  }

  OrderPaymentStatus _readPaymentStatus(Object? value) {
    return OrderPaymentStatus.values.firstWhere(
      (OrderPaymentStatus item) => item.name == value,
      orElse: () => OrderPaymentStatus.notDeclared,
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  String? _readString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String? _readNullableString(Object? value) {
    return _readString(value);
  }

  String _buildReference({required DateTime date, required String documentId}) {
    final DateTime localDate = date.toLocal();
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    final String cleanedId = documentId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final String suffix = cleanedId
        .substring(0, cleanedId.length < 6 ? cleanedId.length : 6)
        .toUpperCase();

    return 'CF-$year$month$day-$suffix';
  }

  void _validateDraft(CustomerOrderDraft draft) {
    if (draft.identity == null ||
        draft.identity!.name.trim().length < 2 ||
        draft.service == null ||
        draft.network == null ||
        draft.selectedOfferLabel == null ||
        (draft.amount ?? 0) <= 0 ||
        draft.beneficiaryNumber == null) {
      throw StateError('La commande est incomplète. Revenez au récapitulatif.');
    }
  }
}
