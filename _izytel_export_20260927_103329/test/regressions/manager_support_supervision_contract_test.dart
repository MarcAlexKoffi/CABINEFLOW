import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('Manager accede aux demandes clients en supervision', () {
    final String more = compact(
      read('lib/features/more/presentation/pages/more_page.dart'),
    );

    expect(more, contains('permissions.canViewSupportRequests'));
    expect(more, contains("title: 'Demandes clients'"));
    expect(more, contains('SupportRequestCenterPage('));
    expect(more, contains('refundRepository: FakeRefundRepository()'));
  });

  test('centre assistance bloque les actions de traitement Manager', () {
    final String support = compact(
      read(
        'lib/features/support/presentation/pages/support_request_center_page.dart',
      ),
    );

    expect(
      support,
      contains('if (!widget.user.permissions.canProcessSupportRequests)'),
    );
    expect(support, contains('_SupportReadOnlyInfo()'));
    expect(
      support,
      contains('traitement, les remboursements et la clôture restent réservés'),
    );
  });

  test('Dashboard ouvre la supervision des demandes sans droit ecriture', () {
    final String dashboard = compact(
      read('lib/features/dashboard/presentation/pages/dashboard_page.dart'),
    );
    final String permissions = read(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );
    final String manager = permissions.substring(
      permissions.indexOf('static const UserPermissions manager'),
      permissions.indexOf('static const UserPermissions legacyOperator'),
    );

    expect(
      dashboard,
      contains('widget.user.permissions.canViewSupportRequests ? widget.onOpenMore : null'),
    );
    expect(manager, contains('canViewSupportRequests: true'));
    expect(manager, contains('canProcessSupportRequests: false'));
    expect(manager, contains('canManageRefunds: false'));
  });
}
