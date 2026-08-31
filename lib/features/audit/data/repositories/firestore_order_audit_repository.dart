import 'dart:async';

import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:cabine_flow/features/audit/domain/repositories/order_audit_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOrderAuditRepository implements OrderAuditRepository {
  FirestoreOrderAuditRepository({
    FirebaseFirestore? firestore,
    this.includeRefundEvents = true,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final bool includeRefundEvents;
  final Map<String, String?> _staffNameCache = <String, String?>{};

  @override
  Stream<List<OrderAuditEntry>> watchForOrder({required String orderId}) {
    final String cleanedOrderId = orderId.trim();
    late final StreamController<List<OrderAuditEntry>> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? orderEventsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? supportSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? refundSub;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> orderEventDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> supportDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? refundDoc;

    bool hasOrderEvents = false;
    bool hasSupport = false;
    bool hasRefund = !includeRefundEvents;
    int generation = 0;

    Future<void> emit() async {
      if (!hasOrderEvents || !hasSupport || !hasRefund || controller.isClosed) {
        return;
      }

      final int currentGeneration = ++generation;
      final List<OrderAuditEntry> entries = <OrderAuditEntry>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in orderEventDocs) {
        final OrderAuditEntry? entry = await _orderEventEntry(document);
        if (entry != null) {
          entries.add(entry);
        }
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in supportDocs) {
        entries.addAll(_supportEntries(document));
      }

      if (includeRefundEvents && refundDoc != null && refundDoc!.exists) {
        entries.addAll(_refundEntries(refundDoc!));
      }

      entries.sort((OrderAuditEntry first, OrderAuditEntry second) {
        final int byDate = second.occurredAt.compareTo(first.occurredAt);
        if (byDate != 0) {
          return byDate;
        }
        return second.id.compareTo(first.id);
      });

      if (!controller.isClosed && currentGeneration == generation) {
        controller.add(List<OrderAuditEntry>.unmodifiable(entries));
      }
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<OrderAuditEntry>>(
      onListen: () {
        if (cleanedOrderId.isEmpty) {
          controller.add(const <OrderAuditEntry>[]);
          return;
        }

        orderEventsSub = _firestore
            .collection('orderEvents')
            .where('orderId', isEqualTo: cleanedOrderId)
            .snapshots()
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
              orderEventDocs = snapshot.docs;
              hasOrderEvents = true;
              unawaited(emit());
            }, onError: addError);

        supportSub = _firestore
            .collection('supportRequests')
            .where('orderId', isEqualTo: cleanedOrderId)
            .snapshots()
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
              supportDocs = snapshot.docs;
              hasSupport = true;
              unawaited(emit());
            }, onError: addError);

        if (includeRefundEvents) {
          refundSub = _firestore
              .collection('refunds')
              .doc(cleanedOrderId)
              .snapshots()
              .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
                refundDoc = snapshot;
                hasRefund = true;
                unawaited(emit());
              }, onError: addError);
        }
      },
      onCancel: () async {
        await orderEventsSub?.cancel();
        await supportSub?.cancel();
        await refundSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<OrderAuditEntry?> _orderEventEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = document.data();
    final String orderId = _string(data['orderId']);
    final String type = _string(data['type']);
    final String actorId = _string(data['actorId']);
    final String actorRole = _string(data['actorRole']);
    final DateTime? createdAt = _date(data['createdAt']);

    if (orderId.isEmpty || type.isEmpty || createdAt == null) {
      return null;
    }

    final String? actorName = await _actorName(actorId, actorRole);
    final Object? rawMetadata = data['metadata'];
    final Map<String, dynamic> metadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : <String, dynamic>{};

    return OrderAuditEntry(
      id: 'orderEvent:${document.id}',
      orderId: orderId,
      occurredAt: createdAt,
      title: _orderEventTitle(type),
      source: OrderAuditSource.orderEvent,
      actorId: actorId.isEmpty ? null : actorId,
      actorName: actorName,
      actorRole: actorRole.isEmpty ? 'system' : actorRole,
      details: _orderEventDetails(type, metadata),
      technicalType: type,
    );
  }

  List<OrderAuditEntry> _supportEntries(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String orderId = _string(data['orderId']);
    final String type = _string(data['type']);
    final String description = _string(data['description']);
    final List<OrderAuditEntry> entries = <OrderAuditEntry>[];

    void add({
      required String suffix,
      required DateTime? date,
      required String title,
      required String actorRole,
      String? actorId,
      String? actorName,
      List<String> details = const <String>[],
    }) {
      if (date == null || orderId.isEmpty) {
        return;
      }
      entries.add(
        OrderAuditEntry(
          id: 'support:${document.id}:$suffix',
          orderId: orderId,
          occurredAt: date,
          title: title,
          source: OrderAuditSource.supportRequest,
          actorId: _nullable(actorId),
          actorName: _nullable(actorName),
          actorRole: actorRole,
          details: details,
          technicalType: suffix,
        ),
      );
    }

    final List<String> creationDetails = <String>[
      'Motif : ${_supportTypeLabel(type)}',
      if (description.isNotEmpty) 'Description : $description',
    ];
    add(
      suffix: 'CREATED',
      date: _date(data['createdAt']),
      title: 'Demande client créée',
      actorRole: 'customer',
      actorId: _string(data['customerAuthUid']),
      actorName: 'Client',
      details: creationDetails,
    );

    add(
      suffix: 'TAKEN_IN_CHARGE',
      date: _date(data['inProgressAt']),
      title: 'Demande prise en charge',
      actorRole: 'admin',
      actorId: _string(data['assignedTo']),
      actorName: _string(data['assignedToName']),
      details: <String>['Motif : ${_supportTypeLabel(type)}'],
    );

    final String resolutionNote = _string(data['resolutionNote']);
    add(
      suffix: 'RESOLVED',
      date: _date(data['resolvedAt']),
      title: 'Demande résolue',
      actorRole: 'admin',
      actorId: _string(data['resolvedBy']),
      actorName: _string(data['resolvedByName']),
      details: <String>[
        if (resolutionNote.isNotEmpty) 'Résolution : $resolutionNote',
      ],
    );

    final String notifiedBy = _string(data['customerNotifiedBy']);
    final String notifiedByName = _string(data['customerNotifiedByName']);
    add(
      suffix: 'CUSTOMER_NOTIFIED',
      date: _date(data['customerNotifiedAt']),
      title: 'Client notifié sur WhatsApp',
      actorRole: 'admin',
      actorId: notifiedBy,
      actorName: notifiedByName,
      details: <String>[
        'Canal : WhatsApp',
        if (notifiedBy.isEmpty && notifiedByName.isEmpty)
          'Auteur non enregistré (action antérieure à la Phase 11C).',
      ],
    );

    final String closedBy = _string(data['closedBy']);
    final String closedByName = _string(data['closedByName']);
    add(
      suffix: 'CLOSED',
      date: _date(data['closedAt']),
      title: 'Dossier de demande fermé',
      actorRole: 'admin',
      actorId: closedBy,
      actorName: closedByName,
      details: <String>[
        if (closedBy.isEmpty && closedByName.isEmpty)
          'Auteur non enregistré (action antérieure à la Phase 11C).',
      ],
    );

    return entries;
  }

  List<OrderAuditEntry> _refundEntries(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic>? data = document.data();
    if (data == null) {
      return const <OrderAuditEntry>[];
    }

    final String orderId = _string(data['orderId']);
    if (orderId.isEmpty) {
      return const <OrderAuditEntry>[];
    }

    final int? amount = data['amount'] is int ? data['amount'] as int : null;
    final String reason = _string(data['reason']);
    final String reasonNote = _string(data['reasonNote']);
    final List<OrderAuditEntry> entries = <OrderAuditEntry>[];

    void add({
      required String suffix,
      required DateTime? date,
      required String title,
      required String actorId,
      required String actorName,
      List<String> details = const <String>[],
    }) {
      if (date == null) {
        return;
      }
      entries.add(
        OrderAuditEntry(
          id: 'refund:${document.id}:$suffix',
          orderId: orderId,
          occurredAt: date,
          title: title,
          source: OrderAuditSource.refund,
          actorId: _nullable(actorId),
          actorName: _nullable(actorName),
          actorRole: 'admin',
          details: details,
          technicalType: suffix,
        ),
      );
    }

    final List<String> commonDetails = <String>[
      if (amount != null) 'Montant : $amount F CFA',
      if (reason.isNotEmpty) 'Motif : ${_refundReasonLabel(reason)}',
      if (reasonNote.isNotEmpty) 'Note : $reasonNote',
    ];

    add(
      suffix: 'REQUESTED',
      date: _date(data['requestedAt']),
      title: 'Remboursement créé',
      actorId: _string(data['requestedBy']),
      actorName: _string(data['requestedByName']),
      details: commonDetails,
    );

    add(
      suffix: 'APPROVED',
      date: _date(data['approvedAt']),
      title: 'Remboursement approuvé',
      actorId: _string(data['approvedBy']),
      actorName: _string(data['approvedByName']),
      details: <String>[if (amount != null) 'Montant : $amount F CFA'],
    );

    final String rejectionReason = _string(data['rejectionReason']);
    add(
      suffix: 'REJECTED',
      date: _date(data['rejectedAt']),
      title: 'Remboursement rejeté',
      actorId: _string(data['rejectedBy']),
      actorName: _string(data['rejectedByName']),
      details: <String>[
        if (rejectionReason.isNotEmpty) 'Motif du rejet : $rejectionReason',
      ],
    );

    final String refundReference = _string(data['refundReference']);
    add(
      suffix: 'REFUNDED',
      date: _date(data['refundedAt']),
      title: 'Remboursement effectué',
      actorId: _string(data['refundedBy']),
      actorName: _string(data['refundedByName']),
      details: <String>[
        if (amount != null) 'Montant : $amount F CFA',
        if (refundReference.isNotEmpty) 'Référence Wave : $refundReference',
      ],
    );

    add(
      suffix: 'CUSTOMER_NOTIFIED',
      date: _date(data['customerNotifiedAt']),
      title: 'Client notifié du remboursement',
      actorId: _string(data['customerNotifiedBy']),
      actorName: _string(data['customerNotifiedByName']),
      details: const <String>['Canal : WhatsApp'],
    );

    add(
      suffix: 'RECONCILED',
      date: _date(data['reconciledAt']),
      title: 'Remboursement rapproché',
      actorId: _string(data['reconciledBy']),
      actorName: _string(data['reconciledByName']),
      details: <String>[
        if (refundReference.isNotEmpty) 'Référence Wave : $refundReference',
      ],
    );

    return entries;
  }

  Future<String?> _actorName(String actorId, String actorRole) async {
    if (actorId.isEmpty || actorRole == 'customer' || actorRole == 'system') {
      return actorRole == 'customer' ? 'Client' : null;
    }

    if (_staffNameCache.containsKey(actorId)) {
      return _staffNameCache[actorId];
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(actorId)
          .get();
      final String name = _string(snapshot.data()?['name']);
      final String? result = name.isEmpty ? null : name;
      _staffNameCache[actorId] = result;
      return result;
    } on Object {
      _staffNameCache[actorId] = null;
      return null;
    }
  }

  String _orderEventTitle(String type) {
    switch (type) {
      case 'ORDER_CREATED':
        return 'Commande créée';
      case 'PAYMENT_DECLARED':
        return 'Paiement déclaré';
      case 'PAYMENT_CONFIRMED':
        return 'Paiement confirmé';
      case 'ASSIGNED':
        return 'Commande affectée';
      case 'ASSIGNMENT_ACCEPTED':
        return 'Affectation acceptée';
      case 'ASSIGNMENT_REFUSED':
        return 'Affectation refusée';
      case 'PROCESSING_STARTED':
        return 'Traitement commencé';
      case 'PUT_ON_HOLD':
        return 'Commande mise en attente';
      case 'PROCESSING_RESUMED':
        return 'Traitement repris';
      case 'PROOF_ADDED':
        return 'Preuve ajoutée';
      case 'PROCESSING_SUCCEEDED':
        return 'Traitement réussi';
      case 'PROCESSING_FAILED':
        return 'Traitement échoué';
      case 'REASSIGNMENT_REQUESTED':
        return 'Réaffectation demandée';
      case 'CUSTOMER_CONTACTED':
        return 'Client contacté';
      default:
        return 'Événement de commande';
    }
  }

  List<String> _orderEventDetails(String type, Map<String, dynamic> metadata) {
    final List<String> details = <String>[];
    final String source = _string(metadata['source']);
    final String network = _string(metadata['network']);
    final Object? amount = metadata['amount'];
    final String paymentReference = _string(metadata['paymentReference']);
    final String agentId = _string(metadata['agentId']);
    final String reason = _string(metadata['reason']);
    final String fileName = _string(metadata['fileName']);
    final Object? sizeBytes = metadata['sizeBytes'];
    final String failureReason = _string(metadata['failureReason']);
    final String observation = _string(metadata['observation']);
    final Object? messageSent = metadata['messageSent'];
    final Object? releasedToQueue = metadata['releasedToQueue'];

    if (source.isNotEmpty) {
      details.add(
        'Source : ${source == 'customerWeb' ? 'Web client' : 'Application opérateur'}',
      );
    }
    if (network.isNotEmpty) {
      details.add('Réseau : ${network.toUpperCase()}');
    }
    if (amount is int) {
      details.add('Montant : $amount F CFA');
    }
    if (paymentReference.isNotEmpty) {
      details.add('Référence paiement : $paymentReference');
    }
    if (agentId.isNotEmpty) {
      details.add('Agent : $agentId');
    }
    if (reason.isNotEmpty) {
      details.add('Motif : $reason');
    }
    if (fileName.isNotEmpty) {
      details.add('Preuve : $fileName');
    }
    if (sizeBytes is int) {
      details.add('Taille preuve : $sizeBytes octets');
    }
    if (failureReason.isNotEmpty) {
      details.add('Motif d’échec : ${_failureReasonLabel(failureReason)}');
    }
    if (observation.isNotEmpty) {
      details.add('Observation : $observation');
    }
    if (messageSent is bool) {
      details.add(
        'Message WhatsApp : ${messageSent ? 'envoyé' : 'non envoyé'}',
      );
    }
    if (releasedToQueue is bool && type == 'ASSIGNMENT_REFUSED') {
      details.add(
        releasedToQueue
            ? 'Commande remise dans le circuit automatique.'
            : 'Commande non remise dans le circuit automatique.',
      );
    }

    return details;
  }

  String _supportTypeLabel(String value) {
    switch (value) {
      case 'paymentNotRecognized':
        return 'Paiement effectué mais non reconnu';
      case 'completedButNotReceived':
        return 'Commande terminée mais rien reçu';
      case 'wrongAmount':
        return 'Mauvais montant';
      case 'wrongNumber':
        return 'Mauvais numéro';
      case 'transactionFailed':
        return 'Transaction échouée';
      case 'other':
        return 'Autre';
      default:
        return value.isEmpty ? 'Non renseigné' : value;
    }
  }

  String _refundReasonLabel(String value) {
    switch (value) {
      case 'serviceNotReceived':
        return 'Service non reçu';
      case 'transactionFailed':
        return 'Transaction échouée';
      case 'wrongAmount':
        return 'Montant incorrect';
      case 'wrongNumber':
        return 'Mauvais numéro';
      case 'duplicatePayment':
        return 'Paiement en double';
      case 'cancellation':
        return 'Annulation';
      case 'paymentIssue':
        return 'Problème de paiement';
      case 'other':
        return 'Autre';
      default:
        return value.isEmpty ? 'Non renseigné' : value;
    }
  }

  String _failureReasonLabel(String value) {
    switch (value) {
      case 'incorrectNumber':
        return 'Numéro incorrect';
      case 'networkUnavailable':
        return 'Réseau indisponible';
      case 'offerUnavailable':
        return 'Offre indisponible';
      case 'insufficientBalance':
        return 'Solde insuffisant';
      case 'technicalError':
        return 'Erreur technique';
      case 'incorrectPayment':
        return 'Paiement incorrect';
      case 'other':
        return 'Autre';
      default:
        return value;
    }
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  String _string(Object? value) => value is String ? value.trim() : '';

  String? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
