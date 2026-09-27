import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('cabiniste reprend la navigation principale Agent', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains("label: 'Accueil'"));
    expect(shell, contains("label: 'Commandes'"));
    expect(shell, contains("label: 'Historique'"));
    expect(shell, contains("label: 'Profil'"));
    expect(shell, isNot(contains("label: 'Gains'")));
    expect(shell, contains('_PartnerAgentStyleHeader'));
    expect(shell, contains('_PartnerOperationalSummary'));
  });

  test('cabiniste partage le profil personnel Agent sans devenir Staff', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String profilePage = source(
      'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
    );
    final String appUser = source(
      'lib/features/auth/domain/models/app_user.dart',
    );

    expect(shell, contains('AgentPersonalProfilePage('));
    expect(shell, contains("roleLabel: 'Cabiniste'"));
    expect(profilePage, contains("this.roleLabel = 'Agent'"));
    expect(appUser, contains('UserRole.cabiniste'));
    expect(shell, isNot(contains('izytel_staff_access')));
  });

  test('fonctions Cabiniste restent propres au role', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(shell, contains('Mes règlements'));
    expect(shell, contains('Mes capacités'));
    expect(shell, isNot(contains('Mes signalements')));
    expect(shell, isNot(contains('Mes commissions')));
    expect(repository, contains('updateOwnOperations'));
    expect(repository, contains('fetchOwnAssignmentHistory'));
  });
}
