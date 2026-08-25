import 'dart:async';

import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/foundation.dart';

class OfferManagementViewModel extends ChangeNotifier {
  OfferManagementViewModel({required AdminOfferRepository repository})
    : _repository = repository;

  final AdminOfferRepository _repository;
  StreamSubscription<List<AdminOffer>>? _subscription;

  List<AdminOffer> _offers = const <AdminOffer>[];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  MobileNetwork? _networkFilter;
  OfferService? _serviceFilter;
  OfferStatusFilter _statusFilter = OfferStatusFilter.all;
  final Set<String> _busyOfferIds = <String>{};

  List<AdminOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  MobileNetwork? get networkFilter => _networkFilter;
  OfferService? get serviceFilter => _serviceFilter;
  OfferStatusFilter get statusFilter => _statusFilter;
  bool isBusy(String id) => _busyOfferIds.contains(id);

  int get activeCount => _offers.where((AdminOffer o) => o.isActive).length;
  int get suspendedCount => _offers.length - activeCount;

  List<AdminOffer> get filteredOffers {
    final String query = _normalized(_searchQuery);
    return _offers.where((AdminOffer offer) {
      if (_networkFilter != null && offer.network != _networkFilter) {
        return false;
      }
      if (_serviceFilter != null && offer.service != _serviceFilter) {
        return false;
      }
      if (_statusFilter == OfferStatusFilter.active && !offer.isActive) {
        return false;
      }
      if (_statusFilter == OfferStatusFilter.suspended && offer.isActive) {
        return false;
      }
      if (query.isEmpty) return true;

      final String haystack = _normalized(<String>[
        offer.title,
        offer.catalogLabel,
        offer.network.name,
        offer.service.label,
        offer.description ?? '',
        offer.validity ?? '',
        offer.volume ?? '',
        offer.minutes ?? '',
        offer.sms ?? '',
      ].join(' '));
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void start() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchOffers().listen(
      (List<AdminOffer> offers) {
        _offers = offers;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _errorMessage =
            'Impossible de charger les offres. Vérifie ta connexion puis réessaie.';
        notifyListeners();
      },
    );
  }

  void updateSearch(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void setNetworkFilter(MobileNetwork? value) {
    _networkFilter = _networkFilter == value ? null : value;
    notifyListeners();
  }

  void setServiceFilter(OfferService? value) {
    _serviceFilter = _serviceFilter == value ? null : value;
    notifyListeners();
  }

  void setStatusFilter(OfferStatusFilter value) {
    _statusFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    _networkFilter = null;
    _serviceFilter = null;
    _statusFilter = OfferStatusFilter.all;
    _searchQuery = '';
    notifyListeners();
  }

  Future<bool> setOfferActive(AdminOffer offer, bool isActive) async {
    if (_busyOfferIds.contains(offer.id)) return false;
    _busyOfferIds.add(offer.id);
    notifyListeners();
    try {
      await _repository.setOfferActive(offerId: offer.id, isActive: isActive);
      return true;
    } catch (_) {
      _errorMessage = isActive
          ? 'Impossible de réactiver cette offre.'
          : 'Impossible de suspendre cette offre.';
      return false;
    } finally {
      _busyOfferIds.remove(offer.id);
      notifyListeners();
    }
  }

  String _normalized(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum OfferStatusFilter { all, active, suspended }
