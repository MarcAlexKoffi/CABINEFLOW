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

  @override
  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderDraft draft,
  }) async {
    _validateDraft(draft);

    final User customer = await _ensureAnonymousCustomer();
    final DocumentReference<Map<String, dynamic>> document = _firestore
        .collection('orders')
        .doc();

    final DateTime now = DateTime.now();
    final String reference = _buildReference(
      date: now,
      documentId: document.id,
    );

    await document.set(
      _buildOrderData(
        draft: draft,
        customerUid: customer.uid,
        reference: reference,
        now: now,
      ),
    );

    return CustomerOrderReceipt(
      id: document.id,
      reference: reference,
      draft: draft,
      createdAt: now,
      paymentDeclaredAt: now,
      status: CustomerOrderTrackingStatus.paymentDeclared,
    );
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
    required DateTime now,
  }) {
    final String offerLabel = draft.selectedOfferLabel!;

    return <String, dynamic>{
      'schemaVersion': 1,
      'reference': reference,
      'source': 'customerWeb',
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
      'paymentStatus': 'declared',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'paymentRequestSentAt': FieldValue.serverTimestamp(),
      'paymentDeclaredAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.toUtc().add(paymentValidity)),
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

  String _buildReference({required DateTime date, required String documentId}) {
    final DateTime localDate = date.toLocal();
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    final String suffix = documentId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .substring(0, 6)
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
