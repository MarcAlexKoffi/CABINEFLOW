import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';

class PaymentDeclaration {
  const PaymentDeclaration({
    required this.waveAccountName,
    required this.wavePayerPhone,
    required this.approximatePaymentTime,
    this.declaredWaveReference,
  });

  final String waveAccountName;
  final WhatsappPhoneNumber wavePayerPhone;
  final String approximatePaymentTime;
  final String? declaredWaveReference;

  factory PaymentDeclaration.parse({
    required String waveAccountName,
    required String wavePayerPhoneInput,
    required String approximatePaymentTime,
    String? declaredWaveReference,
  }) {
    final String cleanedName = waveAccountName.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (cleanedName.length < 2) {
      throw const FormatException(
        'Saisissez le nom affiché sur le compte Wave.',
      );
    }

    if (cleanedName.length > 80) {
      throw const FormatException(
        'Le nom du compte Wave ne doit pas dépasser 80 caractères.',
      );
    }

    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(
      approximatePaymentTime,
    )) {
      throw const FormatException(
        'Sélectionnez une heure approximative valide.',
      );
    }

    final String? cleanedReference = _cleanOptionalReference(
      declaredWaveReference,
    );

    late final WhatsappPhoneNumber payerPhone;

    try {
      payerPhone = WhatsappPhoneNumber.parse(wavePayerPhoneInput);
    } on FormatException catch (error) {
      throw FormatException(
        error.message.toString().replaceAll(
          'votre numéro WhatsApp',
          'le numéro Wave',
        ),
      );
    }

    return PaymentDeclaration(
      waveAccountName: cleanedName,
      wavePayerPhone: payerPhone,
      approximatePaymentTime: approximatePaymentTime,
      declaredWaveReference: cleanedReference,
    );
  }

  static String? _cleanOptionalReference(String? value) {
    final String cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return null;
    }

    if (cleaned.length > 80) {
      throw const FormatException(
        'La référence Wave ne doit pas dépasser 80 caractères.',
      );
    }

    return cleaned;
  }
}
