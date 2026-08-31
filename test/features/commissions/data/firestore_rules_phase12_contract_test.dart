import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles Phase 12 protègent commissions, comptes et paiements', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /commissions/{commissionId}'));
    expect(rules, contains('match /commissionAccounts/{accountId}'));
    expect(rules, contains('match /commissionPayouts/{payoutId}'));
    expect(rules, contains('isValidAgentCommissionCreation'));
    expect(rules, contains('commissionForAccountRequest'));
    expect(rules, contains('commissionMatchesAccountRequest'));
    expect(
      rules,
      contains('resource.data.earnedTotal + commission.commissionAmount'),
    );
    expect(rules, contains('isValidAdminCommissionAccountPayoutUpdate'));
    expect(rules, contains("request.resource.data.commissionAmount == 10"));
    expect(rules, contains("request.resource.data.policyId == 'fixed-10-v1'"));
    expect(rules, contains("order.status == 'awaitingCustomerConfirmation'"));
    expect(
      rules,
      contains("order.get('lastEventType', null) == 'PROCESSING_SUCCEEDED'"),
    );
    expect(rules, contains("request.resource.data.paymentChannel == 'wave'"));
    expect(rules, contains("payoutId.matches('^wave_[A-Za-z0-9_-]+\$')"));
    expect(rules, contains('request.resource.data.amount'));
    expect(rules, contains('account.earnedTotal - account.paidTotal'));

    // Phase 13A ajoute un getAfter unidirectionnel networkTransaction -> order.
    // Aucun cycle de validation n'est ajouté au flux Phase 12.
    expect(
      RegExp(r'getAfter\(').allMatches(rules).length,
      greaterThanOrEqualTo(25),
    );

    // Les garde-fous 9E restent présents.
    expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
    expect(rules, contains('manualAssignmentRequired'));
    expect(rules, contains('autoAssignmentRefusedAgentIds'));
  });

  test('un agent ne peut lister que ses propres traces de performance', () {
    final String rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("resource.data.actorId == request.auth.uid"));
    expect(rules, contains("resource.data.agentId == request.auth.uid"));
  });
}
