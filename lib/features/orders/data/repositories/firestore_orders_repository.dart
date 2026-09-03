import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/order_event.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/services/agent_capacity_policy.dart';
import 'package:cabine_flow/features/orders/domain/services/automatic_assignment_selector.dart';
import 'package:cabine_flow/features/orders/domain/services/order_expiration_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreOrdersRepository
    implements OrdersRepository, OrderHistoryRepository {
  FirestoreOrdersRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    bool enableNativeAutoAssignment = true,
    bool requireFirestoreProof = true,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _enableNativeAutoAssignment = enableNativeAutoAssignment,
       _requireFirestoreProof = requireFirestoreProof;

  static const Duration paymentValidity = Duration(hours: 6);
  static const int maximumLoadedOrders = 250;
  static const int automaticBacklogAssignmentLimit = 25;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final bool _enableNativeAutoAssignment;
  final bool _requireFirestoreProof;

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

  CollectionReference<Map<String, dynamic>> get _proofsCollection {
    return _firestore.collection('orderProofs');
  }

  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    return _firestore.collection('orderEvents');
  }

  CollectionReference<Map<String, dynamic>> get _autoAssignmentQueueCollection {
    return _firestore.collection('autoAssignmentQueue');
  }

  CollectionReference<Map<String, dynamic>> get _commissionsCollection {
    return _firestore.collection('commissions');
  }

  CollectionReference<Map<String, dynamic>> get _commissionAccountsCollection {
    return _firestore.collection('commissionAccounts');
  }

  CollectionReference<Map<String, dynamic>> get _networkTransactionsCollection {
    return _firestore.collection('networkTransactions');
  }

  @override
  Future<QueueOrder> createOrder({required CreateOrderRequest request}) async {
    _validateCreateRequest(request);

    final _AuditActor actor = await _currentStaffActor();
    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc();
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final DateTime now = DateTime.now();
    final String reference = _buildManualReference(
      date: now,
      documentId: document.id,
    );
    final OrderEventType eventType = OrderEventType.orderCreated;

    final Map<String, dynamic> orderData =
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
        )..addAll(_auditLinkData(eventRef: eventRef, type: eventType));

    final WriteBatch batch = _firestore.batch();
    batch.set(document, orderData);
    batch.set(
      eventRef,
      _eventDocumentData(
        orderId: document.id,
        orderReference: reference,
        type: eventType,
        actor: actor,
        metadata: <String, dynamic>{
          'source': OrderSource.operatorApp.name,
          'network': request.network.name,
          'amount': request.amount,
        },
      ),
    );
    await batch.commit();

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
    return _buildPaymentTrackingOrders(orders);
  }

  @override
  Stream<List<QueueOrder>> watchPaymentTrackingOrders() {
    return _ordersCollection
        .orderBy('createdAt', descending: true)
        .limit(maximumLoadedOrders)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<QueueOrder> orders = snapshot.docs
              .map(_mapDocument)
              .toList(growable: false);
          final List<QueueOrder> synchronized = await _synchronizeExpiredOrders(
            orders,
          );
          return _buildPaymentTrackingOrders(synchronized);
        });
  }

  @override
  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  }) async {
    final _AuditActor actor = await _currentStaffActor();
    final String finalReference = _buildPaymentReference(
      paidAt: paidAt,
      suppliedReference: paymentReference,
    );
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(orderId);
    final OrderEventType eventType = OrderEventType.paymentConfirmed;

    final QueueOrder confirmedOrder = await _firestore
        .runTransaction<QueueOrder>((Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(orderRef);
          final Map<String, dynamic>? data = snapshot.data();

          if (!snapshot.exists || data == null) {
            throw StateError('La commande est introuvable.');
          }

          final QueueOrder order = FirestoreOrderMapper.fromMap(
            id: snapshot.id,
            data: data,
          );
          final bool canConfirm =
              order.status == QueueOrderStatus.awaitingPayment ||
              order.status == QueueOrderStatus.paymentToVerify ||
              order.hasPaymentToReviewAfterExpiration;

          if (!canConfirm ||
              order.paymentStatus == OrderPaymentStatus.confirmed) {
            throw StateError(
              'Cette commande n’est plus en attente de paiement.',
            );
          }

          transaction.update(orderRef, <String, dynamic>{
            'status': QueueOrderStatus.paidReady.name,
            'paymentStatus': OrderPaymentStatus.confirmed.name,
            'paidAt': Timestamp.fromDate(paidAt.toUtc()),
            'paymentConfirmedAt': FieldValue.serverTimestamp(),
            'paymentReference': finalReference,
            'updatedAt': FieldValue.serverTimestamp(),
            ..._auditLinkData(eventRef: eventRef, type: eventType),
          });
          transaction.set(
            eventRef,
            _eventDocumentData(
              orderId: order.id,
              orderReference: order.reference,
              type: eventType,
              actor: actor,
              metadata: <String, dynamic>{'paymentReference': finalReference},
            ),
          );
          transaction.set(
            queueRef,
            _automaticQueueDocumentData(
              order: order,
              createdAt: paidAt,
              lastRefusedAgentId: order.lastAssignmentRefusedAgentId,
              refusedAgentIds: order.autoAssignmentRefusedAgentIds,
            ),
          );

          return order.copyWith(
            status: QueueOrderStatus.paidReady,
            paymentStatus: OrderPaymentStatus.confirmed,
            paidAt: paidAt,
            paymentConfirmedAt: paidAt,
            paymentReference: finalReference,
          );
        });

    // En mode hybride Phase 4, Firestore conserve la commande et la file
    // technique, mais Supabase devient la source de vérité de la négociation
    // d'affectation. On évite donc l'affectation native Firestore ici.
    if (!_enableNativeAutoAssignment) {
      return confirmedOrder;
    }

    // Phase 9E native : une confirmation de paiement déclenche immédiatement
    // une tentative d'affectation automatique.
    try {
      return await tryAutomaticAssignment(orderId: orderId) ?? confirmedOrder;
    } catch (error, stackTrace) {
      debugPrint('[AutoAssignment][after-payment] $error');
      debugPrintStack(
        label: '[AutoAssignment][after-payment] stack',
        stackTrace: stackTrace,
      );
      return confirmedOrder;
    }
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
  Stream<List<QueueOrder>> watchPaidQueue() {
    return _ordersCollection
        .where('status', isEqualTo: QueueOrderStatus.paidReady.name)
        .limit(maximumLoadedOrders)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<QueueOrder> orders = snapshot.docs
              .map(_mapDocument)
              .toList();
          orders.sort((QueueOrder first, QueueOrder second) {
            final DateTime firstDate = first.paidAt ?? first.createdAt;
            final DateTime secondDate = second.paidAt ?? second.createdAt;
            return firstDate.compareTo(secondDate);
          });
          return List<QueueOrder>.unmodifiable(orders);
        });
  }

  @override
  Stream<List<AutomaticAssignmentQueueItem>> watchAutomaticAssignmentQueue() {
    return _autoAssignmentQueueCollection
        .orderBy('createdAt')
        .limit(maximumLoadedOrders)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<AutomaticAssignmentQueueItem> items = snapshot.docs
              .map(_automaticQueueItemFromDocument)
              .whereType<AutomaticAssignmentQueueItem>()
              .toList(growable: false);
          return List<AutomaticAssignmentQueueItem>.unmodifiable(items);
        });
  }

  @override
  Future<void> synchronizeAutomaticAssignmentBacklog() async {
    await _currentStaffActor();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .where('status', isEqualTo: QueueOrderStatus.paidReady.name)
        .limit(maximumLoadedOrders)
        .get();

    final List<QueueOrder> waiting =
        snapshot.docs
            .map(_mapDocument)
            .where(_isWaitingForAutomaticAssignment)
            .toList(growable: false)
          ..sort((QueueOrder first, QueueOrder second) {
            final DateTime firstDate = first.paidAt ?? first.createdAt;
            final DateTime secondDate = second.paidAt ?? second.createdAt;
            return firstDate.compareTo(secondDate);
          });

    for (final QueueOrder order in waiting) {
      try {
        await _ensureAutomaticQueueDocument(order);
      } on FirebaseException catch (error) {
        debugPrint(
          '[AutoAssignment][backlog] order=${order.id} skipped: $error',
        );
      }
    }

    for (final QueueOrder order in waiting.take(
      automaticBacklogAssignmentLimit,
    )) {
      try {
        await tryAutomaticAssignment(orderId: order.id);
      } catch (error) {
        debugPrint(
          '[AutoAssignment][backlog] automatic attempt order=${order.id}: $error',
        );
      }
    }
  }

  @override
  Future<QueueOrder?> tryAutomaticAssignment({required String orderId}) async {
    final _AuditActor actor = await _currentStaffActor();
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
    if (!_isWaitingForAutomaticAssignment(order)) {
      await _autoAssignmentQueueCollection.doc(order.id).delete();
      return null;
    }

    await _ensureAutomaticQueueDocument(order);

    final List<AutomaticAssignmentAgent> candidates =
        await _loadAutomaticAssignmentAgents();
    final AutomaticAssignmentSelector selector =
        const AutomaticAssignmentSelector();
    final List<AutomaticAssignmentAgent> ranked = selector.rankEligible(
      order: order,
      agents: candidates,
    );

    debugPrint(
      '[AutoAssignment][staff] order=${order.reference} '
      'network=${order.network.name} amount=${order.amount} '
      'candidates=${candidates.length} eligible=${ranked.length}',
    );
    final Map<String, int> rankByAgent = <String, int>{
      for (int index = 0; index < ranked.length; index += 1)
        ranked[index].agentId: index + 1,
    };
    for (final AutomaticAssignmentAgent candidate in candidates) {
      final String? reason = candidate.ineligibilityReason(order: order);
      debugPrint(
        '[AutoAssignment][candidate] agent=${candidate.agentId} '
        'active=${candidate.isActive} available=${candidate.isAvailable} '
        'authorized=${candidate.authorizedNetworks.map((e) => e.name).toList()} '
        'activeNetworks=${candidate.activeNetworks.map((e) => e.name).toList()} '
        'capacity=${candidate.capacityFor(order.network)} '
        'reserved=${candidate.reservedFor(order.network)} '
        'availableCapacity=${candidate.availableCapacityFor(order.network)} '
        'activeCount=${candidate.activeAssignmentCount} '
        'todayCount=${candidate.todayAssignmentCount} '
        'maxCount=${candidate.maxTransactionsPerDay} '
        'todayAmount=${candidate.todayAssignedAmount} '
        'dailyLimit=${candidate.dailyTransactionLimit} '
        'lastAssignedAt=${candidate.lastAssignedAt?.toIso8601String() ?? 'never'} '
        'rank=${rankByAgent[candidate.agentId] ?? '-'} '
        'result=${reason ?? 'ELIGIBLE'}',
      );
    }

    if (ranked.isEmpty &&
        selector.shouldRequireManualAssignment(
          order: order,
          agents: candidates,
        )) {
      await _markManualAssignmentRequired(order);
      debugPrint(
        '[AutoAssignment][staff] order=${order.reference} '
        'manual assignment required: all eligible agents refused',
      );
      return null;
    }

    for (final AutomaticAssignmentAgent candidate in ranked) {
      try {
        final QueueOrder assigned = await _assignAutomaticallyAsStaff(
          orderId: order.id,
          agent: candidate,
          actor: actor,
        );
        debugPrint(
          '[AutoAssignment][staff] order=${order.reference} assigned=${candidate.agentId}',
        );
        return assigned;
      } on StateError catch (error) {
        debugPrint(
          '[AutoAssignment][staff] candidate=${candidate.agentId} skipped: $error',
        );
      } on FirebaseException catch (error, stackTrace) {
        if (error.code == 'aborted' || error.code == 'failed-precondition') {
          debugPrint(
            '[AutoAssignment][staff] candidate=${candidate.agentId} race: $error',
          );
          continue;
        }
        debugPrint(
          '[AutoAssignment][staff] candidate=${candidate.agentId} '
          'firebase=${error.code} message=${error.message}',
        );
        debugPrintStack(
          label: '[AutoAssignment][staff] candidate stack',
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    final DocumentSnapshot<Map<String, dynamic>> latestSnapshot =
        await _ordersCollection.doc(order.id).get();
    final Map<String, dynamic>? latestData = latestSnapshot.data();
    if (latestSnapshot.exists && latestData != null) {
      final QueueOrder latestOrder = FirestoreOrderMapper.fromMap(
        id: latestSnapshot.id,
        data: latestData,
      );
      if (latestOrder.assignedAgentId != null &&
          latestOrder.assignmentStatus == OrderAssignmentStatus.assigned) {
        return latestOrder;
      }
    }

    debugPrint(
      '[AutoAssignment][staff] no eligible agent for order=${order.id}',
    );
    return null;
  }

  @override
  Future<bool> claimAutomaticQueueItem({
    required AutomaticAssignmentQueueItem item,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid != cleanedAgentId) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }
    if (item.refusedAgentIds.contains(cleanedAgentId) ||
        item.lastRefusedAgentId == cleanedAgentId) {
      return false;
    }

    final _AutomaticAssignmentUsage usage = await _loadAgentUsage(
      cleanedAgentId,
    );
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(item.orderId);
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(item.orderId);
    final DocumentReference<Map<String, dynamic>> userRef = _usersCollection
        .doc(cleanedAgentId);
    final DocumentReference<Map<String, dynamic>> profileRef =
        _agentProfilesCollection.doc(cleanedAgentId);
    final DocumentReference<Map<String, dynamic>> assignmentRef =
        _assignmentsCollection.doc();
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.assigned;

    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> queueSnapshot =
            await transaction.get(queueRef);
        final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
            await transaction.get(userRef);
        final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
            await transaction.get(profileRef);

        final Map<String, dynamic>? queueData = queueSnapshot.data();
        final Map<String, dynamic>? userData = userSnapshot.data();
        final Map<String, dynamic>? profileData = profileSnapshot.data();
        if (!queueSnapshot.exists || queueData == null) {
          throw StateError(
            'Cette commande a déjà été prise par un autre agent.',
          );
        }
        if (!userSnapshot.exists || userData == null) {
          throw StateError('Le compte agent est introuvable.');
        }
        if (!profileSnapshot.exists || profileData == null) {
          throw StateError(
            'Le profil opérationnel de l’agent est introuvable.',
          );
        }

        final AutomaticAssignmentQueueItem? currentItem =
            _automaticQueueItemFromSnapshot(queueSnapshot);
        if (currentItem == null || currentItem.orderId != item.orderId) {
          throw StateError('La file d’affectation est invalide.');
        }
        if (currentItem.refusedAgentIds.contains(cleanedAgentId) ||
            currentItem.lastRefusedAgentId == cleanedAgentId) {
          throw StateError('Cet agent a déjà refusé cette commande.');
        }

        _validateAutomaticAgentProfile(
          userData: userData,
          profileData: profileData,
          network: currentItem.network,
          amount: currentItem.amount,
          usage: usage,
        );

        final String agentName = _stringValue(
          userData['name'],
          fallback: 'Agent',
        );
        transaction.update(orderRef, <String, dynamic>{
          'assignedAgentId': cleanedAgentId,
          'assignedAgentName': agentName,
          'assignedByUserId': cleanedAgentId,
          'assignedAt': FieldValue.serverTimestamp(),
          'assignmentMode': OrderAssignmentMode.automatic.name,
          'assignmentStatus': OrderAssignmentStatus.assigned.name,
          'updatedAt': FieldValue.serverTimestamp(),
          ..._auditLinkData(eventRef: eventRef, type: eventType),
        });
        transaction.set(assignmentRef, <String, dynamic>{
          'schemaVersion': 1,
          'orderId': currentItem.orderId,
          'orderReference': currentItem.orderReference,
          'agentId': cleanedAgentId,
          'agentName': agentName,
          'assignedByUserId': cleanedAgentId,
          'mode': OrderAssignmentMode.automatic.name,
          'status': OrderAssignmentStatus.assigned.name,
          'assignedAt': FieldValue.serverTimestamp(),
          'acceptedAt': null,
          'refusedAt': null,
          'refusalReason': null,
          'completedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          eventRef,
          _eventDocumentData(
            orderId: currentItem.orderId,
            orderReference: currentItem.orderReference,
            type: eventType,
            actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
            metadata: <String, dynamic>{
              'assignmentId': assignmentRef.id,
              'agentId': cleanedAgentId,
            },
          ),
        );
        transaction.delete(queueRef);
      });
      debugPrint(
        '[AutoAssignment][agent] agent=$cleanedAgentId claimed order=${item.orderId}',
      );
      return true;
    } on StateError catch (error) {
      debugPrint(
        '[AutoAssignment][agent] agent=$cleanedAgentId skipped order=${item.orderId}: $error',
      );
      return false;
    } on FirebaseException catch (error) {
      if (error.code == 'aborted' ||
          error.code == 'failed-precondition' ||
          error.code == 'permission-denied') {
        debugPrint(
          '[AutoAssignment][agent] race/denied order=${item.orderId}: $error',
        );
        return false;
      }
      rethrow;
    }
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
  Stream<List<QueueOrder>> watchOrderHistory() {
    return _ordersCollection
        .orderBy('createdAt', descending: true)
        .limit(maximumLoadedOrders)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<QueueOrder> orders = snapshot.docs
              .map(_mapDocument)
              .toList(growable: false);
          final List<QueueOrder> synchronized = await _synchronizeExpiredOrders(
            orders,
          );
          synchronized.sort((QueueOrder first, QueueOrder second) {
            return second.createdAt.compareTo(first.createdAt);
          });
          return List<QueueOrder>.unmodifiable(synchronized);
        });
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
    final String? authenticatedUserId = _firebaseAuth.currentUser?.uid;
    if (authenticatedUserId == null) {
      throw StateError('Aucun administrateur connecté.');
    }
    if (authenticatedUserId != assignedByUserId) {
      throw StateError(
        'La session administrateur ne correspond pas à l’utilisateur courant.',
      );
    }

    final _AuditActor adminActor = await _currentStaffActor();
    if (adminActor.role != 'admin') {
      throw StateError(
        'Seul un compte ayant le rôle admin peut affecter une commande.',
      );
    }

    // La réaffectation manuelle respecte la même capacité réellement
    // disponible que 9E : capacité déclarée - commandes déjà réservées.
    final _AutomaticAssignmentUsage currentUsage = await _loadAgentUsage(
      agentId,
    );

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> userRef = _usersCollection
        .doc(agentId);
    final DocumentReference<Map<String, dynamic>> profileRef =
        _agentProfilesCollection.doc(agentId);
    final DocumentReference<Map<String, dynamic>> assignmentRef =
        _assignmentsCollection.doc();
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.assigned;
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
          !order.isFundedForProcessing) {
        throw StateError(
          'Seule une commande payée et prête peut être affectée.',
        );
      }

      if (order.assignedAgentId != null ||
          order.assignmentStatus != OrderAssignmentStatus.unassigned) {
        throw StateError(
          'Cette commande est déjà affectée ou n’est plus disponible.',
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
      final int reserved = switch (order.network) {
        MobileNetwork.orange => currentUsage.orangeReservedAmount,
        MobileNetwork.mtn => currentUsage.mtnReservedAmount,
        MobileNetwork.moov => currentUsage.moovReservedAmount,
      };
      final int availableCapacity = capacity - reserved;
      if (availableCapacity < order.amount) {
        throw StateError(
          'La capacité réellement disponible de cet agent est insuffisante.',
        );
      }

      debugPrint(
        '[AgentAssignment][preflight] '
        'orderId=${order.id} status=${order.status.name} '
        'payment=${order.paymentStatus.name} network=$network amount=${order.amount} '
        'previousAgent=${order.assignedAgentId ?? 'null'} '
        'assignment=${order.assignmentStatus.name}',
      );
      debugPrint(
        '[AgentAssignment][preflight] '
        'agentId=$agentId role=${userData['role']} active=${userData['isActive']} '
        'availability=${profileData['availability']} '
        'authorized=${profileData['authorizedNetworks']} '
        'activeNetworks=${profileData['activeNetworks']} capacity=$capacity '
        'reserved=$reserved availableCapacity=$availableCapacity',
      );

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
        'manualAssignmentRequired': false,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
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
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: adminActor,
          metadata: <String, dynamic>{
            'assignmentId': assignmentRef.id,
            'agentId': agentId,
          },
        ),
      );
      transaction.delete(queueRef);

      return order.copyWith(
        assignedAgentId: agentId,
        assignedAgentName: agentName,
        assignedByUserId: assignedByUserId,
        assignedAt: assignedAt,
        assignmentMode: OrderAssignmentMode.manual,
        assignmentStatus: OrderAssignmentStatus.assigned,
        manualAssignmentRequired: false,
      );
    });
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    return _buildActiveAssignmentCounts(await _fetchRecentOrders());
  }

  @override
  Stream<Map<String, int>> watchActiveAssignmentCounts() {
    return _ordersCollection
        .orderBy('createdAt', descending: true)
        .limit(maximumLoadedOrders)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<QueueOrder> orders = snapshot.docs
              .map(_mapDocument)
              .toList();
          return _buildActiveAssignmentCounts(orders);
        });
  }

  @override
  Future<int> fetchActiveReservedAmount({
    required String agentId,
    required MobileNetwork network,
  }) async {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) return 0;

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .where('assignedAgentId', isEqualTo: cleanedAgentId)
        .limit(500)
        .get();
    int reserved = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final QueueOrder order = _mapDocument(doc);
      if (_isActiveAssignedOrder(order) && order.network == network) {
        reserved += order.amount;
      }
    }
    return reserved;
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
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.assignmentAccepted;

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
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'status': OrderAssignmentStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{'assignmentId': assignmentRef.id},
        ),
      );

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
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.assignmentRefused;

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

      final List<String> refusedAgentIds = <String>{
        ...order.autoAssignmentRefusedAgentIds,
        cleanedAgentId,
      }.toList(growable: false);

      transaction.update(orderRef, <String, dynamic>{
        'assignedAgentId': null,
        'assignedAgentName': null,
        'assignedByUserId': null,
        'assignedAt': null,
        'assignmentMode': null,
        'assignmentStatus': OrderAssignmentStatus.unassigned.name,
        'lastAssignmentRefusalReason': cleanedReason,
        'lastAssignmentRefusedAt': FieldValue.serverTimestamp(),
        'lastAssignmentRefusedAgentId': cleanedAgentId,
        'autoAssignmentRefusedAgentIds': refusedAgentIds,
        'manualAssignmentRequired': false,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'status': OrderAssignmentStatus.refused.name,
        'refusedAt': FieldValue.serverTimestamp(),
        'refusalReason': cleanedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{
            'assignmentId': assignmentRef.id,
            'reason': cleanedReason,
            'releasedToQueue': true,
          },
        ),
      );
      transaction.set(
        queueRef,
        _automaticQueueDocumentData(
          order: order,
          createdAt: order.paidAt ?? order.createdAt,
          lastRefusedAgentId: cleanedAgentId,
          refusedAgentIds: refusedAgentIds,
        ),
      );

      return order.copyWith(
        clearAgentAssignment: true,
        lastAssignmentRefusalReason: cleanedReason,
        lastAssignmentRefusedAt: DateTime.now(),
        lastAssignmentRefusedAgentId: cleanedAgentId,
        autoAssignmentRefusedAgentIds: refusedAgentIds,
        manualAssignmentRequired: false,
      );
    });
  }

  @override
  Future<QueueOrder> startAgentProcessing({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.processingStarted;
    final DateTime startedAt = DateTime.now();

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(orderRef);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );

      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);

      if (order.status == QueueOrderStatus.inProgress &&
          order.takenByUserId == cleanedAgentId) {
        return order;
      }

      if (order.status != QueueOrderStatus.paidReady) {
        throw StateError('Cette commande ne peut pas être démarrée.');
      }

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.inProgress.name,
        'takenByUserId': cleanedAgentId,
        'takenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });

      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
        ),
      );

      return order.copyWith(
        status: QueueOrderStatus.inProgress,
        takenByUserId: cleanedAgentId,
        takenAt: startedAt,
      );
    });
  }

  @override
  Future<QueueOrder> resumeAgentProcessing({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.processingResumed;
    final DateTime resumedAt = DateTime.now();

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(orderRef);
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );
      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);

      if (order.status != QueueOrderStatus.onHold) {
        throw StateError('Cette commande n’est pas en attente.');
      }

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.inProgress.name,
        'lastResumedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });

      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
        ),
      );

      return order.copyWith(
        status: QueueOrderStatus.inProgress,
        lastResumedAt: resumedAt,
      );
    });
  }

  @override
  Future<OrderProof?> fetchOrderProof({required String orderId}) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _proofsCollection.doc(orderId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return _mapOrderProof(data);
  }

  @override
  Future<OrderProof> saveOrderProof({
    required String orderId,
    required String orderReference,
    required String agentId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final String cleanedFileName = fileName.trim();
    final String cleanedMimeType = mimeType.trim().toLowerCase();
    final Uint8List proofBytes = Uint8List.fromList(bytes);

    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }
    if (proofBytes.isEmpty) {
      throw StateError('La preuve est vide.');
    }
    if (proofBytes.lengthInBytes > 750000) {
      throw StateError('La preuve dépasse la taille maximale autorisée.');
    }
    if (cleanedFileName.isEmpty || cleanedFileName.length > 120) {
      throw StateError('Le nom du fichier de preuve est invalide.');
    }
    if (cleanedMimeType != 'image/jpeg') {
      throw StateError('La preuve doit être enregistrée au format JPEG.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> proofRef = _proofsCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.proofAdded;
    final DateTime now = DateTime.now();

    return _firestore.runTransaction<OrderProof>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> proofSnapshot =
          await transaction.get(proofRef);
      final Map<String, dynamic>? orderData = orderSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);
      if (order.status != QueueOrderStatus.inProgress &&
          order.status != QueueOrderStatus.onHold) {
        throw StateError(
          'La preuve peut être ajoutée uniquement pendant le traitement.',
        );
      }
      if (order.reference != orderReference) {
        throw StateError('La référence de commande ne correspond pas.');
      }

      final Map<String, dynamic>? oldProof = proofSnapshot.data();
      final DateTime createdAt = oldProof == null
          ? now
          : _dateValue(oldProof['createdAt']);
      final Object createdAtValue = oldProof == null
          ? FieldValue.serverTimestamp()
          : oldProof['createdAt'] as Object;

      transaction.set(proofRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': orderId,
        'orderReference': orderReference,
        'agentId': cleanedAgentId,
        'fileName': cleanedFileName,
        'mimeType': cleanedMimeType,
        'proofBytes': Blob(proofBytes),
        'sizeBytes': proofBytes.lengthInBytes,
        'createdAt': createdAtValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(orderRef, <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{
            'fileName': cleanedFileName,
            'sizeBytes': proofBytes.lengthInBytes,
          },
        ),
      );

      return OrderProof(
        orderId: orderId,
        orderReference: orderReference,
        agentId: cleanedAgentId,
        fileName: cleanedFileName,
        mimeType: cleanedMimeType,
        bytes: proofBytes,
        createdAt: createdAt,
        updatedAt: now,
      );
    });
  }

  @override
  Future<QueueOrder> markAgentSuccessful({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }

    final DocumentReference<Map<String, dynamic>> assignmentRef =
        await _findAcceptedAssignmentReference(
          orderId: orderId,
          agentId: cleanedAgentId,
        );
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> proofRef = _proofsCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> profileRef =
        _agentProfilesCollection.doc(cleanedAgentId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final DocumentReference<Map<String, dynamic>> commissionRef =
        _commissionsCollection.doc(orderId);
    final DocumentReference<Map<String, dynamic>> commissionAccountRef =
        _commissionAccountsCollection.doc(cleanedAgentId);
    final DocumentReference<Map<String, dynamic>> networkTransactionRef =
        _networkTransactionsCollection.doc('order_$orderId');
    final OrderEventType eventType = OrderEventType.processingSucceeded;
    final DateTime completedAt = DateTime.now();

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> assignmentSnapshot =
          await transaction.get(assignmentRef);
      final DocumentSnapshot<Map<String, dynamic>>? proofSnapshot =
          _requireFirestoreProof ? await transaction.get(proofRef) : null;
      final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
          await transaction.get(profileRef);
      final DocumentSnapshot<Map<String, dynamic>> commissionAccountSnapshot =
          await transaction.get(commissionAccountRef);
      final Map<String, dynamic>? orderData = orderSnapshot.data();
      final Map<String, dynamic>? assignmentData = assignmentSnapshot.data();
      final Map<String, dynamic>? proofData = proofSnapshot?.data();
      final Map<String, dynamic>? profileData = profileSnapshot.data();
      final Map<String, dynamic>? commissionAccountData =
          commissionAccountSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }
      if (!assignmentSnapshot.exists || assignmentData == null) {
        throw StateError('L’affectation active est introuvable.');
      }
      if (_requireFirestoreProof &&
          (proofSnapshot == null ||
              !proofSnapshot.exists ||
              proofData == null)) {
        throw StateError('Ajoute une preuve avant de valider la réussite.');
      }
      if (!profileSnapshot.exists || profileData == null) {
        throw StateError(
          'Le profil opérationnel de cet agent est introuvable.',
        );
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);
      _validateAcceptedAssignmentEvent(
        assignmentData: assignmentData,
        order: order,
        agentId: cleanedAgentId,
      );
      if (order.status != QueueOrderStatus.inProgress) {
        throw StateError('Cette commande n’est pas en cours de traitement.');
      }
      if (_requireFirestoreProof &&
          (proofData?['agentId'] != cleanedAgentId ||
              proofData?['orderId'] != orderId)) {
        throw StateError('La preuve enregistrée est invalide.');
      }

      final int previousCapacity = _agentCapacityForNetwork(
        profileData,
        order.network,
      );
      if (previousCapacity < order.amount) {
        throw StateError(
          'La capacité ${order.network.name.toUpperCase()} de cet agent est insuffisante.',
        );
      }
      final int remainingCapacity = AgentCapacityPolicy.remainingAfterSuccess(
        currentCapacity: previousCapacity,
        operationAmount: order.amount,
      );
      final String capacityField = _agentCapacityFieldForNetwork(order.network);
      final String movementMarkerField = _agentMovementMarkerFieldForNetwork(
        order.network,
      );

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'failureReason': null,
        'observation': null,
        'customerConfirmationStatus': CustomerConfirmationStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(profileRef, <String, dynamic>{
        capacityField: remainingCapacity,
        movementMarkerField: networkTransactionRef.id,
        'lastCapacityUpdateAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{'assignmentId': assignmentRef.id},
        ),
      );

      final CommissionPolicy commissionPolicy = CommissionPolicy.current;
      final String commissionAgentName =
          (order.assignedAgentName ??
                  assignmentData['agentName'] as String? ??
                  '')
              .trim();
      if (commissionAgentName.length < 2) {
        throw StateError(
          'Le nom de l’agent est introuvable pour la commission.',
        );
      }
      transaction.set(commissionRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': order.id,
        'orderReference': order.reference,
        'agentId': cleanedAgentId,
        'agentName': commissionAgentName,
        'network': order.network.name,
        'orderAmount': order.amount,
        'commissionAmount': commissionPolicy.amountPerSuccessfulTransaction,
        'policyId': commissionPolicy.id,
        'policyType': commissionPolicy.type.name,
        'rate': commissionPolicy.amountPerSuccessfulTransaction,
        'processingStartedAt': order.takenAt,
        'earnedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(networkTransactionRef, <String, dynamic>{
        'schemaVersion': 1,
        'network': order.network.name,
        'direction': 'outgoing',
        'type': 'orderSuccess',
        'amount': order.amount,
        'capacityBefore': previousCapacity,
        'capacityAfter': remainingCapacity,
        'agentId': cleanedAgentId,
        'agentName': commissionAgentName,
        'orderId': order.id,
        'orderReference': order.reference,
        'createdBy': cleanedAgentId,
        'createdByRole': 'agent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final int previousEarnedTotal = commissionAccountData == null
          ? 0
          : (commissionAccountData['earnedTotal'] as num?)?.toInt() ?? 0;
      final int previousPaidTotal = commissionAccountData == null
          ? 0
          : (commissionAccountData['paidTotal'] as num?)?.toInt() ?? 0;
      final int previousEarnedTransactions = commissionAccountData == null
          ? 0
          : (commissionAccountData['earnedTransactions'] as num?)?.toInt() ?? 0;
      final Map<String, dynamic> accountData = <String, dynamic>{
        'schemaVersion': 1,
        'agentId': cleanedAgentId,
        'agentName': commissionAgentName,
        'earnedTotal':
            previousEarnedTotal +
            commissionPolicy.amountPerSuccessfulTransaction,
        'paidTotal': previousPaidTotal,
        'earnedTransactions': previousEarnedTransactions + 1,
        'lastCommissionOrderId': order.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!commissionAccountSnapshot.exists) {
        accountData['createdAt'] = FieldValue.serverTimestamp();
        accountData['lastPayoutId'] = null;
        transaction.set(commissionAccountRef, accountData);
      } else {
        transaction.update(commissionAccountRef, accountData);
      }

      debugPrint(
        '[AgentCapacity][deduct] agentId=$cleanedAgentId '
        'network=${order.network.name} amount=${order.amount} '
        'before=$previousCapacity after=$remainingCapacity',
      );

      return order.copyWith(
        status: QueueOrderStatus.completed,
        completedAt: completedAt,
        customerConfirmationStatus: CustomerConfirmationStatus.pending,
        clearFailureDetails: true,
      );
    });
  }

  @override
  Future<QueueOrder> markAgentFailed({
    required String orderId,
    required String agentId,
    required OrderFailureReason reason,
    String? observation,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final String? cleanedObservation = _cleanNullable(observation);
    if (cleanedAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }
    if (cleanedObservation != null && cleanedObservation.length > 1000) {
      throw StateError('L’observation est trop longue.');
    }

    final DocumentReference<Map<String, dynamic>> assignmentRef =
        await _findAcceptedAssignmentReference(
          orderId: orderId,
          agentId: cleanedAgentId,
        );
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.processingFailed;
    final DateTime completedAt = DateTime.now();

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
        throw StateError('L’affectation active est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);
      _validateAcceptedAssignmentEvent(
        assignmentData: assignmentData,
        order: order,
        agentId: cleanedAgentId,
      );
      if (order.status != QueueOrderStatus.inProgress) {
        throw StateError('Cette commande n’est pas en cours de traitement.');
      }

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.failed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'failureReason': reason.name,
        'observation': cleanedObservation,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.update(assignmentRef, <String, dynamic>{
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{
            'assignmentId': assignmentRef.id,
            'failureReason': reason.name,
            'observation': ?cleanedObservation,
          },
        ),
      );

      return order.copyWith(
        status: QueueOrderStatus.failed,
        completedAt: completedAt,
        failureReason: reason,
        observation: cleanedObservation,
      );
    });
  }

  @override
  Future<QueueOrder> putAgentOnHold({
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
      throw StateError('Indique la raison de la mise en attente.');
    }
    if (cleanedReason.length > 300) {
      throw StateError('Le motif de mise en attente est trop long.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.putOnHold;
    final DateTime heldAt = DateTime.now();

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(orderRef);
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );
      _validateAcceptedAgentOrder(order: order, agentId: cleanedAgentId);
      if (order.status != QueueOrderStatus.inProgress) {
        throw StateError('Cette commande n’est pas en cours de traitement.');
      }

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.onHold.name,
        'lastHoldReason': cleanedReason,
        'lastHeldAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });

      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: _AuditActor(id: cleanedAgentId, role: 'agent'),
          metadata: <String, dynamic>{'reason': cleanedReason},
        ),
      );

      return order.copyWith(
        status: QueueOrderStatus.onHold,
        lastHoldReason: cleanedReason,
        lastHeldAt: heldAt,
      );
    });
  }

  @override
  Future<QueueOrder> prepareFailedOrderForReassignment({
    required String orderId,
  }) async {
    final _AuditActor actor = await _currentStaffActor();
    if (actor.role != 'admin') {
      throw StateError('Seul un administrateur peut réaffecter un échec.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId.trim());
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.reassignmentRequested;

    return _firestore.runTransaction<QueueOrder>((
      Transaction transaction,
    ) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(orderRef);
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('La commande est introuvable.');
      }

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: snapshot.id,
        data: data,
      );
      if (order.status != QueueOrderStatus.failed) {
        throw StateError('Seule une commande échouée peut être réaffectée.');
      }
      if (!order.isFundedForProcessing) {
        throw StateError('Cette commande n’est plus financée pour traitement.');
      }

      transaction.update(orderRef, <String, dynamic>{
        'status': QueueOrderStatus.paidReady.name,
        'takenByUserId': null,
        'takenAt': null,
        'completedAt': null,
        'failureReason': null,
        'observation': null,
        'assignedAgentId': null,
        'assignedAgentName': null,
        'assignedByUserId': null,
        'assignedAt': null,
        'assignmentMode': null,
        'assignmentStatus': OrderAssignmentStatus.unassigned.name,
        'lastAssignmentRefusalReason': null,
        'lastAssignmentRefusedAt': null,
        'lastAssignmentRefusedAgentId': null,
        'autoAssignmentRefusedAgentIds': <String>[],
        'manualAssignmentRequired': true,
        'lastHoldReason': null,
        'lastHeldAt': null,
        'lastResumedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });

      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: order.id,
          orderReference: order.reference,
          type: eventType,
          actor: actor,
          metadata: <String, dynamic>{
            'reason': 'Réaffectation demandée après échec',
          },
        ),
      );

      return order.copyWith(
        status: QueueOrderStatus.paidReady,
        manualAssignmentRequired: true,
        autoAssignmentRefusedAgentIds: const <String>[],
        clearAssignment: true,
        clearAgentAssignment: true,
        clearFailureDetails: true,
        clearProcessingDetails: true,
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

  Future<DocumentReference<Map<String, dynamic>>>
  _findAcceptedAssignmentReference({
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
                  OrderAssignmentStatus.accepted.name;
            })
            .toList(growable: false);

    if (candidates.isEmpty) {
      throw StateError('Aucune affectation acceptée n’a été trouvée.');
    }

    candidates.sort((first, second) {
      final DateTime firstDate = _dateValue(first.data()['acceptedAt']);
      final DateTime secondDate = _dateValue(second.data()['acceptedAt']);
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
        !order.isFundedForProcessing) {
      throw StateError('Cette commande n’est plus disponible à l’acceptation.');
    }
    if (assignmentData['agentId'] != agentId ||
        assignmentData['orderId'] != order.id ||
        assignmentData['status'] != OrderAssignmentStatus.assigned.name) {
      throw StateError('Cette affectation n’est plus active.');
    }
  }

  void _validateAcceptedAgentOrder({
    required QueueOrder order,
    required String agentId,
  }) {
    if (order.assignedAgentId != agentId ||
        order.assignmentStatus != OrderAssignmentStatus.accepted) {
      throw StateError('Cette commande ne t’est plus affectée.');
    }
    if (!order.isFundedForProcessing) {
      throw StateError('Cette commande n’est ni payée ni autorisée à crédit.');
    }
  }

  void _validateAcceptedAssignmentEvent({
    required Map<String, dynamic> assignmentData,
    required QueueOrder order,
    required String agentId,
  }) {
    if (assignmentData['agentId'] != agentId ||
        assignmentData['orderId'] != order.id ||
        assignmentData['status'] != OrderAssignmentStatus.accepted.name ||
        assignmentData['completedAt'] != null) {
      throw StateError('Cette affectation n’est plus active.');
    }
  }

  OrderProof _mapOrderProof(Map<String, dynamic> data) {
    final Object? rawBytes = data['proofBytes'];
    if (rawBytes is! Blob) {
      throw StateError('La preuve enregistrée est invalide.');
    }

    return OrderProof(
      orderId: _stringValue(data['orderId']),
      orderReference: _stringValue(data['orderReference']),
      agentId: _stringValue(data['agentId']),
      fileName: _stringValue(data['fileName'], fallback: 'preuve.jpg'),
      mimeType: _stringValue(data['mimeType'], fallback: 'image/jpeg'),
      bytes: rawBytes.bytes,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
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
  }) async {
    final _AuditActor actor = await _currentStaffActor();
    if (operatorId != actor.id) {
      throw StateError(
        'L’opérateur connecté ne correspond pas à la prise en charge.',
      );
    }
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
      auditType: OrderEventType.processingStarted,
      auditActor: actor,
    );
  }

  @override
  Future<QueueOrder> markSuccessful({required String orderId}) async {
    final _AuditActor actor = await _currentStaffActor();
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
      auditType: OrderEventType.processingSucceeded,
      auditActor: actor,
    );
  }

  @override
  Future<QueueOrder> markFailed({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  }) async {
    final _AuditActor actor = await _currentStaffActor();
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
      auditType: OrderEventType.processingFailed,
      auditActor: actor,
      auditMetadata: (QueueOrder _) => <String, dynamic>{
        'failureReason': reason.name,
        'observation': ?cleanedObservation,
      },
    );
  }

  @override
  Future<QueueOrder> putOnHold({required String orderId}) async {
    final _AuditActor actor = await _currentStaffActor();
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
      auditType: OrderEventType.putOnHold,
      auditActor: actor,
      auditMetadata: (QueueOrder _) => const <String, dynamic>{
        'releasedToQueue': true,
      },
    );
  }

  @override
  Future<QueueOrder> completeCustomerConfirmation({
    required String orderId,
    required bool messageSent,
  }) async {
    final _AuditActor actor = await _currentStaffActor();
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
      auditType: OrderEventType.customerContacted,
      auditActor: actor,
      auditMetadata: (QueueOrder _) => <String, dynamic>{
        'messageSent': messageSent,
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
    OrderEventType? auditType,
    _AuditActor? auditActor,
    Map<String, dynamic> Function(QueueOrder order)? auditMetadata,
  }) {
    final DocumentReference<Map<String, dynamic>> reference = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>>? eventRef = auditType == null
        ? null
        : _eventsCollection.doc();

    if ((auditType == null) != (auditActor == null)) {
      throw StateError('Configuration d’audit incomplète.');
    }

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
      final Map<String, dynamic> update = <String, dynamic>{...firestoreUpdate};
      if (eventRef != null && auditType != null) {
        update.addAll(_auditLinkData(eventRef: eventRef, type: auditType));
      }
      transaction.update(reference, update);

      if (eventRef != null && auditType != null && auditActor != null) {
        transaction.set(
          eventRef,
          _eventDocumentData(
            orderId: currentOrder.id,
            orderReference: currentOrder.reference,
            type: auditType,
            actor: auditActor,
            metadata:
                auditMetadata?.call(currentOrder) ?? const <String, dynamic>{},
          ),
        );
      }

      return localUpdate(currentOrder);
    });
  }

  List<QueueOrder> _buildPaymentTrackingOrders(List<QueueOrder> orders) {
    final List<QueueOrder> paymentOrders = orders.where((QueueOrder order) {
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

      return isCustomerPaymentToVerify || wasConfirmed;
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

  Future<QueueOrder> _assignAutomaticallyAsStaff({
    required String orderId,
    required AutomaticAssignmentAgent agent,
    required _AuditActor actor,
  }) async {
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(orderId);
    final DocumentReference<Map<String, dynamic>> userRef = _usersCollection
        .doc(agent.agentId);
    final DocumentReference<Map<String, dynamic>> profileRef =
        _agentProfilesCollection.doc(agent.agentId);
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(orderId);
    final DocumentReference<Map<String, dynamic>> assignmentRef =
        _assignmentsCollection.doc();
    final DocumentReference<Map<String, dynamic>> eventRef = _eventsCollection
        .doc();
    final OrderEventType eventType = OrderEventType.assigned;
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
      final DocumentSnapshot<Map<String, dynamic>> queueSnapshot =
          await transaction.get(queueRef);

      final Map<String, dynamic>? orderData = orderSnapshot.data();
      final Map<String, dynamic>? userData = userSnapshot.data();
      final Map<String, dynamic>? profileData = profileSnapshot.data();
      if (!orderSnapshot.exists || orderData == null) {
        throw StateError('La commande est introuvable.');
      }
      if (!queueSnapshot.exists || queueSnapshot.data() == null) {
        throw StateError('La commande a déjà quitté la file automatique.');
      }
      if (!userSnapshot.exists || userData == null) {
        throw StateError('Le compte agent est introuvable.');
      }
      if (!profileSnapshot.exists || profileData == null) {
        throw StateError('Le profil opérationnel de l’agent est introuvable.');
      }

      final QueueOrder currentOrder = FirestoreOrderMapper.fromMap(
        id: orderSnapshot.id,
        data: orderData,
      );
      if (!_isWaitingForAutomaticAssignment(currentOrder)) {
        throw StateError('La commande n’est plus disponible à l’affectation.');
      }
      if (currentOrder.autoAssignmentRefusedAgentIds.contains(agent.agentId) ||
          currentOrder.lastAssignmentRefusedAgentId == agent.agentId) {
        throw StateError('Cet agent a déjà refusé cette commande.');
      }

      _validateAutomaticAgentProfile(
        userData: userData,
        profileData: profileData,
        network: currentOrder.network,
        amount: currentOrder.amount,
        usage: _AutomaticAssignmentUsage(
          activeCount: agent.activeAssignmentCount,
          orangeReservedAmount: agent.orangeReservedAmount,
          mtnReservedAmount: agent.mtnReservedAmount,
          moovReservedAmount: agent.moovReservedAmount,
          todayCount: agent.todayAssignmentCount,
          todayAmount: agent.todayAssignedAmount,
          lastAssignedAt: agent.lastAssignedAt,
        ),
      );

      final String agentName = _stringValue(
        userData['name'],
        fallback: agent.name,
      );
      transaction.update(orderRef, <String, dynamic>{
        'assignedAgentId': agent.agentId,
        'assignedAgentName': agentName,
        'assignedByUserId': actor.id,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignmentMode': OrderAssignmentMode.automatic.name,
        'assignmentStatus': OrderAssignmentStatus.assigned.name,
        'updatedAt': FieldValue.serverTimestamp(),
        ..._auditLinkData(eventRef: eventRef, type: eventType),
      });
      transaction.set(assignmentRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': currentOrder.id,
        'orderReference': currentOrder.reference,
        'agentId': agent.agentId,
        'agentName': agentName,
        'assignedByUserId': actor.id,
        'mode': OrderAssignmentMode.automatic.name,
        'status': OrderAssignmentStatus.assigned.name,
        'assignedAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'refusedAt': null,
        'refusalReason': null,
        'completedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        _eventDocumentData(
          orderId: currentOrder.id,
          orderReference: currentOrder.reference,
          type: eventType,
          actor: actor,
          metadata: <String, dynamic>{
            'assignmentId': assignmentRef.id,
            'agentId': agent.agentId,
          },
        ),
      );
      transaction.delete(queueRef);

      return currentOrder.copyWith(
        assignedAgentId: agent.agentId,
        assignedAgentName: agentName,
        assignedByUserId: actor.id,
        assignedAt: assignedAt,
        assignmentMode: OrderAssignmentMode.automatic,
        assignmentStatus: OrderAssignmentStatus.assigned,
      );
    });
  }

  /// Lecture seule des critères 9E utilisée par le moteur hybride Supabase.
  /// Les données opérationnelles de l'agent restent sur Firebase pendant cette
  /// migration afin de ne pas casser disponibilité, réseaux et capacités.
  Future<List<AutomaticAssignmentAgent>>
  fetchAutomaticAssignmentCandidatesForHybrid() {
    return _loadAutomaticAssignmentAgents();
  }

  /// Garantit qu'une commande financée possède la file Firestore technique
  /// nécessaire au handoff lorsqu'un agent accepte finalement dans Supabase.
  Future<void> ensureHybridAssignmentQueue(QueueOrder order) async {
    if (order.status != QueueOrderStatus.paidReady ||
        !order.isFundedForProcessing) {
      throw StateError(
        'Cette commande ne peut pas entrer dans la file hybride.',
      );
    }
    await _autoAssignmentQueueCollection
        .doc(order.id)
        .set(
          _automaticQueueDocumentData(
            order: order,
            createdAt: order.paidAt ?? order.createdAt,
            lastRefusedAgentId: order.lastAssignmentRefusedAgentId,
            refusedAgentIds: order.autoAssignmentRefusedAgentIds,
          ),
        );
  }

  /// Nettoie uniquement le miroir d'affectation Firestore lorsqu'une ancienne
  /// affectation est devenue obsolète après un refus géré dans Supabase.
  /// L'historique officiel du refus reste dans Supabase Phase 4.
  Future<QueueOrder> releaseHybridStaleAssignmentAsStaff({
    required String orderId,
  }) async {
    final _AuditActor actor = await _currentStaffActor();
    if (actor.role != 'admin' && actor.role != 'supervisor') {
      throw StateError('Un compte de supervision est requis.');
    }

    final DocumentReference<Map<String, dynamic>> ref = _ordersCollection.doc(
      orderId.trim(),
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('La commande est introuvable.');
    }
    final QueueOrder order = FirestoreOrderMapper.fromMap(
      id: snapshot.id,
      data: data,
    );
    if (order.status != QueueOrderStatus.paidReady ||
        !order.isFundedForProcessing) {
      return order;
    }
    if (order.assignedAgentId == null &&
        order.assignmentStatus == OrderAssignmentStatus.unassigned) {
      return order;
    }

    await ref.update(<String, dynamic>{
      'assignedAgentId': null,
      'assignedAgentName': null,
      'assignedByUserId': null,
      'assignedAt': null,
      'assignmentMode': null,
      'assignmentStatus': OrderAssignmentStatus.unassigned.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return order.copyWith(clearAgentAssignment: true);
  }

  /// Transforme une acceptation Supabase en affectation Firestore classique.
  /// Après cette étape, preuve, traitement, capacité et commission continuent
  /// d'utiliser exactement le flux Firebase déjà validé.
  ///
  /// On tente d'abord d'accepter un miroir déjà existant (affectation manuelle
  /// ou héritée). S'il n'existe pas encore, l'agent réclame la file technique
  /// 9E puis accepte l'affectation ainsi créée. Cette méthode évite toute
  /// lecture directe d'une commande Firestore encore non affectée, lecture qui
  /// n'est volontairement pas autorisée à un agent.
  Future<QueueOrder> handoffHybridAcceptedAssignment({
    required String orderId,
    required String agentId,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final User? user = _firebaseAuth.currentUser;
    if (cleanedAgentId.isEmpty || user == null || user.uid != cleanedAgentId) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }

    try {
      return await acceptAgentAssignment(
        orderId: orderId,
        agentId: cleanedAgentId,
      );
    } on StateError catch (error) {
      if (!error.toString().contains('Aucune affectation en attente')) {
        rethrow;
      }
    }

    final DocumentSnapshot<Map<String, dynamic>> queueSnapshot =
        await _autoAssignmentQueueCollection.doc(orderId).get();
    final AutomaticAssignmentQueueItem? item = _automaticQueueItemFromSnapshot(
      queueSnapshot,
    );
    if (!queueSnapshot.exists || item == null) {
      throw StateError(
        'La file technique Firebase est absente. Ouvre le compte Admin pour resynchroniser cette commande.',
      );
    }

    final bool claimed = await claimAutomaticQueueItem(
      item: item,
      agentId: cleanedAgentId,
    );
    if (!claimed) {
      // Une course peut avoir créé l'affectation entre-temps. Dans ce cas une
      // seconde tentative d'acceptation suffit et reste idempotente.
      try {
        return await acceptAgentAssignment(
          orderId: orderId,
          agentId: cleanedAgentId,
        );
      } on StateError {
        throw StateError(
          "Cette affectation n'est plus compatible avec la capacité actuelle de l'agent.",
        );
      }
    }

    return acceptAgentAssignment(orderId: orderId, agentId: cleanedAgentId);
  }

  Future<List<AutomaticAssignmentAgent>>
  _loadAutomaticAssignmentAgents() async {
    final QuerySnapshot<Map<String, dynamic>> users = await _usersCollection
        .where('role', isEqualTo: 'agent')
        .get();
    final QuerySnapshot<Map<String, dynamic>> profiles =
        await _agentProfilesCollection.get();
    final QuerySnapshot<Map<String, dynamic>> ordersSnapshot =
        await _ordersCollection
            .orderBy('createdAt', descending: true)
            .limit(1000)
            .get();

    final Map<String, Map<String, dynamic>> profileByAgent =
        <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in profiles.docs)
            doc.id: doc.data(),
        };
    final List<QueueOrder> orders = ordersSnapshot.docs
        .map(_mapDocument)
        .toList(growable: false);
    final DateTime now = DateTime.now().toUtc();

    final List<AutomaticAssignmentAgent> agents = <AutomaticAssignmentAgent>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> user in users.docs) {
      final Map<String, dynamic> userData = user.data();
      final Map<String, dynamic>? profileData = profileByAgent[user.id];
      if (profileData == null) continue;
      final _AutomaticAssignmentUsage usage = _buildUsageFromOrders(
        orders: orders,
        agentId: user.id,
        now: now,
      );
      agents.add(
        AutomaticAssignmentAgent(
          agentId: user.id,
          name: _stringValue(userData['name'], fallback: 'Agent'),
          isActive: userData['isActive'] == true,
          isAvailable: profileData['availability'] == 'available',
          authorizedNetworks: _mobileNetworkSet(
            profileData['authorizedNetworks'],
          ),
          activeNetworks: _mobileNetworkSet(profileData['activeNetworks']),
          orangeCapacity: _intValue(profileData['orangeCapacity']),
          mtnCapacity: _intValue(profileData['mtnCapacity']),
          moovCapacity: _intValue(profileData['moovCapacity']),
          dailyTransactionLimit: _intValue(
            profileData['dailyTransactionLimit'],
          ),
          maxTransactionsPerDay: _intValue(
            profileData['maxTransactionsPerDay'],
          ),
          activeAssignmentCount: usage.activeCount,
          orangeReservedAmount: usage.orangeReservedAmount,
          mtnReservedAmount: usage.mtnReservedAmount,
          moovReservedAmount: usage.moovReservedAmount,
          todayAssignmentCount: usage.todayCount,
          todayAssignedAmount: usage.todayAmount,
          lastAssignedAt: usage.lastAssignedAt,
        ),
      );
    }
    return List<AutomaticAssignmentAgent>.unmodifiable(agents);
  }

  Future<_AutomaticAssignmentUsage> _loadAgentUsage(String agentId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .where('assignedAgentId', isEqualTo: agentId)
        .limit(500)
        .get();
    final List<QueueOrder> orders = snapshot.docs
        .map(_mapDocument)
        .toList(growable: false);
    return _buildUsageFromOrders(
      orders: orders,
      agentId: agentId,
      now: DateTime.now().toUtc(),
    );
  }

  _AutomaticAssignmentUsage _buildUsageFromOrders({
    required Iterable<QueueOrder> orders,
    required String agentId,
    required DateTime now,
  }) {
    int activeCount = 0;
    int orangeReservedAmount = 0;
    int mtnReservedAmount = 0;
    int moovReservedAmount = 0;
    int todayCount = 0;
    int todayAmount = 0;
    DateTime? lastAssignedAt;

    for (final QueueOrder order in orders) {
      if (order.assignedAgentId != agentId) continue;
      final DateTime? assignedAt = order.assignedAt;
      if (_isActiveAssignedOrder(order)) {
        activeCount += 1;
        switch (order.network) {
          case MobileNetwork.orange:
            orangeReservedAmount += order.amount;
            break;
          case MobileNetwork.mtn:
            mtnReservedAmount += order.amount;
            break;
          case MobileNetwork.moov:
            moovReservedAmount += order.amount;
            break;
        }
      }
      if (assignedAt != null) {
        final DateTime utc = assignedAt.toUtc();
        if (_sameUtcDay(utc, now)) {
          todayCount += 1;
          todayAmount += order.amount;
        }
        if (lastAssignedAt == null || assignedAt.isAfter(lastAssignedAt)) {
          lastAssignedAt = assignedAt;
        }
      }
    }

    return _AutomaticAssignmentUsage(
      activeCount: activeCount,
      orangeReservedAmount: orangeReservedAmount,
      mtnReservedAmount: mtnReservedAmount,
      moovReservedAmount: moovReservedAmount,
      todayCount: todayCount,
      todayAmount: todayAmount,
      lastAssignedAt: lastAssignedAt,
    );
  }

  bool _isActiveAssignedOrder(QueueOrder order) {
    if (order.assignmentStatus != OrderAssignmentStatus.assigned &&
        order.assignmentStatus != OrderAssignmentStatus.accepted) {
      return false;
    }
    return order.status != QueueOrderStatus.completed &&
        order.status != QueueOrderStatus.awaitingCustomerConfirmation &&
        order.status != QueueOrderStatus.failed &&
        order.status != QueueOrderStatus.cancelled &&
        order.status != QueueOrderStatus.refunded;
  }

  bool _sameUtcDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Set<MobileNetwork> _mobileNetworkSet(Object? value) {
    if (value is! List) return <MobileNetwork>{};
    return value
        .whereType<String>()
        .map((String raw) {
          for (final MobileNetwork network in MobileNetwork.values) {
            if (network.name == raw) return network;
          }
          return null;
        })
        .whereType<MobileNetwork>()
        .toSet();
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  void _validateAutomaticAgentProfile({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> profileData,
    required MobileNetwork network,
    required int amount,
    required _AutomaticAssignmentUsage usage,
  }) {
    if (userData['role'] != 'agent' || userData['isActive'] != true) {
      throw StateError('Cet agent est inactif.');
    }
    if (profileData['availability'] != 'available') {
      throw StateError('Cet agent est indisponible.');
    }
    final Set<MobileNetwork> authorized = _mobileNetworkSet(
      profileData['authorizedNetworks'],
    );
    final Set<MobileNetwork> active = _mobileNetworkSet(
      profileData['activeNetworks'],
    );
    if (!authorized.contains(network) || !active.contains(network)) {
      throw StateError('Ce réseau n’est pas actif pour cet agent.');
    }
    final int availableCapacity =
        _agentCapacityForNetwork(profileData, network) -
        usage.reservedFor(network);
    if (availableCapacity < amount) {
      throw StateError('La capacité disponible de cet agent est insuffisante.');
    }
    final int maxCount = _intValue(profileData['maxTransactionsPerDay']);
    final int maxAmount = _intValue(profileData['dailyTransactionLimit']);

    // 0 = limite non configurée. Les profils historiques ne doivent pas être
    // exclus de l'affectation automatique uniquement parce qu'ils ont été
    // créés avant l'ajout de ces deux champs.
    if (maxCount > 0 && usage.todayCount >= maxCount) {
      throw StateError('La limite quotidienne de transactions est atteinte.');
    }
    if (maxAmount > 0 && usage.todayAmount + amount > maxAmount) {
      throw StateError('La limite quotidienne de montant est atteinte.');
    }
  }

  Future<void> _markManualAssignmentRequired(QueueOrder order) async {
    final DocumentReference<Map<String, dynamic>> orderRef = _ordersCollection
        .doc(order.id);
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueueCollection.doc(order.id);

    final WriteBatch batch = _firestore.batch();
    batch.update(orderRef, <String, dynamic>{
      'manualAssignmentRequired': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(queueRef);
    await batch.commit();
  }

  bool _isWaitingForAutomaticAssignment(QueueOrder order) {
    return order.status == QueueOrderStatus.paidReady &&
        order.isFundedForProcessing &&
        order.assignedAgentId == null &&
        order.assignmentStatus == OrderAssignmentStatus.unassigned &&
        !order.manualAssignmentRequired;
  }

  Future<void> _ensureAutomaticQueueDocument(QueueOrder order) async {
    if (!_isWaitingForAutomaticAssignment(order)) return;
    final DocumentReference<Map<String, dynamic>> ref =
        _autoAssignmentQueueCollection.doc(order.id);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set(
      _automaticQueueDocumentData(
        order: order,
        createdAt: order.paidAt ?? order.createdAt,
        lastRefusedAgentId: order.lastAssignmentRefusedAgentId,
        refusedAgentIds: order.autoAssignmentRefusedAgentIds,
      ),
    );
  }

  Map<String, dynamic> _automaticQueueDocumentData({
    required QueueOrder order,
    required DateTime createdAt,
    String? lastRefusedAgentId,
    List<String>? refusedAgentIds,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'orderId': order.id,
      'orderReference': order.reference,
      'network': order.network.name,
      'amount': order.amount,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRefusedAgentId': lastRefusedAgentId,
      'refusedAgentIds': refusedAgentIds ?? order.autoAssignmentRefusedAgentIds,
    };
  }

  AutomaticAssignmentQueueItem? _automaticQueueItemFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return _automaticQueueItemFromMap(document.id, document.data());
  }

  AutomaticAssignmentQueueItem? _automaticQueueItemFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();
    if (data == null) return null;
    return _automaticQueueItemFromMap(document.id, data);
  }

  AutomaticAssignmentQueueItem? _automaticQueueItemFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final String orderId = _stringValue(data['orderId'], fallback: documentId);
    final String orderReference = _stringValue(data['orderReference']);
    final String networkRaw = _stringValue(data['network']);
    final int amount = _intValue(data['amount']);
    final Object? createdRaw = data['createdAt'];
    final DateTime? createdAt = createdRaw is Timestamp
        ? createdRaw.toDate()
        : createdRaw is DateTime
        ? createdRaw
        : null;
    MobileNetwork? network;
    for (final MobileNetwork item in MobileNetwork.values) {
      if (item.name == networkRaw) {
        network = item;
        break;
      }
    }
    if (orderId.isEmpty ||
        orderReference.isEmpty ||
        network == null ||
        amount <= 0 ||
        createdAt == null) {
      return null;
    }
    final String? lastRefusedAgentId = _cleanNullable(
      data['lastRefusedAgentId'] is String
          ? data['lastRefusedAgentId'] as String
          : null,
    );
    final List<String> refusedAgentIds = data['refusedAgentIds'] is List
        ? (data['refusedAgentIds'] as List<dynamic>)
              .whereType<String>()
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : <String>[?lastRefusedAgentId];

    return AutomaticAssignmentQueueItem(
      orderId: orderId,
      orderReference: orderReference,
      network: network,
      amount: amount,
      createdAt: createdAt,
      lastRefusedAgentId: lastRefusedAgentId,
      refusedAgentIds: refusedAgentIds,
    );
  }

  Map<String, int> _buildActiveAssignmentCounts(List<QueueOrder> orders) {
    final Map<String, int> counts = <String, int>{};
    for (final QueueOrder order in orders) {
      final String? agentId = order.assignedAgentId;
      if (agentId == null || agentId.isEmpty) continue;
      if (order.assignmentStatus != OrderAssignmentStatus.assigned &&
          order.assignmentStatus != OrderAssignmentStatus.accepted) {
        continue;
      }
      if (order.status == QueueOrderStatus.completed ||
          order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
          order.status == QueueOrderStatus.failed ||
          order.status == QueueOrderStatus.cancelled ||
          order.status == QueueOrderStatus.refunded) {
        continue;
      }
      counts[agentId] = (counts[agentId] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
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
    required _AuditActor actor,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'orderId': orderId,
      'orderReference': orderReference,
      'type': type.value,
      'actorId': actor.id,
      'actorRole': actor.role,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }

  Future<_AuditActor> _currentStaffActor() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw StateError('Aucun utilisateur connecté pour cette action.');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _usersCollection.doc(currentUser.uid).get();
    final Map<String, dynamic>? data = snapshot.data();
    final String role = _stringValue(data?['role']);

    if (!snapshot.exists ||
        data == null ||
        data['isActive'] != true ||
        !<String>{'operator', 'supervisor', 'admin'}.contains(role)) {
      throw StateError(
        'Le profil connecté ne peut pas effectuer cette action.',
      );
    }

    return _AuditActor(id: currentUser.uid, role: role);
  }

  String _agentCapacityFieldForNetwork(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return 'orangeCapacity';
      case MobileNetwork.mtn:
        return 'mtnCapacity';
      case MobileNetwork.moov:
        return 'moovCapacity';
    }
  }

  String _agentMovementMarkerFieldForNetwork(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return 'lastOrangeMovementId';
      case MobileNetwork.mtn:
        return 'lastMtnMovementId';
      case MobileNetwork.moov:
        return 'lastMoovMovementId';
    }
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

class _AutomaticAssignmentUsage {
  const _AutomaticAssignmentUsage({
    required this.activeCount,
    required this.orangeReservedAmount,
    required this.mtnReservedAmount,
    required this.moovReservedAmount,
    required this.todayCount,
    required this.todayAmount,
    required this.lastAssignedAt,
  });

  final int activeCount;
  final int orangeReservedAmount;
  final int mtnReservedAmount;
  final int moovReservedAmount;
  final int todayCount;
  final int todayAmount;
  final DateTime? lastAssignedAt;

  int reservedFor(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return orangeReservedAmount;
      case MobileNetwork.mtn:
        return mtnReservedAmount;
      case MobileNetwork.moov:
        return moovReservedAmount;
    }
  }
}

class _AuditActor {
  const _AuditActor({required this.id, required this.role});

  final String id;
  final String role;
}
