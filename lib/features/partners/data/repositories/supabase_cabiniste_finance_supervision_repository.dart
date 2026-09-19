import 'package:cabine_flow/features/partners/domain/models/cabiniste_finance_supervision_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCabinisteFinanceSupervisionRepository {
  SupabaseCabinisteFinanceSupervisionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<CabinisteFinanceSnapshot> fetchSnapshot({String? partnerId}) async {
    final dynamic response = await _client.rpc(
      'izytel_staff_cabiniste_finance_snapshot',
      params: <String, dynamic>{
        'p_partner_id': _nullable(partnerId),
      },
    );
    return CabinisteFinanceSnapshot.fromJson(_map(response));
  }

  Future<CabinisteFinanceHistory> fetchHistory(
    String partnerId, {
    int limit = 50,
  }) async {
    final dynamic response = await _client.rpc(
      'izytel_staff_cabiniste_finance_history',
      params: <String, dynamic>{
        'p_partner_id': partnerId,
        'p_limit': limit,
      },
    );
    return CabinisteFinanceHistory.fromJson(_map(response));
  }

  Future<void> recordPayout({
    required String partnerId,
    required int amount,
    required String paymentChannel,
    required String paymentReference,
    String? note,
    String? periodId,
  }) async {
    await _client.rpc(
      'izytel_admin_record_cabiniste_payout',
      params: <String, dynamic>{
        'p_partner_id': partnerId,
        'p_amount': amount,
        'p_payment_channel': paymentChannel.trim(),
        'p_payment_reference': paymentReference.trim(),
        'p_note': _nullable(note),
        'p_period_id': _nullable(periodId),
      },
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Réponse financière Cabiniste invalide.');
  }

  String? _nullable(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
