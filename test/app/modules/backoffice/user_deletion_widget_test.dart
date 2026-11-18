import 'package:cabine_flow/app/data/repositories/backoffice_user_administration_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/backoffice/backoffice_user_account.dart';
import 'package:cabine_flow/app/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/backoffice_users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Accounts implements BackofficeUserRepository {
  bool deleted = false;
  int reads = 0;
  @override
  Stream<List<BackofficeUserAccount>> watchUsers() {
    reads++;
    return Stream.value([
      if (!deleted)
        const BackofficeUserAccount(
          id: 'synthetic-agent',
          name: 'Agent test',
          email: 'test@example.invalid',
          phoneNumber: '',
          role: BackofficeAccountRole.agent,
          isActive: true,
        ),
    ]);
  }
}

class _Administration implements BackofficeUserAdministration {
  _Administration(this.accounts, {this.blocked = false});
  final _Accounts accounts;
  final bool blocked;
  final commands = <Map<String, dynamic>>[];
  @override
  Future<List<UserAdminZone>> loadZones() async => [];
  @override
  Future<UserAdminDetails> loadDetails(BackofficeUserAccount user) async =>
      const UserAdminDetails();
  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    commands.add(command);
    if (blocked) throw const UserAdminException('ACTIVE_ORDERS');
    accounts.deleted = true;
    return {'ok': true};
  }
}

void main() {
  for (final blocked in [false, true]) {
    testWidgets(
      'confirmed deletion refreshes registry; business block=$blocked',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final accounts = _Accounts();
        final administration = _Administration(accounts, blocked: blocked);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BackofficeUsersPage(
                currentUser: const AppUser(
                  id: 'admin',
                  name: 'Admin',
                  phoneNumber: '',
                  role: UserRole.administrator,
                ),
                repository: accounts,
                administration: administration,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Voir le détail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer définitivement'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Vérifier et supprimer',
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.enterText(
          find.widgetWithText(TextField, 'UID de confirmation'),
          'wrong',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.enterText(
          find.widgetWithText(TextField, 'UID de confirmation'),
          'synthetic-agent',
        );
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(administration.commands.single['action'], 'delete');
        expect(administration.commands.single['confirmUid'], 'synthetic-agent');
        if (blocked) {
          expect(accounts.deleted, false);
          expect(find.text('Agent test'), findsOneWidget);
          expect(
            find.textContaining('Terminez ou réaffectez les commandes'),
            findsOneWidget,
          );
        } else {
          expect(accounts.reads, 2);
          expect(find.text('Agent test'), findsNothing);
          expect(find.textContaining('Compte supprimé.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      },
    );
  }
}
