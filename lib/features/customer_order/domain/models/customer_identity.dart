import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

/// Identite legere du client IzyTel.
///
/// Le parcours actif ne demande plus de numero WhatsApp. Le champ optionnel
/// reste uniquement pour relire les anciennes commandes creees avant le retrait
/// de ce canal de communication.
class CustomerIdentity {
  const CustomerIdentity({required this.name, this.whatsappNumber});

  final String name;

  @Deprecated('Compatibilite historique uniquement. Ne pas utiliser pour communiquer.')
  final WhatsappPhoneNumber? whatsappNumber;
}
