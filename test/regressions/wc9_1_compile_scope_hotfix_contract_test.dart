import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC9.1 - compile Partner + scope Manager Agents', () {
    test('PartnerShell conserve les imports Flutter necessaires', () {
      final String source = File(
        'lib/features/partners/presentation/pages/partner_shell_page.dart',
      ).readAsStringSync();

      expect(source, contains("package:flutter/foundation.dart"));
      expect(source, contains("package:flutter/services.dart"));
      expect(source, contains('ValueListenable'));
      expect(source, contains('Uint8List'));
      expect(source, contains('FilteringTextInputFormatter'));
    });

    test('enrichissement Firestore Manager reste limite aux Agents Supabase visibles', () {
      final String source = File(
        'lib/features/agents/data/repositories/firestore_agent_repository.dart',
      ).readAsStringSync();

      expect(source, contains('operationsByAgent.containsKey(doc.id)'));
      expect(source, contains('if (_isManager)'));
      expect(source, contains('operations.map((SupabaseAgentOperationalRecord operational)'));
    });
  });
}
