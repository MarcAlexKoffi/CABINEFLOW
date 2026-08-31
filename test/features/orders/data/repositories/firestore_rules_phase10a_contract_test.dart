import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles Phase 10A isolent strictement customerProfiles', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /customerProfiles/{profileId}'));
    expect(rules, contains('hasValidCustomerProfileValues(profileId)'));
    expect(rules, contains('isValidCustomerProfileCreation(profileId)'));
    expect(rules, contains('isValidCustomerProfileUpdate(profileId)'));
    expect(
      rules,
      contains('allow get: if isSignedIn() && request.auth.uid == profileId;'),
    );
    expect(rules, contains('allow list: if false;'));
    expect(rules, contains("'defaultBeneficiaryPhone'"));
    expect(rules, contains("'^[+]225(01|05|07)[0-9]{8}\$'"));
  });

  test('la baseline 9E reste présente avec ses artefacts unidirectionnels', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(
      rules,
      contains('PHASE 9E AUTO ASSIGNMENT FIX V2 - artefacts unidirectionnels'),
    );
    expect(rules, contains('match /autoAssignmentQueue/{orderId}'));
    expect(rules, isNot(contains('isValidAgentAutomaticSelfAssignment')));
    expect(rules, contains('isValidStaffAutomaticAssignment'));
    expect(rules, contains('isValidAutomaticAssignmentEventCreation'));
  });
}
