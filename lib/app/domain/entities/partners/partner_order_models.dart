class PartnerAccountSnapshot {
  const PartnerAccountSnapshot({
    required this.id,
    required this.partnerCode,
    required this.displayName,
    required this.status,
    required this.availability,
    required this.authorizedNetworks,
    required this.activeNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
    this.firebaseUid,
    this.phoneNumber = '',
    this.city = '',
  });

  final String id;
  final String partnerCode;
  final String? firebaseUid;
  final String displayName;
  final String phoneNumber;
  final String city;
  final String status;
  final String availability;
  final List<String> authorizedNetworks;
  final List<String> activeNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;

  bool get isActive => status == 'active';
  bool get isAvailable => isActive && availability == 'available';

  int capacityFor(String network) {
    switch (network.trim().toLowerCase()) {
      case 'orange':
        return orangeCapacity;
      case 'mtn':
        return mtnCapacity;
      case 'moov':
        return moovCapacity;
      default:
        return 0;
    }
  }
}

class PartnerOrderSnapshot {
  const PartnerOrderSnapshot({
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.amount,
    required this.assignmentState,
    required this.orderStatus,
    required this.assignedPartnerId,
    required this.assignedPartnerName,
    required this.beneficiaryPhone,
    required this.operationType,
    required this.offerLabel,
    required this.updatedAt,
    this.clientName = 'Client',
    this.clientWhatsappPhone = '',
    this.paymentStatus = '',
    this.paymentPayerName,
    this.paymentReference,
    this.firebaseCreatedAt,
    this.paidAt,
    this.paymentConfirmedAt,
    this.assignedAt,
    this.processingStartedAt,
    this.lastHeldAt,
    this.lastResumedAt,
    this.completedAt,
    this.failureReason,
    this.observation,
    this.lastHoldReason,
  });

  final String orderId;
  final String orderReference;
  final String network;
  final int amount;
  final String assignmentState;
  final String orderStatus;
  final String assignedPartnerId;
  final String assignedPartnerName;
  final String beneficiaryPhone;
  final String operationType;
  final String offerLabel;
  final String clientName;
  final String clientWhatsappPhone;
  final String paymentStatus;
  final String? paymentPayerName;
  final String? paymentReference;
  final DateTime? firebaseCreatedAt;
  final DateTime? paidAt;
  final DateTime? paymentConfirmedAt;
  final DateTime? assignedAt;
  final DateTime? processingStartedAt;
  final DateTime? lastHeldAt;
  final DateTime? lastResumedAt;
  final DateTime? completedAt;
  final String? failureReason;
  final String? observation;
  final String? lastHoldReason;
  final DateTime updatedAt;

  bool get isAwaitingDecision => assignmentState == 'assigned';
  bool get isAccepted => assignmentState == 'accepted';
  bool get isInProgress => orderStatus == 'inProgress';
  bool get isOnHold => orderStatus == 'onHold';
  bool get isCompleted => orderStatus == 'completed';
  bool get isFailed => orderStatus == 'failed';
  bool get isFundedForProcessing =>
      paymentStatus == 'confirmed' || paymentStatus == 'credit';
}

class PartnerFinalizationResult {
  const PartnerFinalizationResult({
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.orderAmount,
    required this.capacityBefore,
    required this.capacityAfter,
    required this.telecomMarginAmount,
    required this.cabinisteMarginAmount,
    required this.izytelMarginAmount,
    required this.customerFeeAmount,
    required this.cabinisteSettlementAmount,
    required this.izytelGrossGain,
    required this.idempotent,
  });

  final String orderId;
  final String orderReference;
  final String network;
  final int orderAmount;
  final int capacityBefore;
  final int capacityAfter;
  final int telecomMarginAmount;
  final int cabinisteMarginAmount;
  final int izytelMarginAmount;
  final int customerFeeAmount;
  final int cabinisteSettlementAmount;
  final int izytelGrossGain;
  final bool idempotent;
}


class PartnerFinancePayout {
  const PartnerFinancePayout({
    required this.id,
    required this.amount,
    required this.channel,
    required this.reference,
    required this.paidAt,
    this.note,
  });

  final String id;
  final int amount;
  final String channel;
  final String reference;
  final DateTime? paidAt;
  final String? note;
}

class PartnerFinanceSnapshot {
  const PartnerFinanceSnapshot({
    required this.partnerId,
    required this.partnerCode,
    required this.displayName,
    required this.status,
    required this.earnedTotal,
    required this.paidTotal,
    required this.balanceDue,
    required this.earnedTransactions,
    required this.payouts,
  });

  final String partnerId;
  final String partnerCode;
  final String displayName;
  final String status;
  final int earnedTotal;
  final int paidTotal;
  final int balanceDue;
  final int earnedTransactions;
  final List<PartnerFinancePayout> payouts;
}

class PartnerAssignmentHistoryItem {
  const PartnerAssignmentHistoryItem({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.partnerId,
    required this.partnerName,
    required this.mode,
    required this.status,
    required this.network,
    required this.amount,
    required this.assignedAt,
    required this.updatedAt,
    this.acceptedAt,
    this.refusedAt,
    this.refusalReason,
    this.completedAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String partnerId;
  final String partnerName;
  final String mode;
  final String status;
  final String network;
  final int amount;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? refusedAt;
  final String? refusalReason;
  final DateTime? completedAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isRefused => status == 'refused';
  bool get isFailed => status == 'failed';
}
