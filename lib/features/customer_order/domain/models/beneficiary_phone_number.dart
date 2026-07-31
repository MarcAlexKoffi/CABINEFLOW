class BeneficiaryPhoneNumber {
  const BeneficiaryPhoneNumber._({
    required this.normalized,
    required this.localDigits,
  });

  final String normalized;
  final String localDigits;

  static const Set<String> _mobilePrefixes = {'01', '05', '07'};

  factory BeneficiaryPhoneNumber.parse(String input) {
    final String? validationError = validate(input);

    if (validationError != null) {
      throw FormatException(validationError);
    }

    String digits = _digitsOnly(input);

    if (digits.startsWith('00225')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('225')) {
      digits = digits.substring(3);
    }

    return BeneficiaryPhoneNumber._(
      normalized: '+225$digits',
      localDigits: digits,
    );
  }

  static String? validate(
    String? input, {
    String emptyMessage = 'Saisissez le numéro bénéficiaire.',
  }) {
    if (input == null || input.trim().isEmpty) {
      return emptyMessage;
    }

    String digits = _digitsOnly(input);

    if (digits.startsWith('00225')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('225')) {
      digits = digits.substring(3);
    }

    if (digits.length != 10) {
      return 'Le numéro doit contenir 10 chiffres après +225.';
    }

    if (!digits.startsWith('0')) {
      return 'Le numéro ivoirien doit commencer par 0.';
    }

    final String prefix = digits.substring(0, 2);

    if (!_mobilePrefixes.contains(prefix)) {
      return 'Utilisez un numéro mobile commençant par 01, 05 ou 07.';
    }

    return null;
  }

  String get displayValue {
    final List<String> groups = [
      localDigits.substring(0, 2),
      localDigits.substring(2, 4),
      localDigits.substring(4, 6),
      localDigits.substring(6, 8),
      localDigits.substring(8, 10),
    ];

    return '+225 ${groups.join(' ')}';
  }

  static String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  String toString() => normalized;
}
