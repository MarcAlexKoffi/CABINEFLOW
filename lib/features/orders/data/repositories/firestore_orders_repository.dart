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

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _agentProfilesCollection {
    return _firestore.collection('agentProfiles');
  }

  CollectionReference<Map<String, dynamic>> get _assignmentsCollection {
    return _firestore.collection('orderAssignments');
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
  Future<QueueOrder> assignToAgent({
    required String orderId,
    required String agentId,
    required String assignedByUserId,
  }) async {
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> userRef = _usersCollection
        .doc(agentId);
    final DocumentReference<Map<String, dynamic>> profileRef =
        _agentProfilesCollection.doc(agentId);
    final DocumentReference<Map<String, dynamic>> assignmentRef =
        _assignmentsCollection.doc();
    final DateTime assignedAt = DateTime.now();

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await transaction.get(userRef);
      final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
          await transaction.get(profileRef);

      final Map<String, dynamic>? orderData = orderSnapshot.data();
      final Map<String, dynamic>? userData = userSnapshot.data();
      final Map<String, dynamic>? profileData = profileSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }
      if (!userSnapshot.exists ||
          userData == null ||
          userData['role'] != 'agent') {
        throw StateError('Le compte agent est introuvable.');
      }
      if (userData['isActive'] != true) {
        throw StateError('Cet agent est suspendu.');
      }
      if (!profileSnapshot.exists || profileData == null) {
        throw StateError('Le profil opérationnel de cet agent est incomplet.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );

      if (order.status != QueueOrderStatus.paidReady ||
          order.paymentStatus != OrderPaymentStatus.confirmed) {
        throw StateError(
          'Seule une commande payée et prête peut être affectée.',
        );
      }

      final List<dynamic> authorizedNetworks =
          profileData['authorizedNetworks'] is List
          ? profileData['authorizedNetworks'] as List<dynamic>
          : const <dynamic>[];
      final List<dynamic> activeNetworks = profileData['activeNetworks'] is List
          ? profileData['activeNetworks'] as List<dynamic>
          : const <dynamic>[];
      final String network = order.network.name;

      if (profileData['availability'] != 'available') {
        throw StateError('Cet agent est actuellement indisponible.');
      }
      if (!authorizedNetworks.contains(network) ||
          !activeNetworks.contains(network)) {
        throw StateError('Cet agent ne traite pas actuellement ce réseau.');
      }

      final int capacity = _agentCapacityForNetwork(profileData, order.network);
      if (capacity < order.amount) {
        throw StateError('La capacité déclarée de cet agent est insuffisante.');
      }

      final String agentName = _stringValue(
        userData['name'],
        fallback: 'Agent',
      );

      transaction.update(orderRef, <String, dynamic>{
        'assignedAgentId': agentId,
        'assignedAgentName': agentName,
        'assignedByUserId': assignedByUserId,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignmentMode': OrderAssignmentMode.manual.name,
        'assignmentStatus': OrderAssignmentStatus.assigned.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(assignmentRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': order.id,
        'orderReference': order.reference,
        'agentId': agentId,
        'agentName': agentName,
        'assignedByUserId': assignedByUserId,
        'mode': OrderAssignmentMode.manual.name,
        'status': OrderAssignmentStatus.assigned.name,
        'assignedAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'refusedAt': null,
        'refusalReason': null,
        'completedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return order.copyWith(
        assignedAgentId: agentId,
        assignedAgentName: agentName,
        assignedByUserId: assignedByUserId,
        assignedAt: assignedAt,
        assignmentMode: OrderAssignmentMode.manual,
        assignmentStatus: OrderAssignmentStatus.assigned,
      );
    });
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    final List<QueueOrder> orders = await _fetchRecentOrders();
    final Map<String, int> counts = <String, int>{};

    for (final QueueOrder order in orders) {
      final String? agentId = order.assignedAgentId;
      if (agentId == null || agentId.isEmpty) continue;
      if (order.assignmentStatus != OrderAssignmentStatus.assigned &&
          order.assignmentStatus != OrderAssignmentStatus.accepted) {
        continue;
      }
      if (order.status == QueueOrderStatus.completed ||
          order.status == QueueOrderStatus.failed ||
          order.status == QueueOrderStatus.cancelled ||
          order.status == QueueOrderStatus.refunded) {
        continue;
      }
      counts[agentId] = (counts[agentId] ?? 0) + 1;
    }

    return Map<String, int>.unmodifiable(counts);
  }

  @override
  Stream<List<QueueOrder>> watchAssignedOrders({required String agentId}) {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      return Stream<List<QueueOrder>>.value(const <QueueOrder>[]);
    }

    return _ordersCollection
        .where('assignedAgentId', isEqualTo: cleanedAgentId)
        .limit(maximumLoadedOrders)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<QueueOrder> orders = snapshot.docs
              .map(_mapDocument)
              .where((QueueOrder order) {
                return order.assignedAgentId == cleanedAgentId &&
                    order.assignmentStatus != OrderAssignmentStatus.unassigned;
              })
              .toList(growable: false);

          orders.sort((QueueOrder first, QueueOrder second) {
            final DateTime firstDate = first.assignedAt ?? first.createdAt;
            final DateTime secondDate = second.assignedAt ?? second.createdAt;
            return secondDate.compareTo(firstDate);
          });

          return List<QueueOrder>.unmodifiable(orders);
        });
  }

  @override
  Future<QueueOrder> acceptAgentAssignment({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }

    final DocumentReference<Map<String, dynamic>> assignmentRef =
        await _findPendingAssignmentReference(
          orderId: orderId,
          agentId: cleanedAgentId,
        );
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> assignmentSnapshot =
          await transaction.get(assignmentRef);
      final Map<String, dynamic>? orderData = orderSnapshot.data();
      final Map<String, dynamic>? assignmentData = assignmentSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }
      if (!assignmentSnapshot.exists || assignmentData == null) {
        throw StateError('L’affectation est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      _validatePendingAgentAssignment(
        order: order,
        assignmentData: assignmentData,
        agentId: cleanedAgentId,
      );

      transaction.update(orderRef, <String, dynamic>{
        'assignmentStatus': OrderAssignmentStatus.accepted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'status': OrderAssignmentStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return order.copyWith(assignmentStatus: OrderAssignmentStatus.accepted);
    });
  }

  @override
  Future<QueueOrder> refuseAgentAssignment({
    required String orderId,
    required String agentId,
    required String reason,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final String cleanedReason = reason.trim();

    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }
    if (cleanedReason.length < 3) {
      throw StateError('Indique un motif de refus plus précis.');
    }
    if (cleanedReason.length > 500) {
      throw StateError('Le motif de refus est trop long.');
    }

    final DocumentReference<Map<String, dynamic>> assignmentRef =
        await _findPendingAssignmentReference(
          orderId: orderId,
          agentId: cleanedAgentId,
        );
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> assignmentSnapshot =
          await transaction.get(assignmentRef);
      final Map<String, dynamic>? orderData = orderSnapshot.data();
      final Map<String, dynamic>? assignmentData = assignmentSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }
      if (!assignmentSnapshot.exists || assignmentData == null) {
        throw StateError('L’affectation est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      _validatePendingAgentAssignment(
        order: order,
        assignmentData: assignmentData,
        agentId: cleanedAgentId,
      );

      transaction.update(orderRef, <String, dynamic>{
        'assignedAgentId': null,
        'assignedAgentName': null,
        'assignedByUserId': null,
        'assignedAt': null,
        'assignmentMode': null,
        'assignmentStatus': OrderAssignmentStatus.unassigned.name,
        'lastAssignmentRefusalReason': cleanedReason,
        'lastAssignmentRefusedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'status': OrderAssignmentStatus.refused.name,
        'refusedAt': FieldValue.serverTimestamp(),
        'refusalReason': cleanedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return order.copyWith(
        clearAgentAssignment: true,
        lastAssignmentRefusalReason: cleanedReason,
        lastAssignmentRefusedAt: DateTime.now(),
      );
    });
  }

  Future<DocumentReference<Map<String, dynamic>>>
  _findPendingAssignmentReference({
    required String orderId,
    required String agentId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _assignmentsCollection
            .where('agentId', isEqualTo: agentId)
            .where('orderId', isEqualTo: orderId)
            .limit(20)
            .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates =
        snapshot.docs
            .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              return doc.data()['status'] ==
                  OrderAssignmentStatus.assigned.name;
            })
            .toList(growable: false);

    if (candidates.isEmpty) {
      throw StateError('Aucune affectation en attente n’a été trouvée.');
    }

    candidates.sort((first, second) {
      final DateTime firstDate = _dateValue(first.data()['assignedAt']);
      final DateTime secondDate = _dateValue(second.data()['assignedAt']);
      return secondDate.compareTo(firstDate);
    });

    return candidates.first.reference;
  }

  void _validatePendingAgentAssignment({
    required QueueOrder order,
    required Map<String, dynamic> assignmentData,
    required String agentId,
  }) {
    if (order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.assigned) {
      throw StateError('Cette commande ne t’est plus affectée.');
    }
    if (order.status != QueueOrderStatus.paidReady ||
        order.paymentStatus != OrderPaymentStatus.confirmed) {
      throw StateError('Cette commande n’est plus disponible à l’acceptation.');
    }
    if (assignmentData['agentId'] != agentId ||
        assignmentData['orderId'] != order.id ||
        assignmentData['status'] != OrderAssignmentStatus.assigned.name) {
      throw StateError('Cette affectation n’est plus active.');
    }
  }

  DateTime _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
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

  int _agentCapacityForNetwork(
    Map<String, dynamic> profileData,
    MobileNetwork network,
  ) {
    final Object? rawValue;
    switch (network) {
      case MobileNetwork.orange:
        rawValue = profileData['orangeCapacity'];
        break;
      case MobileNetwork.mtn:
        rawValue = profileData['mtnCapacity'];
        break;
      case MobileNetwork.moov:
        rawValue = profileData['moovCapacity'];
        break;
    }
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.toInt();
    return 0;
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
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
