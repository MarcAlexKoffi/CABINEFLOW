import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

class CustomerIdentity {
  const CustomerIdentity({
    required this.name,
    required this.whatsappNumber,
  });

  final String name;
  final WhatsappPhoneNumber whatsappNumber;
}
