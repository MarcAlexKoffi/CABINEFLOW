import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles 13A protègent le journal réseau', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /networkTransactions/{transactionId}'));
    expect(rules, contains('hasValidNetworkTransactionValues'));
    expect(rules, contains('isValidAgentOrderNetworkTransactionCreation'));
    expect(rules, contains("request.resource.data.type == 'orderSuccess'"));
    expect(rules, contains("request.resource.data.direction == 'outgoing'"));
    expect(rules, contains("transactionId == 'order_' + orderId"));
    expect(rules, contains("order.status == 'awaitingCustomerConfirmation'"));
    expect(
      rules,
      contains("order.get('lastEventType', null) == 'PROCESSING_SUCCEEDED'"),
    );
    expect(rules, contains('allow get, list: if isAdmin();'));
    expect(rules, contains('allow update, delete: if false;'));
  });
}
