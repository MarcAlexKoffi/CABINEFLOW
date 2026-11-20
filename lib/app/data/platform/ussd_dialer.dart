import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cabine_flow/app/domain/policies/ussd/ussd_engine.dart';

abstract class UssdDialer {
  bool get supported;
  Future<void> open(String code);
  Future<bool> canOpenMaxIt();
  Future<void> openMaxItStore();
}

class AndroidUssdDialer implements UssdDialer {
  const AndroidUssdDialer();
  static const channel = MethodChannel('com.izytel/ussd_dialer');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> open(String code) async {
    if (code == UssdEngine.maxItCommand) {
      if (!supported) throw const UssdValidationException('maxit_unavailable');
      try {
        await channel.invokeMethod<void>('openMaxIt');
      } on PlatformException catch (error) {
        throw UssdValidationException(
          error.code == 'maxit_not_installed'
              ? 'maxit_not_installed'
              : 'maxit_unavailable',
        );
      }
      return;
    }
    UssdEngine.validateCode(code);
    if (!supported) throw const UssdValidationException('dialer_unavailable');
    await channel.invokeMethod<void>('openDialer', {'code': code});
  }

  @override
  Future<bool> canOpenMaxIt() async {
    if (!supported) throw const UssdValidationException('maxit_unavailable');
    try {
      return await channel.invokeMethod<bool>('canOpenMaxIt') ?? false;
    } on PlatformException {
      throw const UssdValidationException('maxit_unavailable');
    }
  }

  @override
  Future<void> openMaxItStore() async {
    if (!supported) throw const UssdValidationException('store_unavailable');
    try {
      await channel.invokeMethod<void>('openMaxItStore');
    } on PlatformException {
      throw const UssdValidationException('store_unavailable');
    }
  }
}
