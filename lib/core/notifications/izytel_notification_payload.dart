class IzyTelNotificationPayload {
  const IzyTelNotificationPayload({
    required this.type,
    this.title,
    this.body,
    this.orderId,
    this.orderReference,
    this.route,
    this.issueId,
    this.supportRequestId,
    this.conversationId,
    this.zoneId,
    this.rawData = const <String, String>{},
  });

  final String type;
  final String? title;
  final String? body;
  final String? orderId;
  final String? orderReference;
  final String? route;
  final String? issueId;
  final String? supportRequestId;
  final String? conversationId;
  final String? zoneId;
  final Map<String, String> rawData;

  bool get targetsOrder => orderId != null || orderReference != null;

  bool get targetsConversation =>
      conversationId != null || route == 'customer_messaging';

  String get displayMessage =>
      body ?? title ?? 'Nouvelle notification IzyTel.';

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
      title: valueOf('title'),
      body: valueOf('body'),
      orderId: valueOf('orderId'),
      orderReference: valueOf('orderReference'),
      route: valueOf('route'),
      issueId: valueOf('issueId'),
      supportRequestId: valueOf('supportRequestId'),
      conversationId: valueOf('conversationId'),
      zoneId: valueOf('zoneId'),
      rawData: Map<String, String>.unmodifiable(normalizedData),
    );
  }
}
