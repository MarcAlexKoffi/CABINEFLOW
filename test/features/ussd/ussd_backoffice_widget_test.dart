import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_modal.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/ussd/presentation/backoffice_ussd_page.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// Google Fonts exposes this HTTP hook specifically for tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'ussd_test_doubles.dart';

void main() {
  ThemeData? visualTheme;
  setUpAll(() async {
    // Optional local render font. Ordinary tests need no network or font cache.
    final font = File('scratch/ussd_reprise_visual/Manrope-Regular.ttf');
    if (Platform.environment['IZYTEL_USSD_RENDER'] == '1' &&
        font.existsSync()) {
      final bytes = await font.readAsBytes();
      await (FontLoader(
        'Manrope',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      // Render the production theme using pinned local font fixtures. No
      // network request is made by widget tests, including visual captures.
      final cache = Directory('scratch/ussd_reprise_visual/font_cache')
        ..createSync(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => cache.absolute.path,
          );
      font_test.httpClient = MockClient((request) async {
        final hash = request.url.pathSegments.last.replaceAll('.ttf', '');
        final local =
            hash ==
                '1ddeeeff9fe3d294f709f2239557278930f56dab89db1fe535dc5c35cd67e0ee'
            ? font
            : File('scratch/ussd_reprise_visual/$hash.ttf');
        return http.Response.bytes(local.readAsBytesSync(), 200);
      });
      visualTheme = BackofficeTheme.light;
      await GoogleFonts.pendingFonts();
      final monoPath = Platform.environment['IZYTEL_USSD_MONO_FONT'];
      if (monoPath != null && File(monoPath).existsSync()) {
        final mono = await File(monoPath).readAsBytes();
        await (FontLoader(
          'monospace',
        )..addFont(Future.value(ByteData.sublistView(mono)))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
            'packages/material_symbols_icons/MaterialSymbolsRounded',
          )..addFont(
            rootBundle.load(
              'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
            ),
          ))
          .load();
    }
  });
  Future<void> mount(
    WidgetTester tester,
    UssdTestRepository repo,
    UserRole role, {
    bool shellScroll = false,
    Size size = const Size(1400, 1000),
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme:
            visualTheme ??
            ThemeData(
              useMaterial3: true,
              fontFamily: 'Manrope',
              colorScheme: ColorScheme.fromSeed(
                seedColor: BackofficePalette.primary,
              ),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('ussd-app-preview'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('ussd-visual-preview'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (_) {
                  final page = BackofficeUssdPage(
                    user: AppUser(
                      id: 'synthetic',
                      name: 'Test',
                      phoneNumber: '',
                      role: role,
                    ),
                    repository: repo,
                  );
                  return shellScroll
                      ? SingleChildScrollView(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1480),
                              child: page,
                            ),
                          ),
                        )
                      : page;
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> action(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byTooltip('Actions sur la règle'));
    await tester.tap(find.byTooltip('Actions sur la règle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String label) async {
    if (Platform.environment['IZYTEL_USSD_RENDER'] != '1') return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('ussd-app-preview')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('scratch/ussd_reprise_visual/$label.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'human aliases are saved canonically and the status remains a draft',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Template USSD'),
        '*410*numéro*montant*code_secret#',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('*410*{{msisdn_local}}*{{amount}}*{{secret_code}}#'),
        findsOneWidget,
      );
      expect(find.text('*410*0101010101*1000*0000#'), findsOneWidget);
      await capture(tester, 'rule-desktop');
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(
        repo.saved?['ussd_template'],
        '*410*{{msisdn_local}}*{{amount}}*{{secret_code}}#',
      );
      expect(repo.saved?['purpose'], 'order');
      expect(repo.statusChanges, 0);
    },
  );

  testWidgets(
    'variable chips insert at the cursor and replace only the selection',
    (tester) async {
      await mount(tester, UssdTestRepository(), UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Template USSD');
      await tester.enterText(field, '*410**1000#');
      final controller = tester.widget<TextFormField>(field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.ensureVisible(
        find.widgetWithText(ActionChip, 'Bénéficiaire'),
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Bénéficiaire'));
      await tester.pumpAndSettle();
      expect(controller.text, '*410*{{msisdn_local}}*1000#');
      expect(controller.selection.baseOffset, 21);
      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 21,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Montant'));
      await tester.pumpAndSettle();
      expect(controller.text, '*410*{{amount}}*1000#');
      expect(controller.selection.baseOffset, 15);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
    },
  );

  for (final size in [
    const Size(360, 480),
    const Size(768, 640),
    const Size(1280, 800),
  ]) {
    testWidgets('rule modal keeps its header and actions visible at $size', (
      tester,
    ) async {
      await mount(
        tester,
        UssdTestRepository(),
        UserRole.administrator,
        size: size,
        textScale: size.width == 360 ? 1.3 : 1,
      );
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.text('Enregistrer en brouillon');
      expect(tester.getRect(save).bottom, lessThan(size.height));
      expect(find.text('Créer un brouillon').hitTestable(), findsOneWidget);
      final note = find.widgetWithText(
        TextFormField,
        'Note interne (sans données personnelles)',
      );
      await tester.ensureVisible(note);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(save.hitTestable(), findsOneWidget);
      expect(find.text('Créer un brouillon').hitTestable(), findsOneWidget);
      await capture(tester, 'rule-${size.width.toInt()}');
      final template = find.widgetWithText(TextFormField, 'Template USSD');
      await tester.ensureVisible(template);
      await tester.enterText(template, '#154*1*numéro#');
      await tester.tap(find.text('Prévisualiser'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Générer sans lancer').hitTestable(), findsOneWidget);
      expect(
        find.text('Prévisualisation fictive').hitTestable(),
        findsOneWidget,
      );
      final phone = find.widgetWithText(TextField, 'Bénéficiaire fictif');
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '0101010101');
      await tester.tap(find.text('Générer sans lancer'));
      await tester.pumpAndSettle();
      final result = find.descendant(
        of: find.byType(BackofficeModalShell).last,
        matching: find.text('#154*1*0101010101#'),
      );
      await tester.ensureVisible(result);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Générer sans lancer').hitTestable(), findsOneWidget);
      await capture(tester, 'preview-${size.width.toInt()}');
    });
  }

  testWidgets(
    'preview separates fictitious data, errors and generated hash-leading result',
    (tester) async {
      await mount(tester, UssdTestRepository(), UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Template USSD'),
        '#154*1*numéro#',
      );
      await tester.tap(find.text('Prévisualiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer sans lancer'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Numéro bénéficiaire invalide'),
        findsOneWidget,
      );
      final phone = find.widgetWithText(TextField, 'Bénéficiaire fictif');
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '+225 01 01 01 01 01');
      await tester.tap(find.text('Générer sans lancer'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BackofficeModalShell).last,
          matching: find.text('#154*1*0101010101#'),
        ),
        findsOneWidget,
      );
      expect(find.text('Données fictives'), findsOneWidget);
      expect(find.text('Résultat généré'), findsOneWidget);
      expect(find.textContaining('Numéro bénéficiaire invalide'), findsNothing);
      await capture(tester, 'preview-desktop');
    },
  );

  testWidgets('loading and read errors remain explicit and retryable', (
    tester,
  ) async {
    final repo = _DeferredRepository();
    await mount(tester, repo, UserRole.administrator, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pending.completeError(StateError('synthetic offline'));
    await tester.pumpAndSettle();
    expect(find.text('Raccourcis USSD indisponibles.'), findsOneWidget);
    repo.failed = true;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Créer une règle'), findsOneWidget);
  });

  testWidgets('table filters narrow rules and can restore the selection', (
    tester,
  ) async {
    await mount(tester, UssdTestRepository(), UserRole.administrator);
    await capture(tester, 'table-desktop');
    final testButton = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Tester'),
    );
    final actions = tester.getRect(find.byTooltip('Actions sur la règle'));
    expect(actions.top, lessThan(testButton.bottom));
    expect(actions.right, lessThanOrEqualTo(1400));
    expect(
      actions.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byType(BackofficeDesktopTable)).bottom,
      ),
    );
    final network = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Réseau',
    );
    await tester.tap(network);
    await tester.pumpAndSettle();
    await tester.tap(find.text('MTN').last);
    await tester.pumpAndSettle();
    expect(find.text('Aucune règle dans cette sélection.'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Réseau'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous').last);
    await tester.pumpAndSettle();
    expect(find.byType(BackofficeDesktopTable), findsOneWidget);
  });

  for (final role in [UserRole.administrator, UserRole.manager]) {
    for (final empty in [false, true]) {
      testWidgets('USSD renders in shell scroll: $role, empty=$empty', (
        tester,
      ) async {
        await mount(
          tester,
          empty ? _EmptyRepository() : UssdTestRepository(),
          role,
          shellScroll: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Catalogue / Raccourcis USSD'), findsOneWidget);
        expect(find.text('Anomalies USSD'), findsOneWidget);
        expect(
          find.text('Créer une règle'),
          role == UserRole.administrator ? findsOneWidget : findsNothing,
        );
        if (empty) {
          expect(
            find.textContaining('Aucune règle dans cette sélection.'),
            findsOneWidget,
          );
        } else {
          expect(find.byType(BackofficeDesktopTable), findsOneWidget);
        }
      });
    }
  }

  testWidgets('missing Firebase session shows recovery instructions', (
    tester,
  ) async {
    await mount(
      tester,
      _SessionMissingRepository(),
      UserRole.administrator,
      shellScroll: true,
    );
    expect(
      find.textContaining('Déconnectez-vous puis reconnectez-vous'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Créer une règle'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manager sees rules and anomalies with no edit controls', (
    tester,
  ) async {
    await mount(tester, UssdTestRepository(), UserRole.manager);
    expect(find.text('Créer une règle'), findsNothing);
    expect(find.text('Associer les offres'), findsNothing);
    expect(find.text('Gérer les familles'), findsNothing);
    expect(find.text('Anomalies USSD'), findsOneWidget);
    expect(find.byTooltip('Actions sur la règle'), findsNothing);
  });

  testWidgets(
    'balance draft preserves its purpose without inventing an order service',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Usage'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultation du solde').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BackofficeModalShell).last,
          matching: find.widgetWithText(
            DropdownButtonFormField<String>,
            'Service',
          ),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Template USSD'),
        '*414*code_secret#',
      );
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(repo.saved?['purpose'], 'balance');
      expect(repo.saved?['service'], isNull);
      expect(repo.saved?['family_id'], isNull);
      expect(repo.saved?['ussd_template'], '*414*{{secret_code}}#');
    },
  );

  testWidgets(
    'deletion requires confirmation and cancellation keeps the rule',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await action(tester, 'Supprimer');
      expect(find.text('Supprimer cette règle ?'), findsOneWidget);
      expect(repo.ruleDeletions, 0);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.ruleDeletions, 0);
      expect(find.byTooltip('Actions sur la règle'), findsOneWidget);
    },
  );
  testWidgets(
    'confirmed deletion removes the draft and submits its displayed version',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await action(tester, 'Supprimer');
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(repo.deletedRule?.id, 'synthetic-rule');
      expect(repo.deletedRule?.version, 2);
      expect(repo.ruleDeletions, 1);
      expect(find.byTooltip('Actions sur la règle'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('deleting an active rule clearly explains the effect', (
    tester,
  ) async {
    final repo = _ActiveRuleRepository();
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Supprimer');
    expect(
      find.textContaining('les nouveaux lancements seront refusés'),
      findsOneWidget,
    );
    expect(repo.ruleDeletions, 0);
    await tester.tap(find.text('Confirmer la suppression'));
    await tester.pumpAndSettle();
    expect(repo.deletedRule?.status, 'active');
  });
  testWidgets('failed deletion keeps the row and reports the changed rule', (
    tester,
  ) async {
    final repo = UssdTestRepository()..failDeletion = true;
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Supprimer');
    await tester.tap(find.text('Confirmer la suppression'));
    await tester.pumpAndSettle();
    expect(repo.ruleDeletions, 1);
    expect(repo.deletedRule, isNull);
    expect(find.byTooltip('Actions sur la règle'), findsOneWidget);
    expect(find.text(UssdEngine.message('rule_changed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('pending deletion disables additional writes', (tester) async {
    final repo = UssdTestRepository()..deletionPending = Completer<void>();
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Supprimer');
    await tester.tap(find.text('Confirmer la suppression'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.ruleDeletions, 1);
    expect(
      tester
          .widget<PopupMenuButton<String>>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is PopupMenuButton<String> &&
                  widget.tooltip == 'Actions sur la règle',
            ),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Créer une règle'),
          )
          .onPressed,
      isNull,
    );
    repo.deletionPending!.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Actions sur la règle'), findsNothing);
  });
  testWidgets(
    'family deletion is confirmed and reflected after configuration refresh',
    (tester) async {
      final repo = _DeletionRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Gérer les familles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer la famille Famille fictive'));
      await tester.pumpAndSettle();
      expect(repo.familyDeleted, isFalse);
      expect(find.text('Supprimer cette famille ?'), findsOneWidget);
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(repo.familyDeleted, isTrue);
      await tester.tap(find.text('Gérer les familles'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune famille créée.'), findsOneWidget);
    },
  );
  testWidgets(
    'family dependency rejection leaves it available and gives actionable feedback',
    (tester) async {
      final repo = _DeletionRepository()..familyInUse = true;
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Gérer les familles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer la famille Famille fictive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(repo.familyDeleted, isFalse);
      expect(
        find.textContaining('Retirez-la des règles et des associations'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    },
  );
  testWidgets(
    'binding deletion has a confirmation and does not remove the catalogue offer',
    (tester) async {
      final repo = _DeletionRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Associer les offres'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Offre réelle'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Offre fictive').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Supprimer cette association'));
      await tester.tap(find.text('Supprimer cette association'));
      await tester.pumpAndSettle();
      expect(repo.bindingDeleted, isFalse);
      expect(find.text('Supprimer cette association ?'), findsOneWidget);
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(repo.bindingDeleted, isTrue);
      expect(repo.deletedBindingVersion, 4);
      final offers = (await repo.configuration())['offers'] as List;
      expect(offers.single['id'], 'synthetic-offer');
      expect(offers.single['binding'], isNull);
    },
  );
  testWidgets(
    'deletion confirmation remains usable on a compact enlarged screen',
    (tester) async {
      await mount(
        tester,
        UssdTestRepository(),
        UserRole.administrator,
        size: const Size(360, 480),
        textScale: 1.3,
      );
      await action(tester, 'Supprimer');
      expect(find.text('Confirmer la suppression'), findsOneWidget);
      expect(
        tester.getRect(find.text('Confirmer la suppression')).bottom,
        lessThanOrEqualTo(480),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('editing an active rule clearly returns it to draft', (
    tester,
  ) async {
    final repo = _ActiveRuleRepository();
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Modifier (remet en brouillon)');
    expect(
      find.textContaining('Enregistrer désactive la version active'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enregistrer en brouillon'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNotNull);
    expect(repo.saved!.containsKey('status'), isFalse);
    expect(repo.statusChanges, 0);
  });

  testWidgets('disabling an active rule requires confirmation', (tester) async {
    final repo = _ActiveRuleRepository();
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Désactiver');
    expect(repo.statusChanges, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Désactiver'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, 1);
    expect(repo.changedStatus, 'disabled');
  });
  testWidgets(
    'new rule stays a draft; preview static code needs no beneficiary',
    (tester) async {
      final repo = UssdTestRepository();
      await mount(tester, repo, UserRole.administrator);
      await tester.tap(find.text('Créer une règle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Template USSD'),
        '*999*2#',
      );
      await tester.tap(find.text('Prévisualiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer sans lancer'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BackofficeModalShell).last,
          matching: find.text('*999*2#'),
        ),
        findsNWidgets(2),
      );
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(repo.saved?['ussd_template'], '*999*2#');
      expect(repo.statusChanges, 0);
    },
  );
  testWidgets('activation requires explicit SIM confirmation', (tester) async {
    final repo = UssdTestRepository();
    await mount(tester, repo, UserRole.administrator);
    await action(tester, 'Activer après validation SIM');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activer cette version'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Type de SIM testé (aucun numéro)'),
      'SIM cabine de test',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer cette version'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, 1);
  });
  testWidgets(
    'a deleted catalogue offer leaves the editor usable and requires explicit reassociation',
    (tester) async {
      final repo = _DeletedOfferRepository();
      await mount(tester, repo, UserRole.administrator);
      await action(tester, 'Modifier (remet en brouillon)');
      expect(tester.takeException(), isNull);
      expect(find.text('Offre indisponible (à remplacer)'), findsOneWidget);
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      expect(
        find.textContaining('L’association n’est plus disponible'),
        findsOneWidget,
      );
      await tester.tap(find.text('Offre indisponible (à remplacer)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toutes / générique').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer en brouillon'));
      await tester.pumpAndSettle();
      expect(repo.saved?['offer_id'], isNull);
      expect(repo.saved, isNotNull);
    },
  );
}

class _DeletionRepository extends UssdTestRepository {
  bool familyDeleted = false, bindingDeleted = false, familyInUse = false;
  int? deletedBindingVersion;

  @override
  Future<Map<String, dynamic>> configuration() async => {
    ...await super.configuration(),
    'families': [
      if (!familyDeleted)
        {
          'id': 'synthetic-family',
          'network': 'moov',
          'service': 'internetSubscription',
          'label': 'Famille fictive',
        },
    ],
    'offers': [
      {
        'id': 'synthetic-offer',
        'network': 'moov',
        'service': 'internetSubscription',
        'title': 'Offre fictive',
        'binding': bindingDeleted
            ? null
            : {
                'family_id': 'synthetic-family',
                'offer_code': '123',
                'quantity': 1,
                'version': 4,
              },
      },
    ],
  };

  @override
  Future<void> deleteFamily(String familyId) async {
    if (familyInUse) throw StateError('family_in_use');
    familyDeleted = true;
  }

  @override
  Future<void> deleteBinding(String offerId, int version) async {
    bindingDeleted = true;
    deletedBindingVersion = version;
  }
}

class _EmptyRepository extends UssdTestRepository {
  @override
  Future<Map<String, dynamic>> configuration() async => {
    'rules': [],
    'families': [],
    'offers': [],
  };
}

class _SessionMissingRepository extends UssdTestRepository {
  @override
  Future<Map<String, dynamic>> configuration() async =>
      throw const UssdValidationException('authentication_required');
}

class _DeletedOfferRepository extends UssdTestRepository {
  @override
  Future<Map<String, dynamic>> configuration() async {
    final result = await super.configuration();
    ((result['rules'] as List).first as Map)['offer_id'] = 'deleted-offer';
    return result;
  }
}

class _DeferredRepository extends UssdTestRepository {
  final pending = Completer<Map<String, dynamic>>();
  bool failed = false;
  @override
  Future<Map<String, dynamic>> configuration() =>
      failed ? super.configuration() : pending.future;
}

class _ActiveRuleRepository extends UssdTestRepository {
  String? changedStatus;
  @override
  Future<Map<String, dynamic>> configuration() async {
    final data = await super.configuration();
    for (final rule in data['rules'] as List) {
      (rule as Map)['status'] = 'active';
    }
    return data;
  }

  @override
  Future<void> setStatus(
    UssdRule rule,
    String status, {
    String? simType,
  }) async {
    changedStatus = status;
    await super.setStatus(rule, status, simType: simType);
  }
}
