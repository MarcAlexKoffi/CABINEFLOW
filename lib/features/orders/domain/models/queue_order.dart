enum MobileNetwork { orange, mtn, moov }

enum OrderOperationType {
  internetSubscription,
  unitTransfer,
  callBundle,
  mixedBundle,
  other,
}

enum OrderSource { customerWeb, operatorApp }

enum OrderPaymentStatus {
  notDeclared,
  pending,
  declared,
  confirmed,
  rejected,
  expired,
}

enum QueueOrderStatus {
  awaitingPayment,
  paymentToVerify,
  paidReady,
  inProgress,
  onHold,
  awaitingCustomerConfirmation,
  completed,
  failed,
  expired,
  cancelled,
  refundPending,
  refunded,
}

enum OrderFailureReason {
  incorrectNumber,
  networkUnavailable,
  offerUnavailable,
  insufficientBalance,
  technicalError,
  incorrectPayment,
  other,
}

enum CustomerConfirmationStatus { pending, sent, skipped }

class QueueOrder {
  const QueueOrder({
    required this.id,
    required this.reference,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.network,
    required this.beneficiaryPhone,
    required this.operationType,
    required this.offerLabel,
    required this.amount,
    required this.createdAt,
    required this.status,
    this.source = OrderSource.operatorApp,
    this.customerAuthUid,
    this.paymentStatus = OrderPaymentStatus.pending,
    this.originalWhatsappMessage,
    this.internalNotes,
    this.paidAt,
    this.paymentRequestSentAt,
    this.paymentDeclaredAt,
    this.paymentPayerName,
    this.paymentPayerPhone,
    this.paymentApproximateTime,
    this.paymentDeclaredReference,
    this.paymentConfirmedAt,
    this.expiresAt,
    this.expiredAt,
    this.paymentReference,
    this.takenByUserId,
    this.takenAt,
    this.completedAt,
    this.failureReason,
    this.observation,
    this.customerConfirmationStatus,
    this.customerConfirmationCompletedAt,
  });

  final String id;
  final String reference;

  final OrderSource source;
  final String? customerAuthUid;

  final String clientName;
  final String clientWhatsappPhone;

  final MobileNetwork network;
  final String beneficiaryPhone;
  final OrderOperationType operationType;
  final String offerLabel;
  final int amount;

  final String? originalWhatsappMessage;
  final String? internalNotes;

  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? paymentRequestSentAt;
  final DateTime? paymentDeclaredAt;
  final String? paymentPayerName;
  final String? paymentPayerPhone;
  final String? paymentApproximateTime;
  final String? paymentDeclaredReference;
  final DateTime? paymentConfirmedAt;
  final DateTime? expiresAt;
  final DateTime? expiredAt;
  final String? paymentReference;

  final QueueOrderStatus status;
  final OrderPaymentStatus paymentStatus;

  final String? takenByUserId;
  final DateTime? takenAt;
  final DateTime? completedAt;

  final OrderFailureReason? failureReason;
  final String? observation;

  final CustomerConfirmationStatus? customerConfirmationStatus;
  final DateTime? customerConfirmationCompletedAt;

  bool get hasPaymentToReviewAfterExpiration {
    return status == QueueOrderStatus.expired &&
        paymentStatus == OrderPaymentStatus.declared;
  }

  QueueOrder copyWith({
    QueueOrderStatus? status,
    OrderPaymentStatus? paymentStatus,
    DateTime? paidAt,
    DateTime? paymentRequestSentAt,
    DateTime? paymentDeclaredAt,
    String? paymentPayerName,
    String? paymentPayerPhone,
    String? paymentApproximateTime,
    String? paymentDeclaredReference,
    DateTime? paymentConfirmedAt,
    DateTime? expiresAt,
    DateTime? expiredAt,
    String? paymentReference,
    String? takenByUserId,
    DateTime? takenAt,
    DateTime? completedAt,
    OrderFailureReason? failureReason,
    String? observation,
    CustomerConfirmationStatus? customerConfirmationStatus,
    DateTime? customerConfirmationCompletedAt,
    bool clearAssignment = false,
  }) {
    return QueueOrder(
      id: id,
      reference: reference,
      source: source,
      customerAuthUid: customerAuthUid,
      clientName: clientName,
      clientWhatsappPhone: clientWhatsappPhone,
      network: network,
      beneficiaryPhone: beneficiaryPhone,
      operationType: operationType,
      offerLabel: offerLabel,
      amount: amount,
      originalWhatsappMessage: originalWhatsappMessage,
      internalNotes: internalNotes,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      paymentRequestSentAt: paymentRequestSentAt ?? this.paymentRequestSentAt,
      paymentDeclaredAt: paymentDeclaredAt ?? this.paymentDeclaredAt,
      paymentPayerName: paymentPayerName ?? this.paymentPayerName,
      paymentPayerPhone: paymentPayerPhone ?? this.paymentPayerPhone,
      paymentApproximateTime:
          paymentApproximateTime ?? this.paymentApproximateTime,
      paymentDeclaredReference:
          paymentDeclaredReference ?? this.paymentDeclaredReference,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      expiredAt: expiredAt ?? this.expiredAt,
      paymentReference: paymentReference ?? this.paymentReference,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      takenByUserId: clearAssignment
          ? null
          : takenByUserId ?? this.takenByUserId,
      takenAt: clearAssignment ? null : takenAt ?? this.takenAt,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      observation: observation ?? this.observation,
      customerConfirmationStatus:
          customerConfirmationStatus ?? this.customerConfirmationStatus,
      customerConfirmationCompletedAt:
          customerConfirmationCompletedAt ??
          this.customerConfirmationCompletedAt,
    );
  }
}
