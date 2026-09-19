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
    required this.updatedAt,
    this.processingStartedAt,
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
  final DateTime? processingStartedAt;
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
