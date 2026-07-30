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
    await _loadOffers();
  }

  Future<void> selectNetwork(MobileNetwork network) async {
    if (_selectedNetwork == network) {
      return;
    }

    _selectedNetwork = network;
    _selectedOperationType = null;
    _selectedOfferId = null;

    notifyListeners();

    await _loadOffers();
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

  Future<void> _loadOffers() async {
    _isLoadingOffers = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _networkOffers = await _offerCatalogRepository.fetchOffers(
        network: _selectedNetwork,
      );
    } catch (_) {
      _errorMessage = 'Impossible de charger le catalogue des offres.';
    } finally {
      _isLoadingOffers = false;
      notifyListeners();
    }
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
