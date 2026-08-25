import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/services/order_expiration_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOrdersRepository
    implements OrdersRepository, OrderHistoryRepository {
  FirestoreOrdersRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const Duration paymentValidity = Duration(hours: 6);
  static const int maximumLoadedOrders = 250;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return _firestore.collection('orders');
  }

  @override
  Future<QueueOrder> createOrder({required CreateOrderRequest request}) async {
    _validateCreateRequest(request);

    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc();
    final DateTime now = DateTime.now();
    final String reference = _buildManualReference(
      date: now,
      documentId: document.id,
    );

    await document.set(
      FirestoreOrderMapper.operatorOrderCreationData(
        reference: reference,
        clientName: request.clientName,
        clientWhatsappPhone: request.clientWhatsappPhone,
        network: request.network,
        beneficiaryPhone: request.beneficiaryPhone,
        operationType: request.operationType,
        offerLabel: request.offerLabel,
        amount: request.amount,
        offerId: request.offerId,
        isCustomOffer: request.isCustomOffer,
        originalWhatsappMessage: request.originalWhatsappMessage,
        internalNotes: request.internalNotes,
        expiresAt: now.add(paymentValidity),
      ),
    );

    return QueueOrder(
      id: document.id,
      reference: reference,
      source: OrderSource.operatorApp,
      clientName: request.clientName.trim(),
      clientWhatsappPhone: request.clientWhatsappPhone.trim(),
      network: request.network,
      beneficiaryPhone: request.beneficiaryPhone.trim(),
      operationType: request.operationType,
      offerLabel: request.offerLabel.trim(),
      amount: request.amount,
      originalWhatsappMessage: _cleanNullable(request.originalWhatsappMessage),
      internalNotes: _cleanNullable(request.internalNotes),
      createdAt: now,
      status: QueueOrderStatus.awaitingPayment,
      paymentStatus: OrderPaymentStatus.pending,
      expiresAt: now.add(paymentValidity),
      customerConfirmationStatus: CustomerConfirmationStatus.pending,
    );
  }

  @override
  Future<QueueOrder> markPaymentRequestSent({required String orderId}) {
    final DateTime sentAt = DateTime.now();

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: (QueueOrder order) {
        if (order.status != QueueOrderStatus.awaitingPayment) {
          throw StateError('Cette commande n’est pas en attente de paiement.');
        }
      },
      firestoreUpdate: <String, dynamic>{
        'paymentRequestSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(paymentRequestSentAt: sentAt);
      },
    );
  }

  @override
  Future<List<QueueOrder>> fetchPaymentTrackingOrders() async {
    final List<QueueOrder> orders = await _synchronizeExpiredOrders(
      await _fetchRecentOrders(),
    );

    final List<QueueOrder> paymentOrders = orders.where((QueueOrder order) {
      final bool isOperatorPaymentInProgress =
          order.source == OrderSource.operatorApp &&
          order.status == QueueOrderStatus.awaitingPayment;
      final bool isCustomerPaymentToVerify =
          order.source == OrderSource.customerWeb &&
          order.paymentStatus == OrderPaymentStatus.declared &&
          (order.status == QueueOrderStatus.paymentToVerify ||
              order.status == QueueOrderStatus.awaitingPayment ||
              order.status == QueueOrderStatus.expired);
      final bool wasConfirmed =
          order.paymentStatus == OrderPaymentStatus.confirmed &&
          order.paymentReference != null &&
          order.paymentReference!.trim().isNotEmpty;

      return isOperatorPaymentInProgress ||
          isCustomerPaymentToVerify ||
          wasConfirmed;
    }).toList();

    paymentOrders.sort((QueueOrder first, QueueOrder second) {
      final DateTime firstDate =
          first.paidAt ??
          first.paymentDeclaredAt ??
          first.paymentRequestSentAt ??
          first.createdAt;
      final DateTime secondDate =
          second.paidAt ??
          second.paymentDeclaredAt ??
          second.paymentRequestSentAt ??
          second.createdAt;

      return secondDate.compareTo(firstDate);
    });

    return List<QueueOrder>.unmodifiable(paymentOrders);
  }

  @override
  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  }) {
    final String finalReference = _buildPaymentReference(
      paidAt: paidAt,
      suppliedReference: paymentReference,
    );

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: (QueueOrder order) {
        final bool canConfirm =
            order.status == QueueOrderStatus.awaitingPayment ||
            order.status == QueueOrderStatus.paymentToVerify ||
            order.hasPaymentToReviewAfterExpiration;

        if (!canConfirm ||
            order.paymentStatus == OrderPaymentStatus.confirmed) {
          throw StateError('Cette commande n’est plus en attente de paiement.');
        }
      },
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.paidReady.name,
        'paymentStatus': OrderPaymentStatus.confirmed.name,
        'paidAt': Timestamp.fromDate(paidAt.toUtc()),
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
        'paymentReference': finalReference,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.paidReady,
          paymentStatus: OrderPaymentStatus.confirmed,
          paidAt: paidAt,
          paymentConfirmedAt: paidAt,
          paymentReference: finalReference,
        );
      },
    );
  }

  @override
  Future<List<QueueOrder>> fetchPaidQueue() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .where('status', isEqualTo: QueueOrderStatus.paidReady.name)
        .limit(maximumLoadedOrders)
        .get();

    final List<QueueOrder> orders = snapshot.docs.map(_mapDocument).toList();

    orders.sort((QueueOrder first, QueueOrder second) {
      final DateTime firstDate = first.paidAt ?? first.createdAt;
      final DateTime secondDate = second.paidAt ?? second.createdAt;
      return firstDate.compareTo(secondDate);
    });

    return List<QueueOrder>.unmodifiable(orders);
  }

  @override
  Future<List<QueueOrder>> fetchOrderHistory() async {
    final List<QueueOrder> orders = await _synchronizeExpiredOrders(
      await _fetchRecentOrders(),
    );

    orders.sort((QueueOrder first, QueueOrder second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return List<QueueOrder>.unmodifiable(orders);
  }

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _ordersCollection.doc(orderId).get();
    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('La commande est introuvable.');
    }

    final QueueOrder order = FirestoreOrderMapper.fromMap(
      id: snapshot.id,
      data: data,
    );

    return _synchronizeExpirationIfNeeded(order);
  }

  @override
  Future<QueueOrder> takeCharge({
    required String orderId,
    required String operatorId,
  }) {
    final DateTime takenAt = DateTime.now();

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: (QueueOrder order) {
        if (order.status != QueueOrderStatus.paidReady) {
          throw StateError('Cette commande est déjà prise en charge.');
        }
      },
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.inProgress.name,
        'takenByUserId': operatorId,
        'takenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.inProgress,
          takenByUserId: operatorId,
          takenAt: takenAt,
        );
      },
    );
  }

  @override
  Future<QueueOrder> markSuccessful({required String orderId}) {
    final DateTime completedAt = DateTime.now();

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: _verifyOrderIsInProgress,
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.awaitingCustomerConfirmation.name,
        'completedAt': FieldValue.serverTimestamp(),
        'failureReason': null,
        'observation': null,
        'customerConfirmationStatus': CustomerConfirmationStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.awaitingCustomerConfirmation,
          completedAt: completedAt,
          customerConfirmationStatus: CustomerConfirmationStatus.pending,
        );
      },
    );
  }

  @override
  Future<QueueOrder> markFailed({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  }) {
    final DateTime completedAt = DateTime.now();
    final String? cleanedObservation = _cleanNullable(observation);

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: _verifyOrderIsInProgress,
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.failed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'failureReason': reason.name,
        'observation': cleanedObservation,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.failed,
          completedAt: completedAt,
          failureReason: reason,
          observation: cleanedObservation,
        );
      },
    );
  }

  @override
  Future<QueueOrder> putOnHold({required String orderId}) {
    return _updateOrderInTransaction(
      orderId: orderId,
      validate: _verifyOrderIsInProgress,
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.paidReady.name,
        'takenByUserId': null,
        'takenAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.paidReady,
          clearAssignment: true,
        );
      },
    );
  }

  @override
  Future<QueueOrder> completeCustomerConfirmation({
    required String orderId,
    required bool messageSent,
  }) {
    final DateTime confirmationCompletedAt = DateTime.now();
    final CustomerConfirmationStatus confirmationStatus = messageSent
        ? CustomerConfirmationStatus.sent
        : CustomerConfirmationStatus.skipped;

    return _updateOrderInTransaction(
      orderId: orderId,
      validate: (QueueOrder order) {
        if (order.status != QueueOrderStatus.awaitingCustomerConfirmation) {
          throw StateError(
            'Cette commande n’attend pas de confirmation client.',
          );
        }
      },
      firestoreUpdate: <String, dynamic>{
        'status': QueueOrderStatus.completed.name,
        'customerConfirmationStatus': confirmationStatus.name,
        'customerConfirmationCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      localUpdate: (QueueOrder order) {
        return order.copyWith(
          status: QueueOrderStatus.completed,
          customerConfirmationStatus: confirmationStatus,
          customerConfirmationCompletedAt: confirmationCompletedAt,
        );
      },
    );
  }

  Future<List<QueueOrder>> _synchronizeExpiredOrders(
    List<QueueOrder> orders,
  ) async {
    return Future.wait(orders.map(_synchronizeExpirationIfNeeded));
  }

  Future<QueueOrder> _synchronizeExpirationIfNeeded(QueueOrder order) async {
    final DateTime? expiresAt = order.expiresAt;
    final DateTime now = DateTime.now();

    if (expiresAt == null ||
        !OrderExpirationPolicy.shouldExpire(
          status: order.status,
          paymentStatus: order.paymentStatus,
          expiresAt: expiresAt,
          now: now,
        )) {
      return order;
    }

    final DocumentReference<Map<String, dynamic>> reference = _ordersCollection
        .doc(order.id);

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return order;
      }

      final QueueOrder currentOrder = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );
      final DateTime? currentExpiresAt = currentOrder.expiresAt;
      final DateTime transactionTime = DateTime.now();

      if (currentExpiresAt == null ||
          !OrderExpirationPolicy.shouldExpire(
            status: currentOrder.status,
            paymentStatus: currentOrder.paymentStatus,
            expiresAt: currentExpiresAt,
            now: transactionTime,
          )) {
        return currentOrder;
      }

      final OrderPaymentStatus expiredPaymentStatus =
          OrderExpirationPolicy.paymentStatusAfterExpiration(
            currentOrder.paymentStatus,
          );

      transaction.update(reference, <String, dynamic>{
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

  Future<List<QueueOrder>> _fetchRecentOrders() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .orderBy('createdAt', descending: true)
        .limit(maximumLoadedOrders)
        .get();

    return snapshot.docs.map(_mapDocument).toList();
  }

  QueueOrder _mapDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return FirestoreOrderMapper.fromMap(id: document.id, data: document.data());
  }

  Future<QueueOrder> _updateOrderInTransaction({
    required String orderId,
    required void Function(QueueOrder order) validate,
    required Map<String, dynamic> firestoreUpdate,
    required QueueOrder Function(QueueOrder order) localUpdate,
  }) {
    final DocumentReference<Map<String, dynamic>> reference = _ordersCollection
        .doc(orderId);

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder currentOrder = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );

      validate(currentOrder);
      transaction.update(reference, firestoreUpdate);

      return localUpdate(currentOrder);
    });
  }

  void _verifyOrderIsInProgress(QueueOrder order) {
    if (order.status != QueueOrderStatus.inProgress) {
      throw StateError('Cette commande n’est pas en cours de traitement.');
    }
  }

  void _validateCreateRequest(CreateOrderRequest request) {
    if (request.clientName.trim().length < 2 ||
        request.clientWhatsappPhone.trim().isEmpty ||
        request.beneficiaryPhone.trim().isEmpty ||
        request.offerLabel.trim().length < 2 ||
        request.amount <= 0) {
      throw StateError('La commande est incomplète.');
    }
  }

  String _buildManualReference({
    required DateTime date,
    required String documentId,
  }) {
    final DateTime localDate = date.toLocal();
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    final String suffix = documentId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .substring(0, 6)
        .toUpperCase();

    return 'CF-M-$year$month$day-$suffix';
  }

  String _buildPaymentReference({
    required DateTime paidAt,
    required String? suppliedReference,
  }) {
    final String cleanedReference = suppliedReference?.trim() ?? '';

    if (cleanedReference.isNotEmpty) {
      return cleanedReference.toUpperCase();
    }

    final String timestamp = paidAt.millisecondsSinceEpoch.toString();
    final String shortTimestamp = timestamp.length > 8
        ? timestamp.substring(timestamp.length - 8)
        : timestamp;

    return 'MAN-$shortTimestamp';
  }

  String? _cleanNullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
