import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('mise en attente Agent est validee sans dependance getAfter', () {
    final String rules = source('firestore.rules');
    final RegExp holdFunction = RegExp(
      r'function isValidAgentProcessingHold\(\) \{([\s\S]*?)\n    \}',
    );
    final Match? match = holdFunction.firstMatch(rules);
    expect(match, isNotNull);
    final String body = match!.group(1)!;
    final String executableBody = body
        .split('\n')
        .where((String line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(executableBody, contains("lastEventType', null) == 'PUT_ON_HOLD'"));
    expect(executableBody, isNot(matches(RegExp(r'\bgetAfter\s*\('))));
    expect(rules, contains('function isValidAgentPutOnHoldEvent()'));
  });

  test('demande client garde le remboursement normal et explique le credit', () {
    final String page = source(
      'lib/features/support/presentation/pages/support_request_center_page.dart',
    );
    expect(page, contains('Créer un remboursement'));
    expect(page, contains('Cette commande a été autorisée à crédit'));
    expect(page, contains('SupportRequestStatus.resolved'));
  });

  test('feedback adapte automatiquement sa couleur au resultat', () {
    final String feedback = source(
      'lib/shared/widgets/izytel/izytel_feedback.dart',
    );
    expect(feedback, contains('_toneForMessage'));
    expect(feedback, contains("normalized.contains('permission-denied')"));
    expect(feedback, contains('IzyTelColors.errorSoft'));
    expect(feedback, contains('IzyTelColors.successSoft'));
  });

  test('ecran compte suspendu est IzyTel clair', () {
    final String page = source(
      'lib/features/auth/presentation/pages/pending_account_page.dart',
    );
    expect(page, contains("'IzyTel'"));
    expect(page, contains("'Compte suspendu'"));
    expect(page, contains('IzyTelColors.background'));
    expect(page, isNot(contains('CabineFlow')));
  });

  test('affectation utilise le style IzyTel clair', () {
    final String page = source(
      'lib/features/orders/presentation/pages/agent_assignment_page.dart',
    );
    expect(page, contains('IzyTelColors.background'));
    expect(page, contains("'Affecter une commande'"));
    expect(page, isNot(contains('AppColors.')));
  });

  test('centre des commandes echouees est accessible depuis accueil', () {
    final String dashboard = source(
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
    );
    final String failed = source(
      'lib/features/orders/presentation/pages/failed_orders_page.dart',
    );
    final String repository = source(
      'lib/features/orders/domain/repositories/orders_repository.dart',
    );
    expect(dashboard, contains('_openFailedOrdersCenter'));
    expect(dashboard, contains("'Commandes échouées'"));
    expect(failed, contains("'Réaffecter'"));
    expect(failed, contains("'Rembourser'"));
    expect(repository, contains('prepareFailedOrderForReassignment'));
  });

  test('attente des files se recalcule periodiquement', () {
    final String admin = source(
      'lib/features/orders/presentation/pages/orders_page.dart',
    );
    final String agent = source(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    );
    final String viewModel = source(
      'lib/features/orders/presentation/view_models/orders_view_model.dart',
    );
    expect(admin, contains('Timer.periodic(const Duration(seconds: 20)'));
    expect(agent, contains('Timer.periodic(const Duration(seconds: 20)'));
    expect(viewModel, contains('order.paymentConfirmedAt ??'));
    expect(viewModel, contains('order.createdAt'));
  });

  test('detail demande du journal est scrollable et controle en hauteur', () {
    final String page = source(
      'lib/features/more/presentation/pages/admin_activity_journal_page.dart',
    );
    expect(page, contains('isScrollControlled: true'));
    expect(page, contains('SingleChildScrollView'));
    expect(page, contains('constraints: BoxConstraints(maxHeight: maxHeight)'));
  });

  test('reaffectation echec possede une validation audit non circulaire', () {
    final String rules = source('firestore.rules');
    expect(rules, contains('REASSIGNMENT_REQUESTED'));
    expect(rules, contains('function isValidAdminReassignmentRequestedEvent()'));
    expect(rules, contains('function isValidAdminFailedOrderRequeue(orderId)'));
  });
}
