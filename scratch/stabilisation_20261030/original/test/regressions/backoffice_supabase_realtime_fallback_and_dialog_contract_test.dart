import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Back-office - fallback Supabase et dialogues', () {
    test('Support charge d abord via Data API et ne propage pas une panne Realtime', () {
      final String source = read(
        'lib/features/support/data/repositories/supabase_support_request_repository.dart',
      );
      expect(source, contains("from(tableName).select()"));
      expect(source, contains("stream(primaryKey: const <String>['id'])"));
      expect(source, contains('SupabaseSupportRequestRepository.Realtime'));
      expect(source, contains('yield await _fetch'));
    });

    test('Remboursements charge d abord via Data API et ne propage pas une panne Realtime', () {
      final String source = read(
        'lib/features/refunds/data/repositories/supabase_refund_repository.dart',
      );
      expect(source, contains("from(tableName).select()"));
      expect(source, contains("stream(primaryKey: const <String>['order_id'])"));
      expect(source, contains('SupabaseRefundRepository.Realtime'));
      expect(source, contains('yield await _fetch'));
    });

    test('les actions Support et Remboursements forcent une relecture REST locale', () {
      final String support = read(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      );
      final String refunds = read(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      );
      expect(support, contains('void _reload({bool resetPage = false})'));
      expect(support, contains('setState(() => _pageFuture = _fetchPage())'));
      expect(refunds, contains('void _reload({bool resetPage = false})'));
      expect(refunds, contains('setState(() => _pageFuture = _fetchPage())'));
    });

    test('le detail utilisateur est scrollable et ne peut plus deborder en hauteur', () {
      final String users = read(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      );
      expect(users, contains('BackofficeModalShell('));
      expect(users, contains('SingleChildScrollView('));
      expect(users, contains("label: 'Dernière activité'"));
    });
  });
}
