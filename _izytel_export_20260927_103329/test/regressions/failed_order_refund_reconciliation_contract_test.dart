import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Failed order refund reconciliation', () {
    test('legacy unresolved failed orders can be reconciled safely', () {
      final String sql = _read(
        'supabase/migrations/20260915100621_failed_order_refund_legacy_reconciliation.sql',
      );

      expect(sql, contains("p_origin = 'failedOrder'"));
      expect(sql, contains('legacy_state_unresolved'));
      expect(sql, contains('legacy_state_unresolved = false'));
      expect(sql, contains("order_status = 'failed'"));
      expect(sql, contains("raise exception 'FAILED_ORDER_REQUIRED'"));
      expect(sql, contains("payment_status <> 'confirmed'"));
    });

    test('backoffice refreshes the canonical order before a financial action', () {
      final String page = _read(
        'lib/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart',
      );

      expect(page, contains('_freshOrderForTreatment'));
      expect(page, contains('historyRepository.fetchOrderById'));
      expect(page, contains('fresh.status != QueueOrderStatus.failed'));
      expect(page, contains('Aucun remboursement'));
    });

    test('refund repository does not expose raw PostgREST envelopes', () {
      final String repository = _read(
        'lib/features/refunds/data/repositories/supabase_refund_repository.dart',
      );

      expect(repository, contains('_friendlyPostgrestError'));
      expect(repository, contains("'FAILED_ORDER_REQUIRED'"));
      expect(repository, contains("'REFUND_ALREADY_EXISTS'"));
      expect(repository, contains('SupabaseRefunds.create'));
    });
  });
}
