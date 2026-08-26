import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles locales contiennent le contrat de sécurité Phase 9D', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /orderEvents/{eventId}'));
    expect(rules, contains('isValidAgentProofAuditUpdate(orderId)'));
    expect(
      rules,
      contains("hasMatchingOrderEvent(orderId, 'ASSIGNMENT_ACCEPTED')"),
    );
    expect(
      rules,
      contains("hasMatchingOrderEvent(orderId, 'PROCESSING_STARTED')"),
    );
    expect(
      rules,
      contains("hasMatchingOrderEvent(orderId, 'PROCESSING_SUCCEEDED')"),
    );
    expect(
      rules,
      contains("hasMatchingOrderEvent(orderId, 'PROCESSING_FAILED')"),
    );
    expect(
      rules,
      contains(
        "resource.data.get('assignedAgentId', null) == request.auth.uid",
      ),
    );
    expect(rules, isNot(contains('request.resource.data.service')));
    expect(rules, isNot(contains('resource.data.service')));
    expect(rules, contains('isValidStaffPaymentConfirmation'));
    expect(
      rules,
      contains("hasMatchingOrderEvent(orderId, 'PAYMENT_CONFIRMED')"),
    );
    expect(rules, contains('targetAgentUser('));
    expect(rules, contains('targetAgentProfile('));
    expect(rules, contains('getAfter('));
    expect(rules, contains("hasMatchingOrderEvent(orderId, 'ASSIGNED')"));
    expect(rules, contains("actorRole == 'customer'"));
    expect(rules, contains("actorRole == 'agent'"));
  });
}
