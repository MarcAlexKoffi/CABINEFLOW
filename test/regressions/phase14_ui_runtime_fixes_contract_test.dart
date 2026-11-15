import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('remboursement utilise le design clair IzyTel', () {
    final String value = source(
      'lib/app/modules/refunds/widgets/refund_creation_sheet.dart',
    );
    expect(value, contains('color: IzyTelColors.surface'));
    expect(value, contains('fillColor: IzyTelColors.surfaceMuted'));
    expect(value, isNot(contains('AppColors.')));
  });

  test(
    'les feedbacks applicatifs ne reposent plus sur des SnackBars en bas',
    () {
      final Iterable<File> files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'));
      final List<String> offenders = <String>[];
      for (final File file in files) {
        if (file.readAsStringSync().contains('ScaffoldMessenger')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
      expect(
        source('lib/app/shared/widgets/izytel/izytel_feedback.dart'),
        contains('IgnorePointer'),
      );
    },
  );

  test('mise en attente Agent evite la dependance getAfter circulaire', () {
    final String rules = source('firestore.rules');
    expect(rules, contains('function isValidAgentPutOnHoldEvent()'));
    expect(rules, contains("request.resource.data.type == 'PUT_ON_HOLD'"));
    expect(
      rules,
      contains("request.resource.data.get('type', '') == 'PUT_ON_HOLD'"),
    );
  });

  test('progression commande est synchronisee Admin et Agent', () {
    final String admin = source(
      'lib/app/modules/manager_orders/views/order_detail_page.dart',
    );
    final String agent = source(
      'lib/app/modules/agent_orders/views/agent_order_detail_view.dart',
    );
    expect(admin, contains('QueueOrderStatus.awaitingCustomerConfirmation'));
    expect(
      admin,
      contains('order.assignmentStatus != OrderAssignmentStatus.unassigned'),
    );
    expect(agent, contains('QueueOrderStatus.awaitingCustomerConfirmation'));
    expect(
      agent,
      contains('order.assignmentStatus != OrderAssignmentStatus.unassigned'),
    );
  });

  test('se souvenir de moi persiste sans stocker le mot de passe', () {
    final String login = source(
      'lib/app/modules/auth/views/login_page.dart',
    );
    final String preferences = source(
      'lib/app/services/session_preferences.dart',
    );
    final String android = source(
      'android/app/src/main/kotlin/com/izytel/app/MainActivity.kt',
    );
    expect(login, contains('_persistRememberedPreference'));
    expect(preferences, contains('rememberMe'));
    expect(preferences, contains("'email'"));
    expect(preferences, isNot(contains('password')));
    expect(android, contains('SharedPreferences'));
  });

  test('Agents et zones ne montre plus le panneau signalements', () {
    final String page = source(
      'lib/app/modules/agent_ops/views/agent_management_page.dart',
    );
    expect(page, isNot(contains('Signalements agents')));
    expect(page, contains('Suspendus'));
  });

  test('suspension agent est enregistree immediatement', () {
    final String page = source(
      'lib/app/modules/agent_ops/views/agent_detail_page.dart',
    );
    expect(page, contains('Future<void> _toggleAgentActiveState()'));
    expect(page, contains('_viewModel.setActive(targetActive)'));
    expect(page, contains('final bool success = await _viewModel.save()'));
  });

  test('retour Android privilegie navigation interne et double appui', () {
    final String shell = source(
      'lib/app/modules/home/views/main_shell_page.dart',
    );
    expect(shell, contains('PopScope('));
    expect(shell, contains('await currentNavigator.maybePop()'));
    expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
    expect(shell, contains('await SystemNavigator.pop()'));
  });

  test('les echecs remontent en temps reel au tableau Admin', () {
    final String dashboard = source(
      'lib/app/modules/home/views/dashboard_page.dart',
    );
    expect(dashboard, contains('_failedOrdersSubscription'));
    expect(dashboard, contains('QueueOrderStatus.failed'));
    expect(dashboard, contains('à traiter'));
    expect(dashboard, contains('_openFailedOrdersCenter'));
  });

  test('historique Agent separe reussites et echecs avec motif', () {
    final String history = source(
      'lib/app/modules/agent_orders/views/agent_history_page.dart',
    );
    expect(history, contains("'Échecs',"));
    expect(history, contains('_tabBox('));
    expect(history, contains('failedOrders'));
    expect(history, contains("'Motif : "));
    expect(history, contains('order.observation'));
  });

  test(
    'splash premium utilise exclusivement la nouvelle illustration fournie',
    () {
      final String splash = source(
        'lib/app/modules/splash/views/splash_page.dart',
      );
      expect(splash, contains('assets/images/New_splash_illustration.png'));
      expect(splash, contains('LinearGradient'));
      expect(splash, contains('Simple. Rapide. Izy.'));
      expect(
        splash,
        isNot(contains("'assets/images/splash_illustration.png'")),
      );
    },
  );
}
