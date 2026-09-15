import 'dart:async';

import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter/foundation.dart';

class CreateOrderViewModel extends ChangeNotifier {
  CreateOrderViewModel({
    required OrdersRepository ordersRepository,
    required OfferCatalogRepository offerCatalogRepository,
  }) : _ordersRepository = ordersRepository,
       _offerCatalogRepository = offerCatalogRepository;

  final OrdersRepository _ordersRepository;
  final OfferCatalogRepository _offerCatalogRepository;

  StreamSubscription<List<OfferCatalogItem>>? _offerSubscription;
  int _offerSubscriptionGeneration = 0;

  MobileNetwork _selectedNetwork = MobileNetwork.orange;
  OrderOperationType? _selectedOperationType;

  List<OfferCatalogItem> _networkOffers = [];

  String? _selectedOfferId;
  String? _errorMessage;

  bool _isLoadingOffers = false;
  bool _isSubmitting = false;

  MobileNetwork get selectedNetwork => _selectedNetwork;

  OrderOperationType? get selectedOperationType => _selectedOperationType;

  String? get selectedOfferId => _selectedOfferId;

  String? get errorMessage => _errorMessage;

  bool get isLoadingOffers => _isLoadingOffers;

  bool get isSubmitting => _isSubmitting;

  List<OfferCatalogItem> get availableOffers {
    final OrderOperationType? operationType = _selectedOperationType;

    if (operationType == null) {
      return const [];
    }

    final List<OfferCatalogItem> filteredOffers = _networkOffers.where((
      OfferCatalogItem offer,
    ) {
      return offer.operationType == operationType;
    }).toList();

    return [
      ...filteredOffers,
      OfferCatalogItem.custom(
        network: _selectedNetwork,
        operationType: operationType,
      ),
    ];
  }

  OfferCatalogItem? get selectedOffer {
    final String? offerId = _selectedOfferId;

    if (offerId == null) {
      return null;
    }

    for (final OfferCatalogItem offer in availableOffers) {
      if (offer.id == offerId) {
        return offer;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    await _subscribeToOffers();
  }

  Future<void> selectNetwork(MobileNetwork network) async {
    if (_selectedNetwork == network) {
      return;
    }

    _selectedNetwork = network;
    _selectedOperationType = null;
    _selectedOfferId = null;

    notifyListeners();

    await _subscribeToOffers();
  }

  void selectOperationType(OrderOperationType? operationType) {
    if (_selectedOperationType == operationType) {
      return;
    }

    _selectedOperationType = operationType;
    _selectedOfferId = null;

    notifyListeners();
  }

  void selectOffer(String? offerId) {
    if (_selectedOfferId == offerId) {
      return;
    }

    _selectedOfferId = offerId;
    notifyListeners();
  }

  Future<void> _subscribeToOffers() async {
    final int generation = ++_offerSubscriptionGeneration;
    final MobileNetwork network = _selectedNetwork;

    await _offerSubscription?.cancel();

    _isLoadingOffers = true;
    _errorMessage = null;
    notifyListeners();

    final Completer<void> firstSnapshot = Completer<void>();

    _offerSubscription = _offerCatalogRepository
        .watchOffers(network: network)
        .listen(
          (List<OfferCatalogItem> offers) {
            if (generation != _offerSubscriptionGeneration ||
                network != _selectedNetwork) {
              return;
            }

            _networkOffers = offers;
            _isLoadingOffers = false;
            _errorMessage = null;
            notifyListeners();

            if (!firstSnapshot.isCompleted) {
              firstSnapshot.complete();
            }
          },
          onError: (Object _, StackTrace _) {
            if (generation == _offerSubscriptionGeneration &&
                network == _selectedNetwork) {
              _isLoadingOffers = false;
              _errorMessage = 'Impossible de charger le catalogue des offres.';
              notifyListeners();
            }
            if (!firstSnapshot.isCompleted) {
              firstSnapshot.complete();
            }
          },
          onDone: () {
            if (!firstSnapshot.isCompleted) {
              if (generation == _offerSubscriptionGeneration &&
                  network == _selectedNetwork) {
                _isLoadingOffers = false;
                notifyListeners();
              }
              firstSnapshot.complete();
            }
          },
        );

    await firstSnapshot.future;
  }

  @override
  void dispose() {
    _offerSubscriptionGeneration += 1;
    unawaited(_offerSubscription?.cancel());
    super.dispose();
  }

  Future<QueueOrder?> createOrder(CreateOrderRequest request) async {
    if (_isSubmitting) {
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;

    notifyListeners();

    try {
      return await _ordersRepository.createOrder(request: request);
    } catch (_) {
      _errorMessage = 'Impossible d’enregistrer la commande.';

      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
