import 'dart:async';

import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_order_proof_repository.dart';
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
/// Supabase reste la source de négociation pour l'affectation automatique,
/// l'acceptation, le refus et la réaffectation. Les affectations manuelles sont
/// matérialisées immédiatement dans Firestore afin de rester compatibles avec
/// le traitement opérationnel encore Firebase. Pour l'automatique, le handoff
/// Firebase intervient à l'acceptation. La Phase 5 consolide preuves,
/// capacités, mouvements, paiements et commissions dans Supabase. La transaction
/// Firebase de réussite reste seulement un pont de compatibilité jusqu’à la
/// migration du domaine Commandes post-handoff.
class HybridOrdersRepository
    implements
        OrdersRepository,
        OrderHistoryRepository,
        AgentAssignmentHistoryRepository {
  HybridOrdersRepository({
    FirestoreOrdersRepository? firestoreRepository,
    SupabasePhase4AssignmentRepository? phase4Repository,
    SupabaseOrderProofRepository? proofRepository,
    SupabasePhase5FinanceRepository? phase5FinanceRepository,
    FirebaseAuth? firebaseAuth,
  }) : _firestore =
           firestoreRepository ??
           FirestoreOrdersRepository(
             enableNativeAutoAssignment: false,
             requireFirestoreProof: false,
           ),
       _phase4 = phase4Repository ?? SupabasePhase4AssignmentRepository(),
       _proofs = proofRepository ?? SupabaseOrderProofRepository(),
       _phase5Finance = phase5FinanceRepository ?? SupabasePhase5FinanceRepository(),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const int _maximumBacklogOrders = 50;

  final FirestoreOrdersRepository _firestore;
  final SupabasePhase4AssignmentRepository _phase4;
  final SupabaseOrderProofRepository _proofs;
  final SupabasePhase5FinanceRepository _phase5Finance;
  final FirebaseAuth _firebaseAuth;
  final AutomaticAssignmentSelector _selector =
      const AutomaticAssignmentSelector();

  // Les règles Firestore actuellement gelées n'autorisent pas toujours le
  // compte Manager (alias technique supervisor) à nettoyer un ancien miroir
  // /orders. Après le premier permission-denied pour un UID donné, on cesse
  // de retenter cette écriture legacy pendant la session afin de ne pas
  // polluer la console ni interrompre la synchronisation Phase 4.
  String? _legacyMirrorCleanupDeniedUid;

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
    try {
      await _phase5Finance.mirrorOrderPayment(confirmed);
    } catch (error, stackTrace) {
      debugPrint('[Phase5][OrderPaymentMirror] $error');
      debugPrintStack(stackTrace: stackTrace);
    }

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
        // Un compte Manager reconnu par Firebase mais absent du registre
        // Supabase ne doit pas provoquer une erreur par commande à chaque
        // réveil du backlog. On remonte le refus au shell afin qu’il suspende
        // la synchronisation et affiche une seule alerte de provisioning.
        if (error.toString().contains('STAFF_REQUIRED')) {
          rethrow;
        }
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

  Future<QueueOrder> _releaseLegacyMirrorBestEffort(QueueOrder order) async {
    if (order.assignedAgentId == null &&
        order.assignmentStatus == OrderAssignmentStatus.unassigned) {
      return order;
    }

    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isNotEmpty && _legacyMirrorCleanupDeniedUid == uid) {
      return order.copyWith(clearAgentAssignment: true);
    }

    try {
      return await _firestore.releaseHybridStaleAssignmentAsStaff(
        orderId: order.id,
      );
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'permission-denied') rethrow;
      if (uid.isNotEmpty) {
        _legacyMirrorCleanupDeniedUid = uid;
      }
      debugPrint(
        '[Phase4][legacy-mirror-skip] order=${order.id}: '
        'nettoyage Firestore non autorise pour ce compte; Phase 4 reste canonique.',
      );
      debugPrintStack(stackTrace: stackTrace);
      return order.copyWith(clearAgentAssignment: true);
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

    // Un etat Phase 4 deja actif est canonique : ne le reecrivons pas a
    // chaque passage avec phase4_sync_order(). Outre le trafic inutile, cette
    // reecriture modifiait updated_at et pouvait masquer l'anciennete reelle
    // d'une acceptation en attente de handoff.
    Phase4AssignmentSnapshot snapshot =
        existing != null &&
            (existing.isAssigned ||
                existing.isAccepted ||
                existing.isHandedOff ||
                existing.isManualRequired)
        ? existing
        : await _phase4.syncOrder(order);

    final List<String> legacyRefusedIds = <String>{
      ...order.autoAssignmentRefusedAgentIds,
      if (order.lastAssignmentRefusedAgentId != null)
        order.lastAssignmentRefusedAgentId!,
    }.where((String id) => id.trim().isNotEmpty).toList(growable: false);
    // Un vieux miroir Firestore peut conserver manualAssignmentRequired=true
    // quelques secondes apres une affectation Supabase. Cet indicateur legacy
    // ne doit JAMAIS retrograder une affectation Phase 4 deja active vers
    // manual_required, sinon l'UI oscille entre "affectee" et "sans agent".
    final bool phase4HasActiveAssignment =
        snapshot.isAssigned || snapshot.isAccepted || snapshot.isHandedOff;
    final bool importManualRequired =
        order.manualAssignmentRequired && !phase4HasActiveAssignment;
    if (legacyRefusedIds.isNotEmpty || importManualRequired) {
      snapshot = await _phase4.importLegacyRefusals(
        orderId: order.id,
        refusedAgentIds: legacyRefusedIds,
        manualRequired: importManualRequired,
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
          final QueueOrder released = await _releaseLegacyMirrorBestEffort(order);
          await _firestore.ensureHybridAssignmentQueue(released);
        }
      }
      return snapshot;
    }

    if (snapshot.isManualRequired) {
      if (order.assignedAgentId != null ||
          order.assignmentStatus != OrderAssignmentStatus.unassigned) {
        await _releaseLegacyMirrorBestEffort(order);
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

        // Compatibilité avec les affectations manuelles créées avant le
        // dual-write : elles peuvent encore n'exister que dans Supabase. Les
        // nouvelles affectations passent par assignToAgent() et possèdent déjà
        // leur miroir Firestore. Pour une ancienne ligne, on conserve la file
        // technique afin que l'Agent puisse réparer le handoff à l'acceptation.
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
          cleanOrder = await _releaseLegacyMirrorBestEffort(order);
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
          await _releaseLegacyMirrorBestEffort(order);
        }
        await _firestore.ensureHybridAssignmentQueue(
          order.copyWith(clearAgentAssignment: true),
        );
        return snapshot;
      }
      if (snapshot.isWaiting) {
        if (order.assignedAgentId != null) {
          await _releaseLegacyMirrorBestEffort(order);
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
          queueOrder = await _releaseLegacyMirrorBestEffort(order);
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

    // Ne pas re-synchroniser une ligne Phase 4 deja existante a chaque
    // reveil du moteur. phase4_sync_order() met updated_at a now() meme si
    // l'affectation n'a pas change ; cela faisait paraitre une acceptation
    // ancienne comme recente et entretenait les oscillations Firestore/Supabase.
    Phase4AssignmentSnapshot snapshot =
        await _phase4.fetchOrder(order.id) ?? await _phase4.syncOrder(order);
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
    final String targetAgentId = agentId.trim();
    if (uid.isEmpty || uid != assignedByUserId.trim()) {
      throw StateError('La session du compte connecté ne correspond pas.');
    }
    if (targetAgentId.isEmpty) {
      throw StateError('Agent invalide.');
    }

    final QueueOrder order = await _firestore.fetchOrderById(orderId: orderId);
    if (order.status != QueueOrderStatus.paidReady ||
        !order.isFundedForProcessing) {
      throw StateError('Cette commande ne peut pas être affectée.');
    }

    // Phase 4 reste la source canonique de la negociation avant acceptation.
    // Une affectation manuelle n'ecrit volontairement PAS dans /orders ici :
    // le miroir Firebase est materialise par l'Agent au moment de l'acceptation.
    // Cela evite les permission-denied historiques de l'affectation Admin tout
    // en conservant l'etat immediatement visible via les streams hybrides.
    final Phase4AssignmentSnapshot? canonical = await _phase4.fetchOrder(
      order.id,
    );
    final bool canonicalHasAssignment =
        canonical != null &&
        (canonical.isAssigned || canonical.isAccepted || canonical.isHandedOff) &&
        canonical.assignedAgentId != null;

    if (canonicalHasAssignment) {
      final Phase4AssignmentSnapshot activeCanonical = canonical;
      final String canonicalAgentId = activeCanonical.assignedAgentId!.trim();
      final String canonicalAgentName =
          activeCanonical.assignedAgentName?.trim().isNotEmpty == true
          ? activeCanonical.assignedAgentName!.trim()
          : 'un agent';
      final bool sameTarget = canonicalAgentId == targetAgentId;

      if (!sameTarget ||
          activeCanonical.isAccepted ||
          activeCanonical.isHandedOff) {
        throw StateError(
          'Cette commande est déjà affectée à $canonicalAgentName. '
          'Actualise la liste avant toute réaffectation.',
        );
      }

      if (activeCanonical.assignmentMode != OrderAssignmentMode.manual) {
        throw StateError(
          'Cette commande possède déjà une affectation automatique en attente. '
          'Actualise la liste.',
        );
      }

      // Idempotence : si le double-clic ou un ancien écran relance exactement
      // la même affectation manuelle, on renvoie simplement l'état canonique.
      return activeCanonical.overlayOn(order);
    }

    // Ne jamais tenter de nettoyer/écrire le vieux miroir Firestore dans le
    // chemin Admin. Les vues hybrides masquent déjà les miroirs obsolètes à
    // partir de Phase 4 ; l'acceptation Agent effectuera le handoff Firebase.
    await _phase4.syncOrder(order.copyWith(clearAgentAssignment: true));

    // Une intervention manuelle ouvre un NOUVEAU cycle de tentative. Les refus
    // du cycle précédent restent dans l'historique Phase 4, mais ne doivent pas
    // empêcher les autres Agents éligibles d'être essayés à nouveau. Sans ce
    // reset, une vieille commande de test pouvait avoir tous ses Agents déjà
    // présents dans refused_agent_ids et repasser immédiatement en manuel dès
    // le premier refus du nouveau cycle.
    if (canonical?.isManualRequired == true) {
      await _phase4.resetForManualAssignment(order.id);
    }

    final List<AutomaticAssignmentAgent> agents = await _firestore
        .fetchAutomaticAssignmentCandidatesForHybrid();
    final AutomaticAssignmentAgent? rawTarget = _findAgent(
      agents,
      targetAgentId,
    );
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

    // L'affectation manuelle choisit le premier Agent, mais le plan Phase 4
    // doit conserver tous les autres Agents actuellement eligibles. Ainsi, si
    // le premier refuse, Supabase peut poursuivre automatiquement avec le
    // suivant. Le mode manual_required n'est atteint qu'apres refus de tous
    // les candidats eligibles conserves dans ce plan.
    final List<AutomaticAssignmentAgent> rankedFallback = _rankCandidates(
      order: order.copyWith(clearAgentAssignment: true),
      baseCandidates: agents,
      allSnapshots: currentSnapshots,
    );
    final List<AutomaticAssignmentAgent> manualPlanCandidates =
        <AutomaticAssignmentAgent>[
          target,
          ...rankedFallback.where(
            (AutomaticAssignmentAgent item) => item.agentId != targetAgentId,
          ),
        ];

    final Phase4AssignmentSnapshot assigned = await _phase4.assignRanked(
      orderId: order.id,
      candidates: manualPlanCandidates,
      mode: OrderAssignmentMode.manual,
    );

    // IMPORTANT : pas de _firestore.assignToAgent() ici. Phase 4 est visible
    // immédiatement côté Admin et Agent ; Firestore ne devient opérationnel
    // qu'au handoff d'acceptation de l'Agent.
    return assigned.overlayOn(order.copyWith(clearAgentAssignment: true));
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    final Map<String, int> result = Map<String, int>.from(
      await _firestore.fetchActiveAssignmentCounts(),
    );
    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      for (final Phase4AssignmentSnapshot snapshot in snapshots) {
        final String? agentId = snapshot.assignedAgentId;
        if (!snapshot.reservesCapacityInSupabase || agentId == null) continue;
        result[agentId] = (result[agentId] ?? 0) + 1;
      }
    } catch (error, stackTrace) {
      // La charge Firebase reste une valeur de repli sure. Ne jamais vider ou
      // faire mourir l'ecran d'affectation pour une panne Supabase transitoire.
      debugPrint('[Phase4][active-counts-fallback] $error');
      debugPrintStack(stackTrace: stackTrace);
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
        // Comme les autres pollers Phase 4, une erreur initiale ne doit pas
        // detruire le stream pour toute la session.
        yield lastSuccessful ?? const <String, int>{};
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
    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      for (final Phase4AssignmentSnapshot snapshot in snapshots) {
        if (snapshot.reservesCapacityInSupabase &&
            snapshot.assignedAgentId == agentId &&
            snapshot.network == network) {
          amount += snapshot.amount;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[Phase4][reserved-amount-fallback] $error');
      debugPrintStack(stackTrace: stackTrace);
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
    final String cleanedAgentId = agentId.trim();
    if (uid.isEmpty || uid != cleanedAgentId) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }

    await _phase4.accept(orderId);
    try {
      final QueueOrder accepted = await _firestore
          .handoffHybridAcceptedAssignment(
            orderId: orderId,
            agentId: cleanedAgentId,
          );
      try {
        await _phase4.markHandoff(orderId);
      } catch (error, stackTrace) {
        // Le handoff Firebase est deja effectif. Ne jamais faire echouer une
        // acceptation fonctionnelle uniquement parce que le marqueur Supabase
        // n'a pas pu etre mis a jour ; le staff le verra comme accepte.
        debugPrint('[Phase4][handoff-marker] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return accepted;
    } catch (error, stackTrace) {
      // Si la requete Firebase a atteint le serveur mais que sa reponse a ete
      // perdue, ne surtout pas rouvrir Supabase en "assigned". Une lecture
      // Firestore est alors autorisee a l'Agent et permet de confirmer le
      // handoff avant toute compensation.
      try {
        final QueueOrder firebase = await _firestore.fetchOrderById(
          orderId: orderId,
        );
        final bool handoffActuallySucceeded =
            firebase.assignedAgentId == cleanedAgentId &&
            firebase.assignmentStatus == OrderAssignmentStatus.accepted;
        if (handoffActuallySucceeded) {
          try {
            await _phase4.markHandoff(orderId);
          } catch (markerError, markerStackTrace) {
            debugPrint('[Phase4][handoff-confirm-marker] $markerError');
            debugPrintStack(stackTrace: markerStackTrace);
          }
          return firebase;
        }
      } catch (verificationError, verificationStackTrace) {
        debugPrint('[Phase4][handoff-confirm-read] $verificationError');
        debugPrintStack(stackTrace: verificationStackTrace);
      }

      try {
        await _phase4.reopenAcceptance(orderId);
      } catch (reopenError, reopenStackTrace) {
        // Le prochain rafraichissement reconciliara l'etat.
        debugPrint('[Phase4][handoff-reopen] $reopenError');
        debugPrintStack(stackTrace: reopenStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
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
  }) async {
    final String cleanedAgentId = agentId.trim();

    Future<QueueOrder> repairAndRetry(
      Object originalError,
      StackTrace originalStackTrace,
    ) async {
      // Une ancienne acceptation Supabase peut avoir ete conservee alors que
      // le handoff Firebase n'a jamais ete materialise. Selon l'etat du miroir,
      // Firestore peut refuser le transaction.get (permission-denied) OU laisser
      // lire la commande mais la voir encore avec assignmentStatus=assigned.
      final Phase4AssignmentSnapshot? snapshot = await _phase4.fetchOrder(
        orderId,
      );
      final bool canRepairHandoff =
          snapshot != null &&
          snapshot.assignedAgentId == cleanedAgentId &&
          (snapshot.isAccepted || snapshot.isHandedOff);
      if (!canRepairHandoff) {
        debugPrint(
          '[Phase4][processing-start-denied] order=$orderId agent=$cleanedAgentId',
        );
        debugPrintStack(stackTrace: originalStackTrace);
        Error.throwWithStackTrace(originalError, originalStackTrace);
      }

      debugPrint(
        '[Phase4][processing-start-repair] order=$orderId agent=$cleanedAgentId',
      );
      await _firestore.handoffHybridAcceptedAssignment(
        orderId: orderId,
        agentId: cleanedAgentId,
      );
      try {
        await _phase4.markHandoff(orderId);
      } catch (markerError, markerStackTrace) {
        debugPrint(
          '[Phase4][processing-start-repair-marker] order=$orderId: $markerError',
        );
        debugPrintStack(stackTrace: markerStackTrace);
      }

      return _firestore.startAgentProcessing(
        orderId: orderId,
        agentId: cleanedAgentId,
      );
    }

    try {
      return await _firestore.startAgentProcessing(
        orderId: orderId,
        agentId: cleanedAgentId,
      );
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'permission-denied') rethrow;
      return repairAndRetry(error, stackTrace);
    } on StateError catch (error, stackTrace) {
      // Cas d'un miroir Firebase existant mais reste au statut "assigned"
      // alors que Phase 4 est deja accepted/handed_off.
      if (!error.toString().contains('Cette commande ne t’est plus affectée')) {
        rethrow;
      }
      return repairAndRetry(error, stackTrace);
    }
  }

  @override
  Future<QueueOrder> resumeAgentProcessing({
    required String orderId,
    required String agentId,
  }) {
    return _firestore.resumeAgentProcessing(orderId: orderId, agentId: agentId);
  }

  @override
  Future<OrderProof?> fetchOrderProof({required String orderId}) async {
    final OrderProof? proof = await _proofs.fetchProof(orderId: orderId);
    if (proof != null) return proof;

    // Compatibilite historique uniquement : les anciennes preuves deja
    // presentes dans Firestore restent consultables pendant la transition.
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
    return _proofs.saveProof(
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
  }) async {
    final String cleanedAgentId = agentId.trim();
    final OrderProof? supabaseProof = await _proofs.fetchProof(orderId: orderId);
    OrderProof? firestoreCompatibilityProof = await _firestore.fetchOrderProof(
      orderId: orderId,
    );

    if (supabaseProof != null) {
      if (supabaseProof.agentId.trim() != cleanedAgentId) {
        throw StateError('La preuve enregistree appartient a un autre agent.');
      }

      if (firestoreCompatibilityProof == null) {
        // Pont de transition Phase 5B1 -> 5B2.
        // Les regles Firestore actuellement publiees exigent encore
        // orderProofs/{orderId} pour autoriser le passage inProgress ->
        // completed. Supabase reste la source de verite et ce miroir n'est
        // cree qu'au moment de finaliser une commande, jusqu'a migration
        // complete du bloc capacite + commission en Phase 5B2.
        debugPrint(
          '[Phase5B1][proof-bridge] orderId=$orderId agentId=$cleanedAgentId',
        );
        firestoreCompatibilityProof = await _firestore.saveOrderProof(
          orderId: supabaseProof.orderId,
          orderReference: supabaseProof.orderReference,
          agentId: cleanedAgentId,
          fileName: supabaseProof.fileName,
          mimeType: supabaseProof.mimeType,
          bytes: supabaseProof.bytes,
        );
      }
    }

    final OrderProof? effectiveProof =
        supabaseProof ?? firestoreCompatibilityProof;
    if (effectiveProof == null ||
        effectiveProof.agentId.trim() != cleanedAgentId) {
      throw StateError('Ajoute une preuve avant de valider la reussite.');
    }

    // Phase 5 consolidée : on initialise une seule fois le registre de
    // capacité Supabase depuis le profil Firebase encore opérationnel. La
    // transaction Firebase reste le pont de compatibilité tant que ses règles
    // l'imposent, puis le registre financier Supabase est finalisé de manière
    // idempotente pour les lectures Agent / Manager / Admin web.
    final Map<MobileNetwork, int> legacyCapacities = await _firestore
        .fetchAgentCapacitiesForPhase5(agentId: cleanedAgentId);
    final QueueOrder currentOrder = await _firestore.fetchOrderById(
      orderId: orderId,
    );
    final String agentName = (
      currentOrder.assignedAgentName ??
      currentOrder.assignedAgentId ??
      'Agent'
    ).trim();
    try {
      await _phase5Finance.ensureCapacitySeed(
        agentId: cleanedAgentId,
        agentName: agentName,
        orangeCapacity: legacyCapacities[MobileNetwork.orange] ?? 0,
        mtnCapacity: legacyCapacities[MobileNetwork.mtn] ?? 0,
        moovCapacity: legacyCapacities[MobileNetwork.moov] ?? 0,
      );
    } catch (error, stackTrace) {
      debugPrint('[Phase5][CapacitySeed] $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final QueueOrder completed = await _firestore.markAgentSuccessful(
      orderId: orderId,
      agentId: cleanedAgentId,
    );

    try {
      await _phase5Finance.finalizeOrderSuccess(
        order: completed,
        agentId: cleanedAgentId,
        agentName: agentName,
      );
      await _phase5Finance.markFirestoreSuccessMirrored(orderId);
    } catch (error, stackTrace) {
      // La commande Firebase est déjà réussie. Le synchroniseur Phase 5
      // récupère ce miroir plus tard sans jamais redéduire la capacité.
      debugPrint('[Phase5][SuccessMirror] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return completed;
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
    } catch (error) {
      // STAFF_REQUIRED signifie que le compte n'a pas le droit de lire l'etat
      // canonique Phase 4. Ne jamais masquer ce cas par un vieux snapshot
      // Firestore : une page d'affectation pourrait sinon proposer une seconde
      // affectation sur une commande deja assignee dans Supabase.
      if (error.toString().contains('STAFF_REQUIRED')) {
        rethrow;
      }
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
