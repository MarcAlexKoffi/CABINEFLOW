import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

class OfferEditorViewModel extends ChangeNotifier {
  OfferEditorViewModel({
    required AdminOfferRepository repository,
    this.existingOffer,
  }) : _repository = repository,
       network = existingOffer?.network ?? MobileNetwork.orange,
       service = existingOffer?.service ?? OfferService.internet,
       operationType =
           existingOffer?.operationType ??
           OrderOperationType.internetSubscription,
       isActive = existingOffer?.isActive ?? true;

  final AdminOfferRepository _repository;
  final AdminOffer? existingOffer;

  MobileNetwork network;
  OfferService service;
  OrderOperationType operationType;
  bool isActive;
  bool isSaving = false;
  String? errorMessage;

  bool get isEditing => existingOffer != null;

  void setNetwork(MobileNetwork value) {
    network = value;
    notifyListeners();
  }

  void setService(OfferService value) {
    service = value;
    if (value == OfferService.internet) {
      operationType = OrderOperationType.internetSubscription;
    } else if (operationType == OrderOperationType.internetSubscription) {
      operationType = OrderOperationType.callBundle;
    }
    notifyListeners();
  }

  void setOperationType(OrderOperationType value) {
    operationType = value;
    notifyListeners();
  }

  void setActive(bool value) {
    isActive = value;
    notifyListeners();
  }

  Future<bool> save({
    required String title,
    required int sellingPrice,
    required int displayOrder,
    String? volume,
    String? validity,
    String? minutes,
    String? sms,
    String? description,
  }) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    final String cleanedTitle = title.trim();
    final String? cleanedVolume = _clean(volume);
    final String? cleanedValidity = _clean(validity);
    final String? cleanedMinutes = _clean(minutes);
    final String? cleanedSms = _clean(sms);
    final bool characteristicsUnchanged =
        existingOffer != null &&
        _same(cleanedVolume, existingOffer!.volume) &&
        _same(cleanedValidity, existingOffer!.validity) &&
        _same(cleanedMinutes, existingOffer!.minutes) &&
        _same(cleanedSms, existingOffer!.sms);
    final List<String> details = characteristicsUnchanged
        ? existingOffer!.details
        : _buildDetails(
            volume: cleanedVolume,
            validity: cleanedValidity,
            minutes: cleanedMinutes,
            sms: cleanedSms,
          );
    final String catalogLabel = _buildCatalogLabel(
      title: cleanedTitle,
      validity: cleanedValidity,
    );
    final String category = operationType == OrderOperationType.mixedBundle
        ? 'mixed'
        : service == OfferService.calls
        ? 'calls'
        : 'internet';

    final AdminOfferDraft draft = AdminOfferDraft(
      network: network,
      service: service,
      operationType: operationType,
      title: cleanedTitle,
      catalogLabel: catalogLabel,
      sellingPrice: sellingPrice,
      details: details,
      category: category,
      isActive: isActive,
      displayOrder: displayOrder,
      volume: cleanedVolume,
      validity: cleanedValidity,
      minutes: cleanedMinutes,
      sms: cleanedSms,
      description: _clean(description),
      eligibility: existingOffer?.eligibility,
      badgeLabel: existingOffer?.badgeLabel,
    );

    try {
      if (existingOffer == null) {
        await _repository.createOffer(draft);
      } else {
        await _repository.updateOffer(offerId: existingOffer!.id, draft: draft);
      }
      return true;
    } catch (_) {
      errorMessage = isEditing
          ? 'Impossible d’enregistrer les modifications de cette offre.'
          : 'Impossible de créer cette offre.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  List<String> _buildDetails({
    String? volume,
    String? validity,
    String? minutes,
    String? sms,
  }) {
    final List<String> values = <String>[];
    if (minutes != null) values.add(minutes);
    if (volume != null) values.add(volume);
    if (sms != null) values.add(sms);
    if (validity != null) values.add('Validité : $validity');
    return values;
  }

  String _buildCatalogLabel({
    required String title,
    required String? validity,
  }) {
    final AdminOffer? current = existingOffer;
    if (current != null &&
        current.title.trim() == title &&
        current.network == network &&
        current.service == service) {
      return current.catalogLabel;
    }

    final String networkLabel = switch (network) {
      MobileNetwork.orange => 'Orange',
      MobileNetwork.mtn => 'MTN',
      MobileNetwork.moov => 'Moov',
    };

    if (service == OfferService.internet) {
      final String suffix = validity == null ? '' : ' - $validity';
      return 'Internet $networkLabel $title$suffix';
    }

    return '$networkLabel $title';
  }

  bool _same(String? first, String? second) {
    return _clean(first) == _clean(second);
  }

  String? _clean(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
