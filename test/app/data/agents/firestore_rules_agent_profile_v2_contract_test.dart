import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil personnel Agent est isolé de son profil opérationnel', () {
    final String rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /agentPersonalProfiles/{agentId}'));
    expect(rules, contains('isValidAgentPersonalProfileCreation(agentId)'));
    expect(rules, contains('isValidAgentPersonalProfileUpdate(agentId)'));
    expect(rules, contains('isValidAgentOwnUserContactUpdate(userId)'));
    expect(rules, contains("'agent_profiles/' + agentId + '/avatar/profile'"));
    expect(
      rules,
      contains("'agent_profiles/' + agentId + '/identity/document'"),
    );
    expect(
      rules,
      contains(
        "request.resource.data.diff(resource.data).affectedKeys().hasOnly([\n          'name',\n          'phoneNumber',\n          'updatedAt'",
      ),
    );
  });

  test('réussite Agent clôture directement sans supprimer le legacy', () {
    final String rules = File('firestore.rules').readAsStringSync();

    final int start = rules.indexOf(
      'function isValidAgentProcessingSuccess(orderId)',
    );
    final int end = rules.indexOf(
      'function isValidAgentProcessingFailure(orderId)',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String successRule = rules.substring(start, end);
    expect(
      successRule,
      contains("request.resource.data.status == 'completed'"),
    );
    expect(
      successRule,
      isNot(
        contains(
          "request.resource.data.status == 'awaitingCustomerConfirmation'",
        ),
      ),
    );
    expect(
      rules,
      contains("order.status in ['completed', 'awaitingCustomerConfirmation']"),
    );
  });

  test('storage privé limite avatar et pièce identité', () {
    final String rules = File('storage.rules').readAsStringSync();

    expect(rules, contains('match /agent_profiles/{agentId}/avatar/profile'));
    expect(
      rules,
      contains('match /agent_profiles/{agentId}/identity/document'),
    );
    expect(rules, contains('request.resource.size <= 5 * 1024 * 1024'));
    expect(rules, contains('request.resource.size <= 10 * 1024 * 1024'));
    expect(
      rules,
      contains("request.resource.contentType == 'application/pdf'"),
    );
    expect(
      rules,
      contains("request.resource.contentType.matches('^image/.*\$')"),
    );
  });
}
