import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';

abstract class AdminOfferRepository {
  Stream<List<AdminOffer>> watchOffers();

  Future<String> createOffer(AdminOfferDraft draft);

  Future<void> updateOffer({
    required String offerId,
    required AdminOfferDraft draft,
  });

  Future<void> setOfferActive({
    required String offerId,
    required bool isActive,
  });
}
