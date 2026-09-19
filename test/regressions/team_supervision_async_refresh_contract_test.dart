import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Nouvelles pages équipe n utilisent pas un Future retourné par setState', () {
    final List<String> paths = <String>[
      'lib/features/team/presentation/pages/team_performance_page.dart',
      'lib/features/team/presentation/pages/team_member_detail_page.dart',
      'lib/features/finances/presentation/pages/cabiniste_finance_supervision_page.dart',
    ];

    for (final String path in paths) {
      final String content = source(path);
      expect(
        content,
        isNot(contains('setState(() => _future =')),
        reason: path,
      );
    }
  });

  test('Performance équipe importe bien les permissions AppUser', () {
    final String content = source(
      'lib/features/team/presentation/pages/team_performance_page.dart',
    );

    expect(
      content,
      contains(
        "import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';",
      ),
    );
    expect(content, contains('widget.user.isManager'));
  });

  test('Recharge fournisseur Manager importe l extension réseau Agent', () {
    final String content = source(
      'lib/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart',
    );

    expect(
      content,
      contains(
        "import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';",
      ),
    );
    expect(content, contains('draft.network.firestoreValue'));
  });
}
