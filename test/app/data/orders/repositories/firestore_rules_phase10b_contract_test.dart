import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les règles 10B isolent la récupération à une commande exacte', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /orderRecoveryKeys/{recoveryKey}'));
    expect(
      rules,
      contains('match /orderRecoveryAccess/{orderId}/customers/{customerUid}'),
    );
    expect(rules, contains('hasRecoveredOrderAccess(orderId)'));
    expect(rules, contains('isValidOrderRecoveryKeyCreation(recoveryKey)'));
    expect(
      rules,
      contains('isValidRecoveredOrderAccessCreation(orderId, customerUid)'),
    );
    expect(rules, contains('allow list: if false;'));
    expect(
      rules,
      contains(
        "request.resource.data.orderReference + '_' + request.resource.data.whatsappPhone",
      ),
    );
  });

  test(
    'le fallback 9E mémorise tous les refus et stoppe la boucle automatique',
    () {
      final String rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains("'autoAssignmentRefusedAgentIds'"));
      expect(rules, contains("'manualAssignmentRequired'"));
      expect(rules, contains("'refusedAgentIds'"));
      expect(rules, contains('isValidStaffManualAssignmentFallback()'));
      expect(
        rules,
        contains(
          "!(agentId in resource.data.get('autoAssignmentRefusedAgentIds', []))",
        ),
      );
      expect(
        rules,
        contains(
          "resource.data.get('manualAssignmentRequired', false) == false",
        ),
      );
    },
  );

  test('la baseline 9E unidirectionnelle reste présente', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(
      rules,
      contains('PHASE 9E AUTO ASSIGNMENT FIX V2 - artefacts unidirectionnels'),
    );
    expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
    expect(rules, contains('match /autoAssignmentQueue/{orderId}'));
  });
}
