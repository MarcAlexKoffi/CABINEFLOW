import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC9 - navigation mobile globale et Agents Manager resilient', () {
    test('shell Agent et Manager utilisent le garde mobile commun', () {
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();
      final String guard = File(
        'lib/features/navigation/presentation/widgets/izytel_mobile_back_scope.dart',
      ).readAsStringSync();

      expect(RegExp(r'IzyTelMobileBackScope\(').allMatches(shell).length, greaterThanOrEqualTo(2));
      expect(guard, contains('PopScope<Object?>'));
      expect(guard, contains('canPop: false'));
      expect(guard, contains('await activeNavigator.maybePop()'));
      expect(guard, contains('if (!widget.isHomeTab)'));
      expect(guard, contains('widget.onReturnHome()'));
      expect(guard, contains('await SystemNavigator.pop()'));
      expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
    });

    test('barre mobile preserve les piles de navigation entre onglets', () {
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(shell, contains('if (index == _selectedIndex)'));
      expect(shell, contains('// Chaque onglet conserve sa propre pile'));
      expect(shell, contains('void _openRootDestination(int index)'));
    });


    test('Cabiniste suit la meme politique de retour et de piles par onglet', () {
      final String partner = File(
        'lib/features/partners/presentation/pages/partner_shell_page.dart',
      ).readAsStringSync();

      expect(partner, contains('IzyTelMobileBackScope('));
      expect(partner, contains('isHomeTab: _selectedIndex == 0'));
      expect(partner, contains('setState(() => _selectedIndex = 0)'));
      expect(partner, contains('void _openRootTab(int index)'));
      expect(partner, isNot(contains('Appuie encore une fois pour quitter IzyTel.')));
    });

    test('Agents Manager: refresh borne sans restart permanent des streams', () {
      final String page = File(
        'lib/features/agents/presentation/pages/agent_management_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/agents/presentation/view_models/agent_management_view_model.dart',
      ).readAsStringSync();

      expect(page, contains('onRefresh: _viewModel.refresh'));
      expect(page, isNot(contains('onRefresh: _viewModel.start')));
      expect(viewModel, contains('Future<void> refresh() async'));
      expect(viewModel, contains('_initialLoadTimeout = Duration(seconds: 8)'));
      expect(viewModel, contains('_refreshTimeout = Duration(seconds: 6)'));
      expect(viewModel, contains('AgentManagement.initial-timeout'));
      expect(viewModel, contains('AgentManagement.refresh-timeout'));
    });

    test('Manager ne depend plus de Firestore pour afficher ses Agents zones', () {
      final String repository = File(
        'lib/features/agents/data/repositories/firestore_agent_repository.dart',
      ).readAsStringSync();
      final String operations = File(
        'lib/features/agents/data/repositories/supabase_agent_operations_repository.dart',
      ).readAsStringSync();

      expect(repository, contains('if (_isManager)'));
      expect(repository, contains('operations == null || controller.isClosed'));
      expect(repository, contains('operational.agentName'));
      expect(repository, contains('ne doit jamais attendre une'));
      expect(operations, contains('required this.agentName'));
      expect(operations, contains("row['agent_name']"));
    });
  });
}
