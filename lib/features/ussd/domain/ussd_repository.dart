import 'ussd_engine.dart';

class UssdResolution {
  const UssdResolution({
    required this.status,
    required this.reason,
    this.rule,
    this.code,
    this.context = const {},
    this.mismatch = false,
    this.attemptId,
  });
  final String status, reason;
  final UssdRule? rule;
  final String? code, attemptId;
  final Map<String, dynamic> context;
  final bool mismatch;
  bool get available => status == 'available' && rule != null && code != null;
  factory UssdResolution.fromJson(Map<String, dynamic> row) => UssdResolution(
    status: row['status'] as String? ?? 'unavailable',
    reason: row['reason'] as String? ?? 'unavailable',
    rule: row['rule'] is Map
        ? UssdRule.fromJson(Map<String, dynamic>.from(row['rule'] as Map))
        : null,
    code: row['code'] as String?,
    context: Map<String, dynamic>.from(row['context'] as Map? ?? const {}),
    mismatch: row['network_mismatch'] == true,
    attemptId: row['attempt_id'] as String?,
  );
}

abstract class UssdRepository {
  Future<UssdResolution> resolve(String orderId);
  Future<UssdResolution> prepare(
    String orderId,
    UssdResolution confirmed,
    String requestId,
  );
  Future<void> recordResult(String attemptId, String status, String? errorCode);
  Future<void> report(
    String orderId,
    UssdResolution? resolution,
    String reason,
    String note,
  );
  Future<Map<String, dynamic>> configuration();
  Future<void> saveRule(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  });
  Future<void> setStatus(UssdRule rule, String status, {String? simType});
  Future<void> saveFamily(String network, String service, String label);
  Future<void> saveBinding(
    String offerId,
    String? familyId,
    String? offerCode,
    int? quantity,
  );
  Future<List<Map<String, dynamic>>> history(String ruleId);
  Future<List<Map<String, dynamic>>> logs({int offset = 0});
  Future<List<Map<String, dynamic>>> reports({int offset = 0});
  Future<void> reviewReport(String id, String status, String note);
}
