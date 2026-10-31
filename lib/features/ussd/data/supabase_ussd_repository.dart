import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

UssdRepository createUssdRepository() => SupabaseUssdRepository(
  client: SupabaseBootstrap.isInitialized ? Supabase.instance.client : null,
);

class SupabaseUssdRepository implements UssdRepository {
  SupabaseUssdRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  static const timeout = Duration(seconds: 12);

  Future<dynamic> _rpc(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    final client = _client;
    if (client == null) throw const UssdValidationException('unavailable');
    // Do not retry writes: a timeout may follow a successful server commit.
    return await client.rpc(name, params: params).timeout(timeout);
  }

  Map<String, dynamic> _map(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);
  List<Map<String, dynamic>> _list(dynamic raw) =>
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<UssdResolution> resolve(String orderId) async =>
      UssdResolution.fromJson(
        _map(await _rpc('izytel_ussd_resolve', {'p_order_id': orderId})),
      );
  @override
  Future<UssdResolution> prepare(
    String orderId,
    UssdResolution confirmed,
    String requestId,
  ) async => UssdResolution.fromJson(
    _map(
      await _rpc('izytel_ussd_prepare', {
        'p_order_id': orderId,
        'p_rule_id': confirmed.rule!.id,
        'p_version': confirmed.rule!.version,
        'p_context': confirmed.context,
        'p_request_id': requestId,
      }),
    ),
  );
  @override
  Future<void> recordResult(
    String attemptId,
    String status,
    String? errorCode,
  ) async {
    await _rpc('izytel_ussd_record_result', {
      'p_attempt_id': attemptId,
      'p_status': status,
      'p_error_code': errorCode,
    });
  }

  @override
  Future<void> report(
    String orderId,
    UssdResolution? resolution,
    String reason,
    String note,
  ) async {
    await _rpc('izytel_ussd_report', {
      'p_order_id': orderId,
      'p_rule_id': resolution?.rule?.id,
      'p_version': resolution?.rule?.version,
      'p_reason': reason,
      'p_note': note,
    });
  }

  @override
  Future<Map<String, dynamic>> configuration() async =>
      _map(await _rpc('izytel_ussd_configuration'));
  @override
  Future<void> saveRule(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  }) async {
    await _rpc('izytel_ussd_save_rule', {
      'p_rule_id': id,
      'p_expected_version': version,
      'p_payload': payload,
    });
  }

  @override
  Future<void> setStatus(
    UssdRule rule,
    String status, {
    String? simType,
  }) async {
    await _rpc('izytel_ussd_set_status', {
      'p_rule_id': rule.id,
      'p_expected_version': rule.version,
      'p_status': status,
      'p_sim_type': simType,
    });
  }

  @override
  Future<void> saveFamily(String network, String service, String label) async {
    await _rpc('izytel_ussd_save_family', {
      'p_network': network,
      'p_service': service,
      'p_label': label,
    });
  }

  @override
  Future<void> saveBinding(
    String offerId,
    String? familyId,
    String? offerCode,
    int? quantity,
  ) async {
    await _rpc('izytel_ussd_save_binding', {
      'p_offer_id': offerId,
      'p_family_id': familyId,
      'p_offer_code': offerCode,
      'p_quantity': quantity,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> history(String ruleId) async =>
      _list(await _rpc('izytel_ussd_history', {'p_rule_id': ruleId}));
  @override
  Future<List<Map<String, dynamic>>> bindingHistory(String offerId) async =>
      _list(await _rpc('izytel_ussd_binding_history', {'p_offer_id': offerId}));
  @override
  Future<List<Map<String, dynamic>>> logs({int offset = 0}) async =>
      _list(await _rpc('izytel_ussd_logs', {'p_offset': offset}));
  @override
  Future<List<Map<String, dynamic>>> reports({int offset = 0}) async =>
      _list(await _rpc('izytel_ussd_reports', {'p_offset': offset}));
  @override
  Future<void> reviewReport(String id, String status, String note) async {
    await _rpc('izytel_ussd_review_report', {
      'p_report_id': id,
      'p_status': status,
      'p_note': note,
    });
  }
}
