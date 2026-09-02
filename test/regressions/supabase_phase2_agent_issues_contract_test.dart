import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Phase Supabase 2 retire les écritures agentIssues de Firestore', () {
    final String firestoreRepository = _read(
      'lib/features/agents/data/repositories/firestore_agent_repository.dart',
    );
    final String supabaseRepository = _read(
      'lib/features/agents/data/repositories/supabase_agent_issue_repository.dart',
    );

    expect(firestoreRepository, contains('SupabaseAgentIssueRepository'));
    expect(firestoreRepository, isNot(contains("collection('agentIssues')")));
    expect(supabaseRepository, contains("tableName = 'agent_issues'"));
    expect(supabaseRepository, contains('.from(tableName).insert('));
    expect(supabaseRepository, contains('.update(<String, dynamic>{'));
  });

  test('l Agent ne peut créer un signalement que pour sa session Firebase', () {
    final String repository = _read(
      'lib/features/agents/data/repositories/supabase_agent_issue_repository.dart',
    );

    expect(repository, contains('FirebaseAuth.instance.currentUser?.uid'));
    expect(repository, contains('uid != cleanAgentId'));
    expect(repository, contains("'description': description"));
    expect(repository, contains("'status': 'open'"));
  });

  test('Accueil et activité détaillée lisent les signalements Supabase', () {
    final String home = _read(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    );
    final String activityRepository = _read(
      'lib/features/agents/data/repositories/'
      'firestore_agent_activity_v2_repository.dart',
    );

    expect(home, contains('watchAgentIssues(user.id)'));
    expect(activityRepository, contains('SupabaseAgentIssueRepository'));
    expect(activityRepository, isNot(contains("collection('agentIssues')")));
  });

  test('le centre Admin garde les transitions En cours Résolu Sans suite', () {
    final String adminPage = _read(
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
    );

    expect(adminPage, contains("updateStatus('in_progress')"));
    expect(adminPage, contains("updateStatus('resolved')"));
    expect(adminPage, contains("updateStatus('cancelled')"));
  });

  test('Realtime Supabase suit les changements de JWT Firebase', () {
    final String bootstrap = _read('lib/core/supabase/supabase_bootstrap.dart');

    expect(bootstrap, contains('idTokenChanges()'));
    expect(bootstrap, contains('.listen('));
    expect(bootstrap, contains('realtime.setAuth(token)'));
    expect(bootstrap, contains('_syncRealtimeAuth'));
  });

  test('les signalements restent lisibles si Realtime devient instable', () {
    final String repository = _read(
      'lib/features/agents/data/repositories/supabase_agent_issue_repository.dart',
    );

    expect(repository, contains('_pollInterval'));
    expect(repository, contains('.select()'));
    expect(repository, contains('lastSuccessful'));
    expect(repository, isNot(contains('.stream(primaryKey:')));
  });
}
