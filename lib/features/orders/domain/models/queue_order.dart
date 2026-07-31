enum MobileNetwork { orange, mtn, moov }

enum OrderOperationType {
  internetSubscription,
  unitTransfer,
  callBundle,
  mixedBundle,
  other,
}

enum QueueOrderStatus {
  awaitingPayment,
  paidReady,
  inProgress,
  awaitingCustomerConfirmation,
  completed,
  failed,
  cancelled,
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
    this.originalWhatsappMessage,
    this.internalNotes,
    this.paidAt,
    this.paymentRequestSentAt,
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
  final String? paymentReference;

  final QueueOrderStatus status;

  final String? takenByUserId;
  final DateTime? takenAt;
  final DateTime? completedAt;

  final OrderFailureReason? failureReason;
  final String? observation;

  final CustomerConfirmationStatus? customerConfirmationStatus;
  final DateTime? customerConfirmationCompletedAt;

  QueueOrder copyWith({
    QueueOrderStatus? status,
    DateTime? paidAt,
    DateTime? paymentRequestSentAt,
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
      paymentReference: paymentReference ?? this.paymentReference,
      status: status ?? this.status,
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
