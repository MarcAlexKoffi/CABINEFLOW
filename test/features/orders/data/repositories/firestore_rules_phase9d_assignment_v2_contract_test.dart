import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('9D assignment rule stays narrow and audit-linked', () {
    final File rulesFile = File('firestore.rules');
    expect(rulesFile.existsSync(), isTrue);

    final String rules = rulesFile.readAsStringSync();
    final int start = rules.indexOf(
      'function isValidAdminManualAssignment(orderId)',
    );
    final int end = rules.indexOf(
      'function isValidAgentAssignmentAcceptance(orderId)',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final String assignmentRule = rules.substring(start, end);
    expect(assignmentRule, contains('immutableCoreOrderFieldsAreUnchanged()'));
    expect(
      assignmentRule,
      contains("hasMatchingOrderEvent(orderId, 'ASSIGNED')"),
    );
    expect(assignmentRule, contains("resource.data.status == 'paidReady'"));
    expect(
      assignmentRule,
      contains("resource.data.paymentStatus == 'confirmed'"),
    );
    expect(assignmentRule, contains(".availability == 'available'"));
    expect(assignmentRule, contains('affectedKeys().hasOnly'));
  });

  test('ASSIGNED audit event has a dedicated admin branch', () {
    final String rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('actorRole == staffProfile().role'));
    expect(rules, contains("'ASSIGNED'"));
    expect(rules, contains("actorRole == 'admin'"));
    expect(rules, contains("eventType == 'ASSIGNED'"));
    expect(rules, contains('isAdmin()'));
  });
}
