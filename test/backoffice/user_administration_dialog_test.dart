import 'package:cabine_flow/backoffice/data/repositories/backoffice_user_administration_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_user_admin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AdministrationFake implements BackofficeUserAdministration {
  final calls = <Map<String, dynamic>>[];
  Object? nextError;
  bool detailsUnavailable = false;
  String? authEmail;
  @override
  Future<List<UserAdminZone>> loadZones() async => [
    const UserAdminZone('centre', 'Zone Centre'),
  ];
  @override
  Future<UserAdminDetails> loadDetails(BackofficeUserAccount user) async {
    if (detailsUnavailable) throw StateError('Informations indisponibles');
    return UserAdminDetails(
      zoneIds: ['centre'],
      authorizedNetworks: ['orange'],
      email:authEmail,
    );
  }

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    calls.add(Map.from(command));
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    return {'ok': true, 'uid': 'created'};
  }
}

Future<void> open(
  WidgetTester tester,
  AdministrationFake gateway, {
  BackofficeUserAccount? user,
}) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => BackofficeUserAdminDialog(
                administration: gateway,
                user: user,
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> identity(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Marie Test');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'marie@example.test',
  );
  await tester.enterText(find.byType(TextFormField).at(2), '0102030405');
}

void main() {
  testWidgets('Cabiniste email is read from Auth details and reconnect impact is visible',(tester)async{
    final fake=AdministrationFake()..authEmail='firebase@example.test';
    const user=BackofficeUserAccount(id:'uid',name:'Name',email:'',phoneNumber:'01020304',role:BackofficeAccountRole.cabiniste,isActive:true);
    await open(tester,fake,user:user);
    final email=tester.widget<TextFormField>(find.byType(TextFormField).at(1));
    expect(email.controller!.text,'firebase@example.test');
    expect(find.textContaining('doit se reconnecter'),findsOneWidget);
  });
  for (final entry in {
    'admin': 'Administrateur',
    'manager': 'Manager',
    'agent': 'Agent',
    'cabiniste': 'Cabiniste',
  }.entries) {
    testWidgets(
      'creates ${entry.key} through privileged gateway with role-specific details',
      (tester) async {
        final fake = AdministrationFake();
        await open(tester, fake);
        await identity(tester);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value).last);
        await tester.pumpAndSettle();
        if (entry.key != 'admin') await tester.tap(find.text('Zone Centre'));
        if (['agent', 'cabiniste'].contains(entry.key)) {
          await tester.tap(find.text('ORANGE'));
        }
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(fake.calls.single['action'], 'create');
        expect(fake.calls.single.containsKey('uid'), false);
        expect(fake.calls.single['role'], entry.key);
        expect(
          fake.calls.single['zoneIds'],
          entry.key == 'admin' ? [] : ['centre'],
        );
        expect(
          fake.calls.single['authorizedNetworks'],
          ['agent', 'cabiniste'].contains(entry.key) ? ['orange'] : [],
        );
        expect(
          fake.calls.single['requestId'],
          matches(RegExp(r'^[a-f0-9-]{36}$')),
        );
      },
    );
  }
  testWidgets('uncertain response retries exact command and request ID', (
    tester,
  ) async {
    final fake = AdministrationFake()..nextError = StateError('network');
    const user = BackofficeUserAccount(
      id: 'uid',
      name: 'Name',
      email: 'name@example.test',
      phoneNumber: '01020304',
      role: BackofficeAccountRole.agent,
      isActive: true,
    );
    await open(tester, fake, user: user);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('résultat de la demande est incertain'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer la même demande'));
    await tester.pumpAndSettle();
    expect(fake.calls.length, 2);
    expect(fake.calls[0], fake.calls[1]);
  });
  testWidgets(
    'repair requirement blocks repeated submission and shows operation reference',
    (tester) async {
      final fake = AdministrationFake()
        ..nextError = const UserAdminException(
          'OPERATION_REQUIRES_REPAIR',
          operationId: 'repair-ref',
          requiresRepair: true,
        );
      const user = BackofficeUserAccount(
        id: 'uid',
        name: 'Name',
        email: 'name@example.test',
        phoneNumber: '01020304',
        role: BackofficeAccountRole.agent,
        isActive: true,
      );
      await open(tester, fake, user: user);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('repair-ref'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(fake.calls.length, 1);
    },
  );
  testWidgets(
    'unavailable business details cannot be silently replaced by empty scopes',
    (tester) async {
      final fake = AdministrationFake()..detailsUnavailable = true;
      const user = BackofficeUserAccount(
        id: 'uid',
        name: 'Name',
        email: 'name@example.test',
        phoneNumber: '01020304',
        role: BackofficeAccountRole.agent,
        isActive: true,
      );
      await open(tester, fake, user: user);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(find.textContaining('Impossible de charger'), findsOneWidget);
    },
  );
}
