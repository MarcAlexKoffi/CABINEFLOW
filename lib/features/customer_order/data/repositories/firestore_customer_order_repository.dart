import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
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

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return _firestore.collection('orders');
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

    await document.set(
      _buildOrderData(
        draft: draft,
        customerUid: customer.uid,
        reference: reference,
        expiresAt: expiresAt,
      ),
    );

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
  }) async {
    final User customer = await _ensureAnonymousCustomer();
    final DocumentReference<Map<String, dynamic>> document = _ordersCollection
        .doc(order.id);
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

      if (currentStatus == QueueOrderStatus.paymentToVerify &&
          currentPaymentStatus == OrderPaymentStatus.declared) {
        return _receiptFromData(order: order, data: data);
      }

      if (currentStatus != QueueOrderStatus.awaitingPayment ||
          currentPaymentStatus != OrderPaymentStatus.notDeclared) {
        throw StateError(
          'Le paiement de cette commande a déjà été déclaré ou son statut a changé.',
        );
      }

      transaction.update(document, <String, dynamic>{
        'status': QueueOrderStatus.paymentToVerify.name,
        'paymentStatus': OrderPaymentStatus.declared.name,
        'paymentDeclaredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return order.copyWith(
        status: QueueOrderStatus.paymentToVerify,
        paymentStatus: OrderPaymentStatus.declared,
        paymentDeclaredAt: declaredAt,
      );
    });
  }

  @override
  Stream<CustomerOrderReceipt> watchOrder({
    required CustomerOrderReceipt order,
  }) {
    return _ordersCollection.doc(order.id).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('La commande suivie est introuvable.');
      }

      return _receiptFromData(order: order, data: data);
    });
  }

  Future<User> _ensureAnonymousCustomer() async {
    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser != null) {
      return currentUser;
    }

    final UserCredential credential = await _firebaseAuth.signInAnonymously();
    final User? signedInUser = credential.user;

    if (signedInUser == null) {
      throw StateError('Impossible de créer la session temporaire du client.');
    }

    return signedInUser;
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
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
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
    required CustomerOrderReceipt order,
    required Map<String, dynamic> data,
  }) {
    final String? failureReason = _readNullableString(data['failureReason']);
    final String? observation = _readNullableString(data['observation']);

    return CustomerOrderReceipt(
      id: order.id,
      reference: _readString(data['reference']) ?? order.reference,
      draft: order.draft,
      createdAt: _readDate(data['createdAt']) ?? order.createdAt,
      expiresAt: _readDate(data['expiresAt']) ?? order.expiresAt,
      paymentDeclaredAt:
          _readDate(data['paymentDeclaredAt']) ?? order.paymentDeclaredAt,
      paymentConfirmedAt:
          _readDate(data['paymentConfirmedAt']) ?? order.paymentConfirmedAt,
      processingStartedAt:
          _readDate(data['takenAt']) ?? order.processingStartedAt,
      completedAt: _readDate(data['completedAt']) ?? order.completedAt,
      status: _readOrderStatus(data['status']),
      paymentStatus: _readPaymentStatus(data['paymentStatus']),
      failureMessage: observation ?? failureReason ?? order.failureMessage,
    );
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
