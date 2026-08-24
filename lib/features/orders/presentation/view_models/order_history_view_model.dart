import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/foundation.dart';

class OrderHistoryViewModel extends ChangeNotifier {
  OrderHistoryViewModel({
    required OrderHistoryRepository ordersRepository,
    String initialSearchQuery = '',
    OrderHistoryFilters initialFilters = const OrderHistoryFilters(),
  }) : _ordersRepository = ordersRepository,
       _searchQuery = initialSearchQuery.trim(),
       _filters = initialFilters;

  static const int pageSize = 20;

  final OrderHistoryRepository _ordersRepository;

  List<QueueOrder> _orders = <QueueOrder>[];
  String _searchQuery;
  OrderHistoryFilters _filters;
  int _visibleCount = pageSize;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  OrderHistoryFilters get filters => _filters;
  bool get hasLoadedOrders => _orders.isNotEmpty;

  List<String> get operatorIds {
    final Set<String> values = _orders
        .map((QueueOrder order) => order.takenByUserId?.trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .toSet();
    final List<String> result = values.toList()..sort();
    return List<String>.unmodifiable(result);
  }

  List<QueueOrder> get filteredOrders {
    Iterable<QueueOrder> result = _orders;
    final String normalizedQuery = _normalize(_searchQuery);

    if (normalizedQuery.isNotEmpty) {
      final String queryDigits = _digitsOnly(_searchQuery);

      result = result.where((QueueOrder order) {
        final List<String> values = <String>[
          order.reference,
          order.clientName,
          order.clientWhatsappPhone,
          order.beneficiaryPhone,
          order.offerLabel,
          operationTypeLabel(order.operationType),
          networkLabel(order.network),
          orderStatusLabel(order.status),
          order.paymentReference ?? '',
          order.paymentDeclaredReference ?? '',
          order.takenByUserId ?? '',
        ];
        final String searchable = _normalize(values.join(' '));

        if (searchable.contains(normalizedQuery)) {
          return true;
        }

        if (queryDigits.length < 4) {
          return false;
        }

        return _digitsOnly(values.join(' ')).contains(queryDigits);
      });
    }

    result = result.where(_matchesPeriod);

    if (_filters.states.isNotEmpty) {
      result = result.where((QueueOrder order) {
        return _filters.states.any((OrderHistoryStateFilter state) {
          return orderMatchesState(order, state);
        });
      });
    }

    if (_filters.networks.isNotEmpty) {
      result = result.where((QueueOrder order) {
        return _filters.networks.contains(order.network);
      });
    }

    final int? minimumAmount = _filters.minimumAmount;
    if (minimumAmount != null) {
      result = result.where((QueueOrder order) {
        return order.amount >= minimumAmount;
      });
    }

    final int? maximumAmount = _filters.maximumAmount;
    if (maximumAmount != null) {
      result = result.where((QueueOrder order) {
        return order.amount <= maximumAmount;
      });
    }

    final String selectedOperator = _filters.operatorId?.trim() ?? '';
    if (selectedOperator.isNotEmpty) {
      result = result.where((QueueOrder order) {
        return order.takenByUserId?.trim() == selectedOperator;
      });
    }

    final List<QueueOrder> orders = result.toList();
    orders.sort((QueueOrder first, QueueOrder second) {
      return second.createdAt.compareTo(first.createdAt);
    });
    return List<QueueOrder>.unmodifiable(orders);
  }

  List<QueueOrder> get visibleOrders {
    final List<QueueOrder> orders = filteredOrders;
    return List<QueueOrder>.unmodifiable(orders.take(_visibleCount).toList());
  }

  bool get canLoadMore => _visibleCount < filteredOrders.length;

  Future<void> loadHistory() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _ordersRepository.fetchOrderHistory();
    } catch (_) {
      _errorMessage = 'Impossible de charger l’historique des commandes.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearchQuery(String value) {
    final String cleaned = value.trimLeft();
    if (_searchQuery == cleaned) {
      return;
    }

    _searchQuery = cleaned;
    _visibleCount = pageSize;
    notifyListeners();
  }

  void applyFilters(OrderHistoryFilters filters) {
    _filters = filters;
    _visibleCount = pageSize;
    notifyListeners();
  }

  void clearAllFilters() {
    _filters = const OrderHistoryFilters();
    _visibleCount = pageSize;
    notifyListeners();
  }

  void loadMore() {
    if (!canLoadMore) {
      return;
    }

    _visibleCount += pageSize;
    notifyListeners();
  }

  bool _matchesPeriod(QueueOrder order) {
    if (_filters.period == OrderHistoryPeriod.all) {
      return true;
    }

    final DateTime now = DateTime.now();
    final DateTime localCreatedAt = order.createdAt.toLocal();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime orderDay = DateTime(
      localCreatedAt.year,
      localCreatedAt.month,
      localCreatedAt.day,
    );

    switch (_filters.period) {
      case OrderHistoryPeriod.today:
        return orderDay == today;
      case OrderHistoryPeriod.yesterday:
        return orderDay == today.subtract(const Duration(days: 1));
      case OrderHistoryPeriod.last7Days:
        return !orderDay.isBefore(today.subtract(const Duration(days: 6)));
      case OrderHistoryPeriod.last30Days:
        return !orderDay.isBefore(today.subtract(const Duration(days: 29)));
      case OrderHistoryPeriod.all:
        return true;
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
