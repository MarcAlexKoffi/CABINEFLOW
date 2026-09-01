import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_activity_v2_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAgentActivityV2Repository {
  FirestoreAgentActivityV2Repository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AgentActivityV2Snapshot> watchAgentActivity(String agentId) {
    late final StreamController<AgentActivityV2Snapshot> controller;
    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];

    List<AgentActivityOrderV2> orders = const <AgentActivityOrderV2>[];
    List<AgentActivityAssignmentV2> assignments =
        const <AgentActivityAssignmentV2>[];
    List<AgentNetworkMovementV2> movements = const <AgentNetworkMovementV2>[];
    List<AgentCommissionV2> commissions = const <AgentCommissionV2>[];
    AgentCommissionAccountV2? commissionAccount;
    List<AgentCommissionPayoutV2> payouts = const <AgentCommissionPayoutV2>[];
    AgentOperationalSnapshotV2? operationalProfile;
    List<AgentIssueSnapshotV2> issues = const <AgentIssueSnapshotV2>[];

    bool hasOrders = false;
    bool hasAssignments = false;
    bool hasMovements = false;
    bool hasCommissions = false;
    bool hasCommissionAccount = false;
    bool hasPayouts = false;
    bool hasOperationalProfile = false;
    bool hasIssues = false;

    void emit() {
      if (controller.isClosed ||
          !hasOrders ||
          !hasAssignments ||
          !hasMovements ||
          !hasCommissions ||
          !hasCommissionAccount ||
          !hasPayouts ||
          !hasOperationalProfile ||
          !hasIssues) {
        return;
      }
      controller.add(
        AgentActivityV2Snapshot(
          orders: orders,
          assignments: assignments,
          movements: movements,
          commissions: commissions,
          commissionAccount: commissionAccount,
          payouts: payouts,
          operationalProfile: operationalProfile,
          issues: issues,
        ),
      );
    }

    void start() {
      subscriptions.add(
        _firestore
            .collection('orders')
            .where('assignedAgentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              orders =
                  snapshot.docs
                      .map(AgentActivityOrderV2.fromSnapshot)
                      .whereType<AgentActivityOrderV2>()
                      .toList(growable: false)
                    ..sort(
                      (a, b) => _compareDates(
                        b.completedAt ?? b.assignedAt,
                        a.completedAt ?? a.assignedAt,
                      ),
                    );
              hasOrders = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('orderAssignments')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              assignments =
                  snapshot.docs
                      .map(AgentActivityAssignmentV2.fromSnapshot)
                      .whereType<AgentActivityAssignmentV2>()
                      .toList(growable: false)
                    ..sort((a, b) => _compareDates(b.assignedAt, a.assignedAt));
              hasAssignments = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('networkTransactions')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              movements =
                  snapshot.docs
                      .map(AgentNetworkMovementV2.fromSnapshot)
                      .whereType<AgentNetworkMovementV2>()
                      .toList(growable: false)
                    ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
              hasMovements = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('commissions')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              commissions =
                  snapshot.docs
                      .map(AgentCommissionV2.fromSnapshot)
                      .whereType<AgentCommissionV2>()
                      .toList(growable: false)
                    ..sort((a, b) => _compareDates(b.earnedAt, a.earnedAt));
              hasCommissions = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('commissionAccounts')
            .doc(agentId)
            .snapshots()
            .listen((snapshot) {
              commissionAccount = AgentCommissionAccountV2.fromSnapshot(
                snapshot,
              );
              hasCommissionAccount = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('commissionPayouts')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              payouts =
                  snapshot.docs
                      .map(AgentCommissionPayoutV2.fromSnapshot)
                      .whereType<AgentCommissionPayoutV2>()
                      .toList(growable: false)
                    ..sort((a, b) => _compareDates(b.paidAt, a.paidAt));
              hasPayouts = true;
              emit();
            }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore.collection('agentProfiles').doc(agentId).snapshots().listen((
          snapshot,
        ) {
          operationalProfile = AgentOperationalSnapshotV2.fromSnapshot(
            snapshot,
          );
          hasOperationalProfile = true;
          emit();
        }, onError: controller.addError),
      );
      subscriptions.add(
        _firestore
            .collection('agentIssues')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen((snapshot) {
              issues =
                  snapshot.docs
                      .map(AgentIssueSnapshotV2.fromSnapshot)
                      .whereType<AgentIssueSnapshotV2>()
                      .toList(growable: false)
                    ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
              hasIssues = true;
              emit();
            }, onError: controller.addError),
      );
    }

    controller = StreamController<AgentActivityV2Snapshot>(
      onListen: start,
      onCancel: () async {
        for (final StreamSubscription<dynamic> subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  int _compareDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return -1;
    if (right == null) return 1;
    return left.compareTo(right);
  }
}
