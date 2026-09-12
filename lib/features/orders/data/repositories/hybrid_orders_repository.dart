import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
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

/// Phase 3 IzyTel - cutover operationnel Supabase.
///
/// Firestore reste la source legacy/client avant synchronisation d'une commande
/// payee. Des qu'une commande existe dans Phase 4, Supabase devient la source
/// canonique pour l'affectation, l'acceptation/refus, le traitement, les preuves,
/// la capacite et la commission. Aucun handoff Firestore n'est requis pour les
/// nouvelles commandes operationnelles.
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
      IzyTelLog.backendError(
        'Phase5.OrderPaymentMirror',
        error,
        stackTrace: stackTrace,
      );
    }

    // Le paiement ne doit jamais être annulé parce que le moteur d'affectation
    // est temporairement indisponible. La file Firestore reste persistée et le
    // prochain passage du compte Admin reprendra la synchronisation.
    try {
      await _phase4.syncOrder(confirmed);
      return await tryAutomaticAssignment(orderId: confirmed.id) ?? confirmed;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Phase4.after-payment',
        error,
        stackTrace: stackTrace,
      );
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
      IzyTelLog.backendError(
        'Phase4.paid-queue',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      return firebaseOrders;
    }
  }

  @override
  Stream<List<QueueOrder>> watchPaidQueue() {
    return _combineStaffOrderStream(_firestore.watchPaidQueue());
  }

  @override
  Stream<List<AutomaticAssignmentQueueItem>> watchAutomaticAssignmentQueue() {
    // La file Firebase ne sert plus qu'a decouvrir les commandes payees qui
    // n'ont pas encore ete synchronisees. Les changements Supabase reveillent
    // egalement le moteur afin que l'affectation canonique reste reactive.
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
          IzyTelLog.backendError(
            'Phase4.queue-wakeup',
            error,
            stackTrace: stackTrace,
          );
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

    final List<AutomaticAssignmentAgent> baseCandidates =
        await _phase4.fetchAssignmentCandidates();
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
        IzyTelLog.backendError(
          'Phase4.backlog',
          error,
          stackTrace: stackTrace,
        );
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
      // Une commande acceptee ou deja en traitement appartient desormais a
      // Supabase. L'absence de mutation Firestore apres le cutover est normale
      // et ne doit jamais provoquer une fermeture/compensation automatique.
      if (!(snapshot.isWaiting || snapshot.isAssigned || snapshot.isManualRequired)) {
        continue;
      }
      if (snapshot.orderStatus != QueueOrderStatus.paidReady ||
          activePaidIds.contains(snapshot.orderId)) {
        continue;
      }
      try {
        final QueueOrder firebaseOrder = await _firestore.fetchOrderById(
          orderId: snapshot.orderId,
        );
        if (firebaseOrder.status == QueueOrderStatus.paidReady &&
            firebaseOrder.isFundedForProcessing) {
          continue;
        }
        await _phase4.closeOrder(snapshot.orderId);
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4.close-obsolete',
          error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<Phase4AssignmentSnapshot> _syncBacklogOrder({
    required QueueOrder order,
    required List<AutomaticAssignmentAgent> baseCandidates,
    required List<Phase4AssignmentSnapshot> allSnapshots,
  }) async {
    final Phase4AssignmentSnapshot? existing = _findSnapshot(
      allSnapshots,
      order.id,
    );
    Phase4AssignmentSnapshot snapshot =
        existing ?? await _phase4.syncOrder(order.copyWith(clearAgentAssignment: true));

    // Les anciennes lignes handed_off sans statut operationnel verifiable sont
    // conservees telles quelles pour reconciliation historique. Elles ne
    // doivent jamais forcer un retour vers Firestore pour les nouvelles actions.
    if (snapshot.legacyStateUnresolved ||
        snapshot.orderStatus != QueueOrderStatus.paidReady ||
        snapshot.isAccepted ||
        snapshot.isHandedOff) {
      return snapshot;
    }

    if (snapshot.isAssigned) {
      // L'affectation deja canonique reste stable. L'eligibilite sera revalidee
      // atomiquement par Supabase lorsque l'Agent appuie sur Accepter.
      return snapshot;
    }

    if (snapshot.isManualRequired) return snapshot;

    // Migration ponctuelle d'une ancienne affectation Firestore encore visible
    // au premier passage du cutover. On l'importe dans Supabase sans jamais
    // re-ecrire le miroir Firebase ni reimporter ses anciens refus.
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
        final List<AutomaticAssignmentAgent> ranked = _rankCandidates(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: baseCandidates,
        );
        final List<AutomaticAssignmentAgent> candidates =
            <AutomaticAssignmentAgent>[
          current,
          ...ranked.where(
            (AutomaticAssignmentAgent item) => item.agentId != current.agentId,
          ),
        ];
        return _phase4.assignRanked(
          orderId: order.id,
          candidates: candidates,
          mode: mode,
        );
      }
    }

    return await _tryAutomaticAssignmentWithContext(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: baseCandidates,
        ) ??
        snapshot;
  }

  @override
  Future<QueueOrder?> tryAutomaticAssignment({required String orderId}) async {
    Phase4AssignmentSnapshot? snapshot = await _phase4.fetchOrder(orderId);
    QueueOrder? legacyOrder;

    if (snapshot == null) {
      legacyOrder = await _firestore.fetchOrderById(orderId: orderId);
      if (legacyOrder.status != QueueOrderStatus.paidReady ||
          !legacyOrder.isFundedForProcessing) {
        return null;
      }
      snapshot = await _phase4.syncOrder(
        legacyOrder.copyWith(clearAgentAssignment: true),
      );
    }

    final Phase4AssignmentPlan? currentPlan = await _phase4.fetchPlan(orderId);
    if (snapshot.isAssigned ||
        snapshot.isAccepted ||
        snapshot.isHandedOff ||
        snapshot.isManualRequired ||
        snapshot.orderStatus != QueueOrderStatus.paidReady) {
      return snapshot.toQueueOrder(
        legacy: legacyOrder,
        refusedAgentIds: currentPlan?.refusedAgentIds ?? const <String>[],
      );
    }

    final QueueOrder order = snapshot.toQueueOrder(legacy: legacyOrder);
    final List<AutomaticAssignmentAgent> candidates =
        await _phase4.fetchAssignmentCandidates();
    snapshot =
        await _tryAutomaticAssignmentWithContext(
          order: order.copyWith(clearAgentAssignment: true),
          baseCandidates: candidates,
        ) ??
        snapshot;
    final Phase4AssignmentPlan? plan = await _phase4.fetchPlan(order.id);
    return snapshot.toQueueOrder(
      legacy: legacyOrder,
      refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
    );
  }

  Future<Phase4AssignmentSnapshot?> _tryAutomaticAssignmentWithContext({
    required QueueOrder order,
    required List<AutomaticAssignmentAgent> baseCandidates,
  }) async {
    final List<AutomaticAssignmentAgent> ranked = _rankCandidates(
      order: order,
      baseCandidates: baseCandidates,
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
  }) {
    return _selector.rankEligibleIgnoringPreviousRefusals(
      order: order,
      agents: baseCandidates,
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
    if (targetAgentId.isEmpty) throw StateError('Agent invalide.');

    Phase4AssignmentSnapshot? canonical = await _phase4.fetchOrder(orderId);
    QueueOrder? legacyOrder;
    if (canonical == null) {
      legacyOrder = await _firestore.fetchOrderById(orderId: orderId);
      if (legacyOrder.status != QueueOrderStatus.paidReady ||
          !legacyOrder.isFundedForProcessing) {
        throw StateError('Cette commande ne peut pas être affectée.');
      }
      canonical = await _phase4.syncOrder(
        legacyOrder.copyWith(clearAgentAssignment: true),
      );
    }

    final QueueOrder order = canonical.toQueueOrder(legacy: legacyOrder);
    if (canonical.orderStatus != QueueOrderStatus.paidReady) {
      throw StateError('Cette commande ne peut plus être affectée.');
    }

    final bool canonicalHasAssignment =
        (canonical.isAssigned || canonical.isAccepted || canonical.isHandedOff) &&
        canonical.assignedAgentId != null;
    if (canonicalHasAssignment) {
      final String canonicalAgentId = canonical.assignedAgentId!.trim();
      final String canonicalAgentName =
          canonical.assignedAgentName?.trim().isNotEmpty == true
          ? canonical.assignedAgentName!.trim()
          : 'un agent';
      if (canonicalAgentId != targetAgentId ||
          canonical.isAccepted ||
          canonical.isHandedOff) {
        throw StateError(
          'Cette commande est déjà affectée à $canonicalAgentName. '
          'Actualise la liste avant toute réaffectation.',
        );
      }
      if (canonical.assignmentMode == OrderAssignmentMode.manual) {
        return canonical.toQueueOrder(legacy: legacyOrder);
      }
    }

    if (canonical.isManualRequired) {
      canonical = await _phase4.resetForManualAssignment(order.id);
    }

    final List<AutomaticAssignmentAgent> agents =
        await _phase4.fetchAssignmentCandidates();
    final AutomaticAssignmentAgent? target = _findAgent(agents, targetAgentId);
    if (target == null) {
      throw StateError('Le profil opérationnel Supabase de cet agent est introuvable.');
    }
    final bool targetIsEligible = await _phase4.isAgentEligibleForOrder(
      agentId: targetAgentId,
      orderId: order.id,
    );
    if (!targetIsEligible) {
      throw StateError(
        'Cet agent n’est plus éligible pour cette commande. Actualise ses ' 
        'capacités, réseaux et disponibilités puis réessaie.',
      );
    }

    final List<AutomaticAssignmentAgent> rankedFallback = _rankCandidates(
      order: order.copyWith(clearAgentAssignment: true),
      baseCandidates: agents,
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
    return assigned.toQueueOrder(legacy: legacyOrder);
  }

  @override
  Future<Map<String, int>> fetchActiveAssignmentCounts() async {
    final List<AutomaticAssignmentAgent> candidates =
        await _phase4.fetchAssignmentCandidates();
    return Map<String, int>.unmodifiable(<String, int>{
      for (final AutomaticAssignmentAgent agent in candidates)
        agent.agentId: agent.activeAssignmentCount,
    });
  }

  @override
  Stream<Map<String, int>> watchActiveAssignmentCounts() async* {
    Map<String, int>? lastSuccessful;
    int consecutiveFailures = 0;
    while (true) {
      try {
        final Map<String, int> value = await fetchActiveAssignmentCounts();
        lastSuccessful = value;
        consecutiveFailures = 0;
        yield value;
      } catch (error, stackTrace) {
        IzyTelLog.backendError(
          'Phase4.active-counts',
          error,
          stackTrace: stackTrace,
        );
        if (!BackendFailurePolicy.canRetryRead(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        consecutiveFailures += 1;
        if (lastSuccessful != null) yield lastSuccessful;
      }
      await Future<void>.delayed(
        BackendFailurePolicy.retryDelay(
          baseDelay: SupabasePhase4AssignmentRepository.pollInterval,
          consecutiveFailures: consecutiveFailures,
        ),
      );
    }
  }

  @override
  Future<int> fetchActiveReservedAmount({
    required String agentId,
    required MobileNetwork network,
  }) async {
    final List<AutomaticAssignmentAgent> candidates =
        await _phase4.fetchAssignmentCandidates();
    final AutomaticAssignmentAgent? agent = _findAgent(candidates, agentId);
    return agent?.reservedFor(network) ?? 0;
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
              // Firestore is legacy enrichment only after the Phase 3 cutover.
              // Its failure must never turn a healthy Supabase queue into an
              // "Impossible de charger la file" screen.
              firebaseReady = true;
              firebaseOrders = const <QueueOrder>[];
              emit();
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
              if (!firebaseReady) {
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
        result[firebaseOrder.id] = snapshot.legacyStateUnresolved
            ? firebaseOrder
            : snapshot.overlayOn(firebaseOrder);
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
        () => snapshot.toQueueOrder(),
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
    final Phase4AssignmentSnapshot? accepted = await _phase4.fetchOrder(orderId);
    if (accepted == null ||
        accepted.assignedAgentId != cleanedAgentId ||
        !accepted.isAccepted) {
      throw StateError(
        'L’acceptation est enregistrée mais son état Supabase reste illisible. '
        'Actualise la file puis réessaie.',
      );
    }
    return accepted.toQueueOrder();
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
    final Phase4AgentActionOutcome refusalOutcome = await _phase4.refuse(
      orderId: orderId,
      reason: cleanedReason,
    );

    if (refusalOutcome.reassigned) {
      IzyTelLog.debug('[Phase4][refusal-auto-reassigned]');
    } else if (refusalOutcome.manualRequired) {
      IzyTelLog.debug('[Phase4][refusal-manual-required]');
    }

    final List<String> refusedForLocalSnapshot = <String>[agentId];
    return before
        .toQueueOrder(refusedAgentIds: refusedForLocalSnapshot)
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
    _requireCurrentAgent(agentId);
    final Phase4AssignmentSnapshot updated = await _phase4.startProcessing(
      orderId,
    );
    return updated.toQueueOrder();
  }

  @override
  Future<QueueOrder> resumeAgentProcessing({
    required String orderId,
    required String agentId,
  }) async {
    _requireCurrentAgent(agentId);
    final Phase4AssignmentSnapshot updated = await _phase4.resumeProcessing(
      orderId,
    );
    return updated.toQueueOrder();
  }

  @override
  Future<OrderProof?> fetchOrderProof({required String orderId}) async {
    try {
      final OrderProof? proof = await _proofs.fetchProof(orderId: orderId);
      if (proof != null) return proof;
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Phase5B1.proof-read',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    // Le fallback Firestore est strictement historique. Une commande Phase 3
    // canonique sans preuve Supabase ne doit jamais reutiliser un vieux Blob.
    try {
      final Phase4AssignmentSnapshot? snapshot = await _phase4.fetchOrder(orderId);
      if (snapshot != null && !snapshot.legacyStateUnresolved) return null;
    } catch (error) {
      if (!BackendFailurePolicy.canRetryRead(error)) rethrow;
    }
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
    final String cleanedAgentId = _requireCurrentAgent(agentId);
    final OrderProof? proof = await _proofs.fetchProof(orderId: orderId);
    if (proof == null || proof.agentId.trim() != cleanedAgentId) {
      throw StateError('Ajoute une preuve avant de valider la réussite.');
    }

    final Phase4AssignmentSnapshot? before = await _phase4.fetchOrder(orderId);
    if (before == null || before.assignedAgentId != cleanedAgentId) {
      throw StateError('Cette commande ne t’est plus affectée.');
    }
    if (before.orderStatus != QueueOrderStatus.inProgress) {
      throw StateError('Cette commande n’est pas en cours de traitement.');
    }
    final String agentName =
        before.assignedAgentName?.trim().isNotEmpty == true
        ? before.assignedAgentName!.trim()
        : 'Agent';

    await _phase5Finance.finalizeOrderSuccess(
      order: before.toQueueOrder(),
      agentId: cleanedAgentId,
      agentName: agentName,
    );
    final Phase4AssignmentSnapshot? completed = await _phase4.fetchOrder(orderId);
    if (completed == null || completed.orderStatus != QueueOrderStatus.completed) {
      throw StateError(
        'La réussite a été enregistrée mais son état Supabase reste illisible.',
      );
    }
    return completed.toQueueOrder();
  }

  @override
  Future<QueueOrder> markAgentFailed({
    required String orderId,
    required String agentId,
    required OrderFailureReason reason,
    String? observation,
  }) async {
    _requireCurrentAgent(agentId);
    final Phase4AssignmentSnapshot updated = await _phase4.failProcessing(
      orderId: orderId,
      reason: reason,
      observation: observation,
    );
    return updated.toQueueOrder();
  }

  @override
  Future<QueueOrder> putAgentOnHold({
    required String orderId,
    required String agentId,
    required String reason,
  }) async {
    _requireCurrentAgent(agentId);
    final Phase4AssignmentSnapshot updated = await _phase4.holdProcessing(
      orderId: orderId,
      reason: reason,
    );
    return updated.toQueueOrder();
  }

  @override
  Future<QueueOrder> prepareFailedOrderForReassignment({
    required String orderId,
  }) async {
    final Phase4AssignmentSnapshot reopened =
        await _phase4.prepareFailedForReassignment(orderId);
    return reopened.toQueueOrder();
  }

  @override
  Future<List<QueueOrder>> fetchOrderHistory() async {
    List<QueueOrder> firebaseOrders = const <QueueOrder>[];
    Object? firebaseError;
    StackTrace? firebaseStackTrace;
    try {
      firebaseOrders = await _firestore.fetchOrderHistory();
    } catch (error, stackTrace) {
      firebaseError = error;
      firebaseStackTrace = stackTrace;
      IzyTelLog.backendError(
        'Phase3.order-history-legacy',
        error,
        stackTrace: stackTrace,
      );
    }

    try {
      final List<Phase4AssignmentSnapshot> snapshots = await _phase4
          .fetchAllForStaff();
      return _overlayStaffOrders(firebaseOrders, snapshots);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Phase4.order-history',
        error,
        stackTrace: stackTrace,
      );
      if (firebaseOrders.isNotEmpty && BackendFailurePolicy.canRetryRead(error)) {
        return firebaseOrders;
      }
      if (firebaseError != null &&
          !BackendFailurePolicy.canRetryRead(firebaseError)) {
        Error.throwWithStackTrace(firebaseError, firebaseStackTrace!);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Stream<List<QueueOrder>> watchOrderHistory() {
    // Le centre des commandes echouees et l'historique staff doivent rester
    // fonctionnels meme si Firestore legacy est momentanement indisponible.
    // Les lignes Supabase Phase 4 sont suffisantes pour construire les cartes
    // operationnelles et Firestore ne sert plus que d'enrichissement legacy.
    return _combineStaffOrderStream(_firestore.watchOrderHistory());
  }

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) async {
    try {
      final Phase4AssignmentSnapshot? snapshot = await _phase4.fetchOrder(
        orderId,
      );
      if (snapshot != null && !snapshot.legacyStateUnresolved) {
        QueueOrder? legacy;
        try {
          legacy = await _firestore.fetchOrderById(orderId: orderId);
        } catch (error, stackTrace) {
          // Firestore only enriches fields that were not migrated. Once the
          // order is canonical in Supabase, a legacy read failure must not
          // prevent a notification/detail page from opening.
          IzyTelLog.backendError(
            'Phase3.order-detail-legacy-enrichment',
            error,
            stackTrace: stackTrace,
          );
        }
        Phase4AssignmentPlan? plan;
        try {
          plan = await _phase4.fetchPlan(orderId);
        } catch (error) {
          if (!BackendFailurePolicy.canRetryRead(error)) rethrow;
        }
        return snapshot.toQueueOrder(
          legacy: legacy,
          refusedAgentIds: plan?.refusedAgentIds ?? const <String>[],
        );
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'Phase4.order-detail',
        error,
        stackTrace: stackTrace,
      );
      if (!BackendFailurePolicy.canRetryRead(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    // Orders that have not entered Phase 4 yet remain readable from the
    // legacy/customer store until their paidReady synchronization occurs.
    return _firestore.fetchOrderById(orderId: orderId);
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
      if ((!firebaseReady && !phaseReady) || controller.isClosed) return;
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
          IzyTelLog.backendError(
            'Phase3.staff-stream-legacy',
            error,
            stackTrace: stackTrace,
          );
          // Firestore n'est plus la source canonique de l'historique staff.
          // Une coupure reseau OU un permission-denied legacy ne doit donc pas
          // masquer les lignes Phase 4 deja disponibles dans Supabase.
          if (_canIgnoreLegacyStaffReadFailure(error)) {
            firebaseReady = true;
            firebaseOrders = const <QueueOrder>[];
            emit();
            return;
          }
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      phaseSubscription = _phase4.watchAllForStaff().listen(
        (List<Phase4AssignmentSnapshot> value) {
          snapshots = value;
          phaseReady = true;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError(
            'Phase4.staff-stream',
            error,
            stackTrace: stackTrace,
          );
          if (!BackendFailurePolicy.canRetryRead(error)) {
            if (!controller.isClosed) controller.addError(error, stackTrace);
            return;
          }
          // En coupure reseau seulement, on peut conserver la vue Firebase.
          if (!phaseReady) {
            phaseReady = true;
            snapshots = const <Phase4AssignmentSnapshot>[];
            emit();
          }
        },
      );
    };
    controller.onCancel = () async {
      await firebaseSubscription.cancel();
      await phaseSubscription.cancel();
    };
    return controller.stream;
  }


  bool _canIgnoreLegacyStaffReadFailure(Object error) {
    if (BackendFailurePolicy.canRetryRead(error)) return true;
    final String code = BackendFailurePolicy.safeCode(error).toLowerCase();
    return code == 'firebase:permission-denied' ||
        code == 'firebase:permission_denied';
  }

  List<QueueOrder> _overlayStaffOrders(
    List<QueueOrder> firebaseOrders,
    List<Phase4AssignmentSnapshot> snapshots,
  ) {
    final Map<String, QueueOrder> firebaseById = <String, QueueOrder>{
      for (final QueueOrder order in firebaseOrders) order.id: order,
    };
    final Map<String, Phase4AssignmentSnapshot> phase4ById =
        <String, Phase4AssignmentSnapshot>{
          for (final Phase4AssignmentSnapshot item in snapshots)
            if (!item.legacyStateUnresolved) item.orderId: item,
        };

    final List<QueueOrder> result = <QueueOrder>[
      for (final QueueOrder legacy in firebaseOrders)
        phase4ById[legacy.id]?.overlayOn(legacy) ?? legacy,
      for (final Phase4AssignmentSnapshot snapshot in phase4ById.values)
        if (!firebaseById.containsKey(snapshot.orderId)) snapshot.toQueueOrder(),
    ];
    result.sort(
      (QueueOrder first, QueueOrder second) =>
          second.createdAt.compareTo(first.createdAt),
    );
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

  String _requireCurrentAgent(String agentId) {
    final String expected = agentId.trim();
    final String uid = (_firebaseAuth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty || expected.isEmpty || uid != expected) {
      throw StateError('La session agent ne correspond pas à cette action.');
    }
    return uid;
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
