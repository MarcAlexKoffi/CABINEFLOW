import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une réussite Agent termine immédiatement la commande', () {
    final String repository = File(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    ).readAsStringSync();
    final String rules = File('firestore.rules').readAsStringSync();

    final int start = repository.indexOf(
      'Future<QueueOrder> markAgentSuccessful',
    );
    final int end = repository.indexOf(
      'Future<QueueOrder> markAgentFailed',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String agentSuccess = repository.substring(start, end);
    expect(agentSuccess, contains("'status': QueueOrderStatus.completed.name"));
    expect(
      agentSuccess,
      isNot(
        contains(
          "'status': QueueOrderStatus.awaitingCustomerConfirmation.name",
        ),
      ),
    );
    expect(rules, contains("request.resource.data.status == 'completed'"));
    expect(
      rules,
      contains("order.status in ['completed', 'awaitingCustomerConfirmation']"),
    );
  });

  test(
    'après une fin de traitement le prochain onglet est En cours sinon À accepter',
    () {
      final String source = File(
        'lib/features/orders/presentation/view_models/agent_orders_view_model.dart',
      ).readAsStringSync();

      expect(source, contains('void _selectNextWorkTabAfterCompletion()'));
      expect(source, contains('if (inProgressOrders.isNotEmpty)'));
      expect(source, contains('_selectedTab = AgentOrdersTab.inProgress'));
      expect(source, contains('_selectedTab = AgentOrdersTab.toAccept'));
    },
  );

  test('le profil Agent V2 est isolé du profil opérationnel', () {
    final String repository = File(
      'lib/features/agents/data/repositories/firestore_agent_repository.dart',
    ).readAsStringSync();
    final String rules = File('firestore.rules').readAsStringSync();
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(repository, contains("collection('agentPersonalProfiles')"));
    expect(repository, contains("'agent_profiles/\$agentId/avatar/profile'"));
    expect(
      repository,
      contains("'agent_profiles/\$agentId/identity/document'"),
    );
    expect(rules, contains('match /agentPersonalProfiles/{agentId}'));
    expect(rules, contains('isValidAgentOwnUserContactUpdate'));
    expect(pubspec, contains('firebase_storage:'));
    expect(pubspec, contains('file_picker:'));
  });

  test('le legacy À confirmer est présenté comme terminé dans les écrans', () {
    final String agentQueue = File(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    ).readAsStringSync();
    final String displayHelpers = File(
      'lib/features/orders/presentation/widgets/order_display_helpers.dart',
    ).readAsStringSync();
    final String dashboard = File(
      'lib/features/dashboard/data/repositories/firestore_dashboard_repository.dart',
    ).readAsStringSync();

    expect(agentQueue, isNot(contains("'À confirmer'")));
    expect(
      displayHelpers,
      contains(
        'case QueueOrderStatus.awaitingCustomerConfirmation:\n    case QueueOrderStatus.completed:',
      ),
    );
    expect(
      dashboard,
      contains(
        'QueueOrderStatus.awaitingCustomerConfirmation,\n                QueueOrderStatus.completed,',
      ),
    );
  });
}
