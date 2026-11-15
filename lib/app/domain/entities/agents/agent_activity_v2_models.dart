import 'package:cloud_firestore/cloud_firestore.dart';

class AgentActivityOrderV2 {
  const AgentActivityOrderV2({
    required this.id,
    required this.reference,
    required this.network,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    this.assignedAt,
    this.takenAt,
    this.completedAt,
  });

  final String id;
  final String reference;
  final String network;
  final int amount;
  final String status;
  final String paymentStatus;
  final DateTime? assignedAt;
  final DateTime? takenAt;
  final DateTime? completedAt;

  bool get isSuccessful =>
      status == 'completed' || status == 'awaitingCustomerConfirmation';
  bool get isFailed => status == 'failed';
  bool get isActive =>
      status == 'paidReady' || status == 'inProgress' || status == 'onHold';

  Duration? get processingDuration {
    final DateTime? start = takenAt;
    final DateTime? end = completedAt;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  static AgentActivityOrderV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String reference = _string(data['reference']);
    final String network = _string(data['network']);
    final String status = _string(data['status']);
    if (reference.isEmpty || network.isEmpty || status.isEmpty) return null;
    return AgentActivityOrderV2(
      id: snapshot.id,
      reference: reference,
      network: network,
      amount: _int(data['amount']),
      status: status,
      paymentStatus: _string(data['paymentStatus']),
      assignedAt: _date(data['assignedAt']),
      takenAt: _date(data['takenAt']),
      completedAt: _date(data['completedAt']),
    );
  }
}

class AgentActivityAssignmentV2 {
  const AgentActivityAssignmentV2({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.status,
    this.assignedAt,
    this.acceptedAt,
    this.refusedAt,
    this.completedAt,
    this.refusalReason,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String status;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? refusedAt;
  final DateTime? completedAt;
  final String? refusalReason;

  bool get isRefused => status == 'refused' || refusedAt != null;

  static AgentActivityAssignmentV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String orderId = _string(data['orderId']);
    if (orderId.isEmpty) return null;
    return AgentActivityAssignmentV2(
      id: snapshot.id,
      orderId: orderId,
      orderReference: _string(data['orderReference']),
      status: _string(data['status']),
      assignedAt: _date(data['assignedAt']),
      acceptedAt: _date(data['acceptedAt']),
      refusedAt: _date(data['refusedAt']),
      completedAt: _date(data['completedAt']),
      refusalReason: _nullableString(data['refusalReason']),
    );
  }
}

class AgentNetworkMovementV2 {
  const AgentNetworkMovementV2({
    required this.id,
    required this.type,
    required this.direction,
    required this.network,
    required this.amount,
    required this.capacityBefore,
    required this.capacityAfter,
    this.createdAt,
  });

  final String id;
  final String type;
  final String direction;
  final String network;
  final int amount;
  final int capacityBefore;
  final int capacityAfter;
  final DateTime? createdAt;

  bool get isRecharge => type == 'supplierRecharge';
  int get signedAmount => direction == 'outgoing' ? -amount : amount;

  static AgentNetworkMovementV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String network = _string(data['network']);
    if (network.isEmpty) return null;
    return AgentNetworkMovementV2(
      id: snapshot.id,
      type: _string(data['type']),
      direction: _string(data['direction']),
      network: network,
      amount: _int(data['amount']),
      capacityBefore: _int(data['capacityBefore']),
      capacityAfter: _int(data['capacityAfter']),
      createdAt: _date(data['createdAt']),
    );
  }
}

class AgentCommissionV2 {
  const AgentCommissionV2({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.orderAmount,
    required this.commissionAmount,
    this.earnedAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String network;
  final int orderAmount;
  final int commissionAmount;
  final DateTime? earnedAt;

  static AgentCommissionV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String orderId = _string(data['orderId']);
    if (orderId.isEmpty) return null;
    return AgentCommissionV2(
      id: snapshot.id,
      orderId: orderId,
      orderReference: _string(data['orderReference']),
      network: _string(data['network']),
      orderAmount: _int(data['orderAmount']),
      commissionAmount: _int(data['commissionAmount']),
      earnedAt: _date(data['earnedAt']) ?? _date(data['createdAt']),
    );
  }
}

class AgentCommissionAccountV2 {
  const AgentCommissionAccountV2({
    required this.earnedTotal,
    required this.paidTotal,
    required this.earnedTransactions,
    this.updatedAt,
  });

  final int earnedTotal;
  final int paidTotal;
  final int earnedTransactions;
  final DateTime? updatedAt;

  int get outstanding => earnedTotal - paidTotal;

  static AgentCommissionAccountV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    return AgentCommissionAccountV2(
      earnedTotal: _int(data['earnedTotal']),
      paidTotal: _int(data['paidTotal']),
      earnedTransactions: _int(data['earnedTransactions']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

class AgentCommissionPayoutV2 {
  const AgentCommissionPayoutV2({
    required this.id,
    required this.amount,
    required this.paymentChannel,
    required this.paymentReference,
    this.note,
    this.paidAt,
  });

  final String id;
  final int amount;
  final String paymentChannel;
  final String paymentReference;
  final String? note;
  final DateTime? paidAt;

  static AgentCommissionPayoutV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    return AgentCommissionPayoutV2(
      id: snapshot.id,
      amount: _int(data['amount']),
      paymentChannel: _string(data['paymentChannel']),
      paymentReference: _string(data['paymentReference']),
      note: _nullableString(data['note']),
      paidAt: _date(data['paidAt']) ?? _date(data['createdAt']),
    );
  }
}

class AgentOperationalSnapshotV2 {
  const AgentOperationalSnapshotV2({
    required this.agentCode,
    required this.availability,
    required this.activeNetworks,
    required this.orangeCapacity,
    required this.mtnCapacity,
    required this.moovCapacity,
    required this.dailyTransactionLimit,
    required this.maxTransactionsPerDay,
    this.updatedAt,
  });

  final String agentCode;
  final String availability;
  final List<String> activeNetworks;
  final int orangeCapacity;
  final int mtnCapacity;
  final int moovCapacity;
  final int dailyTransactionLimit;
  final int maxTransactionsPerDay;
  final DateTime? updatedAt;

  bool isNetworkActive(String network) => activeNetworks.contains(network);

  int capacityFor(String network) => switch (network) {
    'orange' => orangeCapacity,
    'mtn' => mtnCapacity,
    'moov' => moovCapacity,
    _ => 0,
  };

  static AgentOperationalSnapshotV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    return AgentOperationalSnapshotV2(
      agentCode: _string(data['agentCode']),
      availability: _string(data['availability']),
      activeNetworks: _stringList(data['activeNetworks']),
      orangeCapacity: _int(data['orangeCapacity']),
      mtnCapacity: _int(data['mtnCapacity']),
      moovCapacity: _int(data['moovCapacity']),
      dailyTransactionLimit: _int(data['dailyTransactionLimit']),
      maxTransactionsPerDay: _int(data['maxTransactionsPerDay']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

class AgentIssueSnapshotV2 {
  const AgentIssueSnapshotV2({
    required this.id,
    required this.type,
    required this.status,
    required this.description,
    this.network,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String type;
  final String status;
  final String description;
  final String? network;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isOpen => status != 'resolved' && status != 'cancelled';

  static AgentIssueSnapshotV2? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return null;
    final String description = _string(data['description']);
    if (description.isEmpty) return null;
    return AgentIssueSnapshotV2(
      id: snapshot.id,
      type: _string(data['type']),
      status: _string(data['status']),
      description: description,
      network: _nullableString(data['network']),
      createdAt: _date(data['createdAt']),
      resolvedAt: _date(data['resolvedAt']),
    );
  }
}

class AgentActivityV2Sources {
  const AgentActivityV2Sources._();

  static const String orders = 'orders';
  static const String assignments = 'orderAssignments';
  static const String movements = 'networkTransactions';
  static const String commissions = 'commissions';
  static const String commissionAccount = 'commissionAccounts';
  static const String payouts = 'commissionPayouts';
  static const String operationalProfile = 'agentProfiles';
  static const String issues = 'agentIssues';
}

class AgentActivityV2Snapshot {
  const AgentActivityV2Snapshot({
    required this.orders,
    required this.assignments,
    required this.movements,
    required this.commissions,
    required this.commissionAccount,
    required this.payouts,
    required this.operationalProfile,
    required this.issues,
    this.unavailableSources = const <String>{},
  });

  final List<AgentActivityOrderV2> orders;
  final List<AgentActivityAssignmentV2> assignments;
  final List<AgentNetworkMovementV2> movements;
  final List<AgentCommissionV2> commissions;
  final AgentCommissionAccountV2? commissionAccount;
  final List<AgentCommissionPayoutV2> payouts;
  final AgentOperationalSnapshotV2? operationalProfile;
  final List<AgentIssueSnapshotV2> issues;
  final Set<String> unavailableSources;

  bool isUnavailable(String source) => unavailableSources.contains(source);
  bool get hasUnavailableSources => unavailableSources.isNotEmpty;

  int get assignedCount => assignments.length;
  int get refusedCount => assignments.where((item) => item.isRefused).length;
  int get successfulCount => orders.where((item) => item.isSuccessful).length;
  int get failedCount => orders.where((item) => item.isFailed).length;
  int get activeCount => orders.where((item) => item.isActive).length;
  int get successfulAmount => orders
      .where((item) => item.isSuccessful)
      .fold<int>(0, (total, item) => total + item.amount);
  int get rechargeAmount => movements
      .where((item) => item.isRecharge)
      .fold<int>(0, (total, item) => total + item.amount);
  int get commissionEarned =>
      commissionAccount?.earnedTotal ??
      commissions.fold<int>(0, (total, item) => total + item.commissionAmount);
  int get commissionPaid =>
      commissionAccount?.paidTotal ??
      payouts.fold<int>(0, (total, item) => total + item.amount);
  int get commissionOutstanding => commissionEarned - commissionPaid;
  int get commissionTransactionCount =>
      commissionAccount?.earnedTransactions ?? commissions.length;
  int get openIssueCount => issues.where((item) => item.isOpen).length;

  Duration? get averageProcessingDuration {
    final List<Duration> durations = orders
        .map((item) => item.processingDuration)
        .whereType<Duration>()
        .toList(growable: false);
    if (durations.isEmpty) return null;
    final int totalMs = durations.fold<int>(
      0,
      (total, duration) => total + duration.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ durations.length);
  }
}

String _string(Object? value) => value is String ? value.trim() : '';

String? _nullableString(Object? value) {
  final String text = _string(value);
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
