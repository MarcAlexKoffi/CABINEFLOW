import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('refus relit immediatement l etat canonique Phase 4', () {
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );

    expect(phase4, contains('Future<Phase4AssignmentSnapshot> refuse'));
    expect(phase4, contains('final Phase4AssignmentSnapshot? snapshot = await fetchOrder(orderId)'));
    expect(hybrid, contains('final Phase4AssignmentSnapshot afterRefusal = await _phase4.refuse'));
    expect(hybrid, contains('[Phase4][refusal-auto-reassigned]'));
    expect(hybrid, contains('[Phase4][refusal-manual-required]'));
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
