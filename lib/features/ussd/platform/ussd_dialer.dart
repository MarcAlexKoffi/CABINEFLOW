import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';

abstract class UssdDialer {
  bool get supported;
  Future<void> open(String code);
}

class AndroidUssdDialer implements UssdDialer {
  const AndroidUssdDialer();
  static const channel = MethodChannel('com.izytel/ussd_dialer');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> open(String code) async {
    UssdEngine.validateCode(code);
    if (!supported) throw const UssdValidationException('dialer_unavailable');
    await channel.invokeMethod<void>('openDialer', {'code': code});
  }
}
