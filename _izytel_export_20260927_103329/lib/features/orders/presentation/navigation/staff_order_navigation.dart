import 'dart:async';

import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_history_page.dart';
import 'package:flutter/material.dart';

/// Central route-based navigation for Admin/Manager order flows.
///
/// Every subpage is a real route. This preserves the exact previous screen:
/// queue -> history -> detail -> customer history -> detail -> history -> queue.
class StaffOrderNavigation {
  const StaffOrderNavigation._();

  static Future<void> openHistory({
    required BuildContext context,
    required AppUser user,
    required OrderHistoryRepository repository,
    String initialSearchQuery = '',
    OrderHistoryFilters initialFilters = const OrderHistoryFilters(),
    bool openFiltersOnStart = false,
  }) {
    return Navigator.of(context).push<void>(
      historyRoute(
        user: user,
        repository: repository,
        initialSearchQuery: initialSearchQuery,
        initialFilters: initialFilters,
        openFiltersOnStart: openFiltersOnStart,
      ),
    );
  }

  static Route<void> historyRoute({
    required AppUser user,
    required OrderHistoryRepository repository,
    String initialSearchQuery = '',
    OrderHistoryFilters initialFilters = const OrderHistoryFilters(),
    bool openFiltersOnStart = false,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: initialSearchQuery.trim().isEmpty
            ? 'staff-order-history'
            : 'staff-customer-order-history',
      ),
      builder: (BuildContext historyContext) {
        return OrderHistoryPage(
          user: user,
          ordersRepository: repository,
          onBack: () {
            Navigator.of(historyContext).maybePop();
          },
          onOpenOrder:
              (
                QueueOrder order,
                String searchQuery,
                OrderHistoryFilters filters,
              ) {
                unawaited(
                  openOrderDetail(
                    context: historyContext,
                    user: user,
                    repository: repository,
                    order: order,
                  ),
                );
              },
          initialSearchQuery: initialSearchQuery,
          initialFilters: initialFilters,
          openFiltersOnStart: openFiltersOnStart,
        );
      },
    );
  }

  static Future<void> openOrderDetail({
    required BuildContext context,
    required AppUser user,
    required OrderHistoryRepository repository,
    required QueueOrder order,
  }) {
    return Navigator.of(context).push<void>(
      orderDetailRoute(
        user: user,
        repository: repository,
        order: order,
      ),
    );
  }

  static Route<void> orderDetailRoute({
    required AppUser user,
    required OrderHistoryRepository repository,
    required QueueOrder order,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: 'staff-order-detail/${order.id}'),
      builder: (BuildContext detailContext) {
        return OrderDetailPage(
          user: user,
          initialOrder: order,
          ordersRepository: repository,
          onBack: () {
            Navigator.of(detailContext).maybePop();
          },
          onOpenCustomerHistory: (String whatsappPhone) {
            unawaited(
              openHistory(
                context: detailContext,
                user: user,
                repository: repository,
                initialSearchQuery: whatsappPhone,
              ),
            );
          },
        );
      },
    );
  }
}
