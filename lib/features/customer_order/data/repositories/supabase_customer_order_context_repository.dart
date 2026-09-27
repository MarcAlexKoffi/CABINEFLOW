import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_context_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCustomerOrderContextRepository
    implements CustomerOrderContextRepository {
  SupabaseCustomerOrderContextRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> registerContext({
    required CustomerOrderReceipt order,
    required CustomerOrderContextDraft context,
  }) async {
    await _client.rpc(
      'izytel_wc4_register_customer_context',
      params: <String, dynamic>{
        'p_order_id': order.id,
        'p_order_reference': order.reference,
        'p_source_code': context.sourceCode,
        'p_location_status': context.locationStatus.name,
        'p_latitude': context.latitude,
        'p_longitude': context.longitude,
        'p_accuracy_meters': context.accuracyMeters,
        'p_location_captured_at': context.locationCapturedAt?.toUtc().toIso8601String(),
      },
    );
  }
}
