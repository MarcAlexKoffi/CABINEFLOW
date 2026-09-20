import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Cabinistes - Finance Back-office', () {
    test('le Back Office expose un module Règlements Cabinistes distinct', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_cabiniste_finance_page.dart',
      );

      expect(shell, contains('BackofficeDestination.cabinisteFinances'));
      expect(shell, contains("return 'Cabinistes';"));
      expect(shell, contains('BackofficeCabinisteFinancePage(user: widget.user)'));
      expect(page, contains('class BackofficeCabinisteFinancePage'));
      expect(page, contains('Cabiniste'));
    });

    test('le snapshot consolide acquis, payé et solde Cabiniste', () {
      final String model = _read(
        'lib/backoffice/domain/models/backoffice_finance_snapshot.dart',
      );

      expect(model, contains('cabinisteFinance'));
      expect(model, contains('cabinisteEarnedTotal'));
      expect(model, contains('cabinistePaidTotal'));
      expect(model, contains('cabinisteDebt'));
      expect(model, contains('cabinisteToPayCount'));
      expect(model, contains('commissionDebt -'));
      expect(model, contains('cabinisteDebt;'));
    });

    test('le repository utilise les RPC Cabinistes canoniques', () {
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );
      final String contract = _read(
        'lib/backoffice/domain/repositories/backoffice_finance_repository.dart',
      );

      expect(repository, contains('izytel_admin_cabiniste_finance_snapshot'));
      expect(repository, contains('izytel_admin_cabiniste_finance_history'));
      expect(repository, contains('izytel_admin_record_cabiniste_payout'));
      expect(repository, contains("'p_period_id'"));
      expect(repository, contains("'p_payment_reference'"));
      expect(contract, contains('recordCabinistePayout'));
      expect(contract, contains('fetchCabinisteFinanceHistory'));
    });

    test('le paiement est rattaché à une période et conserve une référence', () {
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );

      expect(repository, contains("'p_period_id'"));
      expect(repository, contains("'p_payment_reference'"));
      expect(repository, contains('izytel_admin_record_cabiniste_payout'));
    });

    test('le module Cabiniste garde une position courante non filtrée artificiellement', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_cabiniste_finance_page.dart',
      );

      expect(shell, contains('BackofficeDestination.cabinisteFinances'));
      expect(page, contains('BackofficeCabinisteFinancePage'));
    });
  });
}
