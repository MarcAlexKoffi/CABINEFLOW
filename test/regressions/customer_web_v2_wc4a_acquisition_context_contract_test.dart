import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - WC4A acquisition et contexte geographique', () {
    late String flow;
    late String viewModel;
    late String sourceWeb;
    late String supabaseRepository;
    late String migration;

    setUpAll(() {
      flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();
      sourceWeb = File(
        'lib/features/customer_order/data/acquisition/customer_acquisition_source_web.dart',
      ).readAsStringSync();
      supabaseRepository = File(
        'lib/features/customer_order/data/repositories/supabase_customer_order_context_repository.dart',
      ).readAsStringSync();
      migration = File(
        'supabase/migrations/20260926235839_wc4a_customer_order_context_foundation.sql',
      ).readAsStringSync();
    });

    test('le code source vient de URL et reste distinct de la geographie', () {
      expect(sourceWeb, contains("queryParameters['src']"));
      expect(sourceWeb, contains("queryParameters['sourceCode']"));
      expect(sourceWeb, contains('localStorage'));
      expect(migration, contains('source_code'));
      expect(migration, contains('nearest_zone_id'));
      expect(migration, isNot(contains('source_code = nearest_zone_id')));
    });

    test('le contexte est enregistre dans Supabase apres creation de commande', () {
      expect(flow, contains('resolveCustomerAcquisitionSourceCode'));
      expect(flow, contains('createOperationalCustomerOrderContextRepository'));
      expect(viewModel, contains('_registerOrderContextSafely'));
      expect(viewModel, contains('CustomerOrder.context-register'));
      expect(
        supabaseRepository,
        contains('izytel_wc4_register_customer_context'),
      );
    });

    test('la geolocalisation reste opt-in et nest pas demandee silencieusement', () {
      expect(migration, contains("location_status = 'granted'"));
      expect(migration, contains('LOCATION_CONSENT_REQUIRED'));
      expect(flow, isNot(contains('getCurrentPosition')));
      expect(flow, isNot(contains('navigator.geolocation')));
    });

    test('WC4A ne cree aucun nouveau flux Firestore', () {
      expect(migration, isNot(contains('firestore')));
      expect(
        supabaseRepository,
        isNot(contains('cloud_firestore')),
      );
    });
  });
}
