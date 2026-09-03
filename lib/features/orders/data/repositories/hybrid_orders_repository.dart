import 'dart:async';

import 'package:cabine_flow/features/orders/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/agent_assignment_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/services/automatic_assignment_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Phase 4 IzyTel.
///
/// Supabase est la source de vérité uniquement pendant la négociation
/// d'affectation (automatique/manuelle, acceptation, refus, réaffectation).
/// Dès qu'un agent accepte, la commande est matérialisée dans le flux Firebase
/// existant afin de conserver sans régression preuve, traitement, capacité,
/// commissions et mouvements financiers.
class HybridOrdersRepository
    implements
        OrdersRepository,
        OrderHistoryRepository,
        AgentAssignmentHistoryRepository {
  HybridOrdersRepository({
    FirestoreOrdersRepository? firestoreRepository,
    SupabasePhase4AssignmentRepository? phase4Repository,
    FirebaseAuth? firebaseAuth,
  }) : _firestore =
           firestoreRepository ??
           FirestoreOrdersRepository(enableNativeAutoAssignment: false),
       _phase4 = phase4Repository ?? SupabasePhase4AssignmentRepository(),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const int _maximumBacklogOrders = 50;

  final FirestoreOrdersRepository _firestore;
  final SupabasePhase4AssignmentRepository _phase4;
  final FirebaseAuth _firebaseAuth;
  final AutomaticAssignmentSelector _selector =
      const AutomaticAssignmentSelector();

  @override
  Future<QueueOrder> createOrder({required CreateOrderRequest request}) {
    return _firestore.createOrder(request: request);
  }

  @override
  Future<QueueOrder> markPaymentRequestSent({required String orderId}) {
    return _firestore.markPaymentRequestSent(orderId: orderId);
  }

  @override
  Future<List<QueueOrder>> fetchPaymentTrackingOrders() {
    return _firestore.fetchPaymentTrackingOrders();
  }

  @override
  Stream<List<QueueOrder>> watchPaymentTrackingOrders() {
    return _firestore.watchPaymentTrackingOrders();
  }

  @override
  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  }) async {
    final QueueOrder confirmed = await _firestore.confirmPayment(
      orderId: orderId,
      paidAt: paidAt,
      paymentReference: paymentReference,
    );

    // Le paiement ne doit jamais être annulé parce que le moteur d'affectation
    // est temporairement indisponible. La file Firestore reste persistée et le
    // prochain passage du compte Admin reprendra la synchronisation.
    try {
      await _firestore.ensureHybridAssignmentQueue(confirmed);
      await _phase4.syncOrder(confirmed);
      return await tryAutomaticAssignment(orderId: confirmed.id) ?? confirmed;
    } catch (error, stackTrace) {
      debugPrint('[Phase4][after-payment] $error');
      debugPrintStack(stackTrace: stackTrace);
      return confirmed;
    }
  }

  @override
  Future<List<QueueOrder>> fetchPaidQueue() async {
    final List<QueueOrder> firebaseOrders = await _firestore.fetchPaidQueue();
    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      return _overlayStaffOrders(firebaseOrders, snapshots);
    } catch (error, stackTrace) {
      debugPrint('[Phase4][paid-queue] $error');
      debugPrintStack(stackTrace: stackTrace);
      return firebaseOrders;
    }
  }

  @override
  Stream<List<QueueOrder>> watchPaidQueue() {
    return _combineStaffOrderStream(_firestore.watchPaidQueue());
  }

  @override
  Stream<List<AutomaticAssignmentQueueItem>> watchAutomaticAssignmentQueue() {
    // Le contenu exposé reste la file technique Firebase. En revanche, les
    // changements Supabase Phase 4 doivent aussi réveiller le moteur staff :
    // c'est notamment ce qui permet de nettoyer rapidement un ancien miroir
    // Firestore après un refus manuel, sans remettre le refus lui-même sur
    // Firestore.
    final StreamController<List<AutomaticAssignmentQueueItem>> controller =
        StreamController<List<AutomaticAssignmentQueueItem>>();
    List<AutomaticAssignmentQueueItem> firebaseItems =
        const <AutomaticAssignmentQueueItem>[];
    bool firebaseReady = false;
    String? lastPhase4Signature;

    void emit() {
      if (!firebaseReady || controller.isClosed) return;
      controller.add(firebaseItems);
    }

    late final StreamSubscription<List<AutomaticAssignmentQueueItem>>
    firebaseSubscription;
    late final StreamSubscription<List<Phase4AssignmentSnapshot>>
    phase4Subscription;

    controller.onListen = () {
      firebaseSubscription = _firestore.watchAutomaticAssignmentQueue().listen(
        (List<AutomaticAssignmentQueueItem> value) {
          firebaseItems = value;
          firebaseReady = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      phase4Subscription = _phase4.watchAllForStaff().listen(
        (List<Phase4AssignmentSnapshot> value) {
          final String signature = value
              .map(
                (Phase4AssignmentSnapshot item) =>
                    '${item.orderId}|${item.assignmentState}|${item.assignedAgentId ?? ''}|${item.assignmentMode?.name ?? ''}',
              )
              .join(';;');
          if (signature == lastPhase4Signature) return;
          lastPhase4Signature = signature;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          // La file Firebase reste utilisable si Supabase est temporairement
          // indisponible ; on journalise seulement le réveil Phase 4 manquant.
          debugPrint('[Phase4][queue-wakeup] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );
    };
    controller.onCancel = () async {
      await firebaseSubscription.cancel();
      await phase4Subscription.cancel();
    };
    return controller.stream;
  }

  @override
  Future<void> synchronizeAutomaticAssignmentBacklog() async {
    final List<QueueOrder> firebaseOrders = await _firestore.fetchPaidQueue();

    final List<AutomaticAssignmentAgent> baseCandidates = await _firestore
        .fetchAutomaticAssignmentCandidatesForHybrid();
    List<Phase4AssignmentSnapshot> snapshots = await _phase4.fetchAllForStaff();

    final List<QueueOrder> backlog = firebaseOrders
        .where(
          (QueueOrder order) =>
              order.status == QueueOrderStatus.paidReady &&
              order.isFundedForProcessing,
        )
        .take(_maximumBacklogOrders)
        .toList(growable: false);

    for (final QueueOrder order in backlog) {
      try {
        final Phase4AssignmentSnapshot snapshot = await _syncBacklogOrder(
          order: order,
          baseCandidates: baseCandidates,
          allSnapshots: snapshots,
        );
        snapshots = <Phase4AssignmentSnapshot>[
          for (final Phase4AssignmentSnapshot item in snapshots)
            if (item.orderId != snapshot.orderId) item,
          snapshot,
        ];
      } catch (error, stackTrace) {
        debugPrint('[Phase4][backlog] order=${order.id}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    await _closeObsoleteNegotiations(
      paidQueue: firebaseOrders,
      snapshots: snapshots,
    );
  }

  Future<void> _closeObsoleteNegotiations({
    required List<QueueOrder> paidQueue,
    required List<Phase4AssignmentSnapshot> snapshots,
  }) async {
    final Set<String> activePaidIds = paidQueue
        .map((QueueOrder order) => order.id)
        .toSet();
    for (final Phase4AssignmentSnapshot snapshot in snapshots) {
      if (!(snapshot.isWaiting ||
          snapshot.isAssigned ||
          snapshot.isAccepted ||
          snapshot.isManualRequired)) {
        continue;
      }
      if (activePaidIds.contains(snapshot.orderId)) continue;
      try {
        final QueueOrder firebaseOrder = await _firestore.fetchOrderById(
          orderId: snapshot.orderId,
        );

        if (snapshot.isAccepted &&
            firebaseOrder.assignedAgentId == snapshot.assignedAgentId &&
            firebaseOrder.assignmentStatus == OrderAssignmentStatus.accepted) {
          // Le téléphone de l'agent a bien terminé le handoff Firebase, mais
          // son dernier marqueur Supabase a pu échouer après coup. On répare
          // l'état même si la commande est déjà passée en traitement.
          await _phase4.reconcileAcceptance(
            orderId: snapshot.orderId,
            firebaseHandoffConfirmed: true,
          );
          continue;
        }

        if (firebaseOrder.status == QueueOrderStatus.paidReady &&
            firebaseOrder.isFundedForProcessing) {
          continue;
        }
        await _phase4.closeOrder(snapshot.orderId);
      } catch (error, stackTrace) {
        debugPrint('[Phase4][close-obsolete] ${snapshot.orderId}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<Phase4AssignmentSnapshot> _syncBacklogOrder({
    required QueueOrder order,
    required List<AutomaticAssignmentAgent> baseCandidates,
    required List<Phase4AssignmentSnapshot> allSnapshots,
  }) async {
    // Une commande déjà acceptée dans Firebase a quitté la négociation. Si elle
    // n'existait pas encore dans Phase 4, on ne la réimporte pas.
    final Phase4AssignmentSnapshot? existing = _findSnapshot(
      allSnapshots,
      order.id,
    );
    if (order.assignmentStatus == OrderAssignmentStatus.accepted &&
        existing == null) {
      return Phase4AssignmentSnapshot(
        orderId: order.id,
        orderReference: order.reference,
        network: order.network,
        amount: order.amount,
        source: order.source,
        clientName: order.clientName,
        clientWhatsappPhone: order.clientWhatsappPhone,
        beneficiaryPhone: order.beneficiaryPhone,
        operationType: order.operationType,
        offerLabel: order.offerLabel,
        originalWhatsappMessage: order.originalWhatsappMessage,
        internalNotes: order.internalNotes,
        paymentStatus: order.paymentStatus,
        paymentPayerName: order.paymentPayerName,
        paymentReference: order.paymentReference,
        paymentConfirmedAt: order.paymentConfirmedAt,
        assignmentState: 'handed_off',
        firebaseCreatedAt: order.createdAt,
        paidAt: order.paidAt,
        assignedAgentId: order.assignedAgentId,
        assignedAgentName: order.assignedAgentName,
        assignedByUid: order.assignedByUserId,
        assignmentMode: order.assignmentMode,
        assignedAt: order.assignedAt,
        firebaseAssignmentSyncedAt: order.assignedAt,
        firebaseHandoffAt: order.assignedAt,
        updatedAt: order.assignedAt ?? order.createdAt,
      );
    }

    Phase4AssignmentSnapshot snapshot = await _phase4.syncOrder(order);

    final List<String> legacyRefusedIds = <String>{
      ...order.autoAssignmentRefusedAgentIds,
      if (order.lastAssignmentRefusedAgentId != null)
        order.lastAssignmentRefusedAgentId!,
    }.where((String id) => id.trim().isNotEmpty).toList(growable: false);
    if (legacyRefusedIds.isNotEmpty || order.manualAssignmentRequired) {
      snapshot = await _phase4.importLegacyRefusals(
        orderId: order.id,
        refusedAgentIds: legacyRefusedIds,
        manualRequired: order.manualAssignmentRequired,
      );
    }

    // Première migration d'une affectation Firestore encore en attente.
    if (snapshot.isWaiting &&
        order.assignedAgentId != null &&
        order.assignmentStatus == OrderAssignmentStatus.assigned) {
      final AutomaticAssignmentAgent? current = _findAgent(
        baseCandidates,
        order.assignedAgentId!,
      );
      if (current != null) {
        final OrderAssignmentMode mode =
            order.assignmentMode ?? OrderAssignmentMode.automatic;
        final List<AutomaticAssignmentAgent> candidates;
        if (mode == OrderAssignmentMode.manual) {
          candidates = <AutomaticAssignmentAgent>[current];
        } else {
          final List<AutomaticAssignmentAgent> ranked = _rankCandidates(
            order: order,
            baseCandidates: baseCandidates,
            allSnapshots: allSnapshots,
          );
          candidates = <AutomaticAssignmentAgent>[
            current,
            ...ranked.where(
              (AutomaticAssignmentAgent item) =>
                  item.agentId != current.agentId,
            ),
          ];
        }
        snapshot = await _phase4.assignRanked(
          orderId: order.id,
          candidates: candidates,
          mode: mode,
        );
        if (mode == OrderAssignmentMode.manual) {
          // Une ancienne affectation manuelle peut viser un agent qui avait
          // déjà refusé auparavant. On conserve donc ce miroir jusqu'à la
          // décision de l'agent : il permettra une acceptation Firebase
          // classique sans passer par l'auto-claim 9E, qui exclut justement
          // les agents déjà refusés.
          try {
            snapshot = await _phase4.markFirebaseAssignmentSynced(order.id);
          } catch (error, stackTrace) {
            debugPrint('[Phase4][legacy-manual-marker] $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        } else {
          final QueueOrder released = await _firestore
              .releaseHybridStaleAssignmentAsStaff(orderId: order.id);
          await _firestore.ensureHybridAssignmentQueue(released);
        }
      }
      return snapshot;
    }

    if (snapshot.isManualRequired) {
      if (order.assignedAgentId != null ||
          order.assignmentStatus != OrderAssignmentStatus.unassigned) {
        await _firestore.releaseHybridStaleAssignmentAsStaff(orderId: order.id);
      }
      await _firestore.ensureHybridAssignmentQueue(
        order.copyWith(clearAgentAssignment: true),
      );
      return snapshot;
    }

    if (snapshot.isAssigned) {
      if (snapshot.assignmentMode == OrderAssignmentMode.manual) {
        final String? targetAgentId = snapshot.assignedAgentId;
        if (targetAgentId == null || targetAgentId.trim().isEmpty) {
          return _phase4.resetForManualAssignment(order.id);
        }

        // Phase 4 : une affectation manuelle reste Supabase-only tant que
        // l'Agent ne l'a pas acceptée. On ne recrée plus ici une affectation
        // manuelle Firestore, car les rules historiques peuvent la refuser.
        // Le handoff Firebase est effectué par l'Agent au moment de Accepter.
        final bool sameLegacyFirebaseMirror =
            order.assignedAgentId == targetAgentId &&
            order.assignmentStatus == OrderAssignmentStatus.assigned &&
            order.assignmentMode == OrderAssignmentMode.manual;
        if (sameLegacyFirebaseMirror) {
          if (snapshot.firebaseAssignmentSyncedAt == null) {
            try {
              return await _phase4.markFirebaseAssignmentSynced(order.id);
            } catch (error, stackTrace) {
              debugPrint('[Phase4][manual-legacy-marker] ${order.id}: $error');
              debugPrintStack(stackTrace: stackTrace);
            }
          }
          return snapshot;
        }

        QueueOrder cleanOrder = order;
        if (order.assignedAgentId != null ||
            order.assignmentStatus != OrderAssignmentStatus.unassigned) {
          cleanOrder = await _firestore.releaseHybridStaleAssignmentAsStaff(
            orderId: order.id,
          );
        }
        await _firestore.ensureHybridAssignmentQueue(
          cleanOrder.copyWith(clearAgentAssignment: true),
        );
        return snapshot;
      }

      if (snapshot.firebaseAssignmentSyncedAt == null &&
          snapshot.assignmentMode == OrderAssignmentMode.automatic) {
        // Réévalue disponibilité/capacité/quota avec les données Firebase
        // actuelles. phase4_assign_ranked conserve l'agent s'il reste éligible
        // et le remplace atomiquement sinon.
        final List<AutomaticAssignmentAgent> ranked = _rankCandidates(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: baseCandidates,
          allSnapshots: allSnapshots,
        );
        snapshot = await _phase4.assignRanked(
          orderId: order.id,
          candidates: ranked,
          mode: OrderAssignmentMode.automatic,
        );
      }

      if (snapshot.isManualRequired) {
        if (order.assignedAgentId != null) {
          await _firestore.releaseHybridStaleAssignmentAsStaff(
            orderId: order.id,
          );
        }
        await _firestore.ensureHybridAssignmentQueue(
          order.copyWith(clearAgentAssignment: true),
        );
        return snapshot;
      }
      if (snapshot.isWaiting) {
        if (order.assignedAgentId != null) {
          await _firestore.releaseHybridStaleAssignmentAsStaff(
            orderId: order.id,
          );
        }
        await _firestore.ensureHybridAssignmentQueue(
          order.copyWith(clearAgentAssignment: true),
        );
        return snapshot;
      }

      if (snapshot.firebaseAssignmentSyncedAt == null) {
        QueueOrder queueOrder = order;
        if (order.assignedAgentId != null ||
            order.assignmentStatus != OrderAssignmentStatus.unassigned) {
          queueOrder = await _firestore.releaseHybridStaleAssignmentAsStaff(
            orderId: order.id,
          );
        }
        await _firestore.ensureHybridAssignmentQueue(
          queueOrder.copyWith(clearAgentAssignment: true),
        );
      }
      return snapshot;
    }

    if (snapshot.isAccepted) {
      final bool firebaseHandoffConfirmed =
          order.assignedAgentId == snapshot.assignedAgentId &&
          order.assignmentStatus == OrderAssignmentStatus.accepted;
      if (firebaseHandoffConfirmed) {
        try {
          return await _phase4.reconcileAcceptance(
            orderId: order.id,
            firebaseHandoffConfirmed: true,
          );
        } catch (error, stackTrace) {
          debugPrint('[Phase4][reconcile-handoff] ${order.id}: $error');
          debugPrintStack(stackTrace: stackTrace);
          return snapshot;
        }
      }

      // Ne jamais rouvrir une acceptation pendant que le téléphone de l'agent
      // est encore entre la validation Supabase et le handoff Firebase.
      final Duration acceptanceAge = DateTime.now().difference(
        snapshot.updatedAt,
      );
      if (acceptanceAge >= const Duration(seconds: 15)) {
        try {
          return await _phase4.reconcileAcceptance(
            orderId: order.id,
            firebaseHandoffConfirmed: false,
          );
        } catch (error, stackTrace) {
          debugPrint('[Phase4][reopen-stale-acceptance] ${order.id}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      return snapshot;
    }

    if (snapshot.isHandedOff) {
      return snapshot;
    }

    // waiting : on maintient toujours le pont technique puis on tente une
    // affectation avec l'état opérationnel Firebase le plus récent.
    await _firestore.ensureHybridAssignmentQueue(
      order.copyWith(clearAgentAssignment: true),
    );
    return await _tryAutomaticAssignmentWithContext(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: baseCandidates,
          allSnapshots: allSnapshots,
        ) ??
        snapshot;
  }

  @override
  Future<QueueOrder?> tryAutomaticAssignment({required String orderId}) async {
    final QueueOrder order = await _firestore.fetchOrderById(orderId: orderId);
    if (order.status != QueueOrderStatus.paidReady ||
        !order.isFundedForProcessing) {
      return null;
    }

    Phase4AssignmentSnapshot snapshot = await _phase4.syncOrder(order);
    if (snapshot.isAssigned || snapshot.isAccepted || snapshot.isHandedOff) {
      final Phase4AssignmentPlan? plan = await _phase4.fetchPlan(order.id);
      return snapshot.overlayOn(
        order,
        refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
      );
    }
    if (snapshot.isManualRequired) {
      final Phase4AssignmentPlan? plan = await _phase4.fetchPlan(order.id);
      return snapshot.overlayOn(
        order,
        refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
      );
    }

    await _firestore.ensureHybridAssignmentQueue(
      order.copyWith(clearAgentAssignment: true),
    );
    final List<AutomaticAssignmentAgent> candidates = await _firestore
        .fetchAutomaticAssignmentCandidatesForHybrid();
    final List<Phase4AssignmentSnapshot> allSnapshots = await _phase4
        .fetchAllForStaff();
    snapshot =
        await _tryAutomaticAssignmentWithContext(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: candidates,
          allSnapshots: allSnapshots,
        ) ??
        snapshot;
    final Phase4AssignmentPlan? plan = await _phase4.fetchPlan(order.id);
    return snapshot.overlayOn(
      order,
      refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
    );
  }

  Future<Phase4AssignmentSnapshot?> _tryAutomaticAssignmentWithContext({
    required QueueOrder order,
    required List<AutomaticAssignmentAgent> baseCandidates,
    required List<Phase4AssignmentSnapshot> allSnapshots,
  }) async {
    final List<AutomaticAssignmentAgent> ranked = _rankCandidates(
      order: order,
      baseCandidates: baseCandidates,
      allSnapshots: allSnapshots,
    );
    return _phase4.assignRanked(
      orderId: order.id,
      candidates: ranked,
      mode: OrderAssignmentMode.automatic,
    );
  }

  List<AutomaticAssignmentAgent> _rankCandidates({
    required QueueOrder order,
    required List<AutomaticAssignmentAgent> baseCandidates,
    required List<Phase4AssignmentSnapshot> allSnapshots,
  }) {
    final List<AutomaticAssignmentAgent> adjusted = baseCandidates
        .map(
          (AutomaticAssignmentAgent agent) =>
              _withPhase4Usage(agent, allSnapshots, excludingOrderId: order.id),
        )
        .toList(growable: false);
    return _selector.rankEligibleIgnoringPreviousRefusals(
      order: order,
      agents: adjusted,
    );
  }

  AutomaticAssignmentAgent _withPhase4Usage(
    AutomaticAssignmentAgent agent,
    List<Phase4AssignmentSnapshot> snapshots, {
    String? excludingOrderId,
  }) {
    int activeExtra = 0;
    int orangeExtra = 0;
    int mtnExtra = 0;
    int moovExtra = 0;
    int todayCountExtra = 0;
    int todayAmountExtra = 0;
    DateTime? lastExtra;
    final DateTime nowUtc = DateTime.now().toUtc();

    for (final Phase4AssignmentSnapshot snapshot in snapshots) {
      if (snapshot.orderId == excludingOrderId) continue;
      if (!snapshot.reservesCapacityInSupabase ||
          snapshot.assignedAgentId != agent.agentId) {
        continue;
      }
      activeExtra += 1;
      switch (snapshot.network) {
        case MobileNetwork.orange:
          orangeExtra += snapshot.amount;
          break;
        case MobileNetwork.mtn:
          mtnExtra += snapshot.amount;
          break;
        case MobileNetwork.moov:
          moovExtra += snapshot.amount;
          break;
      }
      final DateTime? assigned = snapshot.assignedAt;
      if (assigned != null) {
        final DateTime utc = assigned.toUtc();
        if (_sameUtcDay(utc, nowUtc)) {
          todayCountExtra += 1;
          todayAmountExtra += snapshot.amount;
        }
        if (lastExtra == null || assigned.isAfter(lastExtra)) {
          lastExtra = assigned;
        }
      }
    }

    final DateTime? baseLast = agent.lastAssignedAt;
    final DateTime? lastAssignedAt;
    if (baseLast == null) {
      lastAssignedAt = lastExtra;
    } else if (lastExtra == null) {
      lastAssignedAt = baseLast;
    } else {
      lastAssignedAt = lastExtra.isAfter(baseLast) ? lastExtra : baseLast;
    }

    return AutomaticAssignmentAgent(
      agentId: agent.agentId,
      name: agent.name,
      isActive: agent.isActive,
      isAvailable: agent.isAvailable,
      authorizedNetworks: agent.authorizedNetworks,
      activeNetworks: agent.activeNetworks,
      orangeCapacity: agent.orangeCapacity,
      mtnCapacity: agent.mtnCapacity,
      moovCapacity: agent.moovCapacity,
      dailyTransactionLimit: agent.dailyTransactionLimit,
      maxTransactionsPerDay: agent.maxTransactionsPerDay,
      activeAssignmentCount: agent.activeAssignmentCount + activeExtra,
      orangeReservedAmount: agent.orangeReservedAmount + orangeExtra,
      mtnReservedAmount: agent.mtnReservedAmount + mtnExtra,
      moovReservedAmount: agent.moovReservedAmount + moovExtra,
      todayAssignmentCount: agent.todayAssignmentCount + todayCountExtra,
      todayAssignedAmount: agent.todayAssignedAmount + todayAmountExtra,
      lastAssignedAt: lastAssignedAt,
    );
  }

  @override
  Future<bool> claimAutomaticQueueItem({
    required AutomaticAssignmentQueueItem item,
    required String agentId,
  }) {
    // Conservé pour compatibilité avec les anciens écrans. Le flux Phase 4
    // normal passe par acceptAgentAssignment().
    return _firestore.claimAutomaticQueueItem(item: item, agentId: agentId);
  }

  @override
  Future<QueueOrder> assignToAgent({
    required String orderId,
    required String agentId,
    required String assignedByUserId,
  }) async {
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != assignedByUserId.trim()) {
      throw StateError('La session administrateur ne correspond pas.');
    }

    QueueOrder order = await _firestore.fetchOrderById(orderId: orderId);
    if (order.status != QueueOrderStatus.paidReady ||
        !order.isFundedForProcessing) {
      throw StateError('Cette commande ne peut pas être affectée.');
    }

    final bool existingManualMirror =
        order.assignedAgentId == agentId &&
        order.assignmentStatus == OrderAssignmentStatus.assigned &&
        order.assignmentMode == OrderAssignmentMode.manual;

    // L'affectation manuelle Phase 4 ne doit effectuer AUCUNE écriture
    // Firestore avant l'acceptation de l'Agent. On neutralise localement un
    // éventuel miroir historique et Supabase reste l'unique source de décision.
    final QueueOrder phase4SourceOrder = existingManualMirror
        ? order
        : order.copyWith(clearAgentAssignment: true);

    await _phase4.syncOrder(phase4SourceOrder);

    final List<AutomaticAssignmentAgent> agents = await _firestore
        .fetchAutomaticAssignmentCandidatesForHybrid();
    final AutomaticAssignmentAgent? rawTarget = _findAgent(agents, agentId);
    if (rawTarget == null) {
      throw StateError('Le profil opérationnel de cet agent est introuvable.');
    }
    final List<Phase4AssignmentSnapshot> currentSnapshots = await _phase4
        .fetchAllForStaff();
    final AutomaticAssignmentAgent target = _withPhase4Usage(
      rawTarget,
      currentSnapshots,
      excludingOrderId: order.id,
    );
    final String? ineligibility = target.ineligibilityReason(
      order: order,
      ignorePreviousRefusals: true,
    );
    if (ineligibility != null) {
      throw StateError(
        'Cet agent n’est plus éligible pour cette commande ($ineligibility).',
      );
    }

    final Phase4AssignmentSnapshot assigned = await _phase4.assignRanked(
      orderId: order.id,
      candidates: <AutomaticAssignmentAgent>[target],
      mode: OrderAssignmentMode.manual,
    );

    if (existingManualMirror) {
      try {
        final Phase4AssignmentSnapshot marked = await _phase4
            .markFirebaseAssignmentSynced(order.id);
        return marked.overlayOn(order);
      } catch (error, stackTrace) {
        debugPrint('[Phase4][manual-existing-marker] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    // Ne pas appeler FirestoreOrdersRepository.assignToAgent ici : cette
    // transition manuelle dépend d'un ruleset historique qui peut renvoyer
    // permission-denied. Supabase est la source de vérité avant acceptation.
    return assigned.overlayOn(phase4SourceOrder);
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    final Map<String, int> result = Map<String, int>.from(
      await _firestore.fetchActiveAssignmentCounts(),
    );
    final List<Phase4AssignmentSnapshot> snapshots = await _phase4
        .fetchAllForStaff();
    for (final Phase4AssignmentSnapshot snapshot in snapshots) {
      final String? agentId = snapshot.assignedAgentId;
      if (!snapshot.reservesCapacityInSupabase || agentId == null) continue;
      result[agentId] = (result[agentId] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(result);
  }

  @override
  Stream<Map<String, int>> watchActiveAssignmentCounts() async* {
    Map<String, int>? lastSuccessful;
    while (true) {
      try {
        final Map<String, int> value = await fetchActiveAssignmentCounts();
        lastSuccessful = value;
        yield value;
      } catch (error, stackTrace) {
        debugPrint('[Phase4][active-counts] $error');
        debugPrintStack(stackTrace: stackTrace);
        if (lastSuccessful == null) rethrow;
      }
      await Future<void>.delayed(
        SupabasePhase4AssignmentRepository.pollInterval,
      );
    }
  }

  @override
  Future<int> fetchActiveReservedAmount({
    required String agentId,
    required MobileNetwork network,
  }) async {
    int amount = await _firestore.fetchActiveReservedAmount(
      agentId: agentId,
      network: network,
    );
    final List<Phase4AssignmentSnapshot> snapshots = await _phase4
        .fetchAllForStaff();
    for (final Phase4AssignmentSnapshot snapshot in snapshots) {
      if (snapshot.reservesCapacityInSupabase &&
          snapshot.assignedAgentId == agentId &&
          snapshot.network == network) {
        amount += snapshot.amount;
      }
    }
    return amount;
  }

  @override
  Stream<List<QueueOrder>> watchAssignedOrders({required String agentId}) {
    final String cleanedAgentId = agentId.trim();
    if (cleanedAgentId.isEmpty) {
      return Stream<List<QueueOrder>>.value(const <QueueOrder>[]);
    }

    final StreamController<List<QueueOrder>> controller =
        StreamController<List<QueueOrder>>();
    List<QueueOrder> firebaseOrders = const <QueueOrder>[];
    Phase4AgentAssignmentState phase4State = const Phase4AgentAssignmentState(
      currentAssignments: <Phase4AssignmentSnapshot>[],
      knownPhase4OrderIds: <String>{},
    );
    bool firebaseReady = false;
    bool phase4Ready = false;

    void emit() {
      if (!firebaseReady || !phase4Ready || controller.isClosed) return;
      controller.add(
        _mergeAgentOrders(
          agentId: cleanedAgentId,
          firebaseOrders: firebaseOrders,
          phase4State: phase4State,
        ),
      );
    }

    late final StreamSubscription<List<QueueOrder>> firebaseSubscription;
    late final StreamSubscription<Phase4AgentAssignmentState>
    phase4Subscription;

    controller.onListen = () {
      firebaseSubscription = _firestore
          .watchAssignedOrders(agentId: cleanedAgentId)
          .listen(
            (List<QueueOrder> value) {
              firebaseOrders = value;
              firebaseReady = true;
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!phase4Ready && !controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
          );
      phase4Subscription = _phase4
          .watchAgentAssignmentState(cleanedAgentId)
          .listen(
            (Phase4AgentAssignmentState value) {
              phase4State = value;
              phase4Ready = true;
              // Si Firestore échoue mais Supabase possède déjà une affectation
              // pré-handoff, l'Agent doit tout de même pouvoir l'accepter/refuser.
              if (!firebaseReady && value.currentAssignments.isNotEmpty) {
                firebaseReady = true;
                firebaseOrders = const <QueueOrder>[];
              }
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!phase4Ready) {
                phase4Ready = true;
                phase4State = const Phase4AgentAssignmentState(
                  currentAssignments: <Phase4AssignmentSnapshot>[],
                  knownPhase4OrderIds: <String>{},
                );
              }
              if (firebaseReady) {
                emit();
              } else if (!controller.isClosed) {
                controller.addError(error, stackTrace);
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

  List<QueueOrder> _mergeAgentOrders({
    required String agentId,
    required List<QueueOrder> firebaseOrders,
    required Phase4AgentAssignmentState phase4State,
  }) {
    final Map<String, Phase4AssignmentSnapshot> currentById =
        <String, Phase4AssignmentSnapshot>{
          for (final Phase4AssignmentSnapshot item
              in phase4State.currentAssignments)
            item.orderId: item,
        };
    final Map<String, QueueOrder> result = <String, QueueOrder>{};

    for (final QueueOrder firebaseOrder in firebaseOrders) {
      final Phase4AssignmentSnapshot? snapshot = currentById[firebaseOrder.id];
      if (snapshot != null) {
        if (snapshot.assignedAgentId != agentId) continue;
        result[firebaseOrder.id] = snapshot.overlayOn(firebaseOrder);
        continue;
      }

      // Une commande connue par Phase 4 mais qui n'est plus dans les
      // affectations courantes de cet agent est un vieux miroir Firestore : on
      // le masque immédiatement après refus/réaffectation.
      if (phase4State.knownPhase4OrderIds.contains(firebaseOrder.id)) {
        continue;
      }
      result[firebaseOrder.id] = firebaseOrder;
    }

    for (final Phase4AssignmentSnapshot snapshot
        in phase4State.currentAssignments) {
      if (snapshot.assignedAgentId != agentId) continue;
      result.putIfAbsent(
        snapshot.orderId,
        () => snapshot.toPendingQueueOrder(),
      );
    }

    final List<QueueOrder> orders = result.values.toList(growable: false)
      ..sort((QueueOrder first, QueueOrder second) {
        final DateTime firstDate = first.assignedAt ?? first.createdAt;
        final DateTime secondDate = second.assignedAt ?? second.createdAt;
        return secondDate.compareTo(firstDate);
      });
    return List<QueueOrder>.unmodifiable(orders);
  }

  @override
  Stream<List<QueueOrder>> watchAgentRefusedOrders({required String agentId}) {
    return _phase4.watchAgentRefusedOrders(agentId);
  }

  @override
  Future<QueueOrder> acceptAgentAssignment({
    required String orderId,
    required String agentId,
  }) async {
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != agentId.trim()) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }

    await _phase4.accept(orderId);
    try {
      final QueueOrder accepted = await _firestore
          .handoffHybridAcceptedAssignment(orderId: orderId, agentId: agentId);
      try {
        await _phase4.markHandoff(orderId);
      } catch (error, stackTrace) {
        // Le handoff Firebase est déjà effectif. Ne jamais faire échouer une
        // acceptation fonctionnelle uniquement parce que le marqueur Supabase
        // n'a pas pu être mis à jour ; le staff le verra comme accepté.
        debugPrint('[Phase4][handoff-marker] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return accepted;
    } catch (error) {
      try {
        await _phase4.reopenAcceptance(orderId);
      } catch (_) {
        // Le prochain rafraîchissement réconciliera l'état.
      }
      rethrow;
    }
  }

  @override
  Future<QueueOrder> refuseAgentAssignment({
    required String orderId,
    required String agentId,
    required String reason,
  }) async {
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || uid != agentId.trim()) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3) {
      throw StateError('Indique un motif de refus plus précis.');
    }
    if (cleanedReason.length > 500) {
      throw StateError('Le motif de refus est trop long.');
    }

    final Phase4AssignmentSnapshot? before = await _phase4.fetchOrder(orderId);
    if (before == null || before.assignedAgentId != agentId) {
      throw StateError('Cette affectation n’est plus disponible.');
    }
    await _phase4.refuse(orderId: orderId, reason: cleanedReason);

    final List<String> refusedForLocalSnapshot = <String>[agentId];
    return before
        .toPendingQueueOrder(refusedAgentIds: refusedForLocalSnapshot)
        .copyWith(
          assignedAgentId: agentId,
          assignedAgentName: before.assignedAgentName,
          assignmentStatus: OrderAssignmentStatus.refused,
          lastAssignmentRefusalReason: cleanedReason,
          lastAssignmentRefusedAt: DateTime.now(),
          lastAssignmentRefusedAgentId: agentId,
          autoAssignmentRefusedAgentIds: refusedForLocalSnapshot,
        );
  }

  @override
  Future<QueueOrder> startAgentProcessing({
    required String orderId,
    required String agentId,
  }) {
    return _firestore.startAgentProcessing(orderId: orderId, agentId: agentId);
  }

  @override
  Future<QueueOrder> resumeAgentProcessing({
    required String orderId,
    required String agentId,
  }) {
    return _firestore.resumeAgentProcessing(orderId: orderId, agentId: agentId);
  }

  @override
  Future<OrderProof?> fetchOrderProof({required String orderId}) {
    return _firestore.fetchOrderProof(orderId: orderId);
  }

  @override
  Future<OrderProof> saveOrderProof({
    required String orderId,
    required String orderReference,
    required String agentId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) {
    return _firestore.saveOrderProof(
      orderId: orderId,
      orderReference: orderReference,
      agentId: agentId,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  @override
  Future<QueueOrder> markAgentSuccessful({
    required String orderId,
    required String agentId,
  }) {
    return _firestore.markAgentSuccessful(orderId: orderId, agentId: agentId);
  }

  @override
  Future<QueueOrder> markAgentFailed({
    required String orderId,
    required String agentId,
    required OrderFailureReason reason,
    String? observation,
  }) {
    return _firestore.markAgentFailed(
      orderId: orderId,
      agentId: agentId,
      reason: reason,
      observation: observation,
    );
  }

  @override
  Future<QueueOrder> putAgentOnHold({
    required String orderId,
    required String agentId,
    required String reason,
  }) {
    return _firestore.putAgentOnHold(
      orderId: orderId,
      agentId: agentId,
      reason: reason,
    );
  }

  @override
  Future<QueueOrder> prepareFailedOrderForReassignment({
    required String orderId,
  }) async {
    final QueueOrder reopened = await _firestore
        .prepareFailedOrderForReassignment(orderId: orderId);
    await _firestore.ensureHybridAssignmentQueue(reopened);
    await _phase4.syncOrder(reopened);
    await _phase4.resetForManualAssignment(orderId);
    return reopened.copyWith(
      clearAgentAssignment: true,
      manualAssignmentRequired: true,
    );
  }

  @override
  Future<List<QueueOrder>> fetchOrderHistory() async {
    final List<QueueOrder> firebaseOrders = await _firestore
        .fetchOrderHistory();
    try {
      return _overlayStaffOrders(
        firebaseOrders,
        await _phase4.fetchAllForStaff(),
      );
    } catch (_) {
      return firebaseOrders;
    }
  }

  @override
  Stream<List<QueueOrder>> watchOrderHistory() {
    return _combineStaffOrderStream(_firestore.watchOrderHistory());
  }

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) async {
    final QueueOrder order = await _firestore.fetchOrderById(orderId: orderId);
    try {
      final Phase4AssignmentSnapshot? snapshot = await _phase4.fetchOrder(
        orderId,
      );
      if (snapshot == null) return order;
      final Phase4AssignmentPlan? plan = await _phase4.fetchPlan(orderId);
      return snapshot.overlayOn(
        order,
        refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
      );
    } catch (_) {
      return order;
    }
  }

  Stream<List<QueueOrder>> _combineStaffOrderStream(
    Stream<List<QueueOrder>> firebaseStream,
  ) {
    final StreamController<List<QueueOrder>> controller =
        StreamController<List<QueueOrder>>();
    List<QueueOrder> firebaseOrders = const <QueueOrder>[];
    List<Phase4AssignmentSnapshot> snapshots =
        const <Phase4AssignmentSnapshot>[];
    bool firebaseReady = false;
    bool phaseReady = false;

    void emit() {
      if (!firebaseReady || !phaseReady || controller.isClosed) return;
      controller.add(_overlayStaffOrders(firebaseOrders, snapshots));
    }

    late final StreamSubscription<List<QueueOrder>> firebaseSubscription;
    late final StreamSubscription<List<Phase4AssignmentSnapshot>>
    phaseSubscription;

    controller.onListen = () {
      firebaseSubscription = firebaseStream.listen(
        (List<QueueOrder> value) {
          firebaseOrders = value;
          firebaseReady = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );
      phaseSubscription = _phase4.watchAllForStaff().listen(
        (List<Phase4AssignmentSnapshot> value) {
          snapshots = value;
          phaseReady = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          // Si le staff n'est pas encore enregistré dans Supabase, on conserve
          // la vue Firebase au lieu de faire tomber tout l'écran.
          if (!phaseReady) {
            phaseReady = true;
            snapshots = const <Phase4AssignmentSnapshot>[];
            emit();
          }
          debugPrint('[Phase4][staff-stream] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );
    };
    controller.onCancel = () async {
      await firebaseSubscription.cancel();
      await phaseSubscription.cancel();
    };
    return controller.stream;
  }

  List<QueueOrder> _overlayStaffOrders(
    List<QueueOrder> firebaseOrders,
    List<Phase4AssignmentSnapshot> snapshots,
  ) {
    final Map<String, Phase4AssignmentSnapshot> byId =
        <String, Phase4AssignmentSnapshot>{
          for (final Phase4AssignmentSnapshot item in snapshots)
            item.orderId: item,
        };
    final List<QueueOrder> result = firebaseOrders
        .map((QueueOrder order) {
          final Phase4AssignmentSnapshot? snapshot = byId[order.id];
          return snapshot?.overlayOn(order) ?? order;
        })
        .toList(growable: false);
    return List<QueueOrder>.unmodifiable(result);
  }

  Phase4AssignmentSnapshot? _findSnapshot(
    List<Phase4AssignmentSnapshot> snapshots,
    String orderId,
  ) {
    for (final Phase4AssignmentSnapshot item in snapshots) {
      if (item.orderId == orderId) return item;
    }
    return null;
  }

  AutomaticAssignmentAgent? _findAgent(
    List<AutomaticAssignmentAgent> agents,
    String agentId,
  ) {
    for (final AutomaticAssignmentAgent agent in agents) {
      if (agent.agentId == agentId) return agent;
    }
    return null;
  }

  bool _sameUtcDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  // Flux historiques de traitement : délégation intégrale à Firebase.
  @override
  Future<QueueOrder> takeCharge({
    required String orderId,
    required String operatorId,
  }) {
    return _firestore.takeCharge(orderId: orderId, operatorId: operatorId);
  }

  @override
  Future<QueueOrder> markSuccessful({required String orderId}) {
    return _firestore.markSuccessful(orderId: orderId);
  }

  @override
  Future<QueueOrder> markFailed({
    required String orderId,
    required OrderFailureReason reason,
    String? observation,
  }) {
    return _firestore.markFailed(
      orderId: orderId,
      reason: reason,
      observation: observation,
    );
  }

  @override
  Future<QueueOrder> putOnHold({required String orderId}) {
    return _firestore.putOnHold(orderId: orderId);
  }

  @override
  Future<QueueOrder> completeCustomerConfirmation({
    required String orderId,
    required bool messageSent,
  }) {
    return _firestore.completeCustomerConfirmation(
      orderId: orderId,
      messageSent: messageSent,
    );
  }
}
