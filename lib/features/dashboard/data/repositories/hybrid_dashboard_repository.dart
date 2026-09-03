import 'dart:async';

import 'package:cabine_flow/features/dashboard/data/repositories/firestore_dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

/// Dashboard hybride de la Phase 4.
///
/// Toutes les statistiques historiques/financières restent calculées par
/// Firebase. On corrige uniquement `unassignedOrders` pour les affectations
/// automatiques encore exclusivement présentes dans Supabase avant le handoff
/// vers Firestore. Les affectations manuelles sont désormais matérialisées
/// immédiatement dans les deux sources.
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
    final DashboardData firebase = await _firestore.fetchDashboardData();
    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      return _overlay(firebase, snapshots);
    } catch (error, stackTrace) {
      debugPrint('[Phase4][dashboard] $error');
      debugPrintStack(stackTrace: stackTrace);
      return firebase;
    }
  }

  @override
  Stream<DashboardData> watchDashboardData() {
    final StreamController<DashboardData> controller =
        StreamController<DashboardData>();
    DashboardData? firebase;
    List<Phase4AssignmentSnapshot> snapshots =
        const <Phase4AssignmentSnapshot>[];
    bool phase4Ready = false;

    void emit() {
      final DashboardData? base = firebase;
      if (base == null || !phase4Ready || controller.isClosed) return;
      controller.add(_overlay(base, snapshots));
    }

    late final StreamSubscription<DashboardData> firebaseSubscription;
    late final StreamSubscription<List<Phase4AssignmentSnapshot>>
    phase4Subscription;

    controller.onListen = () {
      firebaseSubscription = _firestore.watchDashboardData().listen(
        (DashboardData value) {
          firebase = value;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      phase4Subscription = _phase4.watchAllForStaff().listen(
        (List<Phase4AssignmentSnapshot> value) {
          snapshots = value;
          phase4Ready = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          // Un compte staff non encore enregistré dans Supabase conserve le
          // dashboard Firebase au lieu de perdre tout l'écran.
          debugPrint('[Phase4][dashboard-watch] $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!phase4Ready) {
            phase4Ready = true;
            snapshots = const <Phase4AssignmentSnapshot>[];
            emit();
          }
        },
      );
    };
    controller.onCancel = () async {
      await firebaseSubscription.cancel();
      await phase4Subscription.cancel();
    };
    return controller.stream;
  }

  DashboardData _overlay(
    DashboardData firebase,
    List<Phase4AssignmentSnapshot> snapshots,
  ) {
    final int supabaseOnlyAssigned = snapshots
        .where(
          (Phase4AssignmentSnapshot item) =>
              item.assignmentMode == OrderAssignmentMode.automatic &&
              (item.isAssigned || item.isAccepted) &&
              item.firebaseAssignmentSyncedAt == null,
        )
        .length;
    final int correctedUnassigned =
        (firebase.statistics.unassignedOrders - supabaseOnlyAssigned)
            .clamp(0, firebase.statistics.unassignedOrders)
            .toInt();

    return DashboardData(
      ordersToProcess: firebase.ordersToProcess,
      averageWaitingMinutes: firebase.averageWaitingMinutes,
      todayRevenue: firebase.todayRevenue,
      revenueChangePercentage: firebase.revenueChangePercentage,
      statistics: DashboardStatistics(
        newRequests: firebase.statistics.newRequests,
        paymentsToVerify: firebase.statistics.paymentsToVerify,
        inProgress: firebase.statistics.inProgress,
        completed: firebase.statistics.completed,
        unassignedOrders: correctedUnassigned,
      ),
      balances: firebase.balances,
      priorityOrders: firebase.priorityOrders,
    );
  }
}
