class WavePaymentLinkBuilder {
  const WavePaymentLinkBuilder({
    this.merchantId = 'M_vv7V2SMbMiki',
    this.countryCode = 'ci',
  });

  final String merchantId;
  final String countryCode;

  Uri build({
    required int amount,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Le montant doit être supérieur à zéro.',
      );
    }

    return Uri.https(
      'pay.wave.com',
      '/m/$merchantId/c/$countryCode/',
      <String, String>{
        'amount': amount.toString(),
      },
    );
  }
}