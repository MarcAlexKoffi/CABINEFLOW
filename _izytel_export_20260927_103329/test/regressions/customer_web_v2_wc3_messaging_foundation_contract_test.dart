import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - WC3A messagerie Client -> Manager', () {
    late String migration;
    late String hardeningMigration;
    late String supabaseRepository;
    late String operationalRepository;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260926201853_wc3_customer_manager_messaging_foundation.sql',
      ).readAsStringSync();
      hardeningMigration = File(
        'supabase/migrations/20260926202027_wc3_customer_message_order_access_hardening.sql',
      ).readAsStringSync();
      supabaseRepository = File(
        'lib/features/messaging/data/repositories/supabase_customer_messaging_repository.dart',
      ).readAsStringSync();
      operationalRepository = File(
        'lib/features/messaging/data/repositories/operational_customer_messaging_repository.dart',
      ).readAsStringSync();
    });

    test('Supabase porte conversations et messages sans nouvelle dépendance Firestore', () {
      expect(migration, contains('public.customer_conversations'));
      expect(migration, contains('public.customer_messages'));
      expect(migration, contains('customer_order_recovery_access'));
      expect(supabaseRepository, contains('customer_conversations'));
      expect(supabaseRepository, contains('customer_messages'));
      expect(supabaseRepository.toLowerCase(), isNot(contains('firestore')));
      expect(operationalRepository, contains('ne bascule pas vers Firestore'));
    });

    test('le circuit autorisé est Client -> Manager avec Admin en lecture', () {
      expect(migration, contains("staff.role in ('manager', 'supervisor')"));
      expect(migration, contains('private.izytel_wc3_is_admin()'));
      expect(migration, isNot(contains("staff.role in ('agent'")));
      expect(migration, isNot(contains("staff.role in ('cabiniste'")));
      expect(migration, contains("sender_type in ('client', 'manager', 'system')"));
    });

    test('les écritures passent uniquement par les RPC WC3', () {
      expect(migration, contains('izytel_wc3_create_conversation'));
      expect(migration, contains('izytel_wc3_send_client_message'));
      expect(migration, contains('izytel_wc3_take_conversation'));
      expect(migration, contains('izytel_wc3_send_manager_message'));
      expect(migration, contains('izytel_wc3_resolve_conversation'));
      expect(migration, contains('revoke insert, update, delete'));
    });

    test('une récupération WC2 réussie autorise ensuite la messagerie liée', () {
      expect(migration, contains('private.izytel_wc2_recover_customer_order'));
      expect(migration, contains('customer_order_recovery_access'));
      expect(migration, contains('on conflict (order_id, customer_firebase_uid)'));
      expect(migration, contains('izytel_wc3_customer_has_order_access'));
      expect(hardeningMigration, contains('customer_order_recovery_registry'));
      expect(hardeningMigration, contains('owner_firebase_uid'));
    });

    test('le repository Flutter utilise seulement les RPC WC3 pour écrire', () {
      expect(supabaseRepository, contains("'izytel_wc3_create_conversation'"));
      expect(supabaseRepository, contains("'izytel_wc3_send_client_message'"));
      expect(supabaseRepository, contains("'izytel_wc3_take_conversation'"));
      expect(supabaseRepository, contains("'izytel_wc3_send_manager_message'"));
      expect(supabaseRepository, contains("'izytel_wc3_resolve_conversation'"));
    });
  });
}
