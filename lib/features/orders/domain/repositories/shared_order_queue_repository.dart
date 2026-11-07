import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class AvailableSharedOrder {
  const AvailableSharedOrder({
    required this.id,
    required this.reference,
    required this.zoneId,
    required this.network,
    required this.offerLabel,
    required this.service,
    required this.amount,
    required this.beneficiaryMasked,
    required this.availableAt,
    required this.version,
    required this.canAccept,
  });
  final String id, reference, zoneId, offerLabel, service, beneficiaryMasked;
  final MobileNetwork network;
  final int amount, version;
  final DateTime availableAt;
  final bool canAccept;
  String get serviceLabel => switch (service) {
    'internetSubscription' => 'Forfait internet',
    'unitTransfer' => 'Transfert d’unités',
    'callBundle' => 'Forfait voix',
    'mixedBundle' => 'Forfait mixte',
    _ => 'Service télécom',
  };

  factory AvailableSharedOrder.fromJson(Map<String, dynamic> row) {
    return AvailableSharedOrder(
      id: row['order_id'] as String,
      reference: row['order_reference'] as String,
      zoneId: row['zone_id'] as String,
      network: MobileNetwork.values.byName(row['network'] as String),
      offerLabel: row['offer_label'] as String,
      service: row['operation_type'] as String,
      amount: (row['amount'] as num).toInt(),
      beneficiaryMasked: row['beneficiary_masked'] as String,
      availableAt: DateTime.parse(row['available_at'] as String),
      version: (row['assignment_version'] as num).toInt(),
      canAccept: row['can_accept'] == true,
    );
  }
}

class SharedQueueSnapshot {
  const SharedQueueSnapshot({
    required this.orders,
    required this.serverNow,
    required this.enabled,
  });
  final List<AvailableSharedOrder> orders;
  final DateTime serverNow;
  final bool enabled;
}

abstract interface class SharedOrderQueueRepository {
  Future<SharedQueueSnapshot> fetchAvailableOrders();
  Stream<SharedQueueSnapshot> watchAvailableOrders();
  Future<QueueOrder> claimAvailableOrder(AvailableSharedOrder order);
}

class OrderSupervisionSnapshot {
  const OrderSupervisionSnapshot({
    required this.serverNow,
    required this.orders,
    required this.alerts,
  });
  final DateTime serverNow;
  final List<Map<String, dynamic>> orders, alerts;
}

abstract interface class OrderSupervisionRepository {
  Future<OrderSupervisionSnapshot> fetchSupervision();
  Stream<OrderSupervisionSnapshot> watchSupervision();
}
