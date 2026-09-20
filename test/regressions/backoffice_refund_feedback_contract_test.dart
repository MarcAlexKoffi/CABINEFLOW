import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Back-office - feedback remboursements du 14/09', () {
    test('une demande client ne cree jamais automatiquement un remboursement', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      ).readAsStringSync();

      expect(source, contains("child: const Text('Traiter')"));
      expect(source, contains('Résoudre sans remboursement'));
      expect(source, contains('request.status == SupportRequestStatus.inProgress'));
      expect(source, contains('origin: RefundOrigin.supportRequest'));
      expect(source, contains('Voir le remboursement'));
    });

    test('la page remboursements permet une creation manuelle tracee sur une commande payee', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      ).readAsStringSync();

      expect(source, contains("label: const Text('Nouveau remboursement')"));
      expect(source, contains('fetchOrderHistory()'));
      expect(source, contains('order.paymentStatus == OrderPaymentStatus.confirmed'));
      expect(source, contains('order.status != QueueOrderStatus.refundPending'));
      expect(source, contains('order.status != QueueOrderStatus.refunded'));
      expect(source, contains('origin: RefundOrigin.manual'));
    });

    test('une commande echouee payee propose un choix et le credit ne devient pas un remboursement Wave', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart',
      ).readAsStringSync();

      expect(source, contains('order.paymentStatus == OrderPaymentStatus.confirmed'));
      expect(source, contains('order.isFundedForProcessing'));
      expect(source, contains("Navigator.pop(dialogContext, 'reassign')"));
      expect(source, contains("Navigator.pop(dialogContext, 'refund')"));
      expect(source, contains('origin: RefundOrigin.failedOrder'));
      expect(source, contains('Voir remboursement'));
    });

    test('les filtres remboursements distinguent total de vue et resultats recherches', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      ).readAsStringSync();

      expect(source, contains("tooltip: 'Effacer la recherche'"));
      expect(source, contains(r"'${data.total} résultat"));
      expect(source, contains('après recherche et filtres'));
      expect(source, contains('BackofficePaginationBar'));
    });

    test('Support et remboursements sont operationnels Supabase et non Firestore', () {
      final String app = File('lib/backoffice/backoffice_app.dart').readAsStringSync();
      final String support = File(
        'lib/features/support/data/repositories/supabase_support_request_repository.dart',
      ).readAsStringSync();
      final String refunds = File(
        'lib/features/refunds/data/repositories/supabase_refund_repository.dart',
      ).readAsStringSync();
      final String customerWeb = File('lib/main_customer_web.dart').readAsStringSync();

      expect(app, contains('createOperationalSupportRequestRepository()'));
      expect(app, contains('createOperationalRefundRepository()'));
      expect(support, contains("static const String tableName = 'support_requests'"));
      expect(refunds, contains("static const String tableName = 'refunds'"));
      expect(refunds, contains("'izytel_create_refund'"));
      expect(customerWeb, contains('SupabaseBootstrap.initialize()'));
      expect(app, isNot(contains('FirestoreSupportRequestRepository()')));
      expect(app, isNot(contains('FirestoreRefundRepository()')));
    });


    test('la migration Supabase publie support et remboursements sans etendre Firestore', () {
      final String sql = File(
        'supabase/migrations/20260914105144_support_refunds_supabase_cutover.sql',
      ).readAsStringSync();

      expect(sql, contains('create table if not exists public.support_requests'));
      expect(sql, contains('create table if not exists public.refunds'));
      expect(sql, contains('public.izytel_create_refund'));
      expect(sql, contains('private.is_izytel_finance_admin()'));
      expect(sql, contains("v_order.payment_status <> 'confirmed'"));
      expect(sql, contains("p_origin not in ('supportRequest', 'failedOrder', 'manual')"));
      expect(sql, isNot(contains('match /refunds/{refundId}')));
    });
  });
}
