import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';

enum CustomerOrderTrackingStatus {
  paymentDeclared,
  paymentConfirmed,
  transmitted,
  inProgress,
  completed,
  failed,
}

class CustomerOrderReceipt {
  const CustomerOrderReceipt({
    required this.id,
    required this.reference,
    required this.draft,
    required this.createdAt,
    required this.paymentDeclaredAt,
    required this.status,
    this.paymentConfirmedAt,
    this.transmittedAt,
    this.processingStartedAt,
    this.completedAt,
    this.failureMessage,
  });

  final String id;
  final String reference;
  final CustomerOrderDraft draft;
  final DateTime createdAt;
  final DateTime paymentDeclaredAt;
  final CustomerOrderTrackingStatus status;

  final DateTime? paymentConfirmedAt;
  final DateTime? transmittedAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final String? failureMessage;

  CustomerOrderReceipt copyWith({
    CustomerOrderTrackingStatus? status,
    DateTime? paymentConfirmedAt,
    DateTime? transmittedAt,
    DateTime? processingStartedAt,
    DateTime? completedAt,
    String? failureMessage,
  }) {
    return CustomerOrderReceipt(
      id: id,
      reference: reference,
      draft: draft,
      createdAt: createdAt,
      paymentDeclaredAt: paymentDeclaredAt,
      status: status ?? this.status,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      transmittedAt: transmittedAt ?? this.transmittedAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      completedAt: completedAt ?? this.completedAt,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }
}
