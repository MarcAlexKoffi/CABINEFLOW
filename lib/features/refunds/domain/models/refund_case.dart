enum RefundReason {
  serviceNotReceived,
  transactionFailed,
  wrongAmount,
  wrongNumber,
  duplicatePayment,
  cancellation,
  paymentIssue,
  other,
}

extension RefundReasonX on RefundReason {
  String get storageValue {
    switch (this) {
      case RefundReason.serviceNotReceived:
        return 'serviceNotReceived';
      case RefundReason.transactionFailed:
        return 'transactionFailed';
      case RefundReason.wrongAmount:
        return 'wrongAmount';
      case RefundReason.wrongNumber:
        return 'wrongNumber';
      case RefundReason.duplicatePayment:
        return 'duplicatePayment';
      case RefundReason.cancellation:
        return 'cancellation';
      case RefundReason.paymentIssue:
        return 'paymentIssue';
      case RefundReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case RefundReason.serviceNotReceived:
        return 'Service non reçu';
      case RefundReason.transactionFailed:
        return 'Transaction échouée';
      case RefundReason.wrongAmount:
        return 'Montant incorrect';
      case RefundReason.wrongNumber:
        return 'Mauvais numéro';
      case RefundReason.duplicatePayment:
        return 'Paiement en double';
      case RefundReason.cancellation:
        return 'Annulation';
      case RefundReason.paymentIssue:
        return 'Problème de paiement';
      case RefundReason.other:
        return 'Autre';
    }
  }

  static RefundReason fromStorage(String value) {
    return RefundReason.values.firstWhere(
      (RefundReason reason) => reason.storageValue == value,
      orElse: () => RefundReason.other,
    );
  }
}

enum RefundStatus { pendingApproval, approved, refunded, reconciled, rejected }

extension RefundStatusX on RefundStatus {
  String get storageValue {
    switch (this) {
      case RefundStatus.pendingApproval:
        return 'pendingApproval';
      case RefundStatus.approved:
        return 'approved';
      case RefundStatus.refunded:
        return 'refunded';
      case RefundStatus.reconciled:
        return 'reconciled';
      case RefundStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case RefundStatus.pendingApproval:
        return 'À valider';
      case RefundStatus.approved:
        return 'À effectuer';
      case RefundStatus.refunded:
        return 'Remboursé';
      case RefundStatus.reconciled:
        return 'Rapproché';
      case RefundStatus.rejected:
        return 'Rejeté';
    }
  }

  bool get isActive =>
      this == RefundStatus.pendingApproval || this == RefundStatus.approved;

  bool get isHistory => !isActive;

  static RefundStatus fromStorage(String value) {
    switch (value) {
      case 'approved':
        return RefundStatus.approved;
      case 'refunded':
        return RefundStatus.refunded;
      case 'reconciled':
        return RefundStatus.reconciled;
      case 'rejected':
        return RefundStatus.rejected;
      case 'pendingApproval':
      default:
        return RefundStatus.pendingApproval;
    }
  }
}

class RefundCreationDraft {
  const RefundCreationDraft({
    required this.amount,
    required this.reason,
    required this.reasonNote,
  });

  final int amount;
  final RefundReason reason;
  final String reasonNote;
}

class RefundCreationRequest {
  const RefundCreationRequest({
    required this.orderId,
    required this.orderReference,
    required this.supportRequestId,
    required this.supportRequestType,
    required this.supportRequestDescription,
    required this.customerAuthUid,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.originalAmount,
    required this.amount,
    required this.reason,
    required this.reasonNote,
    required this.paymentChannel,
    required this.originalPaymentReference,
  });

  final String orderId;
  final String orderReference;
  final String supportRequestId;
  final String supportRequestType;
  final String supportRequestDescription;
  final String? customerAuthUid;
  final String clientName;
  final String clientWhatsappPhone;
  final int originalAmount;
  final int amount;
  final RefundReason reason;
  final String reasonNote;
  final String paymentChannel;
  final String? originalPaymentReference;
}

class RefundCase {
  const RefundCase({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.supportRequestId,
    required this.supportRequestType,
    required this.supportRequestDescription,
    required this.customerAuthUid,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.originalAmount,
    required this.amount,
    required this.reason,
    required this.reasonNote,
    required this.paymentChannel,
    required this.originalPaymentReference,
    required this.status,
    required this.requestedAt,
    required this.requestedBy,
    required this.requestedByName,
    required this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectionReason,
    this.refundReference,
    this.refundedAt,
    this.refundedBy,
    this.refundedByName,
    this.customerNotifiedAt,
    this.customerNotifiedBy,
    this.customerNotifiedByName,
    this.notificationChannel,
    this.reconciledAt,
    this.reconciledBy,
    this.reconciledByName,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String supportRequestId;
  final String supportRequestType;
  final String supportRequestDescription;
  final String? customerAuthUid;
  final String clientName;
  final String clientWhatsappPhone;
  final int originalAmount;
  final int amount;
  final RefundReason reason;
  final String reasonNote;
  final String paymentChannel;
  final String? originalPaymentReference;
  final RefundStatus status;
  final DateTime requestedAt;
  final String requestedBy;
  final String requestedByName;
  final DateTime updatedAt;

  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;

  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejectedByName;
  final String? rejectionReason;

  final String? refundReference;
  final DateTime? refundedAt;
  final String? refundedBy;
  final String? refundedByName;

  final DateTime? customerNotifiedAt;
  final String? customerNotifiedBy;
  final String? customerNotifiedByName;
  final String? notificationChannel;

  final DateTime? reconciledAt;
  final String? reconciledBy;
  final String? reconciledByName;

  bool get isActive => status.isActive;
  bool get isHistory => status.isHistory;
  bool get customerWasNotified => customerNotifiedAt != null;
  bool get isRefundCompleted =>
      status == RefundStatus.refunded || status == RefundStatus.reconciled;

  RefundCase copyWith({
    RefundStatus? status,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectedByName,
    String? rejectionReason,
    String? refundReference,
    DateTime? refundedAt,
    String? refundedBy,
    String? refundedByName,
    DateTime? customerNotifiedAt,
    String? customerNotifiedBy,
    String? customerNotifiedByName,
    String? notificationChannel,
    DateTime? reconciledAt,
    String? reconciledBy,
    String? reconciledByName,
  }) {
    return RefundCase(
      id: id,
      orderId: orderId,
      orderReference: orderReference,
      supportRequestId: supportRequestId,
      supportRequestType: supportRequestType,
      supportRequestDescription: supportRequestDescription,
      customerAuthUid: customerAuthUid,
      clientName: clientName,
      clientWhatsappPhone: clientWhatsappPhone,
      originalAmount: originalAmount,
      amount: amount,
      reason: reason,
      reasonNote: reasonNote,
      paymentChannel: paymentChannel,
      originalPaymentReference: originalPaymentReference,
      status: status ?? this.status,
      requestedAt: requestedAt,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      refundReference: refundReference ?? this.refundReference,
      refundedAt: refundedAt ?? this.refundedAt,
      refundedBy: refundedBy ?? this.refundedBy,
      refundedByName: refundedByName ?? this.refundedByName,
      customerNotifiedAt: customerNotifiedAt ?? this.customerNotifiedAt,
      customerNotifiedBy: customerNotifiedBy ?? this.customerNotifiedBy,
      customerNotifiedByName:
          customerNotifiedByName ?? this.customerNotifiedByName,
      notificationChannel: notificationChannel ?? this.notificationChannel,
      reconciledAt: reconciledAt ?? this.reconciledAt,
      reconciledBy: reconciledBy ?? this.reconciledBy,
      reconciledByName: reconciledByName ?? this.reconciledByName,
    );
  }
}
