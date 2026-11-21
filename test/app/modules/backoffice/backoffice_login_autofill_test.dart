import 'dart:async';
import 'package:cabine_flow/app/domain/entities/auth/auth_login_result.dart';
import 'package:cabine_flow/app/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/backoffice_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class AuthFake implements AuthRepository {
  String? identifier, password;
  var response = Completer<AuthLoginResult>();
  int calls = 0;
  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) {
    calls++;
    this.identifier = identifier;
    this.password = password;
    return response.future;
  }

  @override
  Future<void> logout() async {}
  @override
  Future<AuthLoginResult> refreshCurrentAccess() async =>
      const AuthLoginResult.invalidCredentials();
}

void main() {
  for (final opening in ['initial', 'reload']) {
    testWidgets(
      'autofills both fields on $opening opening and retains them on rebuild',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = AuthFake();
        await tester.pumpWidget(
          MaterialApp(
            home: BackofficeLoginPage(
              key: ValueKey(opening),
              authRepository: repository,
              onAuthenticated: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editable = tester
            .stateList<EditableTextState>(find.byType(EditableText))
            .toList();
        expect(
          editable.first.widget.autofillHints!.first,
          AutofillHints.username,
        );
        expect(
          editable.last.widget.autofillHints!.first,
          AutofillHints.password,
        );
        expect(editable.first.widget.focusNode.hasFocus, isTrue);
        tester.binding.channelBuffers.push(
          SystemChannels.textInput.name,
          SystemChannels.textInput.codec.encodeMethodCall(
            MethodCall('TextInputClient.updateEditingStateWithTag', [
              -1,
              {
                editable.first.autofillId: const TextEditingValue(
                  text: 'staff@example.test',
                ).toJSON(),
                editable.last.autofillId: const TextEditingValue(
                  text: 'synthetic-password',
                ).toJSON(),
              },
            ]),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(editable.first.widget.controller.text, 'staff@example.test');
        expect(editable.last.widget.controller.text, 'synthetic-password');
        // The same autofill clients must survive the desktop/mobile breakpoint.
        tester.view.physicalSize = const Size(430, 932);
        await tester.pumpAndSettle();
        // Rebuild both fields while keeping their autofill registrations/controllers.
        await tester.ensureVisible(find.byType(IconButton).first);
        await tester.tap(find.byType(IconButton).first);
        await tester.pumpAndSettle();
        final after = tester
            .stateList<EditableTextState>(find.byType(EditableText))
            .toList();
        expect(after.first.autofillId, editable.first.autofillId);
        expect(after.last.autofillId, editable.last.autofillId);
        expect(after.last.widget.keyboardType, TextInputType.visiblePassword);
        expect(after.last.widget.controller.text, 'synthetic-password');
        await tester.ensureVisible(find.text('Se connecter'));
        await tester.tap(find.text('Se connecter'));
        await tester.pump();
        expect(repository.identifier, 'staff@example.test');
        expect(repository.password, 'synthetic-password');
        repository.response.complete(
          const AuthLoginResult.invalidCredentials(),
        );
        await tester.pumpAndSettle();
        expect(after.last.widget.controller.text, 'synthetic-password');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'a network failure keeps autofill values and allows login retry',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = AuthFake();
      await tester.pumpWidget(
        MaterialApp(
          home: BackofficeLoginPage(
            authRepository: repository,
            onAuthenticated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('backoffice-username')),
        'staff@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('backoffice-current-password')),
        'synthetic-password',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      repository.response.completeError(TimeoutException('synthetic offline'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Connexion interrompue. Vérifiez votre connexion puis réessayez.',
        ),
        findsOneWidget,
      );
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.controller!.text, 'staff@example.test');
      expect(fields.last.controller!.text, 'synthetic-password');
      expect(fields.every((field) => !field.readOnly), isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Se connecter'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      repository.response = Completer<AuthLoginResult>();
      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      expect(repository.calls, 2);
      expect(repository.identifier, 'staff@example.test');
      expect(repository.password, 'synthetic-password');
      repository.response.complete(const AuthLoginResult.invalidCredentials());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
