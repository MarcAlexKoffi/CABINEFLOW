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
    this.validForMs,
  });
  final String status, reason;
  final UssdRule? rule;
  final String? code, attemptId;
  final Map<String, dynamic> context;
  final bool mismatch;
  final int? validForMs;
  bool get available => status == 'available' && rule != null && code != null;
  factory UssdResolution.fromJson(Map<String, dynamic> row) {
    final result = UssdResolution(
      status: row['status'] as String? ?? 'unavailable',
      reason: row['reason'] as String? ?? 'unavailable',
      rule: row['rule'] is Map
          ? UssdRule.fromJson(Map<String, dynamic>.from(row['rule'] as Map))
          : null,
      code: row['code'] as String?,
      context: Map<String, dynamic>.from(row['context'] as Map? ?? const {}),
      mismatch: row['network_mismatch'] == true,
      attemptId: row['attempt_id'] as String?,
      validForMs: (row['valid_for_ms'] as num?)?.toInt(),
    );
    if (result.status == 'available') {
      if (!result.available ||
          result.rule!.status != 'active' ||
          result.rule!.purpose != 'order') {
        throw const FormatException('invalid_ussd_resolution');
      }
      UssdEngine.validateCode(result.code!);
      for (final key in ['network', 'service', 'offer_label', 'beneficiary']) {
        final value = result.context[key];
        if (value != null && value is! String) {
          throw const FormatException('invalid_ussd_context');
        }
      }
    }
    return result;
  }
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
  Future<void> deleteRule(UssdRule rule);
  Future<void> saveFamily(String network, String service, String label);
  Future<void> deleteFamily(String familyId);
  Future<void> deleteBinding(String offerId, int version);
  Future<void> saveBinding(
    String offerId,
    String? familyId,
    String? offerCode,
    int? quantity,
  );
  Future<List<Map<String, dynamic>>> history(String ruleId);
  Future<List<Map<String, dynamic>>> bindingHistory(String offerId);
  Future<List<Map<String, dynamic>>> logs({int offset = 0});
  Future<List<Map<String, dynamic>>> reports({int offset = 0});
  Future<void> reviewReport(String id, String status, String note);
}
