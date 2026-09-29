import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC9/WC10.1 - navigation mobile globale et Agents Manager resilient', () {
    test('shell Agent et Manager restaurent la politique Retour mobile eprouvee', () {
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'return PopScope\(').allMatches(shell).length,
        greaterThanOrEqualTo(2),
      );
      expect(shell, contains('canPop: false'));
      expect(
        RegExp(r'Future<void> _handleSystemBack\(\)').allMatches(shell).length,
        greaterThanOrEqualTo(2),
      );
      expect(shell, isNot(contains('NavigatorPopHandler<Object?>')));
      expect(shell, contains('currentNavigator.canPop()'));
      expect(shell, contains('await currentNavigator.maybePop()'));
      expect(shell, contains("if (_selectedIndex != 0)"));
      expect(shell, contains("setState(() => _selectedIndex = 0)"));
      expect(shell, contains('DateTime? _lastBackPressAt'));
      expect(shell, contains('Duration(seconds: 2)'));
      expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
      expect(shell, contains('await SystemNavigator.pop()'));
      expect(shell, contains('_IzyTelTabNavigationObserver'));
      expect(shell, isNot(contains('IzyTelMobileBackScope(')));
    });

    test('barre mobile desarme la sortie et ramene la destination a sa racine', () {
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(shell, contains('void _disarmExit()'));
      expect(shell, contains('_disarmExit();\n    _popTabToRoot(index);'));
      expect(shell, contains('void _openRootDestination(int index)'));
      expect(shell, contains('_selectDestination(index);'));
      expect(shell, contains('observers: <NavigatorObserver>[_tabNavigatorObservers[index]]'));
    });

    test('Cabiniste suit la meme arborescence et double Retour depuis Accueil', () {
      final String partner = File(
        'lib/features/partners/presentation/pages/partner_shell_page.dart',
      ).readAsStringSync();

      expect(partner, contains('Future<void> _handleBack() async'));
      expect(partner, isNot(contains('NavigatorPopHandler<Object?>')));
      expect(partner, contains('current.canPop()'));
      expect(partner, contains('await current.maybePop()'));
      expect(partner, contains("if (_selectedIndex != 0)"));
      expect(partner, contains('_selectTab(0);'));
      expect(partner, contains('DateTime? _lastBackPressAt'));
      expect(partner, contains('Duration(seconds: 2)'));
      expect(partner, contains('Appuie encore une fois pour quitter IzyTel.'));
      expect(partner, contains('await SystemNavigator.pop()'));
      expect(partner, isNot(contains('IzyTelMobileBackScope(')));
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
