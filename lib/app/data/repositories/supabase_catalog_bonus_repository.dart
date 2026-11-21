import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_bonus_repository.dart';

class SupabaseCatalogBonusRepository implements CatalogBonusRepository {
  SupabaseCatalogBonusRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  Future<dynamic> _rpc(String name, [Map<String, dynamic> params = const {}]) =>
      _client.rpc(name, params: params).timeout(const Duration(seconds: 15));
  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  @override
  Future<List<Map<String, dynamic>>> campaigns() async =>
      _rows(await _rpc('izytel_bonus_campaigns'));
  @override
  Future<void> saveCampaign(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  }) async {
    await _rpc('izytel_bonus_save', {
      'p_id': id,
      'p_expected_version': version,
      'p_payload': payload,
    });
  }

  @override
  Future<void> campaignStatus(
    Map<String, dynamic> campaign,
    String status, {
    String? reference,
  }) async {
    await _rpc('izytel_bonus_set_status', {
      'p_id': campaign['id'],
      'p_expected_version': campaign['version'],
      'p_status': status,
      'p_reference': reference,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> routes() async =>
      _rows(await _rpc('izytel_catalog_subscription_routes'));
  @override
  Future<void> validateRoute(
    Map<String, dynamic> route, {
    String? operatorReference,
  }) async {
    await _rpc('izytel_catalog_validate_subscription_route', {
      'p_rule_id': route['id'],
      'p_expected_version': route['version'],
      'p_operator_reference': operatorReference,
    });
  }
}
