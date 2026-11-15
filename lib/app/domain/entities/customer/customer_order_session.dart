class CustomerOrderSession {
  const CustomerOrderSession({
    required this.orderId,
    required this.reference,
    this.recoveryCode,
    this.whatsappPhone,
  });

  final String orderId;
  final String reference;
  final String? recoveryCode;
  final String? whatsappPhone;

  bool get hasRecoveryCode => (recoveryCode ?? '').trim().isNotEmpty;

  Map<String, String> toMap() {
    return <String, String>{
      'orderId': orderId,
      'reference': reference,
      if ((recoveryCode ?? '').trim().isNotEmpty)
        'recoveryCode': recoveryCode!.trim(),
      if ((whatsappPhone ?? '').trim().isNotEmpty)
        'whatsappPhone': whatsappPhone!.trim(),
    };
  }

  factory CustomerOrderSession.fromMap(Map<String, dynamic> data) {
    final String orderId = (data['orderId'] as String? ?? '').trim();
    final String reference = (data['reference'] as String? ?? '').trim();
    final String recoveryCode = (data['recoveryCode'] as String? ?? '').trim();
    final String whatsappPhone = (data['whatsappPhone'] as String? ?? '')
        .trim();

    if (orderId.isEmpty ||
        reference.isEmpty ||
        (recoveryCode.isEmpty && whatsappPhone.isEmpty)) {
      throw const FormatException('Session de commande locale invalide.');
    }

    return CustomerOrderSession(
      orderId: orderId,
      reference: reference,
      recoveryCode: recoveryCode.isEmpty ? null : recoveryCode,
      whatsappPhone: whatsappPhone.isEmpty ? null : whatsappPhone,
    );
  }
}
