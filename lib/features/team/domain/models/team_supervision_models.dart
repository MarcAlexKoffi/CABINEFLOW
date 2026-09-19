class TeamScopeZone {
  const TeamScopeZone({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    required this.managerId,
    required this.isActive,
  });

  final String id;
  final String name;
  final String city;
  final String region;
  final String managerId;
  final bool isActive;

  String get label => city.trim().isEmpty ? name : '$name, $city';

  factory TeamScopeZone.fromMap(Map<String, dynamic> row) {
    return TeamScopeZone(
      id: _string(row['id']),
      name: _string(row['name']),
      city: _string(row['city']),
      region: _string(row['region']),
      managerId: _string(row['managerId']),
      isActive: row['isActive'] == true,
    );
  }
}

class TeamScopeSnapshot {
  const TeamScopeSnapshot({
    required this.role,
    required this.firebaseUid,
    required this.zoneIds,
    required this.zones,
    required this.agentIds,
    required this.cabinisteIds,
    required this.managerIds,
  });

  final String role;
  final String firebaseUid;
  final List<String> zoneIds;
  final List<TeamScopeZone> zones;
  final List<String> agentIds;
  final List<String> cabinisteIds;
  final List<String> managerIds;

  bool get isAdmin => role == 'admin';

  factory TeamScopeSnapshot.fromMap(Map<String, dynamic> row) {
    return TeamScopeSnapshot(
      role: _string(row['role']),
      firebaseUid: _string(row['firebaseUid']),
      zoneIds: _strings(row['zoneIds']),
      zones: _maps(row['zones'])
          .map(TeamScopeZone.fromMap)
          .toList(growable: false),
      agentIds: _strings(row['agentIds']),
      cabinisteIds: _strings(row['cabinisteIds']),
      managerIds: _strings(row['managerIds']),
    );
  }
}

class TeamMemberDetail {
  const TeamMemberDetail({
    required this.actorType,
    required this.actorId,
    required this.profile,
    required this.operations,
    required this.finance,
  });

  final String actorType;
  final String actorId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> operations;
  final Map<String, dynamic> finance;

  String get firebaseUid => _string(profile['firebase_uid']);
  String get firstName => _string(profile['first_name']);
  String get lastName => _string(profile['last_name']);
  String get displayName {
    final String value = '$firstName $lastName'.trim();
    if (value.isNotEmpty) return value;
    final Map<String, dynamic> account = _map(operations['account']);
    final Map<String, dynamic> manager = _map(operations['managerProfile']);
    return _firstNonEmpty(<String>[
      _string(account['display_name']),
      _string(manager['display_name']),
      actorId,
    ]);
  }

  List<String> get zoneIds {
    if (actorType == 'agent') return _strings(operations['zone_ids']);
    if (actorType == 'cabiniste') {
      return _strings(_map(operations['account'])['zone_ids']);
    }
    return _strings(operations['zoneIds']);
  }

  factory TeamMemberDetail.fromMap(Map<String, dynamic> row) {
    return TeamMemberDetail(
      actorType: _string(row['actorType']),
      actorId: _string(row['actorId']),
      profile: _map(row['profile']),
      operations: _map(row['operations']),
      finance: _map(row['finance']),
    );
  }
}

class TeamPerformanceSnapshot {
  const TeamPerformanceSnapshot({
    required this.scope,
    required this.summary,
    required this.agents,
    required this.cabinistes,
    required this.managers,
    required this.managerCompensationPlan,
  });

  const TeamPerformanceSnapshot.empty()
      : scope = const <String, dynamic>{},
        summary = const <String, dynamic>{},
        agents = const <Map<String, dynamic>>[],
        cabinistes = const <Map<String, dynamic>>[],
        managers = const <Map<String, dynamic>>[],
        managerCompensationPlan = const <String, dynamic>{};

  final Map<String, dynamic> scope;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> agents;
  final List<Map<String, dynamic>> cabinistes;
  final List<Map<String, dynamic>> managers;
  final Map<String, dynamic> managerCompensationPlan;

  factory TeamPerformanceSnapshot.fromMap(Map<String, dynamic> row) {
    return TeamPerformanceSnapshot(
      scope: _map(row['scope']),
      summary: _map(row['summary']),
      agents: _maps(row['agents']),
      cabinistes: _maps(row['cabinistes']),
      managers: _maps(row['managers']),
      managerCompensationPlan: _map(row['managerCompensationPlan']),
    );
  }
}

String teamString(Object? value) => _string(value);
int teamInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double teamDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
Map<String, dynamic> teamMap(Object? value) => _map(value);
List<String> teamStrings(Object? value) => _strings(value);

String _firstNonEmpty(List<String> values) {
  for (final String value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _string(Object? value) => value?.toString().trim() ?? '';

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((Object? item) => _string(item))
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}
