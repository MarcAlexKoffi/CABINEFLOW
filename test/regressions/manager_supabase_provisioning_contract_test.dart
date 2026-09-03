import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('STAFF_REQUIRED ne boucle plus sur chaque commande Manager', () {
    final String hybrid = compact(
      read('lib/features/orders/data/repositories/hybrid_orders_repository.dart'),
    );
    final String shell = compact(
      read('lib/features/navigation/presentation/pages/main_shell_page.dart'),
    );

    expect(hybrid, contains("if (error.toString().contains('STAFF_REQUIRED')) { rethrow; }"));
    expect(shell, contains('_managerSupabaseStaffDenied = true'));
    expect(shell, contains("raw.contains('STAFF_REQUIRED')"));
    expect(shell, contains('izytel_staff_access'));
    expect(shell, contains('if (_managerSupabaseStaffDenied) return'));
  });

  test('centre signalements explique le provisioning Manager vide', () {
    final String issues = read(
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
    );

    expect(issues, contains('widget.user.isManager && allIssues.isEmpty'));
    expect(issues, contains('UID Firebase est enregistré dans Supabase'));
    expect(issues, contains('rôle manager'));
  });

  test('aucune rule Firestore ne fait partie de la finalisation M4', () {
    // Contrat volontairement limite aux sources versionnees M4. Ne jamais
    // parcourir `build/` : Gradle peut supprimer ses repertoires temporaires
    // pendant qu'un autre test les enumere, surtout sous Windows.
    const List<String> m4SourceFiles = <String>[
      'lib/features/agents/presentation/pages/agent_issue_center_page.dart',
      'lib/features/finances/presentation/pages/finances_page.dart',
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
      'lib/features/more/presentation/pages/more_page.dart',
    ];

    expect(m4SourceFiles.where((String path) => path.endsWith('.rules')), isEmpty);
    for (final String path in m4SourceFiles) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
