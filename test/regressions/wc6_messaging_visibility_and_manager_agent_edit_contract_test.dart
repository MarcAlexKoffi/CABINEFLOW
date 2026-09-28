import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC6 - conversations visibles et gestion Agent par Manager', () {
    test('les conversations Firebase JWT sont lisibles via anon et authenticated', () {
      final String sql = File(
        'supabase/migrations/20260927160057_wc6_customer_conversation_anon_read_fix.sql',
      ).readAsStringSync();

      expect(sql, contains('customer_conversations_authorized_read'));
      expect(sql, contains('to anon, authenticated'));
      expect(sql, contains('private.izytel_wc3_can_read_conversation(id)'));
    });

    test('le backend limite la modification Agent au Manager de zone', () {
      final String sql = File(
        'supabase/migrations/20260927160508_wc6_manager_agent_operations_edit.sql',
      ).readAsStringSync();

      expect(sql, contains('izytel_manager_update_agent_operations'));
      expect(sql, contains('private.izytel_manager_can_access_agent'));
      expect(sql, contains('MANAGER_AGENT_SCOPE_REQUIRED'));
      expect(sql, contains('authorized_networks'));
      expect(sql, contains('daily_transaction_limit'));
      expect(sql, contains('max_transactions_per_day'));
      expect(sql, contains('private.phase5_adjust_capacity'));
      expect(sql, isNot(contains('zone_ids =')));
    });

    test('la fiche Manager edite quotas reseaux et capacites sans ouvrir identite ni zone', () {
      final String page = File(
        'lib/features/agents/presentation/pages/agent_detail_page.dart',
      ).readAsStringSync();
      final String repository = File(
        'lib/features/agents/data/repositories/supabase_agent_operations_repository.dart',
      ).readAsStringSync();

      expect(page, contains('_canEditOperationalSettings'));
      expect(page, contains('readOnly: !_canEditOperationalSettings'));
      expect(page, contains('onChanged: !_canEditOperationalSettings'));
      expect(page, contains('Enregistrer la gestion Agent'));
      expect(page, contains('ManagedAgentOperationalUpdate'));
      expect(page, contains('L’identité et le rattachement territorial restent administratifs.'));
      expect(repository, contains("'izytel_manager_update_agent_operations'"));
      expect(repository, contains("'p_authorized_networks'"));
      expect(repository, contains("'p_daily_transaction_limit'"));
      expect(repository, contains("'p_max_transactions_per_day'"));
    });
  });
}
