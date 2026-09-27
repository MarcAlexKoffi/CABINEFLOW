import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles support ajoutent le traitement Admin sans casser 9E/10B', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /supportRequests/{requestId}'));
    expect(rules, contains('isValidCustomerSupportRequestCreation'));
    expect(rules, contains('customerCanRequestSupportForOrder'));
    expect(rules, contains('isValidAdminSupportRequestUpdate'));
    expect(rules, contains('isValidSupportRequestTakeInCharge'));
    expect(rules, contains('isValidSupportRequestResolution'));
    expect(rules, contains('isValidSupportRequestCustomerNotification'));
    expect(rules, contains('isValidSupportRequestClosure'));
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
    expect(rules, contains("request.resource.data.status == 'inProgress'"));
    expect(rules, contains("request.resource.data.status == 'resolved'"));
    expect(rules, contains("request.resource.data.status == 'closed'"));
    expect(
      rules,
      contains(
        "request.resource.data.get('notificationChannel', null) == 'whatsapp'",
      ),
    );
    expect(rules, contains('allow list: if isStaff();'));
    expect(
      rules,
      contains('allow update: if isValidAdminSupportRequestUpdate();'),
    );
    expect(rules, contains('allow delete: if false;'));

    // Phase 13A ajoute un getAfter unidirectionnel networkTransaction -> order.
    expect(
      RegExp(r'getAfter\(').allMatches(rules).length,
      greaterThanOrEqualTo(25),
    );
    expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
    expect(rules, contains('autoAssignmentRefusedAgentIds'));
    expect(rules, contains('manualAssignmentRequired'));
    expect(rules, contains('match /orderRecoveryKeys/{recoveryKey}'));
  });
}
