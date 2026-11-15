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
      'function automaticAssignmentTargetIsEligible(agentId)',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final String assignmentRule = rules.substring(start, end);
    // La transition manuelle reste strictement bornée par le diff et les
    // contrôles de l'agent cible, sans réintroduire la lecture croisée
    // order -> orderEvents qui a déjà provoqué des permission-denied.
    expect(assignmentRule, contains('affectedKeys().hasOnly'));
    expect(assignmentRule, contains("lastEventType', null) == 'ASSIGNED'"));
    expect(assignmentRule, contains("lastEventId', '').size() >= 8"));
    expect(
      assignmentRule,
      isNot(contains("hasMatchingOrderEvent(orderId, 'ASSIGNED')")),
    );
    expect(
      assignmentRule,
      isNot(contains('immutableCoreOrderFieldsAreUnchanged()')),
    );
    expect(assignmentRule, contains("resource.data.status == 'paidReady'"));
    expect(
      assignmentRule,
      contains('paymentStatusAllowsProcessing(resource.data.paymentStatus)'),
    );
    expect(assignmentRule, contains(".availability == 'available'"));
    expect(
      assignmentRule,
      contains("agentProfile.availability == 'available'"),
    );
  });

  test(
    'ASSIGNED audit event est validé par une branche dédiée sans boucle',
    () {
      final String rules = File('firestore.rules').readAsStringSync();
      expect(rules, contains('function isValidAssignedOrderEventCreation()'));
      expect(rules, contains("request.resource.data.type == 'ASSIGNED'"));
      expect(rules, contains('&& isValidAssignedOrderEventCreation()'));
      expect(
        rules,
        contains('request.resource.data.actorRole == staffProfile().role'),
      );
      expect(rules, contains("'operator',"));
      expect(rules, contains("'supervisor',"));
      expect(rules, contains("'admin'"));
    },
  );
}
