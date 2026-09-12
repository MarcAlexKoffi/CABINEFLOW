import 'dart:async';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/agents/data/repositories/supabase_agent_issue_repository.dart';
import 'package:cabine_flow/features/agents/data/repositories/supabase_agent_operations_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_activity_v2_models.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAgentActivityV2Repository {
  FirestoreAgentActivityV2Repository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AgentActivityV2Snapshot> watchAgentActivity(String agentId) {
    late final StreamController<AgentActivityV2Snapshot> controller;
    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];
    final bool useSupabase = SupabaseBootstrap.isInitialized;

    List<AgentActivityOrderV2> orders = const <AgentActivityOrderV2>[];
    List<AgentActivityOrderV2> firestoreOrders = const <AgentActivityOrderV2>[];
    List<AgentActivityOrderV2> phase4Orders = const <AgentActivityOrderV2>[];
    Set<String> phase4KnownOrderIds = const <String>{};
    List<AgentActivityAssignmentV2> assignments =
        const <AgentActivityAssignmentV2>[];
    List<AgentActivityAssignmentV2> firestoreAssignments =
        const <AgentActivityAssignmentV2>[];
    List<AgentActivityAssignmentV2> phase4Assignments =
        const <AgentActivityAssignmentV2>[];
    List<AgentNetworkMovementV2> movements = const <AgentNetworkMovementV2>[];
    List<AgentCommissionV2> commissions = const <AgentCommissionV2>[];
    AgentCommissionAccountV2? commissionAccount;
    List<AgentCommissionPayoutV2> payouts = const <AgentCommissionPayoutV2>[];
    AgentOperationalSnapshotV2? operationalProfile;
    List<AgentIssueSnapshotV2> issues = const <AgentIssueSnapshotV2>[];
    final Set<String> unavailableSources = <String>{};

    bool hasOrders = false;
    bool hasFirestoreOrders = false;
    bool hasPhase4Orders = !useSupabase;
    bool hasAssignments = false;
    bool hasFirestoreAssignments = false;
    bool hasPhase4Assignments = !useSupabase;
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
      // Conserve le dernier snapshot connu pendant une coupure backend.
      unavailableSources.add(source);
      markLoaded();
      emit();
    }

    void markAvailable(String source) {
      unavailableSources.remove(source);
    }

    void mergeOrders() {
      if (!hasFirestoreOrders || !hasPhase4Orders) return;
      final Set<String> currentIds = phase4Orders
          .map((AgentActivityOrderV2 item) => item.id)
          .toSet();
      final Map<String, AgentActivityOrderV2> merged =
          <String, AgentActivityOrderV2>{
            for (final AgentActivityOrderV2 item in firestoreOrders)
              if (!phase4KnownOrderIds.contains(item.id) ||
                  currentIds.contains(item.id))
                item.id: item,
          };
      for (final AgentActivityOrderV2 item in phase4Orders) {
        // Supabase is canonical once the order is synchronized.
        merged[item.id] = item;
      }
      orders = merged.values.toList(growable: false)
        ..sort(
          (a, b) => _compareDates(
            b.completedAt ?? b.assignedAt,
            a.completedAt ?? a.assignedAt,
          ),
        );
      hasOrders = true;
      markAvailable(AgentActivityV2Sources.orders);
      emit();
    }

    void mergeAssignments() {
      if (!hasFirestoreAssignments || !hasPhase4Assignments) return;
      final Map<String, AgentActivityAssignmentV2> merged =
          <String, AgentActivityAssignmentV2>{};
      for (final AgentActivityAssignmentV2 item in firestoreAssignments) {
        final int stamp =
            (item.refusedAt ?? item.acceptedAt ?? item.assignedAt)
                ?.millisecondsSinceEpoch ??
            0;
        merged['${item.orderId}|$stamp|${item.status}'] = item;
      }
      for (final AgentActivityAssignmentV2 item in phase4Assignments) {
        // Phase 4 history is canonical for every post-sync assignment cycle.
        final int stamp =
            (item.refusedAt ?? item.acceptedAt ?? item.assignedAt)
                ?.millisecondsSinceEpoch ??
            0;
        merged['${item.orderId}|$stamp|${item.status}'] = item;
      }
      assignments = merged.values.toList(growable: false)
        ..sort((a, b) => _compareDates(b.assignedAt, a.assignedAt));
      hasAssignments = true;
      markAvailable(AgentActivityV2Sources.assignments);
      emit();
    }

    void listenLegacyOrders() {
      subscriptions.add(
        _firestore
            .collection('orders')
            .where('assignedAgentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                firestoreOrders = snapshot.docs
                    .map(AgentActivityOrderV2.fromSnapshot)
                    .whereType<AgentActivityOrderV2>()
                    .toList(growable: false);
                hasFirestoreOrders = true;
                mergeOrders();
              },
              onError: (Object error, StackTrace stackTrace) {
                hasFirestoreOrders = true;
                unavailableSources.add(AgentActivityV2Sources.orders);
                mergeOrders();
              },
            ),
      );
    }

    void listenLegacyAssignments() {
      subscriptions.add(
        _firestore
            .collection('orderAssignments')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                firestoreAssignments = snapshot.docs
                    .map(AgentActivityAssignmentV2.fromSnapshot)
                    .whereType<AgentActivityAssignmentV2>()
                    .toList(growable: false);
                hasFirestoreAssignments = true;
                mergeAssignments();
              },
              onError: (Object error, StackTrace stackTrace) {
                hasFirestoreAssignments = true;
                unavailableSources.add(AgentActivityV2Sources.assignments);
                mergeAssignments();
              },
            ),
      );
    }

    void startSupabaseCanonicalSources() {
      final SupabasePhase4AssignmentRepository phase4 =
          SupabasePhase4AssignmentRepository();
      final SupabasePhase5FinanceRepository finance =
          SupabasePhase5FinanceRepository();
      final SupabaseAgentOperationsRepository operations =
          SupabaseAgentOperationsRepository();

      subscriptions.add(
        phase4.watchAgentAssignmentState(agentId).listen(
          (Phase4AgentAssignmentState state) {
            phase4KnownOrderIds = state.knownPhase4OrderIds;
            phase4Orders = state.currentAssignments
                .map(
                  (Phase4AssignmentSnapshot item) => AgentActivityOrderV2(
                    id: item.orderId,
                    reference: item.orderReference,
                    network: item.network.name,
                    amount: item.amount,
                    status: item.orderStatus.name,
                    paymentStatus: item.paymentStatus.name,
                    assignedAt: item.assignedAt,
                    takenAt: item.processingStartedAt,
                    completedAt: item.completedAt,
                  ),
                )
                .toList(growable: false);
            hasPhase4Orders = true;
            mergeOrders();
          },
          onError: (Object error, StackTrace stackTrace) {
            hasPhase4Orders = true;
            unavailableSources.add(AgentActivityV2Sources.orders);
            mergeOrders();
          },
        ),
      );

      subscriptions.add(
        phase4.watchAgentAssignmentHistory(agentId).listen(
          (List<Phase4AssignmentHistorySnapshot> items) {
            phase4Assignments = items
                .map(
                  (Phase4AssignmentHistorySnapshot item) =>
                      AgentActivityAssignmentV2(
                        id: 'phase4_${item.id}',
                        orderId: item.orderId,
                        orderReference: item.orderReference,
                        status: item.status,
                        assignedAt: item.assignedAt,
                        acceptedAt: item.acceptedAt,
                        refusedAt: item.refusedAt,
                        refusalReason: item.refusalReason,
                      ),
                )
                .toList(growable: false);
            hasPhase4Assignments = true;
            mergeAssignments();
          },
          onError: (Object error, StackTrace stackTrace) {
            hasPhase4Assignments = true;
            unavailableSources.add(AgentActivityV2Sources.assignments);
            mergeAssignments();
          },
        ),
      );

      subscriptions.add(
        finance.watchNetworkMovements(agentId: agentId).listen(
          (List<NetworkTransaction> items) {
            movements = items
                .map(
                  (NetworkTransaction item) => AgentNetworkMovementV2(
                    id: item.id,
                    type: item.type.name,
                    direction: item.direction.name,
                    network: item.network.name,
                    amount: item.amount,
                    capacityBefore: item.capacityBefore,
                    capacityAfter: item.capacityAfter,
                    createdAt: item.createdAt,
                  ),
                )
                .toList(growable: false)
              ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
            hasMovements = true;
            markAvailable(AgentActivityV2Sources.movements);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            markUnavailable(
              AgentActivityV2Sources.movements,
              () => hasMovements = true,
            );
          },
        ),
      );

      subscriptions.add(
        finance.watchCommissions(agentId: agentId).listen(
          (List<CommissionEntry> items) {
            commissions = items
                .map(
                  (CommissionEntry item) => AgentCommissionV2(
                    id: item.id,
                    orderId: item.orderId,
                    orderReference: item.orderReference,
                    network: item.network.name,
                    orderAmount: item.orderAmount,
                    commissionAmount: item.commissionAmount,
                    earnedAt: item.earnedAt,
                  ),
                )
                .toList(growable: false)
              ..sort((a, b) => _compareDates(b.earnedAt, a.earnedAt));
            hasCommissions = true;
            markAvailable(AgentActivityV2Sources.commissions);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            markUnavailable(
              AgentActivityV2Sources.commissions,
              () => hasCommissions = true,
            );
          },
        ),
      );

      subscriptions.add(
        finance.watchCommissionAccounts(agentId: agentId).listen(
          (List<CommissionAccount> items) {
            final CommissionAccount? item = items.isEmpty ? null : items.first;
            commissionAccount = item == null
                ? null
                : AgentCommissionAccountV2(
                    earnedTotal: item.earnedTotal,
                    paidTotal: item.paidTotal,
                    earnedTransactions: item.earnedTransactions,
                    updatedAt: item.updatedAt,
                  );
            hasCommissionAccount = true;
            markAvailable(AgentActivityV2Sources.commissionAccount);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            markUnavailable(
              AgentActivityV2Sources.commissionAccount,
              () => hasCommissionAccount = true,
            );
          },
        ),
      );

      subscriptions.add(
        finance.watchCommissionPayouts(agentId: agentId).listen(
          (List<CommissionPayout> items) {
            payouts = items
                .map(
                  (CommissionPayout item) => AgentCommissionPayoutV2(
                    id: item.id,
                    amount: item.amount,
                    paymentChannel: item.paymentChannel,
                    paymentReference: item.paymentReference,
                    note: item.note,
                    paidAt: item.paidAt,
                  ),
                )
                .toList(growable: false)
              ..sort((a, b) => _compareDates(b.paidAt, a.paidAt));
            hasPayouts = true;
            markAvailable(AgentActivityV2Sources.payouts);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            markUnavailable(
              AgentActivityV2Sources.payouts,
              () => hasPayouts = true,
            );
          },
        ),
      );

      subscriptions.add(
        operations.watchProfile(agentId).listen(
          (AgentProfile? profile) {
            operationalProfile = profile == null
                ? null
                : AgentOperationalSnapshotV2(
                    agentCode: profile.agentCode,
                    availability: profile.availability.name,
                    activeNetworks: profile.activeNetworks
                        .map((AgentNetwork network) => network.name)
                        .toList(growable: false),
                    orangeCapacity: profile.orangeCapacity,
                    mtnCapacity: profile.mtnCapacity,
                    moovCapacity: profile.moovCapacity,
                    dailyTransactionLimit: profile.dailyTransactionLimit,
                    maxTransactionsPerDay: profile.maxTransactionsPerDay,
                    updatedAt: profile.updatedAt,
                  );
            hasOperationalProfile = true;
            markAvailable(AgentActivityV2Sources.operationalProfile);
            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            markUnavailable(
              AgentActivityV2Sources.operationalProfile,
              () => hasOperationalProfile = true,
            );
          },
        ),
      );
    }

    void startFirestoreFinanceFallback() {
      subscriptions.add(
        _firestore
            .collection('networkTransactions')
            .where('agentId', isEqualTo: agentId)
            .snapshots()
            .listen(
              (snapshot) {
                movements = snapshot.docs
                    .map(AgentNetworkMovementV2.fromSnapshot)
                    .whereType<AgentNetworkMovementV2>()
                    .toList(growable: false)
                  ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));
                hasMovements = true;
                markAvailable(AgentActivityV2Sources.movements);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
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
                commissions = snapshot.docs
                    .map(AgentCommissionV2.fromSnapshot)
                    .whereType<AgentCommissionV2>()
                    .toList(growable: false)
                  ..sort((a, b) => _compareDates(b.earnedAt, a.earnedAt));
                hasCommissions = true;
                markAvailable(AgentActivityV2Sources.commissions);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
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
                payouts = snapshot.docs
                    .map(AgentCommissionPayoutV2.fromSnapshot)
                    .whereType<AgentCommissionPayoutV2>()
                    .toList(growable: false)
                  ..sort((a, b) => _compareDates(b.paidAt, a.paidAt));
                hasPayouts = true;
                markAvailable(AgentActivityV2Sources.payouts);
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
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
                markUnavailable(
                  AgentActivityV2Sources.operationalProfile,
                  () => hasOperationalProfile = true,
                );
              },
            ),
      );
    }

    void startIssues() {
      if (useSupabase) {
        subscriptions.add(
          SupabaseAgentIssueRepository().watchAgentIssues(agentId).listen(
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

    void start() {
      listenLegacyOrders();
      listenLegacyAssignments();
      if (useSupabase) {
        startSupabaseCanonicalSources();
      } else {
        hasPhase4Orders = true;
        hasPhase4Assignments = true;
        mergeOrders();
        mergeAssignments();
        startFirestoreFinanceFallback();
      }
      startIssues();
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
