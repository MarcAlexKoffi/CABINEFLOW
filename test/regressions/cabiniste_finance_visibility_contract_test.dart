import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('repository expose une lecture Cabiniste commune Admin Manager', () {
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_cabiniste_finance_supervision_repository.dart',
    );

    expect(repository, contains("'izytel_staff_cabiniste_finance_snapshot'"));
    expect(repository, contains("'izytel_staff_cabiniste_finance_history'"));
    expect(repository, contains("'izytel_admin_record_cabiniste_payout'"));
  });

  test('modele distingue gain IzyTel et montant a reverser', () {
    final String model = source(
      'lib/features/partners/domain/models/cabiniste_finance_supervision_models.dart',
    );

    expect(model, contains('izytelGrossGainTotal'));
    expect(model, contains('balanceDue'));
    expect(model, contains('cabinisteSettlementAmount'));
    expect(model, contains('telecomMarginAmount'));
    expect(model, contains('cabinisteMarginAmount'));
  });

  test('Manager dispose de la vue Cabinistes en lecture seule', () {
    final String financePage = source(
      'lib/features/finances/presentation/pages/finances_page.dart',
    );
    final String cabinistePage = source(
      'lib/features/finances/presentation/pages/cabiniste_finance_supervision_page.dart',
    );

    expect(financePage, contains("title: 'Cabinistes'"));
    expect(financePage, contains('_openCabinisteFinances'));
    expect(cabinistePage, contains("label: 'Gain IzyTel'"));
    expect(cabinistePage, contains("label: 'À reverser'"));
    expect(cabinistePage, contains('lecture seule'));
    expect(cabinistePage, isNot(contains('recordPayout(')));
  });

  test('Admin dispose de la vue Cabinistes et du reglement', () {
    final String shell = source(
      'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
    );
    final String page = source(
      'lib/backoffice/presentation/pages/finances/backoffice_cabiniste_finance_page.dart',
    );

    expect(shell, contains('cabinisteFinances'));
    expect(shell, contains('BackofficeCabinisteFinancePage'));
    expect(page, contains('Gain brut IzyTel'));
    expect(page, contains('À reverser'));
    expect(page, contains('recordPayout('));
    expect(page, contains('Enregistrer le règlement'));
  });
}
