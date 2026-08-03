import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class OrderExpirationPolicy {
  const OrderExpirationPolicy._();

  static bool shouldExpire({
    required QueueOrderStatus status,
    required OrderPaymentStatus paymentStatus,
    required DateTime expiresAt,
    required DateTime now,
  }) {
    if (paymentStatus == OrderPaymentStatus.confirmed) {
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
    return currentStatus == OrderPaymentStatus.declared
        ? OrderPaymentStatus.declared
        : OrderPaymentStatus.expired;
  }

  static bool isPaymentToReviewAfterExpiration({
    required QueueOrderStatus status,
    required OrderPaymentStatus paymentStatus,
  }) {
    return status == QueueOrderStatus.expired &&
        paymentStatus == OrderPaymentStatus.declared;
  }
}
