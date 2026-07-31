import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/payments/domain/models/payment_link_data.dart';

abstract class PaymentLinkRepository {
  Future<PaymentLinkData> preparePaymentLink({required QueueOrder order});
}
