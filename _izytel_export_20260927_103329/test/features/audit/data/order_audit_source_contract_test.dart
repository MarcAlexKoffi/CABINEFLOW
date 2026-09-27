import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '11C lit les sources réelles et ne reconstruit plus la chronologie depuis orders',
    () {
      final String repository = File(
        'lib/features/audit/data/repositories/firestore_order_audit_repository.dart',
      ).readAsStringSync();
      final String detailPage = File(
        'lib/features/orders/presentation/pages/order_detail_page.dart',
      ).readAsStringSync();

      expect(repository, contains("collection('orderEvents')"));
      expect(repository, contains("collection('supportRequests')"));
      expect(repository, contains("collection('refunds')"));
      expect(
        repository,
        contains("where('orderId', isEqualTo: cleanedOrderId)"),
      );
      expect(detailPage, contains("title: 'Journal d’activité'"));
      expect(detailPage, isNot(contains('_timelineEntries()')));
      expect(detailPage, isNot(contains("title: 'Chronologie'")));
    },
  );
}
