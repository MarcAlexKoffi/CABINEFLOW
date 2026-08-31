import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/financial_reconciliation_repository.dart';
import 'package:cabine_flow/features/finances/domain/services/financial_reconciliation_engine.dart';
import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreFinancialReconciliationRepository
    implements FinancialReconciliationRepository {
  FirestoreFinancialReconciliationRepository({
    FirebaseFirestore? firestore,
    FinancialReconciliationEngine engine = const FinancialReconciliationEngine(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _engine = engine;

  final FirebaseFirestore _firestore;
  final FinancialReconciliationEngine _engine;

  @override
  Future<List<FinancialReconciliationResult>> load() async {
    final List<Future<QuerySnapshot<Map<String, dynamic>>>> reads =
        <Future<QuerySnapshot<Map<String, dynamic>>>>[
          _firestore.collection('orders').get(),
          _firestore.collection('orderAssignments').get(),
          _firestore.collection('users').get(),
          _firestore
              .collection('orderEvents')
              .where(
                'type',
                whereIn: const <String>[
                  'PROCESSING_STARTED',
                  'PROCESSING_SUCCEEDED',
                  'PROCESSING_FAILED',
                ],
              )
              .get(),
          _firestore.collection('orderProofs').get(),
          _firestore
              .collection('networkTransactions')
              .where('type', isEqualTo: 'orderSuccess')
              .get(),
          _firestore.collection('commissions').get(),
          _firestore.collection('refunds').get(),
          _firestore.collection('customerCredits').get(),
        ];
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait<QuerySnapshot<Map<String, dynamic>>>(reads);

    final QuerySnapshot<Map<String, dynamic>> ordersSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> assignmentsSnapshot = snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = snapshots[2];
    final QuerySnapshot<Map<String, dynamic>> eventsSnapshot = snapshots[3];
    final QuerySnapshot<Map<String, dynamic>> proofsSnapshot = snapshots[4];
    final QuerySnapshot<Map<String, dynamic>> movementsSnapshot = snapshots[5];
    final QuerySnapshot<Map<String, dynamic>> commissionsSnapshot = snapshots[6];
    final QuerySnapshot<Map<String, dynamic>> refundsSnapshot = snapshots[7];
    final QuerySnapshot<Map<String, dynamic>> creditsSnapshot = snapshots[8];

    final List<QueueOrder> orders = ordersSnapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              FirestoreOrderMapper.fromMap(id: doc.id, data: doc.data()),
        )
        .toList(growable: false);

    final Map<String, List<ReconciliationAssignmentEvidence>> assignmentsByOrder =
        <String, List<ReconciliationAssignmentEvidence>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in assignmentsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      final String agentId = _string(data['agentId']);
      if (orderId.isEmpty || agentId.isEmpty) continue;
      assignmentsByOrder
          .putIfAbsent(orderId, () => <ReconciliationAssignmentEvidence>[])
          .add(
            ReconciliationAssignmentEvidence(
              orderId: orderId,
              agentId: agentId,
              status: _string(data['status']),
              assignedAt: _date(data['assignedAt']),
            ),
          );
    }

    final Set<String> agentUserIds = usersSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toSet();

    final Map<String, Set<String>> eventsByOrder = <String, Set<String>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in eventsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      final String type = _string(data['type']);
      if (orderId.isEmpty || type.isEmpty) continue;
      eventsByOrder.putIfAbsent(orderId, () => <String>{}).add(type);
    }

    final Set<String> proofOrderIds = proofsSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final String explicitOrderId = _string(doc.data()['orderId']);
          return explicitOrderId.isEmpty ? doc.id : explicitOrderId;
        })
        .where((String orderId) => orderId.isNotEmpty)
        .toSet();

    final Map<String, ReconciliationNetworkMovementEvidence>
        networkMovementsByOrder =
        <String, ReconciliationNetworkMovementEvidence>{};
    DateTime? networkCoverageStart;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in movementsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      if (orderId.isEmpty) continue;
      final DateTime? createdAt = _date(data['createdAt']);
      networkCoverageStart = _earliest(networkCoverageStart, createdAt);
      networkMovementsByOrder[orderId] = ReconciliationNetworkMovementEvidence(
        orderId: orderId,
        network: _string(data['network']),
        amount: _int(data['amount']),
        agentId: _nullableString(data['agentId']),
        createdAt: createdAt,
      );
    }

    final Map<String, ReconciliationCommissionEvidence> commissionsByOrder =
        <String, ReconciliationCommissionEvidence>{};
    DateTime? commissionCoverageStart;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in commissionsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      if (orderId.isEmpty) continue;
      final DateTime? earnedAt = _date(data['earnedAt']);
      commissionCoverageStart = _earliest(commissionCoverageStart, earnedAt);
      commissionsByOrder[orderId] = ReconciliationCommissionEvidence(
        orderId: orderId,
        agentId: _string(data['agentId']),
        orderAmount: _int(data['orderAmount']),
        commissionAmount: _int(data['commissionAmount']),
        earnedAt: earnedAt,
      );
    }

    final Map<String, ReconciliationRefundEvidence> refundsByOrder =
        <String, ReconciliationRefundEvidence>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in refundsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      if (orderId.isEmpty) continue;
      refundsByOrder[orderId] = ReconciliationRefundEvidence(
        id: doc.id,
        orderId: orderId,
        amount: _int(data['amount']),
        status: _string(data['status']),
        updatedAt: _date(data['updatedAt']) ??
            _date(data['reconciledAt']) ??
            _date(data['refundedAt']) ??
            _date(data['requestedAt']),
      );
    }

    final Map<String, ReconciliationCreditEvidence> creditsByOrder =
        <String, ReconciliationCreditEvidence>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in creditsSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String orderId = _string(data['orderId']);
      if (orderId.isEmpty) continue;
      creditsByOrder[orderId] = ReconciliationCreditEvidence(
        orderId: orderId,
        orderReference: _string(data['orderReference']),
        amount: _int(data['amount']),
        paidAmount: _int(data['paidAmount']),
        status: _string(data['status']),
      );
    }

    return _engine.reconcile(
      orders: orders,
      evidence: FinancialReconciliationEvidence(
        assignmentsByOrder: assignmentsByOrder,
        agentUserIds: agentUserIds,
        eventsByOrder: eventsByOrder,
        proofOrderIds: proofOrderIds,
        networkMovementsByOrder: networkMovementsByOrder,
        commissionsByOrder: commissionsByOrder,
        refundsByOrder: refundsByOrder,
        creditsByOrder: creditsByOrder,
        networkMovementCoverageStart: networkCoverageStart,
        commissionCoverageStart: commissionCoverageStart,
      ),
    );
  }

  DateTime? _earliest(DateTime? current, DateTime? candidate) {
    if (candidate == null) return current;
    if (current == null || candidate.isBefore(current)) return candidate;
    return current;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _string(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  String? _nullableString(Object? value) {
    final String cleaned = _string(value);
    return cleaned.isEmpty ? null : cleaned;
  }
}
