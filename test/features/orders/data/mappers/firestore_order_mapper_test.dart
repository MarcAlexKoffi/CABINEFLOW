import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreOrderMapper', () {
    test('convertit un document Firestore en QueueOrder', () {
      final DateTime createdAt = DateTime(2026, 7, 31, 9, 30);
      final DateTime paidAt = DateTime(2026, 7, 31, 9, 35);

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
          'paymentConfirmedAt': Timestamp.fromDate(paidAt),
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
      expect(order.paidAt, paidAt);
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
    });
  });
}
