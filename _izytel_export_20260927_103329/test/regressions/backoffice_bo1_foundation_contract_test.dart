import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-1 - fondation Back-office Web', () {
    test('dispose d un point d entree Web staff separe du client', () {
      final String source = File('lib/main_backoffice_web.dart').readAsStringSync();

      expect(source, contains('BackofficeApp'));
      expect(source, contains('FirebaseBootstrap.initialize()'));
      expect(source, contains('Persistence.LOCAL'));
      expect(source, contains('SupabaseBootstrap.initialize()'));
      expect(source, isNot(contains('CustomerOrderApp')));
    });

    test('le shell filtre Utilisateurs aux Administrateurs', () {
      final String source = File(
        'lib/backoffice/presentation/pages/backoffice_shell_page.dart',
      ).readAsStringSync();

      expect(source, contains("return 'Utilisateurs';"));
      expect(source, contains("return 'ADMINISTRATION';"));
      expect(source, contains('user.role == UserRole.administrator'));
      expect(source, contains('BackofficeDestination.users'));
    });

    test('BO-1 lit users sans inventer une creation privilegiee cote client', () {
      final String source = File(
        'lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart',
      ).readAsStringSync();

      expect(source, contains("collection('users').snapshots()"));
      expect(source, isNot(contains('createUserWithEmailAndPassword')));
      expect(source, isNot(contains('.set(')));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.delete(')));
    });

    test('le mobile Admin existant reste la baseline et n est pas remplace', () {
      final String mainSource = File('lib/main.dart').readAsStringSync();
      final String shellSource = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();

      expect(mainSource, contains('runApp(const CabineFlowApp())'));
      expect(shellSource, contains('FinancesPage('));
      expect(shellSource, contains('MorePage('));
      expect(shellSource, contains('UserRole.administrator'));
    });

    test('la page Utilisateurs couvre recherche roles statuts et detail', () {
      final String source = File(
        'lib/backoffice/presentation/pages/backoffice_users_page.dart',
      ).readAsStringSync();

      expect(source, contains("'Utilisateurs'"));
      expect(source, contains('BackofficeAccountRole'));
      expect(source, contains('_AccountStatusFilter'));
      expect(source, contains('Nom, e-mail, téléphone ou UID'));
      expect(source, contains("label: 'UID'"));
      expect(source, contains("label: 'Dernière activité'"));
    });
  });
}
