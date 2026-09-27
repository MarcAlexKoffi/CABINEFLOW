class ControlActivityEvent {
  const ControlActivityEvent({
    required this.id,
    required this.occurredAt,
    required this.domain,
    required this.eventKind,
    required this.title,
    required this.reference,
    required this.actorName,
    required this.severity,
    required this.details,
  });

  final String id;
  final DateTime? occurredAt;
  final String domain;
  final String eventKind;
  final String title;
  final String reference;
  final String actorName;
  final String severity;
  final Map<String, dynamic> details;

  factory ControlActivityEvent.fromJson(Map<String, dynamic> json) {
    return ControlActivityEvent(
      id: _s(json['id']),
      occurredAt: _date(json['occurred_at']),
      domain: _s(json['domain']),
      eventKind: _s(json['event_kind']),
      title: _s(json['title']),
      reference: _s(json['reference']),
      actorName: _s(json['actor_name']),
      severity: _s(json['severity'], fallback: 'info'),
      details: _map(json['details']),
    );
  }
}

class ControlAuditEvent {
  const ControlAuditEvent({
    required this.id,
    required this.occurredAt,
    required this.domain,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorName,
    required this.details,
  });

  final String id;
  final DateTime? occurredAt;
  final String domain;
  final String action;
  final String entityType;
  final String entityId;
  final String actorName;
  final Map<String, dynamic> details;

  factory ControlAuditEvent.fromJson(Map<String, dynamic> json) {
    return ControlAuditEvent(
      id: _s(json['id']),
      occurredAt: _date(json['occurred_at']),
      domain: _s(json['domain']),
      action: _s(json['action']),
      entityType: _s(json['entity_type']),
      entityId: _s(json['entity_id']),
      actorName: _s(json['actor_name']),
      details: _map(json['details']),
    );
  }
}

class ControlNetworkMetric {
  const ControlNetworkMetric({
    required this.network,
    required this.orders,
    required this.completed,
    required this.failed,
    required this.completedAmount,
  });

  final String network;
  final int orders;
  final int completed;
  final int failed;
  final int completedAmount;

  factory ControlNetworkMetric.fromJson(Map<String, dynamic> json) {
    return ControlNetworkMetric(
      network: _s(json['network'], fallback: 'unknown'),
      orders: _i(json['orders']),
      completed: _i(json['completed']),
      failed: _i(json['failed']),
      completedAmount: _i(json['completed_amount']),
    );
  }
}

class ControlAgentPerformance {
  const ControlAgentPerformance({
    required this.agentId,
    required this.agentName,
    required this.orders,
    required this.completed,
    required this.failed,
    required this.completedAmount,
    required this.averageProcessingMinutes,
  });

  final String agentId;
  final String agentName;
  final int orders;
  final int completed;
  final int failed;
  final int completedAmount;
  final double averageProcessingMinutes;

  factory ControlAgentPerformance.fromJson(Map<String, dynamic> json) {
    return ControlAgentPerformance(
      agentId: _s(json['agent_id']),
      agentName: _s(json['agent_name'], fallback: 'Agent'),
      orders: _i(json['orders']),
      completed: _i(json['completed']),
      failed: _i(json['failed']),
      completedAmount: _i(json['completed_amount']),
      averageProcessingMinutes: _d(json['avg_processing_minutes']),
    );
  }
}

class ControlDailyTrend {
  const ControlDailyTrend({
    required this.date,
    required this.orders,
    required this.completed,
    required this.failed,
    required this.completedAmount,
  });

  final DateTime? date;
  final int orders;
  final int completed;
  final int failed;
  final int completedAmount;

  factory ControlDailyTrend.fromJson(Map<String, dynamic> json) {
    return ControlDailyTrend(
      date: _date(json['date']),
      orders: _i(json['orders']),
      completed: _i(json['completed']),
      failed: _i(json['failed']),
      completedAmount: _i(json['completed_amount']),
    );
  }
}

class ControlSnapshot {
  const ControlSnapshot({
    required this.generatedAt,
    required this.callerRole,
    required this.scopeType,
    required this.auditAllowed,
    required this.statistics,
    required this.adminFinance,
    required this.activity,
    required this.audit,
    required this.networkBreakdown,
    required this.agentPerformance,
    required this.dailyTrend,
  });

  final DateTime? generatedAt;
  final String callerRole;
  final String scopeType;
  final bool auditAllowed;
  final Map<String, dynamic> statistics;
  final Map<String, dynamic> adminFinance;
  final List<ControlActivityEvent> activity;
  final List<ControlAuditEvent> audit;
  final List<ControlNetworkMetric> networkBreakdown;
  final List<ControlAgentPerformance> agentPerformance;
  final List<ControlDailyTrend> dailyTrend;

  factory ControlSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> scope = _map(json['scope']);
    return ControlSnapshot(
      generatedAt: _date(json['generated_at']),
      callerRole: _s(json['caller_role']),
      scopeType: _s(scope['type']),
      auditAllowed: json['audit_allowed'] == true,
      statistics: _map(json['statistics']),
      adminFinance: _map(json['admin_finance']),
      activity: _list(json['activity'])
          .map(ControlActivityEvent.fromJson)
          .toList(growable: false),
      audit: _list(json['audit'])
          .map(ControlAuditEvent.fromJson)
          .toList(growable: false),
      networkBreakdown: _list(json['network_breakdown'])
          .map(ControlNetworkMetric.fromJson)
          .toList(growable: false),
      agentPerformance: _list(json['agent_performance'])
          .map(ControlAgentPerformance.fromJson)
          .toList(growable: false),
      dailyTrend: _list(json['daily_trend'])
          .map(ControlDailyTrend.fromJson)
          .toList(growable: false),
    );
  }

  int stat(String key) => _i(statistics[key]);
  double statDouble(String key) => _d(statistics[key]);
  int finance(String key) => _i(adminFinance[key]);
}

String _s(Object? value, {String fallback = ''}) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _i(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _d(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((dynamic key, dynamic item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((Map item) => item.map(
            (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
          ))
      .toList(growable: false);
}

class ControlActivityPageData {
  const ControlActivityPageData({required this.total, required this.items});

  final int total;
  final List<ControlActivityEvent> items;

  factory ControlActivityPageData.fromJson(Map<String, dynamic> json) {
    return ControlActivityPageData(
      total: _i(json['total']),
      items: _list(json['items'])
          .map(ControlActivityEvent.fromJson)
          .toList(growable: false),
    );
  }
}

class ControlAuditPageData {
  const ControlAuditPageData({required this.total, required this.items});

  final int total;
  final List<ControlAuditEvent> items;

  factory ControlAuditPageData.fromJson(Map<String, dynamic> json) {
    return ControlAuditPageData(
      total: _i(json['total']),
      items: _list(json['items'])
          .map(ControlAuditEvent.fromJson)
          .toList(growable: false),
    );
  }
}
