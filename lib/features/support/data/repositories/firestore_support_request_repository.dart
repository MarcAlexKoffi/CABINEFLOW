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
      'resolvedAt': null,
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
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<SupportRequest> requests = snapshot.docs
              .map(_fromDocument)
              .whereType<SupportRequest>()
              .toList(growable: false);
          requests.sort(
            (SupportRequest a, SupportRequest b) =>
                b.createdAt.compareTo(a.createdAt),
          );
          return requests;
        });
  }

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) {
    return _collection.where('orderId', isEqualTo: orderId).snapshots().map((
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
    });
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
      resolvedAt: _readDate(data['resolvedAt']),
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
