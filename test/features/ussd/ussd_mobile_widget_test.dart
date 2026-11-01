import 'dart:async';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:cabine_flow/features/ussd/presentation/ussd_quick_processing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ussd_test_doubles.dart';

class _ServerResolvedRepository extends UssdTestRepository {
  bool changedSecretRevision = false;
  @override
  Future<UssdResolution> prepare(
    String orderId,
    UssdResolution confirmed,
    String requestId,
  ) async {
    preparations++;
    return UssdResolution(
      status: response.status,
      reason: response.reason,
      rule: response.rule,
      code: response.code,
      context: {
        ...response.context,
        if (changedSecretRevision) 'secret_revision': 'moov:agent:2',
      },
      attemptId: 'synthetic-attempt',
      validForMs: leaseMs,
    );
  }
}

class _CapturingDialer extends UssdTestDialer {
  String? lastCode;
  @override
  Future<void> open(String code) async {
    lastCode = code;
    await super.open(code);
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    UssdTestRepository repo,
    UssdTestDialer dialer, {
    bool processable = true,
    bool initiallyExpanded = true,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              UssdQuickProcessingCard(
                orderId: 'synthetic-order',
                network: 'moov',
                offerLabel: 'Offre synthétique',
                beneficiary: '0101010101',
                amount: 1000,
                processable: processable,
                initiallyExpanded: initiallyExpanded,
                repository: repo,
                dialer: dialer,
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Terminer avec preuve'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Lancer l’opération'));
    await tester.tap(find.text('Lancer l’opération'));
    await tester.pumpAndSettle();
  }

  for (final code in ['#154*1*0101010101#', '*410*0101010101*1000*987654#']) {
    testWidgets(
      'dialer receives exact server code including hashes and secret: $code',
      (tester) async {
        final repo = _ServerResolvedRepository(), dialer = _CapturingDialer();
        repo.response = UssdResolution(
          status: 'available',
          reason: '',
          rule: syntheticRule(),
          code: code,
          context: {
            ...syntheticResolution().context,
            'secret_revision': 'moov:agent:1',
          },
        );
        await mount(tester, repo, dialer);
        await launch(tester);
        expect(dialer.opens, 0);
        await tester.tap(find.text('Confirmer et ouvrir'));
        await tester.pumpAndSettle();
        expect(dialer.lastCode, code);
        expect(repo.statusChanges, 0);
        expect(find.text('Terminer avec preuve'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'secret revision changed during confirmation prevents dialer and preserves manual action',
    (tester) async {
      final repo = _ServerResolvedRepository(), dialer = _CapturingDialer();
      repo.response = UssdResolution(
        status: 'available',
        reason: '',
        rule: syntheticRule(),
        code: '*410*0101010101*1000*0000#',
        context: {
          ...syntheticResolution().context,
          'secret_revision': 'moov:agent:1',
        },
      );
      await mount(tester, repo, dialer);
      await launch(tester);
      repo.changedSecretRevision = true;
      await tester.tap(find.text('Confirmer et ouvrir'));
      await tester.pumpAndSettle();
      expect(dialer.opens, 0);
      expect(repo.statusChanges, 0);
      expect(find.textContaining('Le raccourci a changé'), findsOneWidget);
      expect(find.text('Terminer avec preuve'), findsOneWidget);
    },
  );

  testWidgets(
    'collapsed production section loads only when opened and refreshes on reopening',
    (tester) async {
      final repo = UssdTestRepository(), dialer = UssdTestDialer();
      await mount(tester, repo, dialer, initiallyExpanded: false);
      expect(repo.resolutions, 0);
      expect(find.text('Lancer l’opération'), findsNothing);
      await tester.tap(find.text('Traitement rapide'));
      await tester.pumpAndSettle();
      expect(repo.resolutions, 1);
      expect(find.text('Lancer l’opération'), findsOneWidget);
      await tester.tap(find.text('Traitement rapide'));
      await tester.pumpAndSettle();
      repo.response = syntheticResolution(version: 3);
      await tester.tap(find.text('Traitement rapide'));
      await tester.pumpAndSettle();
      expect(repo.resolutions, 2);
      expect(find.text('Version 3'), findsOneWidget);
    },
  );

  testWidgets(
    'never opens before explicit confirmation; returning keeps business actions',
    (tester) async {
      final repo = UssdTestRepository(), dialer = UssdTestDialer();
      await mount(tester, repo, dialer);
      expect(repo.resolutions, 1);
      await launch(tester);
      expect(dialer.opens, 0);
      expect(repo.preparations, 0);
      await tester.tap(find.text('Confirmer et ouvrir'));
      await tester.pumpAndSettle();
      expect(repo.resolutions, 2);
      expect(repo.preparations, 1);
      expect(dialer.opens, 1);
      expect(repo.lastStatus, 'dialer_opened');
      expect(find.text('Terminer avec preuve'), findsOneWidget);
      expect(find.textContaining('Déclarez le résultat réel'), findsOneWidget);
    },
  );
  testWidgets('rapid repeated taps cannot open two dialers', (tester) async {
    final repo = UssdTestRepository(),
        dialer = UssdTestDialer()..pending = Completer<void>();
    await mount(tester, repo, dialer);
    await launch(tester);
    await tester.tap(find.text('Confirmer et ouvrir'));
    await tester.pump();
    await tester.pump();
    expect(dialer.opens, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lancer l’opération'),
          )
          .onPressed,
      isNull,
    );
    dialer.pending!.complete();
    await tester.pumpAndSettle();
    expect(repo.preparations, 1);
    expect(repo.recordings, 1);
  });
  testWidgets(
    'expired server preparation lease refuses dialer and records interruption',
    (tester) async {
      final repo = UssdTestRepository()..leaseMs = 0, dialer = UssdTestDialer();
      await mount(tester, repo, dialer);
      await launch(tester);
      await tester.tap(find.text('Confirmer et ouvrir'));
      await tester.pumpAndSettle();
      expect(dialer.opens, 0);
      expect(repo.lastStatus, 'failed');
      expect(repo.lastReason, 'interrupted');
      expect(find.textContaining('traitement manuel'), findsOneWidget);
    },
  );
  testWidgets('cancel and mismatch warning preserve order network', (
    tester,
  ) async {
    final repo = UssdTestRepository()
          ..response = syntheticResolution(mismatch: true),
        dialer = UssdTestDialer();
    await mount(tester, repo, dialer);
    expect(find.text(UssdEngine.mismatchMessage), findsOneWidget);
    await launch(tester);
    expect(find.text(UssdEngine.mismatchMessage), findsNWidgets(2));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(dialer.opens, 0);
    expect(repo.preparations, 0);
  });
  testWidgets(
    'revocation while confirming blocks dialer and preserves manual fallback',
    (tester) async {
      final repo = UssdTestRepository()..revokeOnPrepare = true,
          dialer = UssdTestDialer();
      await mount(tester, repo, dialer);
      await launch(tester);
      await tester.tap(find.text('Confirmer et ouvrir'));
      await tester.pumpAndSettle();
      expect(dialer.opens, 0);
      expect(find.textContaining('Le raccourci a changé'), findsOneWidget);
      expect(find.text('Terminer avec preuve'), findsOneWidget);
    },
  );
  testWidgets('dialer failure is audit failure, never telecom success', (
    tester,
  ) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer()..fail = true;
    await mount(tester, repo, dialer);
    await launch(tester);
    await tester.tap(find.text('Confirmer et ouvrir'));
    await tester.pumpAndSettle();
    expect(repo.lastStatus, 'failed');
    expect(repo.lastReason, 'dialer_unavailable');
    expect(find.textContaining('traitement manuel'), findsOneWidget);
  });
  testWidgets(
    'offline read has explicit retry and leaves business action available',
    (tester) async {
      final repo = UssdTestRepository()..failRead = true,
          dialer = UssdTestDialer();
      await mount(tester, repo, dialer);
      expect(find.text(UssdEngine.manualMessage), findsOneWidget);
      expect(find.text('Terminer avec preuve'), findsOneWidget);
      repo.failRead = false;
      await tester.tap(find.text('Actualiser le raccourci'));
      await tester.pumpAndSettle();
      expect(find.text('*999*0101010101#'), findsOneWidget);
    },
  );
  testWidgets('non-processable order performs no USSD read', (tester) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer();
    await mount(tester, repo, dialer, processable: false);
    expect(repo.resolutions, 0);
    expect(dialer.opens, 0);
  });
  testWidgets('copy requires confirmation and a second fresh validation', (
    tester,
  ) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, repo, dialer);
    await tester.tap(find.text('Copier le code'));
    await tester.pumpAndSettle();
    expect(copied, isNull);
    await tester.tap(find.text('Confirmer et copier'));
    await tester.pumpAndSettle();
    expect(copied, '*999*0101010101#');
    expect(repo.resolutions, 3);
    expect(repo.preparations, 0);
    expect(dialer.opens, 0);
  });
  testWidgets('copy cannot use a rule revoked while dialog is open', (
    tester,
  ) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer();
    await mount(tester, repo, dialer);
    await tester.tap(find.text('Copier le code'));
    await tester.pumpAndSettle();
    repo.response = const UssdResolution(
      status: 'unavailable',
      reason: 'no_rule',
    );
    await tester.tap(find.text('Confirmer et copier'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Le raccourci a changé'), findsOneWidget);
    expect(dialer.opens, 0);
  });
  testWidgets('resuming the app revalidates without changing navigation', (
    tester,
  ) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer();
    await mount(tester, repo, dialer);
    repo.response = const UssdResolution(
      status: 'unavailable',
      reason: 'no_rule',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.resolutions, 2);
    expect(find.text(UssdEngine.manualMessage), findsOneWidget);
    expect(find.text('Terminer avec preuve'), findsOneWidget);
  });
  for (final width in [300.0, 420.0, 1000.0]) {
    testWidgets('responsive quick processing at $width px', (tester) async {
      await mount(tester, UssdTestRepository(), UssdTestDialer(), width: width);
      expect(tester.takeException(), isNull);
      await launch(tester);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('report refers to rule actually used even after dialer return', (
    tester,
  ) async {
    final repo = UssdTestRepository(), dialer = UssdTestDialer();
    await mount(tester, repo, dialer);
    await launch(tester);
    await tester.tap(find.text('Confirmer et ouvrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Signaler un problème'));
    await tester.tap(find.text('Signaler un problème'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transmettre'));
    await tester.pumpAndSettle();
    expect(repo.reportCount, 1);
    expect(repo.reportedVersion, 2);
  });
}
