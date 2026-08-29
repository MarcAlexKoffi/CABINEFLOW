import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRefundRepository implements RefundRepository {
  FirestoreRefundRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('refunds');

  @override
  Stream<List<RefundCase>> watchAll() {
    return _collection.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<RefundCase> values = snapshot.docs
          .map(_fromQueryDocument)
          .whereType<RefundCase>()
          .toList(growable: false);
      values.sort(
        (RefundCase first, RefundCase second) =>
            second.requestedAt.compareTo(first.requestedAt),
      );
      return values;
    });
  }

  @override
  Stream<RefundCase?> watchForOrder({required String orderId}) {
    final String cleanedOrderId = orderId.trim();
    if (cleanedOrderId.isEmpty) {
      return Stream<RefundCase?>.value(null);
    }
    return _collection.doc(cleanedOrderId).snapshots().map(_fromDocument);
  }

  @override
  Future<RefundCase> create({
    required RefundCreationRequest request,
    required String staffId,
    required String staffName,
  }) async {
    final String orderId = request.orderId.trim();
    final String orderReference = request.orderReference.trim().toUpperCase();
    final String supportRequestId = request.supportRequestId.trim();
    final String cleanedStaffId = staffId.trim();
    final String cleanedStaffName = staffName.trim();
    final String clientName = request.clientName.trim();
    final String clientPhone = request.clientWhatsappPhone.trim();
    final String reasonNote = request.reasonNote.trim();
    final String supportDescription = request.supportRequestDescription.trim();
    final String? paymentReference = _cleanNullable(
      request.originalPaymentReference,
    );
    final String? customerUid = _cleanNullable(request.customerAuthUid);

    if (orderId.isEmpty || orderReference.length < 8) {
      throw ArgumentError('La commande associée est invalide.');
    }
    if (supportRequestId.isEmpty) {
      throw ArgumentError('La demande client associée est obligatoire.');
    }
    if (cleanedStaffId.isEmpty || cleanedStaffName.length < 2) {
      throw ArgumentError('L’administrateur est invalide.');
    }
    if (request.originalAmount <= 0 ||
        request.amount <= 0 ||
        request.amount > request.originalAmount) {
      throw ArgumentError('Le montant à rembourser est invalide.');
    }
    if (reasonNote.length > 500) {
      throw ArgumentError('La note du remboursement est trop longue.');
    }
    if (request.reason == RefundReason.other && reasonNote.length < 3) {
      throw ArgumentError('Précisez le motif du remboursement.');
    }

    final DocumentReference<Map<String, dynamic>> document = _collection.doc(
      orderId,
    );
    final DateTime now = DateTime.now();

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await transaction
          .get(document);
      if (existing.exists) {
        throw StateError('Un remboursement existe déjà pour cette commande.');
      }

      transaction.set(document, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': orderId,
        'orderReference': orderReference,
        'supportRequestId': supportRequestId,
        'supportRequestType': request.supportRequestType.trim(),
        'supportRequestDescription': supportDescription,
        'customerAuthUid': customerUid,
        'clientName': clientName,
        'clientWhatsappPhone': clientPhone,
        'originalAmount': request.originalAmount,
        'amount': request.amount,
        'reason': request.reason.storageValue,
        'reasonNote': reasonNote,
        'paymentChannel': 'wave',
        'originalPaymentReference': paymentReference,
        'status': RefundStatus.pendingApproval.storageValue,
        'requestedAt': FieldValue.serverTimestamp(),
        'requestedBy': cleanedStaffId,
        'requestedByName': cleanedStaffName,
        'approvedAt': null,
        'approvedBy': null,
        'approvedByName': null,
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectedByName': null,
        'rejectionReason': null,
        'refundReference': null,
        'refundedAt': null,
        'refundedBy': null,
        'refundedByName': null,
        'customerNotifiedAt': null,
        'customerNotifiedBy': null,
        'customerNotifiedByName': null,
        'notificationChannel': null,
        'reconciledAt': null,
        'reconciledBy': null,
        'reconciledByName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return RefundCase(
      id: orderId,
      orderId: orderId,
      orderReference: orderReference,
      supportRequestId: supportRequestId,
      supportRequestType: request.supportRequestType.trim(),
      supportRequestDescription: supportDescription,
      customerAuthUid: customerUid,
      clientName: clientName,
      clientWhatsappPhone: clientPhone,
      originalAmount: request.originalAmount,
      amount: request.amount,
      reason: request.reason,
      reasonNote: reasonNote,
      paymentChannel: 'wave',
      originalPaymentReference: paymentReference,
      status: RefundStatus.pendingApproval,
      requestedAt: now,
      requestedBy: cleanedStaffId,
      requestedByName: cleanedStaffName,
      updatedAt: now,
    );
  }

  @override
  Future<void> approve({
    required String orderId,
    required String staffId,
    required String staffName,
  }) {
    return _collection.doc(orderId.trim()).update(<String, dynamic>{
      'status': RefundStatus.approved.storageValue,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': staffId.trim(),
      'approvedByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reject({
    required String orderId,
    required String staffId,
    required String staffName,
    required String reason,
  }) {
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3 || cleanedReason.length > 500) {
      throw ArgumentError('Précisez pourquoi le remboursement est rejeté.');
    }
    return _collection.doc(orderId.trim()).update(<String, dynamic>{
      'status': RefundStatus.rejected.storageValue,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': staffId.trim(),
      'rejectedByName': staffName.trim(),
      'rejectionReason': cleanedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markRefunded({
    required String orderId,
    required String staffId,
    required String staffName,
    required String refundReference,
  }) {
    final String cleanedReference = refundReference.trim();
    if (cleanedReference.length < 3 || cleanedReference.length > 120) {
      throw ArgumentError('Saisissez la référence du remboursement Wave.');
    }
    return _collection.doc(orderId.trim()).update(<String, dynamic>{
      'status': RefundStatus.refunded.storageValue,
      'refundReference': cleanedReference,
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedBy': staffId.trim(),
      'refundedByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markCustomerNotified({
    required String orderId,
    required String staffId,
    required String staffName,
  }) {
    return _collection.doc(orderId.trim()).update(<String, dynamic>{
      'customerNotifiedAt': FieldValue.serverTimestamp(),
      'customerNotifiedBy': staffId.trim(),
      'customerNotifiedByName': staffName.trim(),
      'notificationChannel': 'whatsapp',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reconcile({
    required String orderId,
    required String staffId,
    required String staffName,
  }) {
    return _collection.doc(orderId.trim()).update(<String, dynamic>{
      'status': RefundStatus.reconciled.storageValue,
      'reconciledAt': FieldValue.serverTimestamp(),
      'reconciledBy': staffId.trim(),
      'reconciledByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  RefundCase? _fromQueryDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return _fromData(document.id, document.data());
  }

  RefundCase? _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final Map<String, dynamic>? data = document.data();
    if (!document.exists || data == null) {
      return null;
    }
    return _fromData(document.id, data);
  }

  RefundCase? _fromData(String id, Map<String, dynamic> data) {
    final String? orderId = data['orderId'] as String?;
    final String? orderReference = data['orderReference'] as String?;
    final String? supportRequestId = data['supportRequestId'] as String?;
    final String? supportRequestType = data['supportRequestType'] as String?;
    final String? clientName = data['clientName'] as String?;
    final String? clientPhone = data['clientWhatsappPhone'] as String?;
    final int? originalAmount = data['originalAmount'] as int?;
    final int? amount = data['amount'] as int?;
    final String? reason = data['reason'] as String?;
    final String? paymentChannel = data['paymentChannel'] as String?;
    final String? status = data['status'] as String?;
    final DateTime? requestedAt = _readDate(data['requestedAt']);
    final String? requestedBy = data['requestedBy'] as String?;
    final String? requestedByName = data['requestedByName'] as String?;
    final DateTime? updatedAt = _readDate(data['updatedAt']);

    if (orderId == null ||
        orderReference == null ||
        supportRequestId == null ||
        supportRequestType == null ||
        clientName == null ||
        clientPhone == null ||
        originalAmount == null ||
        amount == null ||
        reason == null ||
        paymentChannel == null ||
        status == null ||
        requestedAt == null ||
        requestedBy == null ||
        requestedByName == null ||
        updatedAt == null) {
      return null;
    }

    return RefundCase(
      id: id,
      orderId: orderId,
      orderReference: orderReference,
      supportRequestId: supportRequestId,
      supportRequestType: supportRequestType,
      supportRequestDescription:
          (data['supportRequestDescription'] as String?) ?? '',
      customerAuthUid: data['customerAuthUid'] as String?,
      clientName: clientName,
      clientWhatsappPhone: clientPhone,
      originalAmount: originalAmount,
      amount: amount,
      reason: RefundReasonX.fromStorage(reason),
      reasonNote: (data['reasonNote'] as String?) ?? '',
      paymentChannel: paymentChannel,
      originalPaymentReference: data['originalPaymentReference'] as String?,
      status: RefundStatusX.fromStorage(status),
      requestedAt: requestedAt,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      updatedAt: updatedAt,
      approvedAt: _readDate(data['approvedAt']),
      approvedBy: data['approvedBy'] as String?,
      approvedByName: data['approvedByName'] as String?,
      rejectedAt: _readDate(data['rejectedAt']),
      rejectedBy: data['rejectedBy'] as String?,
      rejectedByName: data['rejectedByName'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      refundReference: data['refundReference'] as String?,
      refundedAt: _readDate(data['refundedAt']),
      refundedBy: data['refundedBy'] as String?,
      refundedByName: data['refundedByName'] as String?,
      customerNotifiedAt: _readDate(data['customerNotifiedAt']),
      customerNotifiedBy: data['customerNotifiedBy'] as String?,
      customerNotifiedByName: data['customerNotifiedByName'] as String?,
      notificationChannel: data['notificationChannel'] as String?,
      reconciledAt: _readDate(data['reconciledAt']),
      reconciledBy: data['reconciledBy'] as String?,
      reconciledByName: data['reconciledByName'] as String?,
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

  String? _cleanNullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
