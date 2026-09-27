import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('acceptation Cabiniste demarre puis ouvre directement le detail', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains('await widget.repository.accept(order.orderId)'));
    expect(shell, contains('await widget.repository.startProcessing(order.orderId)'));
    expect(shell, contains('initialOrder: treatmentOrder'));
    expect(shell, contains('PartnerOrderDetailPage('));
  });

  test('detail Cabiniste reprend les blocs essentiels du detail Agent', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    for (final String label in <String>[
      "label: 'Client'",
      "label: 'Paiement'",
      "label: 'Détails de l’offre'",
      "label: 'Preuve'",
      "label: 'Journal d’activité'",
      "label: 'Demande client'",
      "label: 'Remboursement'",
      "'Payée'",
      "'Affectée'",
      "'En traitement'",
      "'Terminée'",
    ]) {
      expect(shell, contains(label), reason: label);
    }

    expect(shell, contains('_PartnerProcessingBottomActions'));
    expect(shell, contains("'Mettre en attente'"));
    expect(shell, contains("'Marquer comme réussie'"));
  });

  test('mise en attente utilise une bottom sheet possedant son controleur', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(shell, contains('class _PartnerHoldReasonSheet extends StatefulWidget'));
    expect(shell, contains('showModalBottomSheet<String>('));
    expect(shell, contains('builder: (_) => const _PartnerHoldReasonSheet()'));
    expect(shell, contains("'Réseau momentanément indisponible'"));
    expect(shell, isNot(contains('Future<String?> _askReason(')));
  });

  test('snapshot Cabiniste transporte les donnees affichees par le detail', () {
    final String model = source(
      'lib/features/partners/domain/models/partner_order_models.dart',
    );
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    for (final String field in <String>[
      'clientName',
      'clientWhatsappPhone',
      'paymentStatus',
      'paymentReference',
      'firebaseCreatedAt',
      'assignedAt',
      'lastHeldAt',
      'lastResumedAt',
    ]) {
      expect(model, contains(field), reason: field);
    }
    expect(repository, contains('client_whatsapp_phone'));
    expect(repository, contains('payment_reference'));
    expect(repository, contains('last_held_at'));
    expect(repository, contains('last_resumed_at'));
    expect(repository, contains('loadProofBytes'));
  });
}
