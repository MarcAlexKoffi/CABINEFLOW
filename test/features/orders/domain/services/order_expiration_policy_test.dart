import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/services/order_expiration_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderExpirationPolicy', () {
    final DateTime expiresAt = DateTime.utc(2026, 8, 3, 12);

    test('expire une commande non confirmée lorsque le délai est atteint', () {
      final bool shouldExpire = OrderExpirationPolicy.shouldExpire(
        status: QueueOrderStatus.awaitingPayment,
        paymentStatus: OrderPaymentStatus.notDeclared,
        expiresAt: expiresAt,
        now: expiresAt,
      );

      expect(shouldExpire, isTrue);
      expect(
        OrderExpirationPolicy.paymentStatusAfterExpiration(
          OrderPaymentStatus.notDeclared,
        ),
        OrderPaymentStatus.expired,
      );
    });

    test('conserve une déclaration de paiement après expiration', () {
      expect(
        OrderExpirationPolicy.paymentStatusAfterExpiration(
          OrderPaymentStatus.declared,
        ),
        OrderPaymentStatus.declared,
      );
      expect(
        OrderExpirationPolicy.isPaymentToReviewAfterExpiration(
          status: QueueOrderStatus.expired,
          paymentStatus: OrderPaymentStatus.declared,
        ),
        isTrue,
      );
    });

    test('n’expire jamais un paiement déjà confirmé', () {
      final bool shouldExpire = OrderExpirationPolicy.shouldExpire(
        status: QueueOrderStatus.paymentToVerify,
        paymentStatus: OrderPaymentStatus.confirmed,
        expiresAt: expiresAt,
        now: expiresAt.add(const Duration(hours: 1)),
      );

      expect(shouldExpire, isFalse);
    });
  });
}
