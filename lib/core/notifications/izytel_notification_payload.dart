class IzyTelNotificationPayload {
  const IzyTelNotificationPayload({
    required this.type,
    this.orderId,
    this.orderReference,
    this.route,
    this.issueId,
    this.supportRequestId,
    this.rawData = const <String, String>{},
  });

  final String type;
  final String? orderId;
  final String? orderReference;
  final String? route;
  final String? issueId;
  final String? supportRequestId;
  final Map<String, String> rawData;

  bool get targetsOrder => orderId != null || orderReference != null;

  static IzyTelNotificationPayload fromMap(Map<String, dynamic> data) {
    String? valueOf(String key) {
      final Object? value = data[key];
      if (value == null) return null;
      final String normalized = value.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }

    final Map<String, String> normalizedData = <String, String>{};
    for (final MapEntry<String, dynamic> entry in data.entries) {
      if (entry.value == null) continue;
      normalizedData[entry.key] = entry.value.toString();
    }

    return IzyTelNotificationPayload(
      type: valueOf('type') ?? 'generic',
      orderId: valueOf('orderId'),
      orderReference: valueOf('orderReference'),
      route: valueOf('route'),
      issueId: valueOf('issueId'),
      supportRequestId: valueOf('supportRequestId'),
      rawData: Map<String, String>.unmodifiable(normalizedData),
    );
  }
}
