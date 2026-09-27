import 'dart:async';

import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_v2_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCommissionV2Repository implements CommissionV2Repository {
  FirestoreCommissionV2Repository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<CommissionV2Snapshot> watchAgent(String agentId) {
    final String cleanId = agentId.trim();
    if (cleanId.isEmpty) {
      return Stream<CommissionV2Snapshot>.error(
        ArgumentError.value(agentId, 'agentId', 'Agent ID is required.'),
      );
    }
    return _watch(agentId: cleanId);
  }

  @override
  Stream<CommissionV2Snapshot> watchAdmin() => _watch();

  @override
  Stream<CommissionV2Snapshot> watchAdminAgent(String agentId) {
    final String cleanId = agentId.trim();
    if (cleanId.isEmpty) {
      return Stream<CommissionV2Snapshot>.error(
        ArgumentError.value(agentId, 'agentId', 'Agent ID is required.'),
      );
    }
    return _watch(agentId: cleanId, adminSingleAgent: true);
  }

  Stream<CommissionV2Snapshot> _watch({
    String? agentId,
    bool adminSingleAgent = false,
  }) {
    late final StreamController<CommissionV2Snapshot> controller;
    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];

    List<CommissionV2Entry> commissions = const <CommissionV2Entry>[];
    List<CommissionPayoutV2Entry> payouts = const <CommissionPayoutV2Entry>[];
    List<CommissionAccountV2> accounts = const <CommissionAccountV2>[];

    bool hasCommissions = false;
    bool hasPayouts = false;
    bool hasAccounts = false;

    void emit() {
      if (controller.isClosed || !hasCommissions || !hasPayouts || !hasAccounts) {
        return;
      }
      controller.add(
        CommissionV2Snapshot(
          commissions: commissions,
          payouts: payouts,
          accounts: accounts,
        ),
      );
    }

    Query<Map<String, dynamic>> commissionQuery = _firestore.collection(
      'commissions',
    );
    Query<Map<String, dynamic>> payoutQuery = _firestore.collection(
      'commissionPayouts',
    );

    if (agentId != null) {
      commissionQuery = commissionQuery.where('agentId', isEqualTo: agentId);
      payoutQuery = payoutQuery.where('agentId', isEqualTo: agentId);
    }

    void start() {
      subscriptions.add(
        commissionQuery.snapshots().listen(
          (snapshot) {
            commissions = snapshot.docs
                .map(_commissionFromDocument)
                .whereType<CommissionV2Entry>()
                .toList(growable: false)
              ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
            hasCommissions = true;
            emit();
          },
          onError: controller.addError,
        ),
      );

      subscriptions.add(
        payoutQuery.snapshots().listen(
          (snapshot) {
            payouts = snapshot.docs
                .map(_payoutFromDocument)
                .whereType<CommissionPayoutV2Entry>()
                .toList(growable: false)
              ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
            hasPayouts = true;
            emit();
          },
          onError: controller.addError,
        ),
      );

      if (agentId == null) {
        subscriptions.add(
          _firestore.collection('commissionAccounts').snapshots().listen(
            (snapshot) {
              accounts = snapshot.docs
                  .map(_accountFromDocument)
                  .whereType<CommissionAccountV2>()
                  .toList(growable: false);
              hasAccounts = true;
              emit();
            },
            onError: controller.addError,
          ),
        );
      } else if (adminSingleAgent) {
        // An Admin can read the same account document directly. Keeping this a
        // document watch avoids any broad list query when opening one Agent.
        subscriptions.add(
          _firestore.collection('commissionAccounts').doc(agentId).snapshots().listen(
            (snapshot) {
              final CommissionAccountV2? account = _accountFromSnapshot(snapshot);
              accounts = account == null
                  ? const <CommissionAccountV2>[]
                  : <CommissionAccountV2>[account];
              hasAccounts = true;
              emit();
            },
            onError: controller.addError,
          ),
        );
      } else {
        // Agent self-view must remain a get on its exact account document.
        // Firestore Rules already scope commissions/payouts through agentId.
        subscriptions.add(
          _firestore.collection('commissionAccounts').doc(agentId).snapshots().listen(
            (snapshot) {
              final CommissionAccountV2? account = _accountFromSnapshot(snapshot);
              accounts = account == null
                  ? const <CommissionAccountV2>[]
                  : <CommissionAccountV2>[account];
              hasAccounts = true;
              emit();
            },
            onError: controller.addError,
          ),
        );
      }
    }

    controller = StreamController<CommissionV2Snapshot>(
      onListen: start,
      onCancel: () async {
        for (final StreamSubscription<dynamic> subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  CommissionV2Entry? _commissionFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data();
    final String orderId = _string(data['orderId']);
    final String agentId = _string(data['agentId']);
    final DateTime? earnedAt = _date(data['earnedAt']) ?? _date(data['createdAt']);
    if (orderId.isEmpty || agentId.isEmpty || earnedAt == null) return null;
    return CommissionV2Entry(
      id: snapshot.id,
      orderId: orderId,
      orderReference: _string(data['orderReference']),
      agentId: agentId,
      agentName: _string(data['agentName']),
      network: _string(data['network']).toLowerCase(),
      orderAmount: _int(data['orderAmount']),
      commissionAmount: _int(data['commissionAmount']),
      policyId: _string(data['policyId']),
      policyType: _string(data['policyType']),
      rate: _int(data['rate']),
      earnedAt: earnedAt,
    );
  }

  CommissionPayoutV2Entry? _payoutFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data();
    final String agentId = _string(data['agentId']);
    final DateTime? paidAt = _date(data['paidAt']) ?? _date(data['createdAt']);
    if (agentId.isEmpty || paidAt == null) return null;
    return CommissionPayoutV2Entry(
      id: snapshot.id,
      agentId: agentId,
      agentName: _string(data['agentName']),
      amount: _int(data['amount']),
      paymentChannel: _string(data['paymentChannel']),
      paymentReference: _string(data['paymentReference']),
      paidAt: paidAt,
      note: _nullableString(data['note']),
      createdByName: _nullableString(data['createdByName']),
    );
  }

  CommissionAccountV2? _accountFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _accountFromMap(snapshot.id, snapshot.data());
  }

  CommissionAccountV2? _accountFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    return _accountFromMap(snapshot.id, data);
  }

  CommissionAccountV2? _accountFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final String agentId = _string(data['agentId']).isEmpty
        ? documentId
        : _string(data['agentId']);
    if (agentId.isEmpty) return null;
    return CommissionAccountV2(
      agentId: agentId,
      agentName: _string(data['agentName']),
      earnedTotal: _int(data['earnedTotal']),
      paidTotal: _int(data['paidTotal']),
      earnedTransactions: _int(data['earnedTransactions']),
      lastCommissionOrderId: _nullableString(data['lastCommissionOrderId']),
      lastPayoutId: _nullableString(data['lastPayoutId']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

String _string(Object? value) => value is String ? value.trim() : '';

String? _nullableString(Object? value) {
  final String text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
