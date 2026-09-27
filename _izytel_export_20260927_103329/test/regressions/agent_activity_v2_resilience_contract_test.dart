import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity V2 isolates Firestore source failures', () {
    final String repository = File(
      'lib/features/agents/data/repositories/firestore_agent_activity_v2_repository.dart',
    ).readAsStringSync();
    final String models = File(
      'lib/features/agents/domain/models/agent_activity_v2_models.dart',
    ).readAsStringSync();
    final String page = File(
      'lib/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart',
    ).readAsStringSync();

    expect(repository, isNot(contains('onError: controller.addError')));
    expect(repository, contains('markUnavailable('));
    expect(
      repository,
      contains('Set<String>.unmodifiable(unavailableSources)'),
    );
    expect(models, contains('class AgentActivityV2Sources'));
    expect(models, contains('final Set<String> unavailableSources;'));
    expect(page, contains('_PartialDataWarning'));
    expect(page, contains('_UnavailableCard'));
  });
}
