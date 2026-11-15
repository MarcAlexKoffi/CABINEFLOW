import 'package:supabase_flutter/supabase_flutter.dart';

/// Historique client WC2 canonique Supabase.
///
/// La RPC ne renvoie que les commandes appartenant a l'UID Firebase courant
/// ou celles auxquelles cet UID a obtenu un acces via reference + code de
/// recuperation. Aucun secret de recuperation n'est expose par cette lecture.
class SupabaseCustomerOrderHistoryRepository {
  SupabaseCustomerOrderHistoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const Duration pollInterval = Duration(seconds: 3);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetch() async {
    final Object? raw = await _client.rpc('izytel_wc2_customer_order_history');

    if (raw == null) {
      return const <Map<String, dynamic>>[];
    }

    if (raw is! List) {
      throw StateError('Historique client Supabase invalide.');
    }

    return raw.map<Map<String, dynamic>>((Object? item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      throw StateError('Entree d historique client Supabase invalide.');
    }).toList(growable: false);
  }
}
