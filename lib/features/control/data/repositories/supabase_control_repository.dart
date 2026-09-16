import 'package:cabine_flow/features/control/domain/models/control_snapshot.dart';
import 'package:cabine_flow/features/control/domain/repositories/control_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseControlRepository implements ControlRepository {
  SupabaseControlRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<ControlSnapshot> fetchSnapshot() async {
    final dynamic response = await _client.rpc('izytel_bo6_control_snapshot');
    if (response is! Map) {
      throw StateError('Le snapshot Contrôle / Pilotage Supabase est invalide.');
    }
    final Map<String, dynamic> json = response.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
    return ControlSnapshot.fromJson(json);
  }
}
