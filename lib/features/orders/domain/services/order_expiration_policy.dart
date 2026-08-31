import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class OrderExpirationPolicy {
  const OrderExpirationPolicy._();

  static bool shouldExpire({
    required QueueOrderStatus status,
    required OrderPaymentStatus paymentStatus,
    required DateTime expiresAt,
    required DateTime now,
  }) {
    if (paymentStatus == OrderPaymentStatus.confirmed ||
        paymentStatus == OrderPaymentStatus.credit) {
      return false;
    }

    if (status != QueueOrderStatus.awaitingPayment &&
        status != QueueOrderStatus.paymentToVerify) {
      return false;
    }

    return !now.toUtc().isBefore(expiresAt.toUtc());
  }

  static OrderPaymentStatus paymentStatusAfterExpiration(
    OrderPaymentStatus currentStatus,
  ) {
    if (currentStatus == OrderPaymentStatus.declared ||
        currentStatus == OrderPaymentStatus.credit) {
      return currentStatus;
    }
    return OrderPaymentStatus.expired;
  }

  static bool isPaymentToReviewAfterExpiration({
    required QueueOrderStatus status,
    required OrderPaymentStatus paymentStatus,
  }) {
    return status == QueueOrderStatus.expired &&
        paymentStatus == OrderPaymentStatus.declared;
  }
}
