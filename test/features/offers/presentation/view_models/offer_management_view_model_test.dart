import 'dart:async';

import 'package:cabine_flow/features/offers/data/repositories/fake_admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/presentation/view_models/offer_management_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AdminOffer offer({
    required String id,
    required MobileNetwork network,
    required OfferService service,
    required bool isActive,
  }) {
    return AdminOffer(
      id: id,
      network: network,
      service: service,
      operationType: service == OfferService.internet
          ? OrderOperationType.internetSubscription
          : OrderOperationType.callBundle,
      title: 'Offre $id',
      catalogLabel: 'Offre $id',
      sellingPrice: 1000,
      details: const <String>[],
      category: service == OfferService.internet ? 'internet' : 'calls',
      isActive: isActive,
      displayOrder: 1,
    );
  }

  test('filtre les offres par réseau, service et statut', () async {
    final FakeAdminOfferRepository repository = FakeAdminOfferRepository(
      initialOffers: <AdminOffer>[
        offer(
          id: 'orange-internet',
          network: MobileNetwork.orange,
          service: OfferService.internet,
          isActive: true,
        ),
        offer(
          id: 'orange-calls',
          network: MobileNetwork.orange,
          service: OfferService.calls,
          isActive: false,
        ),
        offer(
          id: 'mtn-internet',
          network: MobileNetwork.mtn,
          service: OfferService.internet,
          isActive: true,
        ),
      ],
    );
    final OfferManagementViewModel viewModel = OfferManagementViewModel(
      repository: repository,
    );
    addTearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    viewModel.start();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.offers, hasLength(3));
    expect(viewModel.activeCount, 2);
    expect(viewModel.suspendedCount, 1);

    viewModel.setNetworkFilter(MobileNetwork.orange);
    expect(viewModel.filteredOffers, hasLength(2));

    viewModel.setServiceFilter(OfferService.calls);
    expect(viewModel.filteredOffers, hasLength(1));
    expect(viewModel.filteredOffers.single.id, 'orange-calls');

    viewModel.setStatusFilter(OfferStatusFilter.active);
    expect(viewModel.filteredOffers, isEmpty);
  });

  test('suspend et réactive une offre depuis le repository', () async {
    final FakeAdminOfferRepository repository = FakeAdminOfferRepository(
      initialOffers: <AdminOffer>[
        offer(
          id: 'orange-internet',
          network: MobileNetwork.orange,
          service: OfferService.internet,
          isActive: true,
        ),
      ],
    );
    final OfferManagementViewModel viewModel = OfferManagementViewModel(
      repository: repository,
    );
    addTearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    viewModel.start();
    await Future<void>.delayed(Duration.zero);
    final AdminOffer current = viewModel.offers.single;

    expect(await viewModel.setOfferActive(current, false), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.offers.single.isActive, isFalse);

    expect(await viewModel.setOfferActive(viewModel.offers.single, true), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.offers.single.isActive, isTrue);
  });
}
