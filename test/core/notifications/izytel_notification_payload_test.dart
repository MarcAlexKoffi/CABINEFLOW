import 'package:cabine_flow/core/notifications/izytel_notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalise un payload de commande IzyTel', () {
    final IzyTelNotificationPayload payload =
        IzyTelNotificationPayload.fromMap(<String, dynamic>{
          'type': 'order_assigned',
          'orderId': 'order-123',
          'orderReference': 'CF-20260903-ABC123',
          'route': 'order_detail',
          'title': 'Nouvelle commande',
          'body': 'CF-20260903-ABC123 - MTN - 5000 F',
          'ignoredNull': null,
        });

    expect(payload.type, 'order_assigned');
    expect(payload.orderId, 'order-123');
    expect(payload.orderReference, 'CF-20260903-ABC123');
    expect(payload.route, 'order_detail');
    expect(payload.title, 'Nouvelle commande');
    expect(payload.body, 'CF-20260903-ABC123 - MTN - 5000 F');
    expect(payload.displayMessage, 'CF-20260903-ABC123 - MTN - 5000 F');
    expect(payload.targetsOrder, isTrue);
    expect(payload.rawData.containsKey('ignoredNull'), isFalse);
  });

  test('un payload vide reste exploitable', () {
    final IzyTelNotificationPayload payload =
        IzyTelNotificationPayload.fromMap(<String, dynamic>{});

    expect(payload.type, 'generic');
    expect(payload.targetsOrder, isFalse);
  });
}
