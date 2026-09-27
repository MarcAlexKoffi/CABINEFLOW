import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  bool containsCall(String source, String receiver, String method) {
    return RegExp(
      '${RegExp.escape(receiver)}\\s*\\.\\s*${RegExp.escape(method)}\\s*\\(\\s*\\)',
      multiLine: true,
    ).hasMatch(source);
  }

  group('Phase 4 Release - resilience Paiements', () {
    test('Paiements ne delegue plus directement toute la lecture a Firestore', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      final int fetchStart = hybrid.indexOf(
        'Future<List<QueueOrder>> fetchPaymentTrackingOrders() async',
      );
      final int fetchEnd = hybrid.indexOf(
        'Future<QueueOrder> confirmPayment',
        fetchStart,
      );
      expect(fetchStart, greaterThanOrEqualTo(0));
      expect(fetchEnd, greaterThan(fetchStart));
      final String block = hybrid.substring(fetchStart, fetchEnd);

      // Le formatter Dart peut couper `_phase4` et `.fetchAllForStaff()` sur
      // deux lignes. On verifie donc l'appel semantique, pas sa mise en page.
      expect(containsCall(block, '_phase4', 'fetchAllForStaff'), isTrue);
      expect(block, contains('_paymentTrackingOrders('));
      expect(block, contains('_combinePaymentTrackingStream('));
      expect(block, isNot(contains('return _firestore.fetchPaymentTrackingOrders();')));
      expect(block, isNot(contains('return _firestore.watchPaymentTrackingOrders();')));
    });

    test('Firestore reste primaire et Supabase ne peut plus casser Paiements', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      expect(hybrid, contains("'Payments.legacy-tracking-watch'"));
      expect(hybrid, contains("'Payments.phase4-tracking-watch'"));
      expect(hybrid, contains('if (!legacyReady || controller.isClosed) return;'));
      expect(hybrid, contains('controller.addError(error, stackTrace)'));
      expect(hybrid, contains('Supabase est une source d\'enrichissement pour cet ecran'));
      expect(hybrid, contains('_overlayStaffOrders(legacyOrders, snapshots)'));
    });

    test('le filtre Paiements conserve declarations et confirmations uniquement', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      expect(hybrid, contains('order.paymentStatus == OrderPaymentStatus.declared'));
      expect(hybrid, contains('QueueOrderStatus.paymentToVerify'));
      expect(hybrid, contains('QueueOrderStatus.awaitingPayment'));
      expect(hybrid, contains('QueueOrderStatus.expired'));
      expect(hybrid, contains('order.paymentStatus == OrderPaymentStatus.confirmed'));
      expect(hybrid, contains('order.paymentReference!.trim().isNotEmpty'));
    });

    test('le rafraichissement Commandes garde aussi le fallback hybride', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      final int start = hybrid.indexOf(
        'Future<List<QueueOrder>> fetchPaidQueue() async',
      );
      final int end = hybrid.indexOf(
        'Stream<List<QueueOrder>> watchPaidQueue()',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final String block = hybrid.substring(start, end);

      expect(block, contains("'Phase3.paid-queue-legacy'"));
      expect(containsCall(block, '_phase4', 'fetchAllForStaff'), isTrue);
      expect(block, contains('_overlayStaffOrders(legacyOrders, snapshots)'));
      expect(block, contains('if (legacyError == null)'));
    });

    test('une expiration legacy non modifiable ne casse plus une lecture complete', () {
      final String firestore = read(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      );

      expect(firestore, contains('orders.map(_synchronizeExpirationBestEffort)'));
      expect(firestore, contains("'Orders.expiration-sync'"));
      expect(firestore, contains("'permission-denied'"));
      expect(firestore, contains('_projectExpirationLocally('));
      expect(firestore, contains('return _synchronizeExpirationBestEffort(order);'));
    });

    test('les ecritures metier Paiement restent strictes et inchangees', () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );
      final String firestore = read(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      );

      expect(hybrid, contains('final QueueOrder confirmed = await _firestore.confirmPayment('));
      expect(hybrid, contains('await _phase5Finance.mirrorOrderPayment(confirmed)'));
      expect(hybrid, contains('await _phase4.syncOrder(confirmed)'));
      expect(firestore, contains("'paymentStatus': OrderPaymentStatus.confirmed.name"));
      expect(firestore, contains("'status': QueueOrderStatus.paidReady.name"));
    });
  });
}
