import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('profil Agent Cabiniste signale et cible les champs obligatoires', () {
    final String profile = source(
      'lib/app/modules/profile/views/agent_personal_profile_page.dart',
    );

    expect(profile, contains('Les champs marqués * sont obligatoires.'));
    expect(profile, contains("labelText: required ? '\$label *' : label"));
    expect(profile, contains("labelText: 'Date de naissance *'"));
    expect(profile, contains('Scrollable.ensureVisible'));
    expect(profile, contains('Complète les champs obligatoires (*)'));
    expect(profile, contains('saveAvatarOnly('));
  });

  test('profil Staff applique la meme convention de champs obligatoires', () {
    final String profile = source(
      'lib/app/modules/profile/views/staff_personal_profile_page.dart',
    );

    expect(profile, contains('Les champs marqués * sont obligatoires.'));
    expect(profile, contains("labelText: required ? '\$label *' : label"));
    expect(profile, contains('Scrollable.ensureVisible'));
    expect(profile, contains('Complète les champs obligatoires (*)'));
  });
}
