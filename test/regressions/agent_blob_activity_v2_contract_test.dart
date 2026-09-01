import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('B2 stocke avatar et pièce en Blob Firestore sans Firebase Storage', () {
    final String mediaRepository = _read(
      'lib/features/agents/data/repositories/'
      'firestore_agent_personal_media_repository.dart',
    );
    final String profilePage = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );

    expect(mediaRepository, contains('Blob(media.bytes)'));
    expect(mediaRepository, contains('avatarMaxBytes = 250000'));
    expect(mediaRepository, contains('identityMaxBytes = 850000'));
    expect(mediaRepository, contains("mimeType: 'application/pdf'"));
    expect(mediaRepository, contains('bytes[0] == 0x25'));
    expect(mediaRepository, contains('bytes[1] == 0x50'));
    expect(mediaRepository, contains('bytes[2] == 0x44'));
    expect(mediaRepository, contains('bytes[3] == 0x46'));
    expect(profilePage, isNot(contains('FirebaseStorage')));
    expect(profilePage, isNot(contains('firebase_storage')));
    expect(profilePage, isNot(contains('putData(')));
    expect(profilePage, isNot(contains('getDownloadURL(')));
    expect(
      profilePage,
      contains('Aucun fichier n’est envoyé dans Firebase Storage'),
    );
  });

  test('les règles B2 bornent strictement les médias privés Agent', () {
    final String rules = _read('firestore.rules');

    expect(rules, contains('match /agentPersonalMedia/{agentId}/items/{kind}'));
    expect(rules, contains('request.resource.data.contentBytes is bytes'));
    expect(rules, contains('request.resource.data.sizeBytes <= 250000'));
    expect(rules, contains('request.resource.data.sizeBytes <= 850000'));
    expect(rules, contains("profileAfter.verificationStatus != 'verified'"));
    expect(
      rules,
      contains('adminAgentVerificationHasRequiredIdentity(agentId)'),
    );
  });

  test('C agrège uniquement les données métier existantes', () {
    final String activityRepository = _read(
      'lib/features/agents/data/repositories/'
      'firestore_agent_activity_v2_repository.dart',
    );

    for (final String collection in <String>[
      'orders',
      'orderAssignments',
      'networkTransactions',
      'commissions',
      'commissionAccounts',
      'commissionPayouts',
      'agentProfiles',
      'agentIssues',
    ]) {
      expect(
        activityRepository,
        contains(".collection('$collection')"),
        reason: 'Source C absente: $collection',
      );
    }
    expect(
      activityRepository,
      isNot(contains(".collection('agentActivities')")),
    );
  });

  test('C n’élargit en écriture aucun flux financier', () {
    final String rules = _read('firestore.rules');

    expect(rules, contains('resource.data.agentId == request.auth.uid'));
    expect(
      rules,
      contains('allow create: if isValidAgentOrderNetworkTransactionCreation'),
    );
  });

  test('C reste strictement en lecture seule et conserve completed legacy', () {
    final String activityRepository = _read(
      'lib/features/agents/data/repositories/'
      'firestore_agent_activity_v2_repository.dart',
    );
    final String activityModels = _read(
      'lib/features/agents/domain/models/agent_activity_v2_models.dart',
    );
    final String dashboard = _read(
      'lib/features/agents/presentation/pages/'
      'agent_activity_v2_dashboard_page.dart',
    );

    expect(activityRepository, isNot(contains('WriteBatch')));
    expect(activityRepository, isNot(contains('runTransaction')));
    expect(activityRepository, isNot(contains('FieldValue.serverTimestamp')));
    expect(activityRepository, isNot(contains('.update(')));
    expect(activityRepository, isNot(contains('.delete(')));
    expect(activityModels, contains("status == 'completed'"));
    expect(
      activityModels,
      contains("status == 'awaitingCustomerConfirmation'"),
    );
    expect(dashboard, contains('Voir l’historique complet'));
  });

  test('Admin accède à l’identité Blob et à l’activité Agent', () {
    final String adminPage = _read(
      'lib/features/agents/presentation/pages/'
      'admin_agent_profile_activity_page.dart',
    );

    expect(adminPage, contains('AgentPersonalMediaKind.avatar'));
    expect(adminPage, contains('AgentPersonalMediaKind.identity'));
    expect(adminPage, contains('AgentActivityV2DashboardPage'));
  });

  test(
    'les contrats historiques critiques restent présents dans les règles',
    () {
      final String rules = _read('firestore.rules');

      for (final String token in <String>[
        'match /agentProfiles/{agentId}',
        'match /orders/{orderId}',
        'match /orderAssignments/{assignmentId}',
        'match /networkTransactions/{transactionId}',
        'match /commissions/{commissionId}',
        'match /commissionAccounts/{accountId}',
        'match /commissionPayouts/{payoutId}',
        'match /agentIssues/{issueId}',
        'match /agentPersonalProfiles/{agentId}',
      ]) {
        expect(rules, contains(token), reason: 'Contrat absent: $token');
      }
    },
  );
}
