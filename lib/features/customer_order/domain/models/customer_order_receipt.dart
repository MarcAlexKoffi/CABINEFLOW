import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/payment_declaration.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class CustomerOrderReceipt {
  const CustomerOrderReceipt({
    required this.id,
    required this.reference,
    required this.draft,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.paymentStatus,
    this.paymentDeclaredAt,
    this.paymentDeclaration,
    this.paymentConfirmedAt,
    this.expiredAt,
    this.processingStartedAt,
    this.completedAt,
    this.failureMessage,
  });

  final String id;
  final String reference;
  final CustomerOrderDraft draft;

  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? paymentDeclaredAt;
  final PaymentDeclaration? paymentDeclaration;
  final DateTime? paymentConfirmedAt;
  final DateTime? expiredAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;

  final QueueOrderStatus status;
  final OrderPaymentStatus paymentStatus;
  final String? failureMessage;

  bool get isPaymentDeclared {
    return paymentStatus == OrderPaymentStatus.declared ||
        paymentStatus == OrderPaymentStatus.confirmed;
  }

  bool get isPaymentConfirmed {
    return paymentStatus == OrderPaymentStatus.confirmed;
  }

  bool get isExpired {
    return status == QueueOrderStatus.expired;
  }

  bool get hasPaymentToReviewAfterExpiration {
    return isExpired && paymentStatus == OrderPaymentStatus.declared;
  }

  CustomerOrderReceipt copyWith({
    QueueOrderStatus? status,
    OrderPaymentStatus? paymentStatus,
    DateTime? paymentDeclaredAt,
    PaymentDeclaration? paymentDeclaration,
    DateTime? paymentConfirmedAt,
    DateTime? expiredAt,
    DateTime? processingStartedAt,
    DateTime? completedAt,
    String? failureMessage,
  }) {
    return CustomerOrderReceipt(
      id: id,
      reference: reference,
      draft: draft,
      createdAt: createdAt,
      expiresAt: expiresAt,
      paymentDeclaredAt: paymentDeclaredAt ?? this.paymentDeclaredAt,
      paymentDeclaration: paymentDeclaration ?? this.paymentDeclaration,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }
}
