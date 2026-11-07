import 'dart:async';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/hybrid_orders_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_order_proof_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore implements FirestoreOrdersRepository {
  _Firestore(this.confirmed, {this.canonical});
  final QueueOrder confirmed;
  final QueueOrder? canonical;
  int confirmations = 0;
  @override
  Future<QueueOrder> confirmPayment({
    required String orderId,
    required DateTime paidAt,
    String? paymentReference,
  }) async {
    confirmations++;
    return confirmed;
  }

  @override
  Future<QueueOrder> fetchOrderById({required String orderId}) async {
    if (canonical == null) {
      throw TimeoutException('committed timestamp response lost');
    }
    return canonical!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Phase4 implements SupabasePhase4AssignmentRepository {
  final synchronized = <QueueOrder>[];
  @override
  Future<Phase4AssignmentSnapshot> syncOrder(QueueOrder order) async {
    synchronized.add(order);
    throw TimeoutException('stop at publication boundary');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Finance implements SupabasePhase5FinanceRepository {
  final mirrored = <QueueOrder>[];
  @override
  Future<void> mirrorOrderPayment(QueueOrder order) async =>
      mirrored.add(order);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Proofs implements SupabaseOrderProofRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'a confirmed payment survives a lost server timestamp read without publishing an old payment time into the wrong circuit',
    () async {
      final source = (await FakeOrdersRepository(
        isTest: true,
      ).fetchPaidQueue()).first;
      final paidAt = DateTime.utc(2026, 11, 5);
      final confirmed = source.copyWith(
        status: QueueOrderStatus.paidReady,
        paymentStatus: OrderPaymentStatus.confirmed,
        paymentConfirmedAt: paidAt,
      );
      final firestore = _Firestore(confirmed);
      final phase4 = _Phase4();
      final finance = _Finance();
      final repository = HybridOrdersRepository(
        firestoreRepository: firestore,
        phase4Repository: phase4,
        phase5FinanceRepository: finance,
        proofRepository: _Proofs(),
        firebaseAuth: _Auth(),
      );
      final result = await repository.confirmPayment(
        orderId: source.id,
        paidAt: paidAt,
      );
      expect(result.paymentStatus, OrderPaymentStatus.confirmed);
      expect(firestore.confirmations, 1);
      expect(finance.mirrored, hasLength(1));
      expect(phase4.synchronized, isEmpty);
    },
  );

  test(
    'publication uses the committed confirmation timestamp and never the older payer-provided date',
    () async {
      final source = (await FakeOrdersRepository(
        isTest: true,
      ).fetchPaidQueue()).first;
      final paidAt = DateTime.utc(2026, 11, 5);
      final committedAt = DateTime.utc(2026, 11, 6, 10);
      final confirmed = source.copyWith(
        status: QueueOrderStatus.paidReady,
        paymentStatus: OrderPaymentStatus.confirmed,
        paymentConfirmedAt: paidAt,
      );
      final firestore = _Firestore(
        confirmed,
        canonical: confirmed.copyWith(paymentConfirmedAt: committedAt),
      );
      final phase4 = _Phase4();
      final finance = _Finance();
      final repository = HybridOrdersRepository(
        firestoreRepository: firestore,
        phase4Repository: phase4,
        phase5FinanceRepository: finance,
        proofRepository: _Proofs(),
        firebaseAuth: _Auth(),
      );
      final result = await repository.confirmPayment(
        orderId: source.id,
        paidAt: paidAt,
      );
      expect(result.paymentStatus, OrderPaymentStatus.confirmed);
      expect(phase4.synchronized.single.paymentConfirmedAt, committedAt);
      expect(finance.mirrored.single.paymentConfirmedAt, committedAt);
    },
  );
}
