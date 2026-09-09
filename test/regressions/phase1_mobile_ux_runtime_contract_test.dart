import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('la session mobile reste ouverte jusqu a une deconnexion explicite', () {
    final String splash = source(
      'lib/features/splash/presentation/pages/splash_page.dart',
    );
    final String auth = source(
      'lib/features/auth/data/repositories/firebase_auth_repository.dart',
    );

    expect(splash, contains('refreshCurrentAccess()'));
    expect(splash, isNot(contains('await widget.authRepository.logout()')));
    expect(splash, isNot(contains('preference.rememberMe && access')));
    expect(auth, isNot(contains('await currentUser.reload()')));
  });

  test('le formulaire expose Android Autofill et demande la sauvegarde', () {
    final String login = source(
      'lib/features/auth/presentation/pages/login_page.dart',
    );

    expect(login, contains('AutofillGroup('));
    expect(login, contains('AutofillHints.username'));
    expect(login, contains('AutofillHints.email'));
    expect(login, contains('AutofillHints.password'));
    expect(
      login,
      contains('TextInput.finishAutofillContext(shouldSave: true)'),
    );
  });

  test('le feedback reutilise une OverlayEntry au lieu de la remplacer', () {
    final String feedback = source(
      'lib/shared/widgets/izytel/izytel_feedback.dart',
    );

    expect(feedback, contains('ValueNotifier<_IzyTelFeedbackPayload?>'));
    expect(feedback, contains('_entry == null || !_entry!.mounted'));
    expect(feedback, isNot(contains('_entry?.remove();')));
  });

  test('la validation paiement attend la fermeture complete du bottom sheet', () {
    final String payments = source(
      'lib/features/payments/presentation/pages/payments_page.dart',
    );

    expect(payments, contains('class _PaymentConfirmationSheet'));
    expect(payments, isNot(contains('return StatefulBuilder(')));
    expect(payments, contains('await WidgetsBinding.instance.endOfFrame'));
  });

  test('le double retour est reinitialise apres tout changement d onglet', () {
    final String shell = source(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    );

    expect(shell, contains('_lastBackPressAt = null;'));
    expect(shell, contains('Appuie encore une fois pour quitter IzyTel.'));
    expect(shell, contains('await SystemNavigator.pop()'));
  });

  test('activite Agent conserve les dernieres donnees pendant une coupure', () {
    final String repository = source(
      'lib/features/agents/data/repositories/firestore_agent_activity_v2_repository.dart',
    );
    final String page = source(
      'lib/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart',
    );

    expect(repository, contains('Conserve le dernier snapshot connu'));
    expect(page, contains('constraints.maxWidth >= 340'));
    expect(page, contains('Vue consolidée de l’activité opérationnelle.'));
    expect(page, contains('Données non actualisées'));
  });
}
