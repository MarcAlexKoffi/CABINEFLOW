import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreOrderMapper', () {
    test('convertit un document Firestore en QueueOrder', () {
      final DateTime createdAt = DateTime(2026, 7, 31, 9, 30);
      final DateTime paidAt = DateTime(2026, 7, 31, 9, 35);
      final DateTime expiresAt = DateTime(2026, 7, 31, 15, 30);
      final DateTime expiredAt = DateTime(2026, 7, 31, 15, 31);

      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: 'order-123',
        data: <String, dynamic>{
          'reference': 'CF-20260731-ABC123',
          'source': 'customerWeb',
          'clientName': 'Alex',
          'clientWhatsappPhone': '+2250700000000',
          'network': 'mtn',
          'beneficiaryPhone': '+2250512345678',
          'operationType': 'internetSubscription',
          'offerLabel': '4 Go - 7 jours',
          'amount': 1000,
          'createdAt': Timestamp.fromDate(createdAt),
          'paidAt': Timestamp.fromDate(paidAt),
          'paymentRequestSentAt': Timestamp.fromDate(createdAt),
          'paymentDeclaredAt': Timestamp.fromDate(createdAt),
          'paymentPayerName': 'Alex Koffi',
          'paymentPayerPhone': '+2250700000000',
          'paymentApproximateTime': '09:34',
          'paymentDeclaredReference': 'DECL-123',
          'paymentConfirmedAt': Timestamp.fromDate(paidAt),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'expiredAt': Timestamp.fromDate(expiredAt),
          'paymentReference': 'W-ABC123',
          'status': 'paidReady',
          'paymentStatus': 'confirmed',
          'takenByUserId': null,
          'takenAt': null,
          'completedAt': null,
          'failureReason': null,
          'observation': null,
          'customerConfirmationStatus': 'pending',
          'customerConfirmationCompletedAt': null,
          'assignedAgentId': 'agent-007',
          'assignedAgentName': 'Koffi Kouassi',
          'assignedByUserId': 'admin-001',
          'assignedAt': Timestamp.fromDate(paidAt),
          'assignmentMode': 'manual',
          'assignmentStatus': 'assigned',
          'lastAssignmentRefusalReason': 'Réseau indisponible',
          'lastAssignmentRefusedAt': Timestamp.fromDate(paidAt),
          'lastAssignmentRefusedAgentId': 'agent-006',
        },
      );

      expect(order.id, 'order-123');
      expect(order.reference, 'CF-20260731-ABC123');
      expect(order.network, MobileNetwork.mtn);
      expect(order.operationType, OrderOperationType.internetSubscription);
      expect(order.source, OrderSource.customerWeb);
      expect(order.status, QueueOrderStatus.paidReady);
      expect(order.paymentStatus, OrderPaymentStatus.confirmed);
      expect(order.amount, 1000);
      expect(order.paymentReference, 'W-ABC123');
      expect(order.paymentPayerName, 'Alex Koffi');
      expect(order.paymentPayerPhone, '+2250700000000');
      expect(order.paymentApproximateTime, '09:34');
      expect(order.paymentDeclaredReference, 'DECL-123');
      expect(order.paidAt, paidAt);
      expect(order.expiresAt, expiresAt);
      expect(order.expiredAt, expiredAt);
      expect(order.assignedAgentId, 'agent-007');
      expect(order.assignedAgentName, 'Koffi Kouassi');
      expect(order.assignmentMode, OrderAssignmentMode.manual);
      expect(order.assignmentStatus, OrderAssignmentStatus.assigned);
      expect(order.lastAssignmentRefusalReason, 'Réseau indisponible');
      expect(order.lastAssignmentRefusedAt, paidAt);
      expect(order.lastAssignmentRefusedAgentId, 'agent-006');
    });

    test('utilise des valeurs de repli pour un document incomplet', () {
      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: 'incomplete-order',
        data: <String, dynamic>{
          'network': 'inconnu',
          'operationType': 'inconnu',
          'status': 'inconnu',
        },
      );

      expect(order.reference, 'incomplete-order');
      expect(order.network, MobileNetwork.orange);
      expect(order.operationType, OrderOperationType.other);
      expect(order.status, QueueOrderStatus.awaitingPayment);
      expect(order.amount, 0);
      expect(order.assignmentStatus, OrderAssignmentStatus.unassigned);
    });

    test('normalise les anciens formats sans perdre le sens metier', () {
      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: 'legacy-order',
        data: <String, dynamic>{
          'reference': 'IZY-LEGACY-001',
          'source': 'CUSTOMER-WEB',
          'clientName': 'Client historique',
          'network': 'Moov Africa',
          'operationType': 'internet_subscription',
          'offerLabel': 'Ancienne offre',
          'amount': '1 500',
          'createdAt': '2026-08-15T10:30:00Z',
          'status': 'paid_ready',
          'paymentStatus': 'CONFIRMED',
          'assignmentMode': 'AUTO-MATIC',
          'assignmentStatus': 'ASSIGNED',
          'manualAssignmentRequired': 'true',
        },
      );

      expect(order.network, MobileNetwork.moov);
      expect(order.operationType, OrderOperationType.internetSubscription);
      expect(order.source, OrderSource.customerWeb);
      expect(order.status, QueueOrderStatus.paidReady);
      expect(order.paymentStatus, OrderPaymentStatus.confirmed);
      expect(order.assignmentMode, OrderAssignmentMode.automatic);
      expect(order.assignmentStatus, OrderAssignmentStatus.assigned);
      expect(order.amount, 1500);
      expect(order.manualAssignmentRequired, isTrue);
      expect(order.createdAt, DateTime.parse('2026-08-15T10:30:00Z'));
    });

    test('reconstruit une date stable depuis les jalons historiques', () {
      final QueueOrder order = FirestoreOrderMapper.fromMap(
        id: 'legacy-without-created-at',
        data: <String, dynamic>{
          'paidAt': '2026-08-20T11:00:00Z',
          'assignedAt': '2026-08-20T11:05:00Z',
          'completedAt': '2026-08-20T11:10:00Z',
        },
      );

      expect(order.createdAt, DateTime.parse('2026-08-20T11:00:00Z'));
    });

    test('un document sans aucune date garde un fallback deterministe', () {
      final QueueOrder first = FirestoreOrderMapper.fromMap(
        id: 'legacy-undated',
        data: const <String, dynamic>{},
      );
      final QueueOrder second = FirestoreOrderMapper.fromMap(
        id: 'legacy-undated',
        data: const <String, dynamic>{},
      );

      final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      expect(first.createdAt, epoch);
      expect(second.createdAt, epoch);
    });
  });
}
