import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-7.5A2 - filtres périodiques Finances Web', () {
    test('les historiques financiers utilisent le filtre partagé et le calendrier ancien', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      expect(page, contains("shared/widgets/izytel_period_filter.dart"));
      expect(page, contains('IzyTelPeriodFilterBar'));
      expect(page, contains('DateTime(2000, 1, 1)'));
      expect(page, contains("calendarHelpText: 'Rechercher dans l’historique financier'"));
      expect(page, contains('Période de l’historique'));
    });

    test('une période active interroge Supabase au lieu de dépendre du snapshot limité', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      expect(page, contains("'izytel_bo75_finance_period_history'"));
      expect(page, contains("'p_start'"));
      expect(page, contains("'p_end'"));
      expect(page, contains('_periodRows('));
      expect(page, contains("'network_movements'"));
      expect(page, contains("'commission_payouts'"));
      expect(page, contains("'supplier_recharges'"));
      expect(page, contains("'credit_settlements'"));
      expect(page, contains("'expenses'"));
      expect(page, contains("'closings'"));
    });

    test('les vues de position courante ne sont pas faussement filtrées', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      expect(page, contains('widget.module != BackofficeFinanceModule.overview')); 
      expect(page, contains('BackofficeFinanceModule.workingCapital'));
      expect(
        page,
        contains('Les soldes et comptes courants restent actuels.'),
      );
    });

    test('le RPC historique conserve les contrôles de rôle finance', () {
      final String migration = _read(
        'supabase/migrations/20260917012401_bo75a2_finance_period_history.sql',
      );
      expect(migration, contains('private.is_izytel_finance_staff()'));
      expect(migration, contains("raise exception 'STAFF_REQUIRED'"));
      expect(migration, contains('security definer'));
      expect(migration, contains('finance_wave_balance_adjustments'));
      expect(migration, contains('phase5_commission_payouts'));
      expect(migration, contains('phase5_agent_recharges'));
      expect(migration, contains('finance_customer_credits'));
      expect(migration, contains('finance_expenses'));
      expect(migration, contains('finance_daily_closings'));
    });
  });
}
