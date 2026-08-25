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
  });
}
