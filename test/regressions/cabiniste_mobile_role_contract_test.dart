import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('mobile auth resolves cabiniste outside staff roles', () {
    final String appUser = source(
      'lib/features/auth/domain/models/app_user.dart',
    );
    final String auth = source(
      'lib/features/auth/data/repositories/firebase_auth_repository.dart',
    );
    final String permissions = source(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    );

    expect(appUser, contains('cabiniste'));
    expect(appUser, contains("return 'Cabiniste';"));
    expect(auth, contains("from('partner_accounts')"));
    expect(auth, contains('role: UserRole.cabiniste'));
    expect(auth, contains('Les profils Staff reconnus restent prioritaires'));
    expect(permissions, contains('case UserRole.cabiniste:'));
    expect(permissions, contains('return null;'));
  });

  test('cabiniste uses a dedicated mobile shell', () {
    final String app = source('lib/app/app.dart');
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );

    expect(app, contains('arguments.role == UserRole.cabiniste'));
    expect(app, contains('PartnerShellPage('));
    expect(shell, contains("label: 'Accueil'"));
    expect(shell, contains("label: 'Commandes'"));
    expect(shell, contains("label: 'Historique'"));
    expect(shell, contains("label: 'Profil'"));
  });

  test('cabiniste order UI is wired to validated partner RPC layer', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(shell, contains('repository.accept('));
    expect(shell, contains('repository.refuse('));
    expect(shell, contains('repository.startProcessing('));
    expect(shell, contains('repository.saveProof('));
    expect(shell, contains('repository.finalizeSuccess('));
    expect(repository, contains("'phase4_partner_action'"));
    expect(repository, contains("'phase5_finalize_partner_order_success'"));
  });

  test('cabiniste shell registers FCM and listens to assigned orders', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(shell, contains('IzyTelNotificationDeviceRegistry.start'));
    expect(shell, contains("payload.type == 'order_assigned'"));
    expect(shell, contains("payload.type == 'order_reassigned'"));
    expect(repository, contains('watchAssignedOrders'));
    expect(repository, contains(".stream(primaryKey: const <String>['order_id'])"));
  });

  test('cabiniste finance and capacities remain server controlled', () {
    final String shell = source(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(repository, contains("rpc('izytel_partner_finance_snapshot')"));
    expect(repository, contains("'izytel_update_own_partner_operations'"));
    expect(shell, contains('finance.balanceDue'));
    expect(shell, contains('updateOwnOperations('));
    expect(repository, isNot(contains('partner_margin_share_bps')));
  });
}
