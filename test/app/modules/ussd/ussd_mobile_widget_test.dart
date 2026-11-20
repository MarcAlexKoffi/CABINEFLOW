import 'dart:async';
import 'package:cabine_flow/app/domain/policies/ussd/ussd_engine.dart';
import 'package:cabine_flow/app/domain/repositories/ussd_repository.dart';
import 'package:cabine_flow/app/modules/ussd/widgets/ussd_quick_processing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/ussd_test_doubles.dart';

class _ServerResolvedRepository extends UssdTestRepository {
  bool changedSecretRevision = false;
  String? preparationFailure;
  @override
  Future<UssdResolution> prepare(
    String orderId,
    UssdResolution confirmed,
    String requestId, {
    bool confirmNotExecuted = false,
  }) async {
    preparations++;
    lastConfirmedNotExecuted = confirmNotExecuted;
    if (preparationFailure != null) {
      return UssdResolution(status: 'unavailable', reason: preparationFailure!);
    }
    if (revokeOnPrepare) {
      return const UssdResolution(
        status: 'unavailable',
        reason: 'rule_changed',
      );
    }
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

class _DelayedMaxItAuditRepository extends _ServerResolvedRepository {
  final audit = Completer<void>();

  @override
  Future<void> recordResult(
    String attemptId,
    String status,
    String? errorCode,
  ) async {
    await audit.future;
    await super.recordResult(attemptId, status, errorCode);
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
    String beneficiary = '0101010101',
    bool? canCopyNumber,
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
                beneficiary: beneficiary,
                canCopyNumber: canCopyNumber,
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

  Future<void> confirmAction(WidgetTester tester, String label) async {
    final acknowledgment = find.byKey(
      const ValueKey('ussd-not-executed-confirmation'),
    );
    if (acknowledgment.evaluate().isNotEmpty) {
      await tester.ensureVisible(acknowledgment);
      await tester.tap(acknowledgment);
      await tester.pump();
    }
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Lancer l’opération'));
    await tester.tap(find.text('Lancer l’opération'));
    await tester.pumpAndSettle();
  }

  UssdResolution maxIt() => UssdResolution(
    status: 'available',
    reason: '',
    code: UssdEngine.maxItCommand,
    rule: UssdRule(
      id: 'maxit-rule',
      version: 1,
      network: 'orange',
      service: 'internetSubscription',
      scope: 'agent',
      template: UssdEngine.maxItCommand,
      offerId: 'orange-offer',
      priority: 0,
      status: 'active',
      effectiveFrom: DateTime.utc(2020),
    ),
    context: const {
      'network': 'orange',
      'service': 'internetSubscription',
      'beneficiary': '0707070707',
      'offer_label': 'Offre Orange associée',
      'amount': 1000,
    },
  );

  Future<void> confirmMaxIt(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Ouvrir Max it'));
    await tester.tap(find.text('Ouvrir Max it'));
    await tester.pumpAndSettle();
    await confirmAction(tester, 'Confirmer et ouvrir');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Max it requires confirmation and preparation, preserves order on return and does not complete it',
    (tester) async {
      final repo = _ServerResolvedRepository()..response = maxIt();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      expect(find.text('Copier le code'), findsNothing);
      expect(dialer.opens, 0);
      await confirmMaxIt(tester);
      expect(repo.preparations, 1);
      expect(dialer.opens, 1);
      expect(dialer.lastCode, UssdEngine.maxItCommand);
      expect(repo.lastStatus, 'app_opened');
      expect(repo.statusChanges, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(dialer.opens, 1);
      expect(repo.preparations, 1);
      expect(repo.statusChanges, 0);
      expect(find.text('Terminer avec preuve'), findsOneWidget);
      expect(find.textContaining('Offre Orange associée'), findsOneWidget);
    },
  );

  testWidgets(
    'USSD reopening requires a fresh explicit no-execution confirmation on every tap',
    (tester) async {
      final repo = _ServerResolvedRepository();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      for (var attempt = 1; attempt <= 2; attempt++) {
        await launch(tester);
        final confirmButton = find.widgetWithText(
          FilledButton,
          'Confirmer et ouvrir',
        );
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
        expect(repo.preparations, attempt - 1);
        await confirmAction(tester, 'Confirmer et ouvrir');
        await tester.pumpAndSettle();
        expect(repo.lastConfirmedNotExecuted, isTrue);
        expect(repo.preparations, attempt);
        expect(dialer.opens, attempt);
        expect(repo.statusChanges, 0);
      }
    },
  );

  testWidgets(
    'USSD can reopen after Android resumes while the first audit is pending',
    (tester) async {
      final repo = _DelayedMaxItAuditRepository();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      await launch(tester);
      await confirmAction(tester, 'Confirmer et ouvrir');
      await tester.pump();
      expect(dialer.opens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repo.audit.complete();
      await tester.pumpAndSettle();
      await launch(tester);
      await confirmAction(tester, 'Confirmer et ouvrir');
      await tester.pumpAndSettle();
      expect(dialer.opens, 2);
      expect(repo.statusChanges, 0);
    },
  );

  testWidgets(
    'same order can reopen Max it without lifecycle refresh, with fresh server checks each time',
    (tester) async {
      final repo = _ServerResolvedRepository()..response = maxIt();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      await confirmMaxIt(tester);
      final firstResolutions = repo.resolutions;
      await confirmMaxIt(tester);
      expect(repo.resolutions, greaterThan(firstResolutions));
      expect(repo.preparations, 2);
      expect(repo.recordings, 2);
      expect(dialer.opens, 2);
      expect(repo.statusChanges, 0);
    },
  );

  testWidgets(
    'Max it remains reopenable when Android resumes before the opening audit finishes',
    (tester) async {
      final repo = _DelayedMaxItAuditRepository()..response = maxIt();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      await tester.ensureVisible(find.text('Ouvrir Max it'));
      await tester.tap(find.text('Ouvrir Max it'));
      await tester.pumpAndSettle();
      await confirmAction(tester, 'Confirmer et ouvrir');
      await tester.pump();
      expect(dialer.opens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      repo.audit.complete();
      await tester.pumpAndSettle();
      await confirmMaxIt(tester);
      expect(dialer.opens, 2);
      expect(repo.preparations, 2);
      expect(repo.statusChanges, 0);
    },
  );

  testWidgets(
    'reopening Max it still fails closed offline and displays an uncertain execution refusal',
    (tester) async {
      final repo = _ServerResolvedRepository()..response = maxIt();
      final dialer = _CapturingDialer();
      await mount(tester, repo, dialer);
      await confirmMaxIt(tester);
      repo.failRead = true;
      await tester.ensureVisible(find.text('Ouvrir Max it'));
      await tester.tap(find.text('Ouvrir Max it'));
      await tester.pumpAndSettle();
      expect(dialer.opens, 1);
      expect(repo.preparations, 1);
      repo.failRead = false;
      repo.preparationFailure = 'execution_uncertain';
      await tester.ensureVisible(find.text('Actualiser le raccourci'));
      await tester.tap(find.text('Actualiser le raccourci'));
      await tester.pumpAndSettle();
      await confirmMaxIt(tester);
      expect(dialer.opens, 1);
      expect(
        find.textContaining('Faites vérifier son résultat par votre Manager'),
        findsOneWidget,
      );
      expect(repo.statusChanges, 0);
    },
  );

  testWidgets(
    'absent Max it offers Google Play without consuming preparation or opening a dialer',
    (tester) async {
      final repo = _ServerResolvedRepository()..response = maxIt();
      final dialer = UssdTestDialer()..maxItInstalled = false;
      await mount(tester, repo, dialer);
      await confirmMaxIt(tester);
      expect(dialer.opens, 0);
      expect(repo.preparations, 0);
      expect(repo.recordings, 0);
      expect(find.textContaining('n’est pas installé'), findsOneWidget);
      await tester.ensureVisible(find.text('Voir Max it sur Google Play'));
      await tester.tap(find.text('Voir Max it sur Google Play'));
      await tester.pumpAndSettle();
      expect(dialer.storeOpens, 1);
      expect(dialer.opens, 0);
    },
  );

  testWidgets(
    'revoked or expired Max it authorization never launches the application',
    (tester) async {
      final repo = _ServerResolvedRepository()
        ..response = maxIt()
        ..revokeOnPrepare = true;
      final dialer = UssdTestDialer();
      await mount(tester, repo, dialer);
      await confirmMaxIt(tester);
      expect(dialer.opens, 0);
      repo.revokeOnPrepare = false;
      repo.leaseMs = 0;
      await tester.tap(find.text('Actualiser le raccourci'));
      await tester.pumpAndSettle();
      await confirmMaxIt(tester);
      expect(dialer.opens, 0);
      expect(repo.lastStatus, 'failed');
      expect(repo.lastReason, 'interrupted');
    },
  );

  testWidgets(
    'non-processable and offline Max it orders cannot launch the app',
    (tester) async {
      final repo = _ServerResolvedRepository()..response = maxIt();
      final dialer = UssdTestDialer();
      await mount(tester, repo, dialer, processable: false);
      expect(repo.resolutions, 0);
      expect(repo.preparations, 0);
      expect(dialer.opens, 0);
      repo.failRead = true;
      await mount(tester, repo, dialer);
      expect(repo.preparations, 0);
      expect(dialer.opens, 0);
    },
  );

  for (final phone in [
    '+225 01 02 03 04 05',
    '00225 01 02 03 04 05',
    '0102030405',
  ]) {
    testWidgets(
      'copies local beneficiary directly without a dialer or USSD request: $phone',
      (tester) async {
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
        await mount(
          tester,
          repo,
          dialer,
          beneficiary: phone,
          processable: false,
          canCopyNumber: true,
        );
        await tester.tap(find.text('Copier le numéro'));
        await tester.pumpAndSettle();
        expect(copied, '0102030405');
        expect(repo.resolutions, 0);
        expect(repo.preparations, 0);
        expect(dialer.opens, 0);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
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
        await confirmAction(tester, 'Confirmer et ouvrir');
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
      await confirmAction(tester, 'Confirmer et ouvrir');
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
      await confirmAction(tester, 'Confirmer et ouvrir');
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
    await confirmAction(tester, 'Confirmer et ouvrir');
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
      await confirmAction(tester, 'Confirmer et ouvrir');
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
      await confirmAction(tester, 'Confirmer et ouvrir');
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
    await confirmAction(tester, 'Confirmer et ouvrir');
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
    await confirmAction(tester, 'Confirmer et copier');
    await tester.pumpAndSettle();
    expect(copied, '*999*0101010101#');
    expect(repo.resolutions, 3);
    expect(repo.preparations, 1);
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
    await confirmAction(tester, 'Confirmer et copier');
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
    await confirmAction(tester, 'Confirmer et ouvrir');
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
