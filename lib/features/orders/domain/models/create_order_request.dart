import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.network,
    required this.beneficiaryPhone,
    required this.operationType,
    required this.offerLabel,
    required this.amount,
    this.originalWhatsappMessage,
    this.internalNotes,
  });

  final String clientName;
  final String clientWhatsappPhone;

  final MobileNetwork network;
  final String beneficiaryPhone;
  final OrderOperationType operationType;

  final String offerLabel;
  final int amount;

  final String? originalWhatsappMessage;
  final String? internalNotes;
}
