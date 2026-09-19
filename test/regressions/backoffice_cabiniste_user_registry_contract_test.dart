import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('registre Admin reconnait le role Cabiniste', () {
    final String model = source(
      'lib/backoffice/domain/models/backoffice_user_account.dart',
    );
    final String page = source(
      'lib/backoffice/presentation/pages/backoffice_users_page.dart',
    );

    expect(model, contains('cabiniste,'));
    expect(model, contains("return 'Cabiniste';"));
    expect(model, contains("case 'cabiniste':"));
    expect(page, contains('Agents, Cabinistes, Managers'));
    expect(page, contains('BackofficeAccountRole.cabiniste'));
  });

  test('registre fusionne Firestore Staff et Supabase partner_accounts', () {
    final String repository = source(
      'lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart',
    );

    expect(repository, contains("collection('users')"));
    expect(repository, contains("from('partner_accounts')"));
    expect(repository, contains('BackofficeAccountRole.cabiniste'));
    expect(repository, contains('SupabaseBootstrap.isInitialized'));
    expect(repository, isNot(contains('izytel_staff_access')));
  });
}
