import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles Phase 9E contiennent le circuit automatique sécurisé', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /autoAssignmentQueue/{orderId}'));
    expect(rules, contains('isValidStaffAutomaticAssignment'));
    expect(rules, contains('allow delete: if isStaff();'));
    expect(rules, isNot(contains('isValidAgentAutomaticSelfAssignment')));
    expect(
      rules,
      contains(
        "request.resource.data.get('assignmentMode', null) == 'automatic'",
      ),
    );
    expect(rules, contains("lastAssignmentRefusedAgentId"));
    expect(rules, contains('isValidManualAssignmentEventCreation'));
    expect(rules, contains('isValidAutomaticAssignmentEventCreation'));
    expect(rules, contains('isValidAgentQueueRecreationAfterRefusal'));
    expect(rules, isNot(contains('isValidAgentAutomaticQueueDelete')));
    expect(rules, contains('isValidCustomerOrderCreation'));
    expect(rules, contains('isValidCustomerPaymentDeclaration'));
    expect(rules, contains("'ASSIGNED'"));
    expect(rules, isNot(contains('.service')));
  });
}
