import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Envoie une notification operationnelle au client dans la messagerie IzyTel.
///
/// Aucun numero de telephone n'est utilise : l'ordre et son UID client sont
/// resolus cote Supabase, puis le message systeme est route dans la zone de la
/// commande.
class CustomerMessagingDeliveryService {
  CustomerMessagingDeliveryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Notification de succes strictement systeme. Le texte est construit
  /// cote Supabase : un Agent/Cabiniste ne peut donc pas ecrire librement au
  /// client, meme lorsqu'un ancien parcours Flutter termine la commande dans
  /// Firestore avant la synchronisation operationnelle.
  Future<void> notifyCompletedOrder({
    required String orderId,
    required String orderReference,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('La messagerie IzyTel est temporairement indisponible.');
    }
    await _client.rpc(
      'izytel_wc5_notify_completed_order',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_order_reference': orderReference.trim().toUpperCase(),
      },
    );
  }

  Future<void> notifyOrder({
    required String orderId,
    required String orderReference,
    required String message,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('La messagerie IzyTel est temporairement indisponible.');
    }
    final String body = message.trim();
    if (body.isEmpty || body.length > 2000) {
      throw ArgumentError('Le message client est invalide.');
    }

    await _client.rpc(
      'izytel_wc3_notify_customer_order',
      params: <String, dynamic>{
        'p_order_id': orderId.trim(),
        'p_order_reference': orderReference.trim().toUpperCase(),
        'p_body': body,
      },
    );
  }
}
