import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-3A - support transactionnel lié', () {
    test('Demandes clients reçoit commandes et remboursements dans le shell', () {
      final String shell = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();
      expect(shell, contains('refundRepository: refundRepository'));
      expect(shell, contains('orderHistoryRepository: historyRepository'));
      expect(shell, contains('onOpenRefunds: _openRefundsForReference'));
      expect(shell, contains('initialOrderReference: _supportFocusOrderReference'));
      expect(shell, contains('supportRepository: widget.supportRepository'));
      expect(shell, contains('onOpenSupportRequests: _openSupportForReference'));
      expect(shell, contains('initialOrderReference: _refundFocusOrderReference'));
    });

    test('une demande peut créer un remboursement lié', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      ).readAsStringSync();
      expect(source, contains('widget.refundRepository.create('));
      expect(source, contains('origin: RefundOrigin.supportRequest'));
      expect(source, contains('supportRequestId: request.id'));
      expect(source, contains('orderHistoryRepository.fetchOrderById'));
      expect(source, contains('Créer remboursement'));
      expect(source, contains('request.status == SupportRequestStatus.inProgress'));
      expect(source, contains('Voir le remboursement'));
      expect(source, contains('Remboursement •'));
      expect(source, contains('widget.repository.resolve('));
    });

    test('la notification support ouvre réellement WhatsApp avant de tracer', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart',
      ).readAsStringSync();
      expect(source, contains('BackofficeWhatsAppService.openMessage('));
      expect(source, contains('Message WhatsApp réellement envoyé ?'));
      expect(source, contains('markCustomerNotified('));
    });

    test('la notification remboursement synchronise la demande client', () {
      final String source = File(
        'lib/backoffice/presentation/pages/clients/backoffice_refunds_page.dart',
      ).readAsStringSync();
      expect(source, contains('BackofficeWhatsAppService.openMessage('));
      expect(source, contains('support.resolve('));
      expect(source, contains('support.markCustomerNotified('));
      expect(source, contains('refund.supportRequestId'));
      expect(source, contains('Voir la demande client'));
    });

    test('le service WhatsApp utilise wa.me et une application externe', () {
      final String source = File(
        'lib/backoffice/presentation/services/backoffice_whatsapp_service.dart',
      ).readAsStringSync();
      expect(source, contains("Uri.https('wa.me'"));
      expect(source, contains('LaunchMode.externalApplication'));
      expect(source, contains("return '225\$digits';"));
    });
  });
}
