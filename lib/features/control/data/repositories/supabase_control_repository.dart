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

    // BO-7.1 : la série temporelle est isolée dans un RPC additif pour ne pas
    // remplacer le snapshot BO-6 déjà validé en production. Si une ancienne
    // préproduction ne possède pas encore ce RPC, le contrôle BO-6 reste
    // utilisable et la zone graphique affiche simplement un état vide.
    try {
      final dynamic trend = await _client.rpc(
        'izytel_bo7_daily_trend',
        params: const <String, dynamic>{'p_days': 30},
      );
      if (trend is List) {
        json['daily_trend'] = trend;
      } else if (trend is Map && trend['daily_trend'] is List) {
        json['daily_trend'] = trend['daily_trend'];
      }
    } on PostgrestException {
      json['daily_trend'] = const <dynamic>[];
    }

    return ControlSnapshot.fromJson(json);
  }
}
