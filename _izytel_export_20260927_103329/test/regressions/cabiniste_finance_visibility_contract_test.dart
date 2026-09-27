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

  test('Cabinistes sont ranges dans Equipe sur mobile Admin et Manager', () {
    final String more = source(
      'lib/features/more/presentation/pages/more_page.dart',
    );
    final String cabinistePage = source(
      'lib/features/finances/presentation/pages/cabiniste_finance_supervision_page.dart',
    );

    expect(more, contains("const _SectionLabel('Équipe')"));
    expect(more, contains("title: 'Cabinistes'"));
    expect(more, contains('CabinisteFinanceSupervisionPage'));
    expect(cabinistePage, contains("label: 'Gain IzyTel'"));
    expect(cabinistePage, contains("label: 'À reverser'"));
    expect(cabinistePage, isNot(contains('recordPayout(')));
  });

  test('Back Office range Cabinistes dans Equipe et reserve le paiement Admin', () {
    final String shell = source(
      'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
    );
    final String page = source(
      'lib/backoffice/presentation/pages/finances/backoffice_cabiniste_finance_page.dart',
    );

    expect(shell, contains('case BackofficeDestination.cabinisteFinances:'));
    expect(shell, contains('return _BackofficeSection.team;'));
    expect(shell, contains('BackofficeCabinisteFinancePage(user: widget.user)'));
    expect(page, contains('_canRecordPayouts'));
    expect(page, contains('_canRecordPayouts && partner.balanceDue > 0'));
    expect(page, contains('recordPayout('));
    expect(page, contains('Enregistrer le règlement'));
  });
}
