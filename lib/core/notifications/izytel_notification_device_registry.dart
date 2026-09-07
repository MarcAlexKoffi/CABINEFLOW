import 'dart:async';

import 'package:cabine_flow/core/notifications/firebase_messaging_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enregistre l'installation mobile courante dans Supabase afin que le backend
/// IzyTel sache quel token FCM joindre pour un Firebase UID donne.
///
/// Ce service n'ecrit jamais dans Firestore et ne contient aucun secret FCM.
class IzyTelNotificationDeviceRegistry {
  IzyTelNotificationDeviceRegistry._();

  static StreamSubscription<String>? _tokenSubscription;
  static String? _activeUid;
  static bool _starting = false;

  static Future<void> start({required AppUser user}) async {
    if (!SupabaseBootstrap.isInitialized || _starting) return;

    final String firebaseUid =
        (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (firebaseUid.isEmpty || firebaseUid != user.id.trim()) {
      debugPrint(
        '[FCM][device-register-skip] session Firebase incoherente.',
      );
      return;
    }

    _starting = true;
    try {
      _activeUid = firebaseUid;
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessagingBootstrap.tokenChanges.listen(
        (String token) {
          unawaited(_registerToken(token));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[FCM][device-token-stream-error] $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      final String? token = FirebaseMessagingBootstrap.currentToken;
      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(token);
      }
    } finally {
      _starting = false;
    }
  }

  static Future<void> deactivateCurrentDevice() async {
    final String? token = FirebaseMessagingBootstrap.currentToken;
    if (!SupabaseBootstrap.isInitialized ||
        token == null ||
        token.trim().isEmpty) {
      await stop();
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'izytel_deactivate_notification_device',
        params: <String, dynamic>{'p_token': token.trim()},
      );
      debugPrint('[FCM][device-deactivated]');
    } catch (error, stackTrace) {
      // La deconnexion ne doit jamais etre bloquee par FCM.
      debugPrint('[FCM][device-deactivate-error] $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await stop();
    }
  }

  static Future<void> stop() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUid = null;
    _starting = false;
  }

  static Future<void> _registerToken(String token) async {
    final String cleanedToken = token.trim();
    if (cleanedToken.isEmpty || !SupabaseBootstrap.isInitialized) return;

    final String currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (currentUid.isEmpty || currentUid != _activeUid) return;

    try {
      await Supabase.instance.client.rpc(
        'izytel_register_notification_device',
        params: <String, dynamic>{
          'p_token': cleanedToken,
          'p_platform': _platformLabel,
        },
      );
      debugPrint(
        '[FCM][device-registered] uid=$currentUid platform=$_platformLabel',
      );
    } catch (error, stackTrace) {
      // Une indisponibilite du registre de notifications ne doit pas casser
      // les commandes, la connexion ou le reste de l'application.
      debugPrint('[FCM][device-register-error] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
