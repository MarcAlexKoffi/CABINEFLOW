import 'dart:async';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/agents/data/repositories/supabase_agent_issue_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_activity_v2_models.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
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
    final Set<String> unavailableSources = <String>{};

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
          unavailableSources: Set<String>.unmodifiable(unavailableSources),
        ),
      );
    }

    void markUnavailable(String source, void Function() markLoaded) {
      unavailableSources.add(source);
      markLoaded();
      emit();
    }

    void markAvailable(String source) {
      unavailableSources.remove(source);
    }

    void start() {
      subscriptions.add(
        _firestore
            .collection('orders')
            .where('assignedAgentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
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
                markAvailable(AgentActivityV2Sources.orders);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                orders = const <AgentActivityOrderV2>[];
                markUnavailable(
                  AgentActivityV2Sources.orders,
                  () => hasOrders = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('orderAssignments')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                assignments =
                    snapshot.docs
                        .map(AgentActivityAssignmentV2.fromSnapshot)
                        .whereType<AgentActivityAssignmentV2>()
                        .toList(growable: false)
                      ..sort(
                        (a, b) => _compareDates(b.assignedAt, a.assignedAt),
                      );
                hasAssignments = true;
                markAvailable(AgentActivityV2Sources.assignments);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                assignments = const <AgentActivityAssignmentV2>[];
                markUnavailable(
                  AgentActivityV2Sources.assignments,
                  () => hasAssignments = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('networkTransactions')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                movements =
                    snapshot.docs
                        .map(AgentNetworkMovementV2.fromSnapshot)
                        .whereType<AgentNetworkMovementV2>()
                        .toList(growable: false)
                      ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
                hasMovements = true;
                markAvailable(AgentActivityV2Sources.movements);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                movements = const <AgentNetworkMovementV2>[];
                markUnavailable(
                  AgentActivityV2Sources.movements,
                  () => hasMovements = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('commissions')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                commissions =
                    snapshot.docs
                        .map(AgentCommissionV2.fromSnapshot)
                        .whereType<AgentCommissionV2>()
                        .toList(growable: false)
                      ..sort((a, b) => _compareDates(b.earnedAt, a.earnedAt));
                hasCommissions = true;
                markAvailable(AgentActivityV2Sources.commissions);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                commissions = const <AgentCommissionV2>[];
                markUnavailable(
                  AgentActivityV2Sources.commissions,
                  () => hasCommissions = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('commissionAccounts')
            .doc(agentId)
            .snapshots()
            .listen(
              (snapshot) {
                commissionAccount = AgentCommissionAccountV2.fromSnapshot(
                  snapshot,
                );
                hasCommissionAccount = true;
                markAvailable(AgentActivityV2Sources.commissionAccount);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                commissionAccount = null;
                markUnavailable(
                  AgentActivityV2Sources.commissionAccount,
                  () => hasCommissionAccount = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('commissionPayouts')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                payouts =
                    snapshot.docs
                        .map(AgentCommissionPayoutV2.fromSnapshot)
                        .whereType<AgentCommissionPayoutV2>()
                        .toList(growable: false)
                      ..sort((a, b) => _compareDates(b.paidAt, a.paidAt));
                hasPayouts = true;
                markAvailable(AgentActivityV2Sources.payouts);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                payouts = const <AgentCommissionPayoutV2>[];
                markUnavailable(
                  AgentActivityV2Sources.payouts,
                  () => hasPayouts = true,
                );
              },
            ),
      );
      subscriptions.add(
        _firestore
            .collection('agentProfiles')
            .doc(agentId)
            .snapshots()
            .listen(
              (snapshot) {
                operationalProfile = AgentOperationalSnapshotV2.fromSnapshot(
                  snapshot,
                );
                hasOperationalProfile = true;
                markAvailable(AgentActivityV2Sources.operationalProfile);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                operationalProfile = null;
                markUnavailable(
                  AgentActivityV2Sources.operationalProfile,
                  () => hasOperationalProfile = true,
                );
              },
            ),
      );
      if (SupabaseBootstrap.isInitialized) {
        subscriptions.add(
          SupabaseAgentIssueRepository()
              .watchAgentIssues(agentId)
              .listen(
                (List<AgentIssue> items) {
                  issues = items
                      .map(
                        (AgentIssue issue) => AgentIssueSnapshotV2(
                          id: issue.id,
                          type: issue.type,
                          status: issue.status,
                          description: issue.description,
                          network: issue.network?.name,
                          createdAt: issue.createdAt,
                          resolvedAt: issue.resolvedAt,
                        ),
                      )
                      .toList(growable: false);
                  hasIssues = true;
                  markAvailable(AgentActivityV2Sources.issues);
                  emit();
                },
                onError: (Object error, StackTrace stackTrace) {
                  issues = const <AgentIssueSnapshotV2>[];
                  markUnavailable(
                    AgentActivityV2Sources.issues,
                    () => hasIssues = true,
                  );
                },
              ),
        );
      } else {
        issues = const <AgentIssueSnapshotV2>[];
        markUnavailable(AgentActivityV2Sources.issues, () => hasIssues = true);
      }
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
