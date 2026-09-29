import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('mobile tabs preserve each nested navigation stack', () {
    final String shell = read(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );
    expect(
      shell,
      contains('if (index == _selectedIndex) {\n      _popTabToRoot(index);'),
    );
    expect(
      shell,
      contains('void _openRootDestination(int index)'),
    );
    expect(
      shell,
      isNot(contains(
        'void _selectDestination(int index) {\n    _disarmExit();\n    _popTabToRoot(index);\n    if (index == _selectedIndex) return;',
      )),
    );
  });

  test('cabiniste tabs follow the same mobile navigation contract', () {
    final String shell = read(
      'lib/features/partners/presentation/pages/partner_shell_page.dart',
    );
    expect(
      shell,
      contains('if (index == _selectedIndex) {\n      _popTabToRoot(index);'),
    );
    expect(shell, contains('void _openRootTab(int index)'));
  });

  test('canonical zone survives Phase 4 conversion into QueueOrder', () {
    final String order = read(
      'lib/features/orders/domain/models/queue_order.dart',
    );
    final String phase4 = read(
      'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
    );
    expect(order, contains('final String? zoneId;'));
    expect(phase4, contains('zoneId: zoneId ?? legacy?.zoneId'));
  });

  test('manual assignment UI filters and displays the canonical order zone', () {
    final String vm = read(
      'lib/features/orders/presentation/view_models/agent_assignment_view_model.dart',
    );
    final String page = read(
      'lib/features/orders/presentation/pages/agent_assignment_page.dart',
    );
    expect(vm, contains("reason = 'Hors zone de la commande'"));
    expect(vm, contains('String get orderZoneLabel'));
    expect(page, contains('zoneLabel: _viewModel.orderZoneLabel'));
    expect(
      page,
      isNot(contains("value: 'Non renseignée pour cette commande'")),
    );
  });

  test('WC13 migration keeps IzyTel checks while restoring Firebase role compatibility', () {
    final String sql = read(
      'supabase/migrations/20260929091500_wc13_phase4_firebase_third_party_role_compatibility.sql',
    );
    expect(sql, contains('to anon, authenticated'));
    expect(sql, contains('phase4 staff inserts zoned orders'));
    expect(sql, contains('phase4 staff updates zoned orders'));
  });
}
