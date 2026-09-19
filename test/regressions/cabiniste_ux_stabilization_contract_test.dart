import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('historique et refresh Cabiniste ne retournent plus de Future depuis setState', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, isNot(contains('setState(() => _future =')));
    expect(shell, isNot(contains('setState(() => _initialOrders =')));
    expect(shell, contains('_future = widget.repository.fetchOwnAssignmentHistory();'));
    expect(shell, contains('_future = widget.repository.fetchFinanceSnapshot();'));
  });

  test('capacites Cabiniste disposent d une action explicite de modification', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains("'cabiniste-capacity-edit-\$network'"));
    expect(shell, contains("label: const Text('Modifier')"));
    expect(shell, contains("'Enregistrer la capacité'"));
    expect(shell, contains('updateOwnOperations('));
  });

  test('retour Android restaure navigation interne avant de quitter', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains('bool _handlingBack = false;'));
    expect(shell, contains('current.canPop()'));
    expect(shell, contains('current.pop();'));
    expect(shell, contains('if (_selectedIndex != 0)'));
    expect(shell, contains('_selectTab(0);'));
    expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
  });

  test('avatar Cabiniste est rafraichi sur les onglets apres modification', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String profileRepository = source(
      'lib/features/auth/data/repositories/supabase_staff_profile_repository.dart',
    );

    expect(shell, contains('_refreshProfile'));
    expect(shell, contains('widget.onProfileUpdated();'));
    expect(profileRepository, contains('millisecondsSinceEpoch'));
  });
}
