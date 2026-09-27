import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('ancien handoff Firestore v4 reste retire du parcours Agent', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );

    expect(hybrid, contains('cutover operationnel Supabase'));
    expect(hybrid, isNot(contains('handoffHybridAcceptedAssignment(')));
    expect(hybrid, isNot(contains('ensureHybridAssignmentQueue(')));
    expect(hybrid, isNot(contains('trustPhase4Reservation')));
    expect(phase4, contains('phase3_agent_is_eligible_for_order'));
    expect(phase4, contains('phase4_agent_action'));
  });

  test('aucune Firestore Rule nest requise pour accepter une affectation Phase 4', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );

    final int acceptStart = hybrid.indexOf(
      'Future<QueueOrder> acceptAgentAssignment',
    );
    final int refuseStart = hybrid.indexOf(
      'Future<QueueOrder> refuseAgentAssignment',
      acceptStart,
    );
    expect(acceptStart, greaterThanOrEqualTo(0));
    expect(refuseStart, greaterThan(acceptStart));

    final String acceptBlock = hybrid.substring(acceptStart, refuseStart);
    expect(acceptBlock, contains('_phase4.accept('));
    expect(acceptBlock, isNot(contains('_firestore.')));
    expect(acceptBlock, isNot(contains('FirebaseException')));
    expect(phase4, contains('phase3_agent_is_eligible_for_order'));
    expect(phase4, contains('isAgentEligibleForOrder'));
  });
}
