import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'le repertoire Agent recupere uniquement un avatar signe via Supabase',
    () {
      final String repository = _read(
        'lib/features/agents/data/repositories/'
        'supabase_agent_personal_profile_repository.dart',
      );

      expect(repository, contains('fetchDirectoryAvatarUrl('));
      expect(repository, contains("'agent_directory_avatar_path'"));
      expect(repository, contains("'p_agent_id': normalizedAgentId"));
      expect(repository, contains('createSignedMediaUrl('));
    },
  );

  test(
    'la liste Admin Agents affiche la photo Supabase avec repli initials',
    () {
      final String page = _read(
        'lib/features/agents/presentation/pages/agent_management_page.dart',
      );
      final String avatar = _read(
        'lib/features/agents/presentation/widgets/agent_directory_avatar.dart',
      );

      expect(page, contains('AgentDirectoryAvatar('));
      expect(page, contains('agentId: agent.userId'));
      expect(avatar, contains('SupabaseBootstrap.isInitialized'));
      expect(avatar, contains('.fetchDirectoryAvatarUrl(widget.agentId)'));
      expect(avatar, contains('IzyTelAvatar('));
      expect(avatar, contains('imageUrl: snapshot.data'));
    },
  );

  test('la fiche Agent reutilise le meme avatar sans dupliquer la logique', () {
    final String page = _read(
      'lib/features/agents/presentation/pages/agent_detail_page.dart',
    );

    expect(page, contains('AgentDirectoryAvatar('));
    expect(page, contains('agentId: agent.userId'));
    expect(page, contains('size: 88'));
    expect(page, isNot(contains('foregroundImage:')));
  });
}
