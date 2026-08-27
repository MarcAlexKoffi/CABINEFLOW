import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles 10D ajoutent supportRequests sans casser 9E/10B', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /supportRequests/{requestId}'));
    expect(rules, contains('isValidCustomerSupportRequestCreation'));
    expect(rules, contains('customerCanRequestSupportForOrder'));
    expect(
      rules,
      contains(r'orderRecoveryAccess/$(orderId)/customers/$(request.auth.uid)'),
    );
    expect(rules, contains("'paymentNotRecognized'"));
    expect(rules, contains("'completedButNotReceived'"));
    expect(rules, contains("'wrongAmount'"));
    expect(rules, contains("'wrongNumber'"));
    expect(rules, contains("'transactionFailed'"));
    expect(rules, contains("request.resource.data.status == 'new'"));
    expect(rules, contains('allow list: if isStaff();'));
    expect(rules, contains('allow update, delete: if false;'));

    // Baseline 9E V2 : aucune nouvelle dépendance getAfter n'est introduite.
    expect(RegExp(r'getAfter\(').allMatches(rules), hasLength(21));
    expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
    expect(rules, contains('autoAssignmentRefusedAgentIds'));
    expect(rules, contains('manualAssignmentRequired'));
    expect(rules, contains('match /orderRecoveryKeys/{recoveryKey}'));
  });
}
