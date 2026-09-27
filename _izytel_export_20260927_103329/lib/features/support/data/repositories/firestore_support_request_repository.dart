import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreSupportRequestRepository implements SupportRequestRepository {
  FirestoreSupportRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('supportRequests');
  }

  @override
  Future<SupportRequest> create({
    required String orderId,
    required String orderReference,
    required SupportRequestType type,
    required String description,
  }) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('La session client n’est pas disponible.');
    }

    final String cleanedOrderId = orderId.trim();
    final String cleanedReference = orderReference.trim().toUpperCase();
    final String cleanedDescription = description.trim();

    if (cleanedOrderId.isEmpty || cleanedReference.length < 8) {
      throw ArgumentError('La commande associée est invalide.');
    }
    if (cleanedDescription.length > 1000) {
      throw ArgumentError('La description est trop longue.');
    }
    if (type == SupportRequestType.other && cleanedDescription.length < 3) {
      throw ArgumentError('Précisez le problème en quelques mots.');
    }

    final DocumentReference<Map<String, dynamic>> document = _collection.doc();
    final DateTime now = DateTime.now();

    await document.set(<String, dynamic>{
      'schemaVersion': 1,
      'orderId': cleanedOrderId,
      'orderReference': cleanedReference,
      'customerAuthUid': user.uid,
      'type': type.storageValue,
      'description': cleanedDescription,
      'status': SupportRequestStatus.newRequest.storageValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedTo': null,
      'assignedToName': null,
      'inProgressAt': null,
      'resolutionNote': null,
      'resolvedAt': null,
      'resolvedBy': null,
      'resolvedByName': null,
      'customerNotifiedAt': null,
      'customerNotifiedBy': null,
      'customerNotifiedByName': null,
      'notificationChannel': null,
      'closedAt': null,
      'closedBy': null,
      'closedByName': null,
    });

    return SupportRequest(
      id: document.id,
      orderId: cleanedOrderId,
      orderReference: cleanedReference,
      customerAuthUid: user.uid,
      type: type,
      description: cleanedDescription,
      status: SupportRequestStatus.newRequest,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Stream<List<SupportRequest>> watchNewRequests() {
    return _collection
        .where(
          'status',
          isEqualTo: SupportRequestStatus.newRequest.storageValue,
        )
        .snapshots()
        .map(_mapSnapshot);
  }

  @override
  Stream<List<SupportRequest>> watchAllRequests() {
    return _collection.snapshots().map(_mapSnapshot);
  }

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) {
    return _collection
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map(_mapSnapshot);
  }

  @override
  Future<void> takeInCharge({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    final String cleanedId = requestId.trim();
    final String cleanedStaffId = staffId.trim();
    final String cleanedStaffName = staffName.trim();
    if (cleanedId.isEmpty ||
        cleanedStaffId.isEmpty ||
        cleanedStaffName.isEmpty) {
      throw ArgumentError(
        'Les informations de prise en charge sont invalides.',
      );
    }

    await _collection.doc(cleanedId).update(<String, dynamic>{
      'status': SupportRequestStatus.inProgress.storageValue,
      'assignedTo': cleanedStaffId,
      'assignedToName': cleanedStaffName,
      'inProgressAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> resolve({
    required String requestId,
    required String staffId,
    required String staffName,
    required String resolutionNote,
  }) async {
    final String cleanedNote = resolutionNote.trim();
    if (cleanedNote.length < 3) {
      throw ArgumentError('Ajoutez une note de résolution.');
    }
    if (cleanedNote.length > 1000) {
      throw ArgumentError('La note de résolution est trop longue.');
    }

    await _collection.doc(requestId.trim()).update(<String, dynamic>{
      'status': SupportRequestStatus.resolved.storageValue,
      'resolutionNote': cleanedNote,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': staffId.trim(),
      'resolvedByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markCustomerNotified({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    await _collection.doc(requestId.trim()).update(<String, dynamic>{
      'customerNotifiedAt': FieldValue.serverTimestamp(),
      'customerNotifiedBy': staffId.trim(),
      'customerNotifiedByName': staffName.trim(),
      'notificationChannel': 'whatsapp',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> close({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    await _collection.doc(requestId.trim()).update(<String, dynamic>{
      'status': SupportRequestStatus.closed.storageValue,
      'closedAt': FieldValue.serverTimestamp(),
      'closedBy': staffId.trim(),
      'closedByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<SupportRequest> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<SupportRequest> requests = snapshot.docs
        .map(_fromDocument)
        .whereType<SupportRequest>()
        .toList(growable: false);
    requests.sort(
      (SupportRequest a, SupportRequest b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return requests;
  }

  SupportRequest? _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String? orderId = data['orderId'] as String?;
    final String? orderReference = data['orderReference'] as String?;
    final String? customerAuthUid = data['customerAuthUid'] as String?;
    final String? type = data['type'] as String?;
    final String? status = data['status'] as String?;
    final DateTime? createdAt = _readDate(data['createdAt']);
    final DateTime? updatedAt = _readDate(data['updatedAt']);

    if (orderId == null ||
        orderReference == null ||
        customerAuthUid == null ||
        type == null ||
        status == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return SupportRequest(
      id: document.id,
      orderId: orderId,
      orderReference: orderReference,
      customerAuthUid: customerAuthUid,
      type: SupportRequestTypeX.fromStorage(type),
      description: (data['description'] as String?) ?? '',
      status: SupportRequestStatusX.fromStorage(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
      inProgressAt: _readDate(data['inProgressAt']),
      resolutionNote: data['resolutionNote'] as String?,
      resolvedAt: _readDate(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
      resolvedByName: data['resolvedByName'] as String?,
      customerNotifiedAt: _readDate(data['customerNotifiedAt']),
      customerNotifiedBy: data['customerNotifiedBy'] as String?,
      customerNotifiedByName: data['customerNotifiedByName'] as String?,
      notificationChannel: data['notificationChannel'] as String?,
      closedAt: _readDate(data['closedAt']),
      closedBy: data['closedBy'] as String?,
      closedByName: data['closedByName'] as String?,
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
}
