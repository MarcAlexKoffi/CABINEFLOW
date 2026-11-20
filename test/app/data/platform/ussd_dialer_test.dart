import 'package:cabine_flow/app/domain/policies/ussd/ussd_engine.dart';
import 'package:cabine_flow/app/data/platform/ussd_dialer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidUssdDialer.channel, (call) async {
          calls.add(call);
          return null;
        });
    calls.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidUssdDialer.channel, null);
  });
  test(
    'Max it uses the fixed native app action without USSD or order data',
    () async {
      await const AndroidUssdDialer().open(UssdEngine.maxItCommand);
      expect(calls.single.method, 'openMaxIt');
      expect(calls.single.arguments, isNull);
      calls.clear();
      await const AndroidUssdDialer().canOpenMaxIt();
      expect(calls.single.method, 'canOpenMaxIt');
      calls.clear();
      await const AndroidUssdDialer().openMaxItStore();
      expect(calls.single.method, 'openMaxItStore');
    },
  );
  test(
    'absent Max it is explicit and never falls back to the dialer',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidUssdDialer.channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'maxit_not_installed');
          });
      await expectLater(
        const AndroidUssdDialer().open(UssdEngine.maxItCommand),
        throwsA(
          isA<UssdValidationException>().having(
            (e) => e.code,
            'code',
            'maxit_not_installed',
          ),
        ),
      );
      expect(calls.map((c) => c.method), ['openMaxIt']);
    },
  );
  test(
    'only validated raw code is passed to native dialer with hash intact',
    () async {
      await const AndroidUssdDialer().open('*999*0101010101#');
      expect(calls.single.method, 'openDialer');
      expect(calls.single.arguments, {'code': '*999*0101010101#'});
    },
  );
  test(
    'Orange leading and closing hashes reach native channel intact',
    () async {
      await const AndroidUssdDialer().open('#154*1*0101010101#');
      expect(calls.single.arguments, {'code': '#154*1*0101010101#'});
    },
  );
  for (final code in ['tel:*999#', '*999#;CALL', '*999*abc#', '*999#\n']) {
    test('native channel not invoked for malformed code $code', () async {
      await expectLater(
        const AndroidUssdDialer().open(code),
        throwsA(isA<UssdValidationException>()),
      );
      expect(calls, isEmpty);
    });
  }
  test('unsupported platforms cannot open a dialer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(const AndroidUssdDialer().supported, isFalse);
    await expectLater(
      const AndroidUssdDialer().open('*999#'),
      throwsA(isA<UssdValidationException>()),
    );
    expect(calls, isEmpty);
  });
}
