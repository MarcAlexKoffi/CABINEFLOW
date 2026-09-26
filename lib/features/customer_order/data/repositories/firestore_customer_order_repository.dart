import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/supabase_customer_order_recovery_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/supabase_customer_order_status_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_recovery_key.dart';
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
  static final DateTime _wc2RecoveryCutover = DateTime.utc(2026, 9, 22);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  Future<User>? _anonymousCustomerFuture;
  final Set<String> _recoveredOrderIds = <String>{};
  final Set<String> _recoveryKeysEnsuredForOrderIds = <String>{};
  final Map<String, String> _recoveryCodesByOrderId = <String, String>{};
  final Map<String, String> _supabaseRecoveredCodesByOrderId = <String, String>{};

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return _firestore.collection('orders');
  }

  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    return _firestore.collection('orderEvents');
  }

  CollectionReference<Map<String, dynamic>> get _recoveryKeysCollection {
    return _firestore.collection('orderRecoveryKeys');
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
    final String recoveryCode = CustomerOrderRecoveryKey.generateCode();

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

    final CustomerOrderReceipt createdOrder = CustomerOrderReceipt(
      id: document.id,
      reference: reference,
      draft: draft,
      createdAt: now,
      expiresAt: expiresAt,
      status: QueueOrderStatus.awaitingPayment,
      paymentStatus: OrderPaymentStatus.notDeclared,
      recoveryCode: recoveryCode,
    );
    _recoveryCodesByOrderId[createdOrder.id] = recoveryCode;
    await _registerSupabaseRecoverySafely(createdOrder);
    return createdOrder;
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

    final CustomerOrderReceipt updatedOrder =
        await _firestore.runTransaction<CustomerOrderReceipt>((
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
    await _registerSupabaseRecoverySafely(updatedOrder);
    return updatedOrder;
  }

  @override
  Future<CustomerOrderReceipt> synchronizeExpiration({
    required CustomerOrderReceipt order,
  }) {
    return _synchronizeExpirationIfNeeded(order);
  }

  @override
  Future<CustomerOrderReceipt> recoverOrder({
    required String reference,
    required String whatsappInput,
  }) async {
    final User customer = await _ensureAnonymousCustomer();
    final String normalizedReference =
        CustomerOrderRecoveryKey.normalizeReference(reference);
    if (CustomerOrderRecoveryKey.validateReference(normalizedReference) !=
        null) {
      throw const FormatException('Référence de commande invalide.');
    }

    final WhatsappPhoneNumber whatsappPhone = WhatsappPhoneNumber.parse(
      whatsappInput,
    );
    final String recoveryKey = CustomerOrderRecoveryKey.build(
      reference: normalizedReference,
      whatsappPhone: whatsappPhone,
    );
    final DocumentReference<Map<String, dynamic>> recoveryKeyRef =
        _recoveryKeysCollection.doc(recoveryKey);

    final DocumentSnapshot<Map<String, dynamic>> recoverySnapshot =
        await recoveryKeyRef.get();
    final Map<String, dynamic>? recoveryData = recoverySnapshot.data();
    if (!recoverySnapshot.exists || recoveryData == null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    final String? orderId = _readNullableString(recoveryData['orderId']);
    final String? storedReference = _readNullableString(
      recoveryData['orderReference'],
    );
    final String? storedWhatsapp = _readNullableString(
      recoveryData['whatsappPhone'],
    );
    if (orderId == null ||
        storedReference != normalizedReference ||
        storedWhatsapp != whatsappPhone.normalized) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    final DocumentReference<Map<String, dynamic>> accessRef = _firestore
        .collection('orderRecoveryAccess')
        .doc(orderId)
        .collection('customers')
        .doc(customer.uid);
    final DocumentSnapshot<Map<String, dynamic>> accessSnapshot =
        await accessRef.get();
    if (!accessSnapshot.exists) {
      await accessRef.set(<String, dynamic>{
        'schemaVersion': 1,
        'customerAuthUid': customer.uid,
        'recoveryKey': recoveryKey,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
        await _ordersCollection.doc(orderId).get();
    final Map<String, dynamic>? orderData = orderSnapshot.data();
    if (!orderSnapshot.exists || orderData == null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    if (_readNullableString(orderData['reference']) != normalizedReference ||
        _readNullableString(orderData['clientWhatsappPhone']) !=
            whatsappPhone.normalized) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    final CustomerOrderReceipt? recoveredOrder = _receiptFromDocument(
      id: orderSnapshot.id,
      data: orderData,
    );
    if (recoveredOrder == null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    _recoveredOrderIds.add(orderId);
    return _overlayOperationalStatus(recoveredOrder);
  }

  @override
  Future<CustomerOrderReceipt> recoverOrderByCode({
    required String reference,
    required String recoveryCodeInput,
  }) async {
    await _ensureAnonymousCustomer();
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('Le service de recuperation est temporairement indisponible.');
    }

    final String normalizedReference =
        CustomerOrderRecoveryKey.normalizeReference(reference);
    final String normalizedCode = CustomerOrderRecoveryKey.normalizeCode(
      recoveryCodeInput,
    );

    if (CustomerOrderRecoveryKey.validateReference(normalizedReference) !=
            null ||
        CustomerOrderRecoveryKey.validateCode(normalizedCode) != null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    final Map<String, dynamic>? row =
        await SupabaseCustomerOrderRecoveryRepository().recover(
          reference: normalizedReference,
          recoveryCode: normalizedCode,
        );
    if (row == null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    final CustomerOrderReceipt? receipt = _receiptFromSupabaseRecoveryRow(
      row,
      recoveryCode: normalizedCode,
    );
    if (receipt == null) {
      throw StateError('Commande introuvable ou informations incorrectes.');
    }

    _recoveredOrderIds.add(receipt.id);
    _recoveryCodesByOrderId[receipt.id] = normalizedCode;
    _supabaseRecoveredCodesByOrderId[receipt.id] = normalizedCode;
    return receipt;
  }

  @override
  Future<CustomerOrderReceipt> findCustomerOrder({
    required MobileNetwork network,
    required CustomerService service,
    required String beneficiaryInput,
  }) async {
    final User customer = await _ensureAnonymousCustomer();
    final BeneficiaryPhoneNumber beneficiary = BeneficiaryPhoneNumber.parse(
      beneficiaryInput,
    );
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .where('customerAuthUid', isEqualTo: customer.uid)
        .get();
    final List<CustomerOrderReceipt> orders =
        await _receiptsFromCustomerSnapshot(snapshot);

    for (final CustomerOrderReceipt order in orders) {
      if (order.draft.network == network &&
          order.draft.service == service &&
          order.draft.beneficiaryNumber?.normalized == beneficiary.normalized) {
        return _overlayOperationalStatus(order);
      }
    }

    throw StateError('Commande introuvable ou informations incorrectes.');
  }

  @override
  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  }) {
    final String? recoveredCode = _supabaseRecoveredCodesByOrderId[order.id];
    if (recoveredCode == null && order.recoveryCode != null) {
      unawaited(_registerSupabaseRecoverySafely(order));
    }
    if (recoveredCode != null && SupabaseBootstrap.isInitialized) {
      return SupabaseCustomerOrderRecoveryRepository()
          .watch(reference: order.reference, recoveryCode: recoveredCode)
          .map((Map<String, dynamic> row) {
            final CustomerOrderReceipt? recovered =
                _receiptFromSupabaseRecoveryRow(
                  row,
                  recoveryCode: recoveredCode,
                );
            if (recovered == null) {
              throw StateError('La commande suivie est introuvable.');
            }
            return recovered;
          });
    }

    if (!SupabaseBootstrap.isInitialized) {
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
        if (_recoveredOrderIds.contains(order.id)) return currentOrder;
        return _synchronizeExpirationIfNeeded(currentOrder);
      });
    }

    late final StreamController<CustomerOrderReceipt> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? firestoreSub;
    Timer? refreshTimer;
    CustomerOrderReceipt latest = order;
    bool refreshing = false;

    Future<void> refresh() async {
      if (refreshing || controller.isClosed) return;
      refreshing = true;
      try {
        final CustomerOrderReceipt value = await _overlayOperationalStatus(latest);
        latest = value;
        if (!controller.isClosed) controller.add(value);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        refreshing = false;
      }
    }

    controller = StreamController<CustomerOrderReceipt>(
      onListen: () {
        firestoreSub = _ordersCollection.doc(order.id).snapshots().listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) async {
            final Map<String, dynamic>? data = snapshot.data();
            if (!snapshot.exists || data == null) {
              if (!controller.isClosed) {
                controller.addError(StateError('La commande suivie est introuvable.'));
              }
              return;
            }
            CustomerOrderReceipt current = _receiptFromData(
              fallbackOrder: latest,
              data: data,
            );
            if (!_recoveredOrderIds.contains(order.id)) {
              current = await _synchronizeExpirationIfNeeded(current);
            }
            latest = current;
            await refresh();
          },
          onError: controller.addError,
        );
        refreshTimer = Timer.periodic(
          SupabaseCustomerOrderStatusRepository.pollInterval,
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        refreshTimer?.cancel();
        await firestoreSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<CustomerOrderReceipt>> watchCustomerOrders() async* {
    final User customer = await _ensureAnonymousCustomer();
    final Stream<QuerySnapshot<Map<String, dynamic>>> firestoreStream =
        _ordersCollection
            .where('customerAuthUid', isEqualTo: customer.uid)
            .snapshots();

    if (!SupabaseBootstrap.isInitialized) {
      yield* firestoreStream.asyncMap(_receiptsFromCustomerSnapshot);
      return;
    }

    late final StreamController<List<CustomerOrderReceipt>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    Timer? refreshTimer;
    List<CustomerOrderReceipt> latest = const <CustomerOrderReceipt>[];
    bool refreshing = false;

    Future<void> refresh() async {
      if (refreshing || controller.isClosed || latest.isEmpty) return;
      refreshing = true;
      try {
        final List<CustomerOrderReceipt> overlaid = await Future.wait(
          latest.map(_overlayOperationalStatus),
        );
        overlaid.sort((CustomerOrderReceipt a, CustomerOrderReceipt b) =>
            b.createdAt.compareTo(a.createdAt));
        latest = List<CustomerOrderReceipt>.unmodifiable(overlaid);
        if (!controller.isClosed) controller.add(latest);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        refreshing = false;
      }
    }

    controller = StreamController<List<CustomerOrderReceipt>>(
      onListen: () {
        firestoreSub = firestoreStream.listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) async {
            try {
              latest = await _receiptsFromCustomerSnapshot(snapshot);
              if (latest.isEmpty && !controller.isClosed) {
                controller.add(latest);
              } else {
                await refresh();
              }
            } catch (error, stackTrace) {
              if (!controller.isClosed) controller.addError(error, stackTrace);
            }
          },
          onError: controller.addError,
        );
        refreshTimer = Timer.periodic(
          SupabaseCustomerOrderStatusRepository.pollInterval,
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        refreshTimer?.cancel();
        await firestoreSub?.cancel();
      },
    );
    yield* controller.stream;
  }

  Future<List<CustomerOrderReceipt>> _receiptsFromCustomerSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final List<CustomerOrderReceipt> orders = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return _receiptFromDocument(id: document.id, data: document.data());
        })
        .whereType<CustomerOrderReceipt>()
        .toList();
    final List<CustomerOrderReceipt> synchronized = await Future.wait(
      orders.map(_synchronizeExpirationIfNeeded),
    );
    await Future.wait(synchronized.map(_ensureRecoveryKeySafely));
    synchronized.sort((CustomerOrderReceipt a, CustomerOrderReceipt b) =>
        b.createdAt.compareTo(a.createdAt));
    return synchronized;
  }

  Future<CustomerOrderReceipt> _overlayOperationalStatus(
    CustomerOrderReceipt receipt,
  ) async {
    if (!SupabaseBootstrap.isInitialized ||
        (!receipt.isPaymentConfirmed &&
            receipt.paymentStatus != OrderPaymentStatus.credit &&
            receipt.status.index < QueueOrderStatus.paidReady.index)) {
      return receipt;
    }
    try {
      return await SupabaseCustomerOrderStatusRepository().overlay(receipt);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerOrder.operational-status',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      return receipt;
    }
  }

  Future<void> _registerSupabaseRecoverySafely(
    CustomerOrderReceipt order,
  ) async {
    final String? recoveryCode = order.recoveryCode?.trim();
    if (!SupabaseBootstrap.isInitialized ||
        recoveryCode == null ||
        recoveryCode.isEmpty) {
      return;
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await SupabaseCustomerOrderRecoveryRepository().register(
          order: order,
          recoveryCode: recoveryCode,
        );
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (!BackendFailurePolicy.canRetryRead(error) || attempt == 2) break;
        await Future<void>.delayed(
          BackendFailurePolicy.retryDelay(
            baseDelay: const Duration(milliseconds: 500),
            consecutiveFailures: attempt,
          ),
        );
      }
    }

    IzyTelLog.backendError(
      'CustomerOrder.recovery-register',
      lastError ?? StateError('Enregistrement du code impossible.'),
      stackTrace: lastStackTrace,
    );
  }

  Future<void> _ensureRecoveryKeySafely(CustomerOrderReceipt order) async {
    // Compatibilite Phase 10B uniquement. A partir de WC2, aucune nouvelle
    // commande ne cree de secret de recuperation reference + WhatsApp dans
    // Firestore. Les nouvelles commandes utilisent le registre Supabase.
    if (!order.createdAt.toUtc().isBefore(_wc2RecoveryCutover) ||
        _recoveryKeysEnsuredForOrderIds.contains(order.id)) {
      return;
    }

    final CustomerIdentity? identity = order.draft.identity;
    if (identity == null) return;

    final String recoveryKey = CustomerOrderRecoveryKey.build(
      reference: order.reference,
      whatsappPhone: identity.whatsappNumber,
    );
    final DocumentReference<Map<String, dynamic>> recoveryRef =
        _recoveryKeysCollection.doc(recoveryKey);

    try {
      final DocumentSnapshot<Map<String, dynamic>> existing =
          await recoveryRef.get();
      if (!existing.exists) {
        await recoveryRef.set(<String, dynamic>{
          'schemaVersion': 1,
          'orderId': order.id,
          'orderReference': order.reference,
          'whatsappPhone': identity.whatsappNumber.normalized,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _recoveryKeysEnsuredForOrderIds.add(order.id);
    } on Object catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerOrder.legacy-recovery-key',
        error,
        stackTrace: stackTrace,
      );
    }
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

    final CustomerOrderReceipt synchronizedOrder =
        await _firestore.runTransaction<CustomerOrderReceipt>((
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
    await _registerSupabaseRecoverySafely(synchronizedOrder);
    return synchronizedOrder;
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
    final CustomerOrderReceipt? parsed = _receiptFromDocument(
      id: fallbackOrder.id,
      data: data,
    );
    if (parsed == null) return fallbackOrder;
    if (parsed.recoveryCode == null && fallbackOrder.recoveryCode != null) {
      return parsed.copyWith(recoveryCode: fallbackOrder.recoveryCode);
    }
    return parsed;
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
        recoveryCode: _recoveryCodesByOrderId[id],
        failureMessage: observation ?? failureReason,
      );
    } on Object {
      return null;
    }
  }

  CustomerOrderReceipt? _receiptFromSupabaseRecoveryRow(
    Map<String, dynamic> data, {
    required String recoveryCode,
  }) {
    try {
      final String orderId = _readString(data['order_id'])!;
      final String reference = _readString(data['order_reference'])!;
      final CustomerService service = CustomerService.values.firstWhere(
        (CustomerService item) => item.name == data['service'],
      );
      final MobileNetwork network = MobileNetwork.values.firstWhere(
        (MobileNetwork item) => item.name == data['network'],
      );
      final BeneficiaryPhoneNumber beneficiaryNumber =
          BeneficiaryPhoneNumber.parse(
            _readString(data['beneficiary_phone'])!,
          );
      final String offerLabel =
          _readString(data['offer_label']) ?? service.label;
      final int amount = _readInt(data['amount']);
      final String? offerId = _readNullableString(data['offer_id']);
      final bool isCustomOffer = data['is_custom_offer'] == true;
      final CustomerOffer? recoveredOffer =
          service == CustomerService.unitTransfer ||
              isCustomOffer ||
              offerId == null
          ? null
          : CustomerOffer(
              id: offerId,
              network: network,
              type: service == CustomerService.internetSubscription
                  ? CustomerOfferType.internet
                  : CustomerOfferType.calls,
              title: offerLabel,
              catalogLabel: offerLabel,
              amount: amount,
              details: const <String>[],
            );
      final DateTime createdAt =
          _readDate(data['created_at']) ?? DateTime.now();
      final DateTime expiresAt =
          _readDate(data['expires_at']) ?? createdAt.add(paymentValidity);
      final String? failureReason = _readNullableString(data['failure_reason']);
      final String? observation = _readNullableString(data['observation']);

      final CustomerOrderDraft draft = CustomerOrderDraft(
        service: service,
        network: network,
        offer: recoveredOffer,
        customOfferLabel: service == CustomerService.unitTransfer
            ? null
            : isCustomOffer
            ? offerLabel
            : null,
        amount: amount,
        beneficiaryNumber: beneficiaryNumber,
      );

      return CustomerOrderReceipt(
        id: orderId,
        reference: reference,
        draft: draft,
        createdAt: createdAt,
        expiresAt: expiresAt,
        paymentDeclaredAt: _readDate(data['payment_declared_at']),
        paymentConfirmedAt: _readDate(data['payment_confirmed_at']),
        processingStartedAt: _readDate(data['processing_started_at']),
        completedAt: _readDate(data['completed_at']),
        expiredAt: _readDate(data['expired_at']) ??
            (_readOrderStatus(data['order_status']) == QueueOrderStatus.expired
                ? _readDate(data['updated_at']) ?? expiresAt
                : null),
        status: _readOrderStatus(data['order_status']),
        paymentStatus: _readPaymentStatus(data['payment_status']),
        recoveryCode: recoveryCode,
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

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
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
