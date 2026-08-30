import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('11C conserve les sources réelles et la baseline 9E', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /orderEvents/{eventId}'));
    expect(rules, contains('allow get: if isStaff()'));
    expect(rules, contains('allow list: if isStaff()'));
    expect(rules, contains('match /supportRequests/{requestId}'));
    expect(rules, contains('match /refunds/{refundId}'));

    expect(rules, contains("'customerNotifiedBy'"));
    expect(rules, contains("'customerNotifiedByName'"));
    expect(rules, contains("'closedBy'"));
    expect(rules, contains("'closedByName'"));
    expect(
      rules,
      contains(
        "request.resource.data.get('customerNotifiedBy', null) == request.auth.uid",
      ),
    );
    expect(
      rules,
      contains(
        "request.resource.data.get('closedBy', null) == request.auth.uid",
      ),
    );

    // Phase 13A ajoute un getAfter unidirectionnel sans toucher au moteur 9E.
    expect(RegExp(r'getAfter\(').allMatches(rules), hasLength(25));
    expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
    expect(rules, contains('autoAssignmentRefusedAgentIds'));
    expect(rules, contains('manualAssignmentRequired'));
  });
}
