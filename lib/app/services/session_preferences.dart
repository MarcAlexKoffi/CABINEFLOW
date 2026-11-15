import 'package:flutter/services.dart';

class RememberedSessionPreference {
  const RememberedSessionPreference({
    required this.rememberMe,
    required this.email,
  });

  final bool rememberMe;
  final String email;
}

/// Persistance Android minimale pour « Se souvenir de moi ».
///
/// Aucun mot de passe n'est stocké. Firebase Auth conserve sa session de son
/// côté ; ce store mémorise seulement le choix de l'utilisateur et son e-mail.
class SessionPreferences {
  SessionPreferences._();

  static const MethodChannel _channel = MethodChannel(
    'com.izytel/session_preferences',
  );

  static Future<RememberedSessionPreference> load() async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('getRememberedSession');
      return RememberedSessionPreference(
        rememberMe: result?['rememberMe'] == true,
        email: (result?['email'] as String? ?? '').trim(),
      );
    } on MissingPluginException {
      return const RememberedSessionPreference(rememberMe: false, email: '');
    } on PlatformException {
      return const RememberedSessionPreference(rememberMe: false, email: '');
    }
  }

  static Future<void> save({
    required bool rememberMe,
    required String email,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'saveRememberedSession',
        <String, Object>{
          'rememberMe': rememberMe,
          'email': email.trim().toLowerCase(),
        },
      );
    } on MissingPluginException {
      // Plateforme non Android : Firebase continue de gérer sa session.
    } on PlatformException {
      // La connexion ne doit jamais échouer uniquement à cause de ce confort.
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearRememberedSession');
    } on MissingPluginException {
      // Rien à effacer sur cette plateforme.
    } on PlatformException {
      // Ne bloque pas la déconnexion.
    }
  }
}
