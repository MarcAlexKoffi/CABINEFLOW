import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';

class AgentIssueCenterEvent {
  const AgentIssueCenterEvent({
    required this.id,
    required this.kind,
    required this.status,
    required this.occurredAt,
    required this.actorUid,
    required this.actorName,
    required this.note,
  });

  final String id;
  final String kind;
  final String status;
  final DateTime? occurredAt;
  final String actorUid;
  final String actorName;
  final String note;

  factory AgentIssueCenterEvent.fromJson(Map<String, dynamic> json) {
    return AgentIssueCenterEvent(
      id: _string(json['id']),
      kind: _string(json['event_kind']),
      status: _string(json['status']),
      occurredAt: _date(json['occurred_at']),
      actorUid: _string(json['actor_uid']),
      actorName: _string(json['actor_name']),
      note: _string(json['note']),
    );
  }
}

class AgentIssueCenterItem {
  const AgentIssueCenterItem({
    required this.id,
    required this.agentId,
    required this.type,
    required this.network,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.resolvedByUid,
    required this.resolutionNote,
    required this.events,
  });

  final String id;
  final String agentId;
  final String type;
  final AgentNetwork? network;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String resolvedBy;
  final String resolvedByUid;
  final String resolutionNote;
  final List<AgentIssueCenterEvent> events;

  factory AgentIssueCenterItem.fromJson(Map<String, dynamic> json) {
    return AgentIssueCenterItem(
      id: _string(json['id']),
      agentId: _string(json['agent_id']),
      type: _string(json['type']),
      network: _network(json['network']),
      description: _string(json['description']),
      status: _string(json['status'], fallback: 'open'),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      resolvedAt: _date(json['resolved_at']),
      resolvedBy: _string(json['resolved_by']),
      resolvedByUid: _string(json['resolved_by_uid']),
      resolutionNote: _string(json['resolution_note']),
      events: _list(json['events'])
          .map(AgentIssueCenterEvent.fromJson)
          .toList(growable: false),
    );
  }
}

class AgentIssueCenterSnapshot {
  const AgentIssueCenterSnapshot({
    required this.generatedAt,
    required this.callerRole,
    required this.scopeType,
    required this.issues,
  });

  final DateTime? generatedAt;
  final String callerRole;
  final String scopeType;
  final List<AgentIssueCenterItem> issues;

  bool get isManagerScope => scopeType == 'manager_territory';

  factory AgentIssueCenterSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> scope = _map(json['scope']);
    return AgentIssueCenterSnapshot(
      generatedAt: _date(json['generated_at']),
      callerRole: _string(json['caller_role']),
      scopeType: _string(scope['type']),
      issues: _list(json['issues'])
          .map(AgentIssueCenterItem.fromJson)
          .toList(growable: false),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value.toLocal();
  final String raw = _string(value);
  return raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map(
    (dynamic key, dynamic item) => MapEntry(key.toString(), item),
  );
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map(
        (Map<dynamic, dynamic> item) => item.map(
          (dynamic key, dynamic field) => MapEntry(key.toString(), field),
        ),
      )
      .toList(growable: false);
}

AgentNetwork? _network(Object? value) {
  final String raw = _string(value).toLowerCase();
  for (final AgentNetwork network in AgentNetwork.values) {
    if (network.name == raw) return network;
  }
  return null;
}
