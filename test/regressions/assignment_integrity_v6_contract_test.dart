import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('réaffectation manuelle évite la boucle getAfter orderAssignments', () {
    final String rules = File('firestore.rules').readAsStringSync();
    final int start = rules.indexOf(
      'function isValidManualAssignmentEventCreation()',
    );
    final int end = rules.indexOf(
      'function isValidAutomaticAssignmentEventCreation()',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String block = rules.substring(start, end);
    expect(block, contains('let orderBefore = get('));
    expect(block, isNot(contains('getAfter(')));
    expect(block, contains("orderBefore.status == 'paidReady'"));
  });

  test('la baseline 9E conserve ses deux chemins automatiques validés', () {
    final String rules = File('firestore.rules').readAsStringSync();
    final String agentVm = File(
      'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
    ).readAsStringSync();

    expect(rules, contains('isValidAgentAutomaticSelfAssignment(orderId)'));
    expect(rules, contains('isValidStaffAutomaticAssignment(orderId)'));
    expect(rules, contains('isValidAgentAutomaticQueueDelete(orderId)'));

    // Le ViewModel courant ne déclenche pas de prise autonome : on préserve
    // exactement la baseline installée, sans réintroduire le patch V6 refusé.
    expect(agentVm, isNot(contains('_scheduleAutomaticClaim')));
  });

  test(
    'une réussite en attente de confirmation ne réserve plus deux fois la capacité',
    () {
      final String repository = File(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      ).readAsStringSync();

      expect(
        repository,
        contains(
          'order.status != QueueOrderStatus.awaitingCustomerConfirmation',
        ),
      );
      expect(
        repository,
        contains(
          'order.status == QueueOrderStatus.awaitingCustomerConfirmation',
        ),
      );
    },
  );

  test('Voir la commande peut ouvrir la commande exacte', () {
    final String payments = File(
      'lib/features/payments/presentation/pages/payments_page.dart',
    ).readAsStringSync();
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();

    expect(payments, contains('final ValueChanged<QueueOrder>? onOpenOrder;'));
    expect(payments, contains('openOrder(order);'));
    expect(
      shell,
      contains('Future<void> _openSpecificOrder(QueueOrder order)'),
    );
    expect(shell, contains('fetchOrderById(orderId: order.id)'));
    expect(shell, contains('initialOrder: latest'));
  });
}
