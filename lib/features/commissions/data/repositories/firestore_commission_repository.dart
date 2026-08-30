import 'dart:convert';

import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCommissionRepository implements CommissionRepository {
  FirestoreCommissionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _commissions =>
      _firestore.collection('commissions');

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _firestore.collection('commissionPayouts');

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _firestore.collection('commissionAccounts');

  CollectionReference<Map<String, dynamic>> get _assignments =>
      _firestore.collection('orderAssignments');

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('orderEvents');

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  @override
  Stream<List<CommissionEntry>> watchCommissions({String? agentId}) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    final Query<Map<String, dynamic>> query = cleanedAgentId == null
        ? _commissions
        : _commissions.where('agentId', isEqualTo: cleanedAgentId);

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<CommissionEntry> values = snapshot.docs
          .map(_mapCommission)
          .whereType<CommissionEntry>()
          .toList(growable: false);
      values.sort(
        (CommissionEntry first, CommissionEntry second) =>
            second.earnedAt.compareTo(first.earnedAt),
      );
      return values;
    });
  }

  @override
  Stream<List<CommissionPayout>> watchPayouts({String? agentId}) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    final Query<Map<String, dynamic>> query = cleanedAgentId == null
        ? _payouts
        : _payouts.where('agentId', isEqualTo: cleanedAgentId);

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<CommissionPayout> values = snapshot.docs
          .map(_mapPayout)
          .whereType<CommissionPayout>()
          .toList(growable: false);
      values.sort(
        (CommissionPayout first, CommissionPayout second) =>
            second.paidAt.compareTo(first.paidAt),
      );
      return values;
    });
  }

  @override
  Stream<List<CommissionAccount>> watchAccounts({String? agentId}) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    if (cleanedAgentId != null) {
      return _accounts.doc(cleanedAgentId).snapshots().map((snapshot) {
        final CommissionAccount? value = _mapAccount(snapshot);
        return value == null
            ? const <CommissionAccount>[]
            : <CommissionAccount>[value];
      });
    }

    return _accounts.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<CommissionAccount> values = snapshot.docs
          .map(_mapAccount)
          .whereType<CommissionAccount>()
          .toList(growable: false);
      values.sort(
        (CommissionAccount first, CommissionAccount second) => first.agentName
            .toLowerCase()
            .compareTo(second.agentName.toLowerCase()),
      );
      return values;
    });
  }

  @override
  Stream<List<AgentAssignmentMetric>> watchAssignmentMetrics({
    String? agentId,
  }) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    final Query<Map<String, dynamic>> query = cleanedAgentId == null
        ? _assignments
        : _assignments.where('agentId', isEqualTo: cleanedAgentId);

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<AgentAssignmentMetric> values = snapshot.docs
          .map(_mapAssignment)
          .whereType<AgentAssignmentMetric>()
          .toList(growable: false);
      values.sort(
        (AgentAssignmentMetric first, AgentAssignmentMetric second) =>
            second.assignedAt.compareTo(first.assignedAt),
      );
      return values;
    });
  }

  @override
  Stream<List<AgentProcessingMetric>> watchProcessingMetrics({
    String? agentId,
  }) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    final Query<Map<String, dynamic>> query = cleanedAgentId == null
        ? _events
        : _events.where('actorId', isEqualTo: cleanedAgentId);

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<AgentProcessingMetric> values = snapshot.docs
          .map(_mapProcessingMetric)
          .whereType<AgentProcessingMetric>()
          .toList(growable: false);
      values.sort(
        (AgentProcessingMetric first, AgentProcessingMetric second) =>
            second.createdAt.compareTo(first.createdAt),
      );
      return values;
    });
  }

  @override
  Stream<List<AgentOrderMetric>> watchOrderMetrics({String? agentId}) {
    final String? cleanedAgentId = _cleanNullable(agentId);
    final Query<Map<String, dynamic>> query = cleanedAgentId == null
        ? _orders
        : _orders.where('assignedAgentId', isEqualTo: cleanedAgentId);

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<AgentOrderMetric> values = snapshot.docs
          .map(_mapOrderMetric)
          .whereType<AgentOrderMetric>()
          .toList(growable: false);
      values.sort((AgentOrderMetric first, AgentOrderMetric second) {
        final DateTime firstDate = first.completedAt ?? first.createdAt;
        final DateTime secondDate = second.completedAt ?? second.createdAt;
        return secondDate.compareTo(firstDate);
      });
      return values;
    });
  }

  @override
  Future<void> recordPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String paymentReference,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String cleanedAgentId = agentId.trim();
    final String cleanedAgentName = agentName.trim();
    final String cleanedReference = paymentReference.trim().toUpperCase();
    final String cleanedStaffId = staffId.trim();
    final String cleanedStaffName = staffName.trim();
    final String? cleanedNote = _cleanNullable(note);

    if (cleanedAgentId.isEmpty || cleanedAgentName.length < 2) {
      throw ArgumentError('L’agent est invalide.');
    }
    if (amount <= 0) {
      throw ArgumentError('Le montant à payer doit être supérieur à zéro.');
    }
    if (cleanedReference.length < 3 || cleanedReference.length > 120) {
      throw ArgumentError('Saisissez la référence du paiement Wave.');
    }
    if (cleanedStaffId.isEmpty || cleanedStaffName.length < 2) {
      throw ArgumentError('L’administrateur est invalide.');
    }
    if (cleanedNote != null && cleanedNote.length > 500) {
      throw ArgumentError('La note interne est trop longue.');
    }

    final DocumentReference<Map<String, dynamic>> accountRef = _accounts.doc(
      cleanedAgentId,
    );
    final DocumentReference<Map<String, dynamic>> payoutRef = _payouts.doc(
      _payoutDocumentId(cleanedReference),
    );

    await _firestore.runTransaction<void>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> accountSnapshot =
          await transaction.get(accountRef);
      final DocumentSnapshot<Map<String, dynamic>> payoutSnapshot =
          await transaction.get(payoutRef);
      final Map<String, dynamic>? accountData = accountSnapshot.data();
      if (!accountSnapshot.exists || accountData == null) {
        throw StateError('Aucune commission acquise pour cet agent.');
      }
      if (payoutSnapshot.exists) {
        throw StateError('Cette référence Wave a déjà été enregistrée.');
      }

      final String accountAgentName =
          (accountData['agentName'] as String? ?? '').trim();
      if (accountAgentName.length < 2) {
        throw StateError('Le compte de commission de cet agent est invalide.');
      }

      final int earnedTotal = _readInt(accountData['earnedTotal']);
      final int paidTotal = _readInt(accountData['paidTotal']);
      final int balance = earnedTotal - paidTotal;
      if (amount > balance) {
        throw StateError(
          'Le paiement dépasse le solde de commission disponible.',
        );
      }

      transaction.set(payoutRef, <String, dynamic>{
        'schemaVersion': 1,
        'agentId': cleanedAgentId,
        'agentName': accountAgentName,
        'amount': amount,
        'paymentChannel': 'wave',
        'paymentReference': cleanedReference,
        'note': cleanedNote,
        'paidAt': FieldValue.serverTimestamp(),
        'createdBy': cleanedStaffId,
        'createdByName': cleanedStaffName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(accountRef, <String, dynamic>{
        'paidTotal': paidTotal + amount,
        'lastPayoutId': payoutRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  CommissionEntry? _mapCommission(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final DateTime? earnedAt = _readDate(data['earnedAt']);
    final String? orderId = data['orderId'] as String?;
    final String? orderReference = data['orderReference'] as String?;
    final String? agentId = data['agentId'] as String?;
    final String? agentName = data['agentName'] as String?;
    final String? network = data['network'] as String?;
    final int commissionAmount = _readInt(data['commissionAmount']);
    final int rate = _readInt(data['rate']);
    if (earnedAt == null ||
        orderId == null ||
        orderReference == null ||
        agentId == null ||
        agentName == null ||
        network == null ||
        commissionAmount <= 0 ||
        rate <= 0) {
      return null;
    }

    return CommissionEntry(
      id: document.id,
      orderId: orderId,
      orderReference: orderReference,
      agentId: agentId,
      agentName: agentName,
      network: _networkFromStorage(network),
      orderAmount: _readInt(data['orderAmount']),
      commissionAmount: commissionAmount,
      policyId: (data['policyId'] as String?) ?? CommissionPolicy.current.id,
      policyType: CommissionPolicyType.fixedPerSuccessfulTransaction,
      rate: rate,
      earnedAt: earnedAt,
      processingStartedAt: _readDate(data['processingStartedAt']),
    );
  }

  CommissionPayout? _mapPayout(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String? agentId = data['agentId'] as String?;
    final String? agentName = data['agentName'] as String?;
    final String? reference = data['paymentReference'] as String?;
    final String? createdBy = data['createdBy'] as String?;
    final String? createdByName = data['createdByName'] as String?;
    final DateTime? paidAt = _readDate(data['paidAt']);
    final int amount = _readInt(data['amount']);
    if (agentId == null ||
        agentName == null ||
        reference == null ||
        createdBy == null ||
        createdByName == null ||
        paidAt == null ||
        amount <= 0) {
      return null;
    }

    return CommissionPayout(
      id: document.id,
      agentId: agentId,
      agentName: agentName,
      amount: amount,
      paymentChannel: (data['paymentChannel'] as String?) ?? 'wave',
      paymentReference: reference,
      paidAt: paidAt,
      createdBy: createdBy,
      createdByName: createdByName,
      note: data['note'] as String?,
    );
  }

  CommissionAccount? _mapAccount(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();
    final DateTime? updatedAt = _readDate(data?['updatedAt']);
    final String? agentId = data?['agentId'] as String?;
    final String? agentName = data?['agentName'] as String?;
    if (!document.exists ||
        data == null ||
        updatedAt == null ||
        agentId == null ||
        agentName == null) {
      return null;
    }

    return CommissionAccount(
      agentId: agentId,
      agentName: agentName,
      earnedTotal: _readInt(data['earnedTotal']),
      paidTotal: _readInt(data['paidTotal']),
      earnedTransactions: _readInt(data['earnedTransactions']),
      updatedAt: updatedAt,
    );
  }

  AgentAssignmentMetric? _mapAssignment(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final DateTime? assignedAt = _readDate(data['assignedAt']);
    final String? orderId = data['orderId'] as String?;
    final String? agentId = data['agentId'] as String?;
    final String? status = data['status'] as String?;
    if (assignedAt == null ||
        orderId == null ||
        agentId == null ||
        status == null) {
      return null;
    }
    return AgentAssignmentMetric(
      id: document.id,
      orderId: orderId,
      agentId: agentId,
      status: status,
      assignedAt: assignedAt,
      acceptedAt: _readDate(data['acceptedAt']),
      refusedAt: _readDate(data['refusedAt']),
      completedAt: _readDate(data['completedAt']),
    );
  }

  AgentProcessingMetric? _mapProcessingMetric(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String? type = data['type'] as String?;
    if (type == null ||
        (type != 'PROCESSING_STARTED' &&
            type != 'PROCESSING_SUCCEEDED' &&
            type != 'PROCESSING_FAILED')) {
      return null;
    }
    final String? orderId = data['orderId'] as String?;
    final String? actorId = data['actorId'] as String?;
    final DateTime? createdAt = _readDate(data['createdAt']);
    if (orderId == null || actorId == null || createdAt == null) {
      return null;
    }
    return AgentProcessingMetric(
      id: document.id,
      orderId: orderId,
      agentId: actorId,
      type: type,
      createdAt: createdAt,
    );
  }

  AgentOrderMetric? _mapOrderMetric(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String? agentId = data['assignedAgentId'] as String?;
    final String? status = data['status'] as String?;
    final DateTime? createdAt = _readDate(data['createdAt']);
    final int amount = _readInt(data['amount']);
    if (agentId == null ||
        agentId.isEmpty ||
        status == null ||
        createdAt == null ||
        amount <= 0) {
      return null;
    }
    return AgentOrderMetric(
      orderId: document.id,
      agentId: agentId,
      amount: amount,
      status: status,
      createdAt: createdAt,
      takenAt: _readDate(data['takenAt']),
      completedAt: _readDate(data['completedAt']),
    );
  }

  MobileNetwork _networkFromStorage(String value) {
    switch (value.toLowerCase()) {
      case 'orange':
        return MobileNetwork.orange;
      case 'mtn':
        return MobileNetwork.mtn;
      case 'moov':
      default:
        return MobileNetwork.moov;
    }
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _payoutDocumentId(String paymentReference) {
    final String encoded = base64Url
        .encode(utf8.encode(paymentReference.trim().toUpperCase()))
        .replaceAll('=', '');
    return 'wave_$encoded';
  }

  String? _cleanNullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
