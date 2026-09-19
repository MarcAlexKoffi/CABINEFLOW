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
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      expect(shell, contains('BackofficeDestination.cabinisteSettlements'));
      expect(page, contains('BackofficeFinanceModule.cabinisteSettlements'));
      expect(page, contains('Règlements Cabinistes'));
      expect(page, contains('Comptes Cabinistes'));
      expect(page, contains('Historique'));
      expect(page, contains('Payer'));
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
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      expect(page, contains('Période à régler'));
      expect(page, contains('Référence du paiement'));
      expect(page, contains('Maximum pour cette période'));
      expect(page, contains('periodId: periodId'));
      expect(page, contains('Règlement Cabiniste enregistré.'));
    });

    test('le module Cabiniste garde une position courante non filtrée artificiellement', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      expect(
        page,
        contains('widget.module != BackofficeFinanceModule.cabinisteSettlements'),
      );
      expect(page, contains('Acquis, payé et reste à payer par période.'));
      expect(page, contains('Commandes exécutées'));
    });
  });
}
