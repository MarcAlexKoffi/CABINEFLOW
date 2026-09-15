import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-4 - Catalogue Supabase', () {
    test('le Back-office expose une vraie page Offres & tarifs', () {
      final String shell = _read(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      );
      final String page = _read(
        'lib/backoffice/presentation/pages/catalog/backoffice_offers_page.dart',
      );

      expect(shell, contains('BackofficeDestination.offers'));
      expect(shell, contains('BackofficeOffersPage('));
      expect(shell, contains("return 'BO-4';"));
      expect(page, contains('Catalogue commercial IzyTel'));
      expect(page, contains('Nouvelle offre'));
      expect(page, contains('Synchroniser historique'));
      expect(page, contains('Suspendre'));
      expect(page, contains('Réactiver'));
      expect(page, contains('Prix de vente (FCFA)'));
      expect(page, contains('Ordre d’affichage'));
      expect(page, contains('Détails affichés (un élément par ligne)'));
    });

    test('le repository Admin utilise Supabase REST puis Realtime et des RPC', () {
      final String source = _read(
        'lib/features/offers/data/repositories/supabase_admin_offer_repository.dart',
      );

      expect(source, contains("tableName = 'catalog_offers'"));
      expect(source, contains("stream(primaryKey: const <String>['id'])"));
      expect(source, contains('yield await _fetchOffers()'));
      expect(source, contains('izytel_create_catalog_offer'));
      expect(source, contains('izytel_update_catalog_offer'));
      expect(source, contains('izytel_set_catalog_offer_active'));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains("collection('offers')")));
    });

    test('le client Web et le staff lisent le même catalogue Supabase', () {
      final String staff = _read(
        'lib/features/orders/data/repositories/supabase_offer_catalog_repository.dart',
      );
      final String customer = _read(
        'lib/features/customer_order/data/repositories/supabase_customer_offer_repository.dart',
      );
      final String app = _read('lib/app/app.dart');
      final String customerFlow = _read(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      );

      expect(staff, contains("_offersTable = 'catalog_offers'"));
      expect(staff, contains(".eq('is_active', true)"));
      expect(customer, contains("_offersTable = 'catalog_offers'"));
      expect(customer, contains(".eq('is_active', true)"));
      expect(app, contains('SupabaseOfferCatalogRepository()'));
      expect(app, contains('SupabaseAdminOfferRepository()'));
      expect(customerFlow, contains('SupabaseCustomerOfferRepository()'));
      expect(app, contains('SupabaseBootstrap.isInitialized'));
      expect(app, contains('LegacyCatalogBackfillService().runIfNeeded()'));
      expect(customerFlow, contains('SupabaseBootstrap.isInitialized'));
    });

    test('Firestore ne sert plus que de backfill historique ponctuel', () {
      final String backfill = _read(
        'lib/core/migrations/legacy_catalog_backfill_service.dart',
      );
      final String backoffice = _read('lib/backoffice/backoffice_app.dart');

      expect(backfill, contains("collection('offers').get()"));
      expect(backfill, contains('izytel_catalog_backfill_needed'));
      expect(backfill, contains('izytel_import_legacy_catalog_offer'));
      expect(backfill, contains('izytel_finish_catalog_backfill'));
      expect(
        RegExp(r'LegacyCatalogBackfillService\(\)\.runIfNeeded\(\)')
            .allMatches(backoffice)
            .length,
        greaterThanOrEqualTo(2),
      );
    });

    test('la migration crée catalogue, audit, RLS, RPC et Realtime', () {
      final String migration = _read(
        'supabase/migrations/20260915013543_bo4_catalog_supabase_cutover.sql',
      );
      final String hardening = _read(
        'supabase/migrations/20260915014159_bo4_catalog_public_read_hardening.sql',
      );

      expect(migration, contains('create table if not exists public.catalog_offers'));
      expect(
        migration,
        contains('create table if not exists public.catalog_offer_audit_events'),
      );
      expect(migration, contains('enable row level security'));
      expect(migration, contains('izytel_create_catalog_offer'));
      expect(migration, contains('izytel_update_catalog_offer'));
      expect(migration, contains('izytel_set_catalog_offer_active'));
      expect(migration, contains('izytel_import_legacy_catalog_offer'));
      expect(
        migration,
        contains('alter publication supabase_realtime add table public.catalog_offers'),
      );
      expect(hardening, contains('is_active = true'));
      expect(
        hardening,
        contains(
          'imported_count = public.catalog_migration_state.imported_count + excluded.imported_count',
        ),
      );
    });

    test('le nouvel écran Catalogue ne crée pas de flux métier Firestore', () {
      final List<String> files = <String>[
        'lib/backoffice/presentation/pages/catalog/backoffice_offers_page.dart',
        'lib/features/offers/data/repositories/supabase_admin_offer_repository.dart',
        'lib/features/orders/data/repositories/supabase_offer_catalog_repository.dart',
        'lib/features/customer_order/data/repositories/supabase_customer_offer_repository.dart',
      ];
      for (final String path in files) {
        final String source = _read(path);
        expect(source, isNot(contains('FirebaseFirestore')));
        expect(source, isNot(contains("collection('offers')")));
      }
    });
  });
}
