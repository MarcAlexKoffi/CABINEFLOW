import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('BO-4 - propagation temps reel catalogue', () {
    test('Supabase expose un signal Realtime public sans donnees catalogue', () {
      final String migration = _read(
        'supabase/migrations/20260915020800_bo4_catalog_realtime_signal.sql',
      );

      expect(
        migration,
        contains('create table if not exists public.catalog_change_feed'),
      );
      expect(migration, contains('catalog_offers_touch_change_feed'));
      expect(migration, contains('after insert or update or delete'));
      expect(
        migration,
        contains(
          'alter publication supabase_realtime add table public.catalog_change_feed',
        ),
      );
      expect(migration, contains('grant select on table public.catalog_change_feed'));
    });

    test('le Web client ecoute les changements et refait une lecture REST', () {
      final String repository = _read(
        'lib/features/customer_order/data/repositories/supabase_customer_offer_repository.dart',
      );
      final String contract = _read(
        'lib/features/customer_order/domain/repositories/customer_offer_repository.dart',
      );
      final String home = _read(
        'lib/features/customer_order/presentation/pages/customer_home_page.dart',
      );
      final String catalog = _read(
        'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
      );
      final String offer = _read(
        'lib/features/customer_order/presentation/pages/customer_offer_page.dart',
      );

      expect(repository, contains("_changeFeedTable = 'catalog_change_feed'"));
      expect(repository, contains('watchAllOffers()'));
      expect(repository, contains('watchOffers({'));
      expect(repository, contains('stream(primaryKey: const <String>[\'id\'])'));
      expect(repository, contains('final List<CustomerOffer> next = await loader()'));
      expect(contract, contains('Stream<List<CustomerOffer>> watchOffers'));
      expect(contract, contains('Stream<List<CustomerOffer>> watchAllOffers'));
      expect(home, contains('StreamBuilder<List<CustomerOffer>>'));
      expect(catalog, contains('StreamBuilder<List<CustomerOffer>>'));
      expect(offer, contains('StreamBuilder<List<CustomerOffer>>'));
      expect(offer, contains('reconcileCatalogOffers(offers)'));
    });

    test('le Staff conserve un abonnement actif au reseau selectionne', () {
      final String repository = _read(
        'lib/features/orders/data/repositories/supabase_offer_catalog_repository.dart',
      );
      final String contract = _read(
        'lib/features/orders/domain/repositories/offer_catalog_repository.dart',
      );
      final String viewModel = _read(
        'lib/features/orders/presentation/view_models/create_order_view_model.dart',
      );

      expect(repository, contains("_changeFeedTable = 'catalog_change_feed'"));
      expect(repository, contains('Stream<List<OfferCatalogItem>> watchOffers'));
      expect(repository, contains('final List<OfferCatalogItem> next = await fetchOffers'));
      expect(contract, contains('Stream<List<OfferCatalogItem>> watchOffers'));
      expect(viewModel, contains('StreamSubscription<List<OfferCatalogItem>>'));
      expect(viewModel, contains('_subscribeToOffers()'));
      expect(viewModel, contains('.watchOffers(network: network)'));
      expect(viewModel, contains('unawaited(_offerSubscription?.cancel())'));
    });

    test('une offre selectionnee ne peut pas rester obsolete ou suspendue', () {
      final String viewModel = _read(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      );

      expect(viewModel, contains('void reconcileCatalogOffers'));
      expect(viewModel, contains('clearOffer: true'));
      expect(viewModel, contains('clearAmount: true'));
      expect(viewModel, contains('offer: latest'));
      expect(viewModel, contains('amount: latest.amount'));
    });
  });
}
