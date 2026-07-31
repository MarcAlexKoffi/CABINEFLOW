import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/payments/domain/models/payment_link_data.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';

class WavePaymentLinkRepository implements PaymentLinkRepository {
  const WavePaymentLinkRepository({required WavePaymentLinkBuilder linkBuilder})
    : _linkBuilder = linkBuilder;

  final WavePaymentLinkBuilder _linkBuilder;

  @override
  Future<PaymentLinkData> preparePaymentLink({
    required QueueOrder order,
  }) async {
    if (order.status != QueueOrderStatus.awaitingPayment) {
      throw StateError('Cette commande n’est pas en attente de paiement.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));

    final Uri paymentUri = _linkBuilder.build(amount: order.amount);

    return PaymentLinkData(
      uri: paymentUri,
      merchantDisplayName: 'Sarah com vente en ligne',
    );
  }
}
