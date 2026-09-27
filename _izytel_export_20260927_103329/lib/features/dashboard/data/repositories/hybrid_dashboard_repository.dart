import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/dashboard/data/repositories/firestore_dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

/// Dashboard de cloture Phase 3.
///
/// Firestore ne fournit plus que les etats pre-sync encore legitimes
/// (principalement les paiements a verifier). Les indicateurs operationnels,
/// les encaissements confirmes, les capacites reseau et les commandes actives
/// sont calcules a partir des sources canoniques Supabase.
class HybridDashboardRepository implements DashboardRepository {
  HybridDashboardRepository({
    FirestoreDashboardRepository? firestoreRepository,
    SupabasePhase4AssignmentRepository? phase4Repository,
  }) : _firestore = firestoreRepository ?? FirestoreDashboardRepository(),
       _phase4 = phase4Repository ?? SupabasePhase4AssignmentRepository();

  final FirestoreDashboardRepository _firestore;
  final SupabasePhase4AssignmentRepository _phase4;

  @override
  Future<DashboardData> fetchDashboardData() async {
    DashboardData firebase = _emptyDashboardData();
    try {
      firebase = await _firestore.fetchDashboardData();
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Dashboard.legacy-pre-sync',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      final List<AutomaticAssignmentAgent> candidates = await _phase4
          .fetchAssignmentCandidates();
      return _overlay(firebase, snapshots, candidates);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Phase4.dashboard',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      return firebase;
    }
  }

  @override
  Stream<DashboardData> watchDashboardData() {
    final StreamController<DashboardData> controller =
        StreamController<DashboardData>();
    DashboardData firebase = _emptyDashboardData();
    List<Phase4AssignmentSnapshot> snapshots =
        const <Phase4AssignmentSnapshot>[];
    List<AutomaticAssignmentAgent> candidates =
        const <AutomaticAssignmentAgent>[];
    bool firebaseReady = false;
    bool phase4Ready = false;
    bool candidatesReady = false;
    int candidateRefreshSerial = 0;

    void emit() {
      if ((!firebaseReady && !phase4Ready) || controller.isClosed) return;
      controller.add(
        phase4Ready
            ? _overlay(
                firebase,
                snapshots,
                candidates,
                capacitiesReady: candidatesReady,
              )
            : firebase,
      );
    }

    Future<void> refreshPhase4(
      List<Phase4AssignmentSnapshot> value,
    ) async {
      snapshots = value;
      phase4Ready = true;

      // Au premier snapshot Phase 4, ne pas afficher de faux soldes a 0 :
      // on attend le premier chargement des capacites Supabase. Les mises a
      // jour suivantes peuvent reutiliser la derniere valeur fiable pendant
      // que le refresh capacite s'effectue.
      if (candidatesReady) emit();

      final int serial = ++candidateRefreshSerial;
      try {
        final List<AutomaticAssignmentAgent> latest = await _phase4
            .fetchAssignmentCandidates();
        if (serial != candidateRefreshSerial || controller.isClosed) return;
        candidates = latest;
        candidatesReady = true;
        emit();
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4.dashboard-capacities',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error) && !controller.isClosed) {
          controller.addError(error, stackTrace);
          return;
        }
        // En panne transitoire avant le premier chargement, les autres
        // indicateurs restent utilisables mais les soldes reseau restent
        // explicitement indisponibles plutot que d'afficher un faux zero.
        if (!candidatesReady) emit();
      }
    }

    late final StreamSubscription<DashboardData> firebaseSubscription;
    late final StreamSubscription<List<Phase4AssignmentSnapshot>>
    phase4Subscription;

    controller.onListen = () {
      firebaseSubscription = _firestore.watchDashboardData().listen(
        (DashboardData value) {
          firebase = value;
          firebaseReady = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'Dashboard.legacy-pre-sync-watch',
            error,
            stackTrace: stackTrace,
          );
          if (BackendFailurePolicy.canRetryRead(error)) {
            firebaseReady = true;
            emit();
            return;
          }
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      phase4Subscription = _phase4.watchAllForStaff().listen(
        (List<Phase4AssignmentSnapshot> value) {
          unawaited(refreshPhase4(value));
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'Phase4.dashboard-watch',
            error,
            stackTrace: stackTrace,
          );
          if (!BackendFailurePolicy.canRetryRead(error)) {
            if (!controller.isClosed) controller.addError(error, stackTrace);
            return;
          }
          if (!phase4Ready) {
            phase4Ready = true;
            emit();
          }
        },
      );
    };
    controller.onCancel = () async {
      candidateRefreshSerial += 1;
      await firebaseSubscription.cancel();
      await phase4Subscription.cancel();
    };
    return controller.stream;
  }

  DashboardData _overlay(
    DashboardData firebase,
    List<Phase4AssignmentSnapshot> snapshots,
    List<AutomaticAssignmentAgent> candidates, {
    bool capacitiesReady = true,
  }) {
    final List<Phase4AssignmentSnapshot> canonical = snapshots
        .where((Phase4AssignmentSnapshot item) => !item.legacyStateUnresolved)
        .toList(growable: false);
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
    final DateTime yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final int supabaseReady = canonical
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.orderStatus == QueueOrderStatus.paidReady,
        )
        .length;
    final int supabaseInProgress = canonical
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.orderStatus == QueueOrderStatus.inProgress ||
              item.orderStatus == QueueOrderStatus.onHold,
        )
        .length;
    final int supabaseCompletedToday = canonical
        .where(
          (Phase4AssignmentSnapshot item) =>
              (item.orderStatus == QueueOrderStatus.completed ||
                  item.orderStatus ==
                      QueueOrderStatus.awaitingCustomerConfirmation) &&
              _isBetween(item.completedAt, todayStart, tomorrowStart),
        )
        .length;
    final int supabaseUnassigned = canonical
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.orderStatus == QueueOrderStatus.paidReady &&
              (item.isWaiting || item.isManualRequired),
        )
        .length;
    final int paidToday = canonical.where((Phase4AssignmentSnapshot item) {
      return item.paymentStatus == OrderPaymentStatus.confirmed &&
          _isBetween(
            item.paymentConfirmedAt ?? item.paidAt,
            todayStart,
            tomorrowStart,
          );
    }).length;

    final int todayRevenue = _confirmedRevenueBetween(
      canonical,
      start: todayStart,
      end: tomorrowStart,
    );
    final int yesterdayRevenue = _confirmedRevenueBetween(
      canonical,
      start: yesterdayStart,
      end: todayStart,
    );

    final List<Phase4AssignmentSnapshot> waiting = canonical
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.orderStatus == QueueOrderStatus.paidReady,
        )
        .toList(growable: false);
    final int averageWaitingMinutes = waiting.isEmpty
        ? 0
        : waiting
                  .map((Phase4AssignmentSnapshot item) {
                    final DateTime start =
                        item.paymentConfirmedAt ??
                        item.paidAt ??
                        item.firebaseCreatedAt;
                    return now
                        .difference(start)
                        .inMinutes
                        .clamp(0, 999999)
                        .toInt();
                  })
                  .fold<int>(0, (int sum, int value) => sum + value) ~/
              waiting.length;

    return DashboardData(
      ordersToProcess: supabaseReady + firebase.statistics.paymentsToVerify,
      averageWaitingMinutes: averageWaitingMinutes,
      todayRevenue: todayRevenue,
      revenueChangePercentage: _calculateRevenueChange(
        todayRevenue: todayRevenue,
        yesterdayRevenue: yesterdayRevenue,
      ),
      statistics: DashboardStatistics(
        newRequests: paidToday,
        paymentsToVerify: firebase.statistics.paymentsToVerify,
        inProgress: supabaseInProgress,
        completed: supabaseCompletedToday,
        unassignedOrders: supabaseUnassigned,
      ),
      balances: _buildNetworkBalances(
        candidates,
        capacitiesReady: capacitiesReady,
      ),
      priorityOrders: _buildPriorityOrders(
        firebase: firebase.priorityOrders,
        canonical: canonical,
        now: now,
      ),
    );
  }

  int _confirmedRevenueBetween(
    List<Phase4AssignmentSnapshot> orders, {
    required DateTime start,
    required DateTime end,
  }) {
    return orders.fold<int>(0, (int total, Phase4AssignmentSnapshot order) {
      if (order.paymentStatus != OrderPaymentStatus.confirmed ||
          !_isBetween(order.paymentConfirmedAt ?? order.paidAt, start, end)) {
        return total;
      }
      return total + order.amount;
    });
  }

  double? _calculateRevenueChange({
    required int todayRevenue,
    required int yesterdayRevenue,
  }) {
    if (yesterdayRevenue == 0) return todayRevenue == 0 ? 0 : null;
    return ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }

  List<AccountBalance> _buildNetworkBalances(
    List<AutomaticAssignmentAgent> candidates, {
    required bool capacitiesReady,
  }) {
    if (!capacitiesReady) {
      return const <AccountBalance>[
        AccountBalance(channel: ServiceChannel.orange),
        AccountBalance(channel: ServiceChannel.mtn),
        AccountBalance(channel: ServiceChannel.moov),
        AccountBalance(channel: ServiceChannel.wave),
      ];
    }
    int availableFor(MobileNetwork network) {
      return candidates.fold<int>(0, (int total, AutomaticAssignmentAgent agent) {
        if (!agent.isActive ||
            !agent.isAvailable ||
            !agent.authorizedNetworks.contains(network) ||
            !agent.activeNetworks.contains(network)) {
          return total;
        }
        return total + agent.availableCapacityFor(network);
      });
    }

    return <AccountBalance>[
      AccountBalance(
        channel: ServiceChannel.orange,
        amount: availableFor(MobileNetwork.orange),
      ),
      AccountBalance(
        channel: ServiceChannel.mtn,
        amount: availableFor(MobileNetwork.mtn),
      ),
      AccountBalance(
        channel: ServiceChannel.moov,
        amount: availableFor(MobileNetwork.moov),
      ),
      const AccountBalance(channel: ServiceChannel.wave),
    ];
  }

  List<PriorityOrder> _buildPriorityOrders({
    required List<PriorityOrder> firebase,
    required List<Phase4AssignmentSnapshot> canonical,
    required DateTime now,
  }) {
    final List<PriorityOrder> values = <PriorityOrder>[
      ...firebase.where(
        (PriorityOrder item) =>
            item.status == PriorityOrderStatus.pendingVerification,
      ),
      ...canonical
          .where(
            (Phase4AssignmentSnapshot item) =>
                item.orderStatus == QueueOrderStatus.paidReady ||
                item.orderStatus == QueueOrderStatus.inProgress ||
                item.orderStatus == QueueOrderStatus.onHold,
          )
          .map((Phase4AssignmentSnapshot item) {
            final bool processing =
                item.orderStatus == QueueOrderStatus.inProgress ||
                item.orderStatus == QueueOrderStatus.onHold;
            final DateTime waitingSince =
                item.paymentConfirmedAt ?? item.paidAt ?? item.firebaseCreatedAt;
            final bool urgent =
                !processing && now.difference(waitingSince).inMinutes >= 15;
            return PriorityOrder(
              orderId: item.orderId,
              reference: item.orderReference,
              phoneNumber: item.beneficiaryPhone,
              operationLabel: item.offerLabel.trim().isEmpty
                  ? _operationLabel(item.operationType)
                  : item.offerLabel.trim(),
              amount: item.amount,
              channel: _serviceChannel(item.network),
              status: processing
                  ? PriorityOrderStatus.inProgress
                  : urgent
                  ? PriorityOrderStatus.urgent
                  : PriorityOrderStatus.ready,
              actionLabel: processing ? 'Ouvrir' : 'Traiter',
            );
          }),
    ];

    values.sort((PriorityOrder first, PriorityOrder second) {
      final int rank = _priorityRank(first.status).compareTo(
        _priorityRank(second.status),
      );
      if (rank != 0) return rank;
      return first.reference.compareTo(second.reference);
    });

    final Set<String> seen = <String>{};
    final List<PriorityOrder> unique = <PriorityOrder>[];
    for (final PriorityOrder item in values) {
      final String key = item.orderId.trim().isEmpty
          ? item.reference
          : item.orderId;
      if (!seen.add(key)) continue;
      unique.add(item);
      if (unique.length == 5) break;
    }
    return List<PriorityOrder>.unmodifiable(unique);
  }

  int _priorityRank(PriorityOrderStatus status) {
    switch (status) {
      case PriorityOrderStatus.pendingVerification:
        return 0;
      case PriorityOrderStatus.urgent:
        return 1;
      case PriorityOrderStatus.ready:
        return 2;
      case PriorityOrderStatus.inProgress:
        return 3;
    }
  }

  ServiceChannel _serviceChannel(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return ServiceChannel.orange;
      case MobileNetwork.mtn:
        return ServiceChannel.mtn;
      case MobileNetwork.moov:
        return ServiceChannel.moov;
    }
  }

  String _operationLabel(OrderOperationType type) {
    switch (type) {
      case OrderOperationType.internetSubscription:
        return 'Souscription Internet';
      case OrderOperationType.unitTransfer:
        return 'Transfert d’unites';
      case OrderOperationType.callBundle:
        return 'Forfait d’appels';
      case OrderOperationType.mixedBundle:
        return 'Forfait mixte';
      case OrderOperationType.other:
        return 'Commande';
    }
  }

  bool _isBetween(DateTime? date, DateTime start, DateTime end) {
    if (date == null) return false;
    final DateTime local = date.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }

  DashboardData _emptyDashboardData() {
    return const DashboardData(
      ordersToProcess: 0,
      averageWaitingMinutes: 0,
      statistics: DashboardStatistics(
        newRequests: 0,
        paymentsToVerify: 0,
        inProgress: 0,
        completed: 0,
      ),
      balances: <AccountBalance>[
        AccountBalance(channel: ServiceChannel.orange),
        AccountBalance(channel: ServiceChannel.mtn),
        AccountBalance(channel: ServiceChannel.moov),
        AccountBalance(channel: ServiceChannel.wave),
      ],
      priorityOrders: <PriorityOrder>[],
    );
  }
}
