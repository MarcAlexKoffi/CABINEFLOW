import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';

abstract class AdminOfferRepository {
  Future<List<AdminOffer>> fetchOffers();

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

  /// Retire l'offre du catalogue courant tout en préservant l'historique.
  Future<void> deleteOffer({required String offerId});
}
