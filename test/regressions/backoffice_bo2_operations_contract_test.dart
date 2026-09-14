import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-2 - opérations Back-office', () {
    test('le back-office partage les repositories operationnels du mobile', () {
      final String app = File('lib/backoffice/backoffice_app.dart').readAsStringSync();

      expect(app, contains('HybridOrdersRepository()'));
      expect(app, contains('FirestoreOrdersRepository()'));
      expect(app, contains('FirestoreAgentRepository()'));
      expect(app, contains('SupabaseBootstrap.isInitialized'));
      expect(app, contains('ordersRepository: widget.ordersRepository'));
      expect(app, contains('agentRepository: widget.agentRepository'));
    });

    test('les quatre destinations BO-2 ne sont plus des placeholders', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();

      expect(shell, contains('BackofficeOrdersPage('));
      expect(shell, contains('BackofficePaymentsPage('));
      expect(shell, contains('BackofficeAssignmentsPage('));
      expect(shell, contains('BackofficeFailedOrdersPage('));
      expect(shell, contains('_openAssignmentsFor'));
    });

    test('Commandes garde recherche filtres detail et passage vers affectation', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_orders_page.dart',
      ).readAsStringSync();

      expect(source, contains("title: 'Centre des commandes'"));
      expect(source, contains('watchOrderHistory()'));
      expect(source, contains('showBackofficeOrderDetails'));
      expect(source, contains('onOpenAssignments'));
      expect(source, contains('DropdownButtonFormField<_OrdersScope>'));
    });

    test('Paiements reutilise le ViewModel valide et confirme via le repository', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_payments_page.dart',
      ).readAsStringSync();

      expect(source, contains('PaymentsViewModel('));
      expect(source, contains('_viewModel.confirmPayment'));
      expect(source, contains("title: 'Centre de vérification des paiements'"));
      expect(source, contains('PaymentOrderFilter.values'));
    });

    test('Affectations reutilise les regles eligibilite et capacite existantes', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_assignments_page.dart',
      ).readAsStringSync();

      expect(source, contains('AgentAssignmentViewModel('));
      expect(source, contains('watchPaidQueue()'));
      expect(source, contains('candidate.capacity'));
      expect(source, contains('_viewModel.assign(candidate)'));
    });

    test('Echecs choisit entre reaffectation et remboursement selon le paiement', () {
      final String source = File(
        'lib/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart',
      ).readAsStringSync();

      expect(source, contains('prepareFailedOrderForReassignment'));
      expect(source, contains('order.isFundedForProcessing'));
      expect(source, contains('onOpenAssignments(reopened)'));
      expect(source, contains('order.paymentStatus == OrderPaymentStatus.confirmed'));
      expect(source, contains('origin: RefundOrigin.failedOrder'));
      expect(source, contains("label: const Text('Rembourser')"));
      expect(source, contains("? 'Traiter'"));
      expect(source, contains('Voir remboursement'));
    });

    test('BO-2 reste dans le design system light premium IzyTel', () {
      final String widgets = File(
        'lib/backoffice/presentation/widgets/backoffice_order_widgets.dart',
      ).readAsStringSync();

      expect(widgets, contains('BackofficePalette.primarySoft'));
      expect(widgets, contains('backofficePanelDecoration'));
      expect(widgets, contains('Symbols.receipt_long_rounded'));
      expect(widgets, contains('fill: 1'));
      expect(widgets, isNot(contains('Color(0xFF020617)')));
    });
  });
}
