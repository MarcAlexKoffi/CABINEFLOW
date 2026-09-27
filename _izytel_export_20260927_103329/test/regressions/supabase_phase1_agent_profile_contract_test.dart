import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Phase Supabase 1 initialise le client avec le JWT Firebase', () {
    final String main = _read('lib/main.dart');
    final String bootstrap = _read('lib/core/supabase/supabase_bootstrap.dart');

    expect(main, contains('SupabaseBootstrap.initialize()'));
    expect(bootstrap, contains('Supabase.initialize('));
    expect(bootstrap, contains('publishableKey'));
    expect(
      bootstrap,
      contains('FirebaseAuth.instance.currentUser?.getIdToken()'),
    );
    expect(bootstrap, isNot(contains('service_role')));
    expect(bootstrap, isNot(contains('sb_secret_')));
  });

  test('le profil Agent écrit uniquement dans Supabase', () {
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );
    final String repository = _read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_personal_profile_repository.dart',
    );

    expect(page, contains('SupabaseAgentPersonalProfileRepository'));
    expect(page, contains('await repository.saveProfile('));
    expect(page, isNot(contains(".collection('agentPersonalProfiles')")));
    expect(page, isNot(contains('WriteBatch')));
    expect(page, isNot(contains('FieldValue.serverTimestamp')));
    expect(repository, contains("tableName = 'agent_personal_profiles'"));
    expect(repository, contains("bucketName = 'agent-personal'"));
    expect(repository, contains('.uploadBinary('));
    expect(repository, contains('FileOptions('));
  });

  test('photo et pièce restent privées et liées au Firebase UID', () {
    final String repository = _read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_personal_profile_repository.dart',
    );

    expect(repository, contains("avatarPath = '\$agentId/avatar/profile.jpg'"));
    expect(
      repository,
      contains("identityPath = '\$agentId/identity/document.\$extension'"),
    );
    expect(repository, contains('FirebaseAuth.instance.currentUser?.uid'));
    expect(repository, contains('uid != agentId.trim()'));
    expect(repository, contains('avatarMaxBytes = 250000'));
    expect(repository, contains('identityMaxBytes = 850000'));
  });

  test('le profil général Agent lit son profil Supabase en temps réel', () {
    final String firestoreRepository = _read(
      'lib/features/agents/data/repositories/firestore_agent_repository.dart',
    );
    final String supabaseRepository = _read(
      'lib/features/agents/data/repositories/'
      'supabase_agent_personal_profile_repository.dart',
    );

    expect(firestoreRepository, contains('SupabaseBootstrap.isInitialized'));
    expect(firestoreRepository, contains('.watchProfile(agentId)'));
    expect(firestoreRepository, contains('.createSignedMediaUrl(cleaned)'));
    expect(supabaseRepository, contains('.stream(primaryKey:'));
    expect(supabaseRepository, contains(".eq('firebase_uid', agentId)"));
  });

  test('Accueil Agent affiche la photo privée Supabase', () {
    final String home = _read(
      'lib/features/agents/presentation/pages/agent_home_page.dart',
    );

    expect(home, contains('watchPersonalProfile(widget.agentId)'));
    expect(home, contains('resolvePersonalFileUrl('));
    expect(home, contains('imageUrl: _avatarUrl'));
    expect(home, contains('IzyTelAvatar('));
  });
}
