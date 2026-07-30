class PaymentLinkData {
  const PaymentLinkData({
    required this.uri,
    required this.merchantDisplayName,
  });

  final Uri uri;
  final String merchantDisplayName;

  String get url {
    return uri.toString();
  }
}