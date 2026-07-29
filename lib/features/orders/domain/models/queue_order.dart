enum MobileNetwork { orange, mtn, moov }

enum QueueOrderStatus { paidReady, inProgress }

class QueueOrder {
  const QueueOrder({
    required this.id,
    required this.reference,
    required this.network,
    required this.beneficiaryPhone,
    required this.offerLabel,
    required this.amount,
    required this.paidAt,
    required this.status,
    this.takenByUserId,
    this.takenAt,
  });

  final String id;
  final String reference;
  final MobileNetwork network;
  final String beneficiaryPhone;
  final String offerLabel;
  final int amount;
  final DateTime paidAt;
  final QueueOrderStatus status;
  final String? takenByUserId;
  final DateTime? takenAt;

  QueueOrder copyWith({
    QueueOrderStatus? status,
    String? takenByUserId,
    DateTime? takenAt,
  }) {
    return QueueOrder(
      id: id,
      reference: reference,
      network: network,
      beneficiaryPhone: beneficiaryPhone,
      offerLabel: offerLabel,
      amount: amount,
      paidAt: paidAt,
      status: status ?? this.status,
      takenByUserId: takenByUserId ?? this.takenByUserId,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
