enum MobileNetwork { orange, mtn, moov }

enum QueueOrderStatus {
  paidReady,
  inProgress,
  awaitingCustomerConfirmation,
  completed,
  failed,
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
    required this.offerLabel,
    required this.amount,
    required this.paidAt,
    required this.status,
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

  // Numéro WhatsApp du client ayant passé la commande.
  final String clientWhatsappPhone;

  // Numéro qui reçoit réellement le forfait ou les unités.
  final String beneficiaryPhone;

  final MobileNetwork network;
  final String offerLabel;
  final int amount;
  final DateTime paidAt;
  final QueueOrderStatus status;

  final String? takenByUserId;
  final DateTime? takenAt;

  // Heure à laquelle la transaction réseau a été terminée.
  final DateTime? completedAt;

  final OrderFailureReason? failureReason;
  final String? observation;

  final CustomerConfirmationStatus? customerConfirmationStatus;

  final DateTime? customerConfirmationCompletedAt;

  QueueOrder copyWith({
    QueueOrderStatus? status,
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
      offerLabel: offerLabel,
      amount: amount,
      paidAt: paidAt,
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
