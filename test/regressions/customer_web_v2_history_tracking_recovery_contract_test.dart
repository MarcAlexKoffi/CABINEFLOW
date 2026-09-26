import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - Historique Suivi Recuperation', () {
    test('historique reprend les quatre etats de la maquette', () {
      final String history = File(
        'lib/features/customer_order/presentation/pages/customer_order_history_page.dart',
      ).readAsStringSync();

      expect(history, contains("'Historique'"));
      expect(history, contains("'Toutes'"));
      expect(history, contains("'En cours'"));
      expect(history, contains("'Terminées'"));
      expect(history, contains("'Incidents'"));
      expect(history, contains("'Voir le suivi'"));
    });

    test('suivi utilise les vrais jalons de la commande', () {
      final String tracking = File(
        'lib/features/customer_order/presentation/pages/customer_confirmation_page.dart',
      ).readAsStringSync();

      expect(tracking, contains("'Suivi de commande'"));
      expect(tracking, contains("'Commande créée'"));
      expect(tracking, contains("'Paiement confirmé'"));
      expect(tracking, contains("'En traitement'"));
      expect(tracking, contains("'Dernière mise à jour · \$_title'"));
      expect(tracking, contains("'Contacter IzyTel'"));
      expect(tracking, isNot(contains('message WhatsApp')));
    });

    test('recuperation publique repose sur reference et code', () {
      final String recovery = File(
        'lib/features/customer_order/presentation/pages/customer_order_recovery_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();

      expect(recovery, contains("'Référence de commande'"));
      expect(recovery, contains("'Code de récupération'"));
      expect(recovery, contains('recoverOrderByCode'));
      expect(recovery, isNot(contains("'Type de commande'")));
      expect(viewModel, contains('recoverOrderByCode'));
      expect(viewModel, contains('session.hasRecoveryCode'));
    });

    test('recuperation V2 est canonique Supabase sans nouvelles rules Firestore', () {
      final String repository = File(
        'lib/features/customer_order/data/repositories/firestore_customer_order_repository.dart',
      ).readAsStringSync();
      final String recoveryRepository = File(
        'lib/features/customer_order/data/repositories/supabase_customer_order_recovery_repository.dart',
      ).readAsStringSync();
      final String statusRepository = File(
        'lib/features/customer_order/data/repositories/supabase_customer_order_status_repository.dart',
      ).readAsStringSync();
      final String migration = File(
        'supabase/migrations/20260922003000_wc2_customer_recovery_supabase.sql',
      ).readAsStringSync();
      final String statusMigration = File(
        'supabase/migrations/20260922004500_wc2_customer_recovery_status_snapshot.sql',
      ).readAsStringSync();
      final String rules = File('firestore.rules').readAsStringSync();
      final String cutover = File(
        'supabase/PHASE3_OPERATIONAL_CUTOVER_APPLIED.md',
      ).readAsStringSync();

      expect(repository, contains('SupabaseCustomerOrderRecoveryRepository'));
      expect(repository, contains('CustomerOrderRecoveryKey.generateCode()'));
      expect(repository, contains('recoverOrderByCode'));
      expect(repository, contains('_wc2RecoveryCutover'));
      expect(repository, isNot(contains("'customerRecoveryCode'")));

      expect(recoveryRepository, contains('izytel_wc2_register_customer_recovery'));
      expect(recoveryRepository, contains('izytel_wc2_recover_customer_order'));
      expect(statusRepository, contains('izytel_wc2_customer_order_status'));
      expect(statusRepository, isNot(contains("'p_whatsapp'")));

      expect(migration, contains('customer_order_recovery_registry'));
      expect(migration, contains('extensions.crypt'));
      expect(migration, contains('revoke all on table public.customer_order_recovery_registry'));
      expect(migration, contains('izytel_wc2_recover_customer_order'));
      expect(migration, contains('izytel_wc2_customer_order_status'));
      expect(statusMigration, contains('order_status'));
      expect(statusMigration, contains('payment_status'));
      expect(statusMigration, contains('customer_order_recovery_rpc_only'));
      expect(statusMigration, contains('using (false)'));

      expect(rules, isNot(contains("'customerRecoveryCode'")));
      expect(rules, contains('match /orderRecoveryKeys/{recoveryKey}'));
      expect(cutover, contains('No Firestore Rules deployment is required'));
    });

    test('le parcours direct reste explicitement protege', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String catalog = File(
        'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
      ).readAsStringSync();

      expect(flow, contains('CustomerService.unitTransfer'));
      expect(catalog, contains("'Commencer sans offre'"));
    });
  });
}
