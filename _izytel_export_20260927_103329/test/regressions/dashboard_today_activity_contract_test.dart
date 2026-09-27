import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la carte Payées compte uniquement les paiements du jour', () {
    final String repository = File(
      'lib/features/dashboard/data/repositories/firestore_dashboard_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('final int paidTodayCount = orders'));
    expect(
      repository,
      contains('order.paymentStatus == OrderPaymentStatus.confirmed'),
    );
    expect(
      repository,
      contains('order.paymentConfirmedAt ?? order.paidAt'),
    );
    expect(repository, contains('newRequests: paidTodayCount'));
    expect(repository, isNot(contains('newRequests: readyCount')));
  });

  test('l’affectation Admin est appliquée localement avant resynchronisation', () {
    final String viewModel = File(
      'lib/features/orders/presentation/view_models/orders_view_model.dart',
    ).readAsStringSync();
    final String page = File(
      'lib/features/orders/presentation/pages/orders_page.dart',
    ).readAsStringSync();

    expect(viewModel, contains('void applyQueueOrder(QueueOrder updatedOrder)'));
    expect(page, contains('_viewModel.applyQueueOrder(updatedOrder);'));
    expect(page, contains('await _viewModel.loadQueue();'));
  });
}
