import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/entities/payments/payment_link_data.dart';

abstract class PaymentLinkRepository {
  Future<PaymentLinkData> preparePaymentLink({required QueueOrder order});
}
