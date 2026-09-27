import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-5 - Finances Back-office', () {
    test('les dix sous-modules Finances sont routes vers une vraie page', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      for (final String destination in <String>[
        'finances',
        'waveCash',
        'commissions',
        'suppliers',
        'customerCredits',
        'expenses',
        'workingCapital',
        'reconciliations',
        'movements',
        'closings',
      ]) {
        expect(shell, contains('BackofficeDestination.$destination'));
      }
      for (final String module in <String>[
        'overview',
        'waveCash',
        'commissions',
        'suppliers',
        'customerCredits',
        'expenses',
        'workingCapital',
        'reconciliations',
        'movements',
        'closings',
      ]) {
        expect(page, contains('BackofficeFinanceModule.$module'));
      }
      expect(shell, contains('BackofficeFinancePage('));
      expect(shell, contains('ordersRepository: widget.ordersRepository'));
      expect(page, isNot(contains('Module en préparation')));
    });

    test('la page Finances respecte le scroll porte par le shell', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      // Le shell fournit deja le scroll vertical du contenu. Une ListView
      // imbriquee ici recevrait une hauteur non bornee sur le Web et peut
      // laisser toute la zone BO-5 vide malgre une navigation fonctionnelle.
      expect(shell, contains('SingleChildScrollView('));
      expect(page, contains('return Padding('));
      expect(page, contains('crossAxisAlignment: CrossAxisAlignment.stretch'));
      expect(page, isNot(contains('return ListView(')));
    });

    test('Supabase fournit un snapshot canonique et un signal Realtime', () {
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );
      final String realtime = _read(
        'supabase/migrations/20260915113104_bo5_finance_realtime_bridge.sql',
      );
      final String phase5Realtime = _read(
        'supabase/migrations/20260915113931_bo5_finance_realtime_orders_bridge.sql',
      );

      expect(repository, contains("rpc('izytel_finance_snapshot')"));
      expect(repository, contains("from('finance_change_feed')"));
      expect(repository, contains("stream(primaryKey: const <String>['id'])"));
      expect(realtime, contains('alter publication supabase_realtime add table public.finance_change_feed'));
      expect(phase5Realtime, contains("'phase4_assignment_orders'"));
      expect(phase5Realtime, contains("'phase5_supplier_payments'"));
      expect(phase5Realtime, contains("'phase5_commission_payouts'"));
      expect(phase5Realtime, contains("'refunds'"));
    });

    test('les ecritures sensibles restent Admin et le Manager est lecture seule', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String migration = _read(
        'supabase/migrations/20260915174752_bo5_finance_supplier_admin_write_hardening.sql',
      );
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );

      expect(page, contains('canManageFinanceSettings'));
      expect(page, contains('Mode consultation Manager'));
      expect(migration, contains('private.is_izytel_finance_admin()'));
      expect(migration, contains('finance admin creates suppliers'));
      expect(migration, contains('finance admin updates suppliers'));
      expect(repository, contains('izytel_finance_set_wave_opening'));
      expect(repository, contains('phase5_record_supplier_payment'));
      expect(repository, contains('phase5_record_commission_payout'));
    });

    test('la vente a credit passe atomiquement par Supabase et non par une ecriture Firestore', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );
      final String migration = _read(
        'supabase/migrations/20260915174444_bo5_finance_credit_canonical_authorization.sql',
      );

      expect(page, contains('fetchPaymentTrackingOrders()'));
      expect(page, contains('OrderPaymentStatus.declared'));
      expect(page, contains('authorizeCreditOrder('));
      expect(page, contains('tryAutomaticAssignment('));
      expect(repository, contains('izytel_finance_authorize_credit_order'));
      expect(migration, contains('public.phase3_sync_order'));
      expect(migration, contains("'credit'"));
      expect(migration, contains('public.izytel_finance_create_credit'));
      expect(migration, contains('PAYMENT_ALREADY_IN_PROGRESS'));
      expect(repository, isNot(contains('FirebaseFirestore')));
    });

    test('approvisionnement, dette fournisseur et capacite partagent le noyau Phase 5', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String repository = _read(
        'lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart',
      );

      expect(repository, contains('phase5_record_supplier_recharge'));
      expect(repository, contains('phase5_record_supplier_payment'));
      expect(page, contains('amountOwed: principalValue'));
      expect(page, contains('Le bonus augmente uniquement la capacité reçue'));
      expect(page, isNot(contains('TextEditingController owed')));
    });

    test('la caisse Wave et la cloture utilisent un point de depart reel', () {
      final String model = _read(
        'lib/backoffice/domain/models/backoffice_finance_snapshot.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      expect(model, contains('waveOpeningEffectiveAt'));
      expect(model, contains('waveIncomingSinceOpening'));
      expect(model, contains('waveOutgoingSinceOpening'));
      expect(model, contains('waveTheoreticalBalance'));
      expect(model, contains('effectiveAt == null || !at.isBefore(effectiveAt)'));
      expect(page, contains("if (!s.hasWaveOpening)"));
      expect(page, contains("'wave_actual_balance': actualValue"));
      expect(page, contains('Supabase recalculera les totaux canoniques'));
      expect(page, contains('Justifie l’écart Wave avant la clôture'));

      final String closingGuard = _read(
        'supabase/migrations/20260915175546_bo5_finance_closing_guard_hardening.sql',
      );
      expect(closingGuard, contains('WAVE_OPENING_REQUIRED'));
      expect(closingGuard, contains('WAVE_DIFFERENCE_NOTE_REQUIRED'));
      expect(closingGuard, contains('finance_wave_settings'));
    });

    test('le fonds de roulement distingue stock, engagements et capacite libre', () {
      final String model = _read(
        'lib/backoffice/domain/models/backoffice_finance_snapshot.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );

      expect(model, contains('int committedFor(String network)'));
      expect(model, contains('int freeCapacityFor(String network)'));
      expect(model, contains('totalCommittedCapacity'));
      expect(model, contains('totalFreeCapacity'));
      expect(model, contains('netWorkingCapital'));
      expect(page, contains('Capacité engagée'));
      expect(page, contains('Capacité libre'));
      expect(page, contains('Fonds net estimé'));
    });

    test('le backfill Firestore est uniquement une reprise historique', () {
      final String backfill = _read(
        'lib/core/migrations/legacy_finance_backfill_service.dart',
      );
      final String app = _read('lib/backoffice/backoffice_app.dart');

      expect(backfill, contains('izytel_finance_backfill_needed'));
      expect(backfill, contains('izytel_import_legacy_finance'));
      expect(backfill, contains('izytel_finish_finance_backfill'));
      // Le lecteur Firestore est volontairement generique : les collections
      // historiques sont declarees dans _run(), puis lues via
      // _firestore.collection(collection). Le contrat doit verifier ce
      // comportement reel sans imposer une lecture Firestore codee en dur.
      expect(
        backfill,
        contains("_importCollection('customerCredits', 'credit', _creditPayload)"),
      );
      expect(
        backfill,
        contains("_importCollection('customerCreditSettlements', 'credit_settlement', _settlementPayload)"),
      );
      expect(
        backfill,
        contains("_importCollection('financeExpenses', 'expense', _expensePayload)"),
      );
      expect(
        backfill,
        contains("_importCollection('waveBalanceAdjustments', 'wave_adjustment', _waveAdjustmentPayload)"),
      );
      expect(
        backfill,
        contains("_importCollection('dailyFinancialClosings', 'closing', _closingPayload)"),
      );
      expect(backfill, contains('.collection(collection)'));
      expect(backfill, contains('orderBy(FieldPath.documentId)'));
      expect(backfill, contains('startAfterDocument(cursor)'));
      expect(backfill, isNot(contains('.set(')));
      expect(backfill, isNot(contains('.update(')));
      expect(
        RegExp(r'LegacyFinanceBackfillService\(\)\.runIfNeeded\(\)')
            .allMatches(app)
            .length,
        greaterThanOrEqualTo(2),
      );
    });


    test('les rapprochements isolent le legacy pre-Phase 4 des anomalies courantes', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String hardening = _read(
        'supabase/migrations/20260915224305_bo5_finance_integrity_hardening.sql',
      );

      expect(page, contains("financeDate(row['created_at'])"));
      expect(page, contains('canonicalOrderCutoff'));
      expect(page, contains('historique(s) pré-Phase 4'));
      expect(page, contains("financeString(row['legacy_firestore_id']).isNotEmpty"));
      expect(hardening, contains('firebase_created_at,created_at,updated_at'));
    });

    test('la cloture est recalculee canoniquement par Supabase', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart',
      );
      final String hardening = _read(
        'supabase/migrations/20260915224305_bo5_finance_integrity_hardening.sql',
      );

      expect(page, contains('Supabase recalculera les totaux canoniques'));
      expect(page, contains("'wave_actual_balance': actualValue"));
      expect(page, isNot(contains("'client_receipts': s.confirmedReceiptsOn(today)")));
      expect(hardening, contains("v_today date := (now() at time zone 'Africa/Abidjan')::date"));
      expect(hardening, contains("raise exception 'CLOSING_DATE_MUST_BE_TODAY'"));
      expect(hardening, contains("jsonb_build_object('canonical',v_canonical,'client_request',p_payload)"));
      expect(hardening, contains("o.payment_status='confirmed'"));
      expect(hardening, contains("m.movement_type='orderSuccess'"));
    });
  });
}
