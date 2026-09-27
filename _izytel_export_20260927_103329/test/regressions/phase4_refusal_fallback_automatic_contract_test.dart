import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('refus retourne atomiquement l issue Phase 4 sans relecture RLS', () {
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    final String migration = read(
      'supabase/migrations/20260911_phase3_refusal_atomic_outcome.sql',
    );

    final int refuseStart = phase4.indexOf(
      'Future<Phase4AgentActionOutcome> refuse',
    );
    final int refuseEnd = phase4.indexOf(
      'Future<Phase4AgentActionOutcome> _agentAction',
      refuseStart,
    );
    expect(refuseStart, greaterThanOrEqualTo(0));
    expect(refuseEnd, greaterThan(refuseStart));
    final String refuseBlock = phase4.substring(refuseStart, refuseEnd);

    expect(refuseBlock, contains("action: 'refuse'"));
    expect(refuseBlock, contains('outcome.isRefusalApplied'));
    expect(refuseBlock, isNot(contains('fetchOrder(orderId)')));
    expect(hybrid, contains('final Phase4AgentActionOutcome refusalOutcome'));
    expect(hybrid, contains('refusalOutcome.reassigned'));
    expect(hybrid, contains('refusalOutcome.manualRequired'));
    expect(migration, contains("'assignment_state', v_row.assignment_state"));
    expect(migration, contains("'reassigned'"));
    expect(migration, contains("'manual_required'"));
  });

  test('fallback apres refus est explicitement automatique cote Supabase', () {
    final String sql = read(
      'supabase/migrations/20260903_phase4_refusal_fallback_becomes_automatic.sql',
    );

    expect(sql, contains("set plan_mode = 'automatic'"));
    expect(sql, contains("new.assignment_mode := 'automatic'"));
    expect(sql, contains("'automatic', 'assigned'"));
    expect(sql, contains("new.assignment_state := 'manual_required'"));
  });
}
