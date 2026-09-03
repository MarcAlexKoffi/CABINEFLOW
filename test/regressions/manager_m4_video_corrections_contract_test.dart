import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('Manager dispose d un avatar Supabase modifiable sans Firestore', () {
    final String repository = read(
      'lib/features/auth/data/repositories/manager_avatar_repository.dart',
    );
    final String widget = read(
      'lib/features/auth/presentation/widgets/manager_profile_avatar.dart',
    );
    final String dashboard = read(
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
    );
    final String more = read(
      'lib/features/more/presentation/pages/more_page.dart',
    );

    expect(repository, contains("bucketName = 'agent-personal'"));
    expect(repository, contains("/avatar/profile.jpg"));
    expect(repository, isNot(contains('FirebaseStorage')));
    expect(widget, contains('ImageSource.gallery'));
    expect(dashboard, contains("import 'package:cabine_flow/features/auth/presentation/widgets/manager_profile_avatar.dart';"));
    expect(dashboard, contains('if (user.isManager)'));
    expect(dashboard, contains('ManagerProfileAvatar('));
    expect(more, contains('ManagerProfileAvatar'));
  });

  test('Dashboard Manager ne transforme plus les anciens echecs en taches', () {
    final String dashboard = compact(
      read('lib/features/dashboard/presentation/pages/dashboard_page.dart'),
    );
    expect(
      dashboard,
      contains('if (widget.user.permissions.canManageFailedOrders)'),
    );
    expect(dashboard, isNot(contains('à surveiller')));
  });

  test('Dashboard hybride corrige aussi les affectations manuelles Phase 4', () {
    final String hybrid = compact(
      read(
        'lib/features/dashboard/data/repositories/hybrid_dashboard_repository.dart',
      ),
    );
    expect(hybrid, contains('(item.isAssigned || item.isAccepted)'));
    expect(hybrid, contains('item.assignedAgentId?.trim().isNotEmpty == true'));
    expect(
      hybrid,
      isNot(contains('item.assignmentMode == OrderAssignmentMode.automatic')),
    );
  });

  test('Manager ne peut pas affecter depuis un snapshot canonique indisponible', () {
    final String viewModel = read(
      'lib/features/orders/presentation/view_models/agent_assignment_view_model.dart',
    );
    expect(viewModel, contains('required this.isManager'));
    expect(viewModel, contains('_canonicalStateVerified = false'));
    expect(viewModel, contains("raw.contains('STAFF_REQUIRED')"));
    expect(viewModel, contains('izytel_staff_access'));

    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );
    expect(hybrid, contains("error.toString().contains('STAFF_REQUIRED')"));
    expect(hybrid, contains('rethrow;'));
  });
}
