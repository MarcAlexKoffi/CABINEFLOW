import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Migration remuneration bloque la cloture si seuils non atteints', () {
    final String sql = source(
      'supabase/migrations/20260919180605_bloc2_performance_eligibility_hardening.sql',
    );

    expect(sql, contains('MANAGER_COMPENSATION_THRESHOLDS_NOT_MET'));
    expect(sql, contains("'eligibleTotalAmount'"));
    expect(sql, contains("'theoreticalTotalAmount'"));
    expect(sql, contains("'periodCommissionEarned'"));
    expect(sql, contains("'periodSettlementEarned'"));
  });

  test('Migration historique applique le scope avant de lire les evenements', () {
    final String sql = source(
      'supabase/migrations/20260919181143_bloc2_team_member_activity_history.sql',
    );

    expect(sql, contains('izytel_staff_can_access_agent'));
    expect(sql, contains('izytel_staff_can_access_partner'));
    expect(sql, contains('AGENT_SCOPE_DENIED'));
    expect(sql, contains('CABINISTE_SCOPE_DENIED'));
    expect(sql, contains("'currentMonth'"));
    expect(sql, contains("'earnings'"));
    expect(sql, contains("'payouts'"));
    expect(sql, contains("'movements'"));
  });
  test('Eligibilite Manager exige plan actif et seuils atteints', () {
    final String sql = source(
      'supabase/migrations/20260919181749_bloc2_manager_eligibility_plan_gate.sql',
    );

    expect(sql, contains("v_eligible := v_thresholds_met and v_plan_active"));
    expect(sql, contains("'planActive',v_plan_active"));
    expect(sql, contains("'eligibleTotalAmount',v_eligible_total"));
  });

  test('Ajustement de capacite Agent accepte Admin ou Manager scope', () {
    final String sql = source(
      'supabase/migrations/20260919181709_bloc2_admin_manager_agent_capacity.sql',
    );

    expect(sql, contains('private.is_izytel_finance_admin()'));
    expect(sql, contains("v_role in ('manager','supervisor')"));
    expect(sql, contains('izytel_manager_can_access_agent'));
    expect(sql, contains('STAFF_AGENT_SCOPE_REQUIRED'));
  });

}
