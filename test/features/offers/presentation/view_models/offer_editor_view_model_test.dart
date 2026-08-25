import 'dart:async';

import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/presentation/view_models/offer_editor_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crée une nouvelle offre active', () async {
    final FakeAdminOfferRepository repository = FakeAdminOfferRepository();
    addTearDown(repository.dispose);
    final OfferEditorViewModel viewModel = OfferEditorViewModel(
      repository: repository,
    );
    addTearDown(viewModel.dispose);

    final Future<List<AdminOffer>> firstNonEmpty = repository
        .watchOffers()
        .firstWhere((List<AdminOffer> offers) => offers.isNotEmpty);

    final bool saved = await viewModel.save(
      title: 'Pass Test',
      sellingPrice: 1500,
      displayOrder: 2,
      validity: '7 jours',
      volume: '2 Go',
    );

    expect(saved, isTrue);
    final List<AdminOffer> offers = await firstNonEmpty;
    expect(offers, hasLength(1));
    expect(offers.single.title, 'Pass Test');
    expect(offers.single.sellingPrice, 1500);
    expect(offers.single.network, MobileNetwork.orange);
    expect(offers.single.service, OfferService.internet);
    expect(offers.single.isActive, isTrue);
  });

  test('modifie une offre sans perdre son identifiant', () async {
    const AdminOffer initial = AdminOffer(
      id: 'offer-1',
      network: MobileNetwork.mtn,
      service: OfferService.calls,
      operationType: OrderOperationType.callBundle,
      title: 'Appels 100',
      catalogLabel: 'MTN Appels 100',
      sellingPrice: 1000,
      details: <String>['100 min'],
      category: 'calls',
      isActive: true,
      displayOrder: 1,
      minutes: '100 min',
    );
    final FakeAdminOfferRepository repository = FakeAdminOfferRepository(
      initialOffers: const <AdminOffer>[initial],
    );
    addTearDown(repository.dispose);
    final OfferEditorViewModel viewModel = OfferEditorViewModel(
      repository: repository,
      existingOffer: initial,
    );
    addTearDown(viewModel.dispose);

    final StreamIterator<List<AdminOffer>> iterator = StreamIterator(
      repository.watchOffers(),
    );
    addTearDown(iterator.cancel);
    await iterator.moveNext();

    final bool saved = await viewModel.save(
      title: 'Appels 100',
      sellingPrice: 1200,
      displayOrder: 1,
      minutes: '100 min',
    );

    expect(saved, isTrue);
    await iterator.moveNext();
    final AdminOffer updated = iterator.current.single;
    expect(updated.id, 'offer-1');
    expect(updated.sellingPrice, 1200);
    expect(updated.catalogLabel, 'MTN Appels 100');
  });
}
