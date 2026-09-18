import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/notifications/firebase_messaging_bootstrap.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
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
  static final Set<String> _registeringTokens = <String>{};

  /// Active le registre pour la session staff courante.
  ///
  /// Le bootstrap FCM et Supabase peut avoir echoue au tout premier demarrage
  /// a cause d'une coupure reseau. Cette methode les relance donc sans bloquer
  /// la connexion ni le reste de l'application.
  static Future<void> start({required AppUser user}) async {
    await _activate(user: user, resetSubscription: true);
  }

  /// Auto-reparation appelee lorsque l'application revient au premier plan.
  ///
  /// Elle relit le token FCM puis rejoue son enregistrement Supabase, meme si
  /// le token n'a pas change. L'RPC serveur est un upsert idempotent et remet
  /// ainsi a jour `last_seen_at` / `is_active` apres une coupure ou rotation.
  static Future<void> refresh({required AppUser user}) async {
    await _activate(user: user, resetSubscription: false);
  }

  static Future<void> _activate({
    required AppUser user,
    required bool resetSubscription,
  }) async {
    if (_starting) return;

    final String firebaseUid =
        (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (firebaseUid.isEmpty || firebaseUid != user.id.trim()) {
      IzyTelLog.debug(
        '[FCM][device-register-skip] session Firebase incoherente.',
      );
      return;
    }

    _starting = true;
    try {
      final FirebaseMessagingBootstrapResult messaging =
          await FirebaseMessagingBootstrap.ensureReady(refreshToken: true);
      if (!messaging.supported) return;

      final bool supabaseReady = await _ensureSupabaseReady();
      if (!supabaseReady) {
        IzyTelLog.debug(
          '[FCM][device-register-deferred] Supabase indisponible.',
        );
        return;
      }

      _activeUid = firebaseUid;

      if (resetSubscription || _tokenSubscription == null) {
        await _tokenSubscription?.cancel();
        _tokenSubscription = FirebaseMessagingBootstrap.tokenChanges.listen(
          (String token) {
            unawaited(_registerToken(token));
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'FCM.device-token-stream',
              error,
              stackTrace: stackTrace,
            );
          },
        );
      }

      final String? token = FirebaseMessagingBootstrap.currentToken;
      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(token);
      } else {
        IzyTelLog.debug('[FCM][device-register-deferred] token indisponible.');
      }
    } finally {
      _starting = false;
    }
  }

  static Future<bool> _ensureSupabaseReady() async {
    if (SupabaseBootstrap.isInitialized) return true;

    for (int attempt = 0; attempt < 2; attempt++) {
      if (await SupabaseBootstrap.initialize()) return true;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return SupabaseBootstrap.isInitialized;
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
      await BackendFailurePolicy.retryIdempotent<void>(
        () async {
          await Supabase.instance.client.rpc(
            'izytel_deactivate_notification_device',
            params: <String, dynamic>{'p_token': token.trim()},
          );
        },
        maxAttempts: 2,
        baseDelay: const Duration(milliseconds: 250),
        maxDelay: const Duration(seconds: 1),
      );
      IzyTelLog.debug('[FCM][device-deactivated]');
    } catch (error, stackTrace) {
      // La deconnexion ne doit jamais etre bloquee par FCM.
      IzyTelLog.backendError(
        'FCM.device-deactivate',
        error,
        stackTrace: stackTrace,
      );
    } finally {
      await stop();
    }
  }

  static Future<void> stop() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUid = null;
    _starting = false;
    _registeringTokens.clear();
  }

  static Future<void> _registerToken(String token) async {
    final String cleanedToken = token.trim();
    if (cleanedToken.isEmpty || !SupabaseBootstrap.isInitialized) return;
    if (!_registeringTokens.add(cleanedToken)) return;

    final String currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (currentUid.isEmpty || currentUid != _activeUid) {
      _registeringTokens.remove(cleanedToken);
      return;
    }

    try {
      await BackendFailurePolicy.retryIdempotent<void>(
        () async {
          await Supabase.instance.client.rpc(
            'izytel_register_notification_device',
            params: <String, dynamic>{
              'p_token': cleanedToken,
              'p_platform': _platformLabel,
            },
          );
        },
        maxAttempts: 3,
        baseDelay: const Duration(milliseconds: 400),
        maxDelay: const Duration(seconds: 3),
      );
      IzyTelLog.debug(
        '[FCM][device-registered] platform=$_platformLabel',
      );
    } catch (error, stackTrace) {
      // Une indisponibilite du registre de notifications ne doit pas casser
      // les commandes, la connexion ou le reste de l'application.
      IzyTelLog.backendError(
        'FCM.device-register',
        error,
        stackTrace: stackTrace,
      );
    } finally {
      _registeringTokens.remove(cleanedToken);
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
