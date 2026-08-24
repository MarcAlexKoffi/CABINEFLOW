class CustomerOrderSession {
  const CustomerOrderSession({
    required this.orderId,
    required this.reference,
    required this.whatsappPhone,
  });

  final String orderId;
  final String reference;
  final String whatsappPhone;

  Map<String, String> toMap() {
    return <String, String>{
      'orderId': orderId,
      'reference': reference,
      'whatsappPhone': whatsappPhone,
    };
  }

  factory CustomerOrderSession.fromMap(Map<String, dynamic> data) {
    final String orderId = (data['orderId'] as String? ?? '').trim();
    final String reference = (data['reference'] as String? ?? '').trim();
    final String whatsappPhone = (data['whatsappPhone'] as String? ?? '')
        .trim();

    if (orderId.isEmpty || reference.isEmpty || whatsappPhone.isEmpty) {
      throw const FormatException('Session de commande locale invalide.');
    }

    return CustomerOrderSession(
      orderId: orderId,
      reference: reference,
      whatsappPhone: whatsappPhone,
    );
  }
}
