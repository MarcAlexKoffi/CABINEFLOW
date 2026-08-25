import 'dart:async';

import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';

class FakeAdminOfferRepository implements AdminOfferRepository {
  FakeAdminOfferRepository({
    List<AdminOffer> initialOffers = const <AdminOffer>[],
  }) : _offers = List<AdminOffer>.from(initialOffers);

  final List<AdminOffer> _offers;
  final StreamController<List<AdminOffer>> _controller =
      StreamController<List<AdminOffer>>.broadcast();

  @override
  Stream<List<AdminOffer>> watchOffers() {
    late final StreamController<List<AdminOffer>> controller;
    controller = StreamController<List<AdminOffer>>(
      onListen: () {
        controller.add(List<AdminOffer>.unmodifiable(_offers));
        final StreamSubscription<List<AdminOffer>> sub = _controller.stream
            .listen(controller.add);
        controller.onCancel = () => sub.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<String> createOffer(AdminOfferDraft draft) async {
    final String id = 'fake-offer-${_offers.length + 1}';
    _offers.add(
      AdminOffer(
        id: id,
        network: draft.network,
        service: draft.service,
        operationType: draft.operationType,
        title: draft.title,
        catalogLabel: draft.catalogLabel,
        sellingPrice: draft.sellingPrice,
        details: draft.details,
        category: draft.category,
        isActive: draft.isActive,
        displayOrder: draft.displayOrder,
        description: draft.description,
        badgeLabel: draft.badgeLabel,
        validity: draft.validity,
        volume: draft.volume,
        minutes: draft.minutes,
        sms: draft.sms,
        eligibility: draft.eligibility,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> updateOffer({
    required String offerId,
    required AdminOfferDraft draft,
  }) async {
    final int index = _offers.indexWhere(
      (AdminOffer item) => item.id == offerId,
    );
    if (index < 0) throw StateError('Offre introuvable.');
    final AdminOffer current = _offers[index];
    _offers[index] = AdminOffer(
      id: offerId,
      network: draft.network,
      service: draft.service,
      operationType: draft.operationType,
      title: draft.title,
      catalogLabel: draft.catalogLabel,
      sellingPrice: draft.sellingPrice,
      details: draft.details,
      category: draft.category,
      isActive: draft.isActive,
      displayOrder: draft.displayOrder,
      description: draft.description,
      badgeLabel: draft.badgeLabel,
      validity: draft.validity,
      volume: draft.volume,
      minutes: draft.minutes,
      sms: draft.sms,
      eligibility: draft.eligibility,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    _emit();
  }

  @override
  Future<void> setOfferActive({
    required String offerId,
    required bool isActive,
  }) async {
    final int index = _offers.indexWhere(
      (AdminOffer item) => item.id == offerId,
    );
    if (index < 0) throw StateError('Offre introuvable.');
    _offers[index] = _offers[index].copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<AdminOffer>.unmodifiable(_offers));
    }
  }

  Future<void> dispose() => _controller.close();
}
