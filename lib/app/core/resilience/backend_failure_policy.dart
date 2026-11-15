import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BackendFailureKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  contract,
  unknown,
}

/// Classe les erreurs backend sans dependre de leur texte affiche a l'utilisateur.
///
/// En Phase 3, seules les erreurs de transport ou de disponibilite peuvent etre
/// masquees temporairement par une derniere valeur connue. Les erreurs de droit,
/// de contrat ou de schema doivent remonter afin de ne pas produire un faux etat
/// "vide" dans l'interface.
class BackendFailurePolicy {
  const BackendFailurePolicy._();

  static const Duration defaultMaxBackoff = Duration(seconds: 30);

  static bool canRetryRead(Object error) {
    if (error is TimeoutException) return true;

    if (error is FirebaseException) {
      if (const <String>{
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'network-request-failed',
        'resource-exhausted',
        'retry-limit-exceeded',
        'unavailable',
        'unknown',
      }.contains(error.code)) {
        return true;
      }
      return _looksTransientText(error.toString());
    }

    if (error is PostgrestException) {
      final String code = (error.code ?? '').trim().toUpperCase();
      if (code.startsWith('08') ||
          code.startsWith('53') ||
          code.startsWith('57') ||
          code.startsWith('58') ||
          code.startsWith('XX')) {
        return true;
      }
      if (const <String>{
        'PGRST000',
        'PGRST001',
        'PGRST002',
        'PGRST003',
        'PGRSTX00',
      }.contains(code)) {
        return true;
      }

      // Certaines coupures reseau remontent via PostgREST sans code SQL/PGRST.
      // Dans ce cas, ne les transforme pas en erreur metier definitive.
      return _looksTransientText(error.toString());
    }

    if (error is AuthException) {
      final String type = error.runtimeType.toString().toLowerCase();
      return type.contains('retryable') ||
          _looksTransientText(error.toString());
    }

    final String type = error.runtimeType.toString().toLowerCase();
    if (type.contains('socketexception') ||
        type.contains('clientexception') ||
        type.contains('fetch') ||
        type.contains('handshakeexception') ||
        type.contains('connectionclosed') ||
        type.contains('realtimesubscribeexception') ||
        type.contains('websocket')) {
      return true;
    }

    return _looksTransientText(error.toString());
  }

  static BackendFailureKind classify(Object error) {
    if (error is TimeoutException) return BackendFailureKind.timeout;

    if (error is FirebaseException) {
      final String code = error.code.toLowerCase();
      if (code == 'unauthenticated' || code == 'user-token-expired') {
        return BackendFailureKind.unauthorized;
      }
      if (code == 'permission-denied') return BackendFailureKind.forbidden;
      if (code == 'not-found') return BackendFailureKind.notFound;
      if (canRetryRead(error)) return BackendFailureKind.network;
      if (code == 'internal' || code == 'unknown') {
        return BackendFailureKind.server;
      }
    }

    if (error is PostgrestException) {
      final String code = (error.code ?? '').trim().toUpperCase();
      if (const <String>{
        'PGRST301',
        'PGRST302',
        'PGRST303',
        '401',
      }.contains(code)) {
        return BackendFailureKind.unauthorized;
      }
      if (code == '42501' || code == '403') {
        return BackendFailureKind.forbidden;
      }
      if (code == 'PGRST202' || code == 'PGRST204' || code == '404') {
        return BackendFailureKind.notFound;
      }
      if (canRetryRead(error)) return BackendFailureKind.network;
      if (code.startsWith('5') ||
          code.startsWith('XX') ||
          code.startsWith('PGRST0')) {
        return BackendFailureKind.server;
      }
    }

    if (error is AuthException) {
      return canRetryRead(error)
          ? BackendFailureKind.network
          : BackendFailureKind.unauthorized;
    }
    if (error is FormatException || error is StateError || error is TypeError) {
      return BackendFailureKind.contract;
    }
    if (canRetryRead(error)) return BackendFailureKind.network;
    return BackendFailureKind.unknown;
  }

  static String readMessage(Object error, {required String resource}) {
    return readMessageForKind(classify(error), resource: resource);
  }

  static String readMessageForKind(
    BackendFailureKind kind, {
    required String resource,
  }) {
    return switch (kind) {
      BackendFailureKind.network =>
        'Connexion indisponible pendant la lecture de $resource. Réessaie dans un instant.',
      BackendFailureKind.timeout =>
        'La lecture de $resource a dépassé le délai prévu. Réessaie.',
      BackendFailureKind.unauthorized =>
        'La session a expiré pendant la lecture de $resource. Reconnecte-toi puis réessaie.',
      BackendFailureKind.forbidden =>
        'Le serveur a refusé l’accès à $resource. Vérifie le rôle du compte sans modifier les permissions.',
      BackendFailureKind.notFound =>
        'Le service attendu pour $resource est introuvable ou incompatible avec cette version.',
      BackendFailureKind.server =>
        'Le serveur ne peut pas charger $resource pour le moment. Réessaie plus tard.',
      BackendFailureKind.contract =>
        'La réponse reçue pour $resource ne respecte pas le format attendu.',
      BackendFailureKind.unknown =>
        'Impossible de charger $resource pour le moment.',
    };
  }

  static bool _looksTransientText(String value) {
    final String text = value.toLowerCase();
    return text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('connection reset') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('network is unreachable') ||
        text.contains('network request failed') ||
        text.contains('failed to fetch') ||
        text.contains('xmlhttprequest error') ||
        text.contains('failed host lookup') ||
        text.contains('temporary failure') ||
        text.contains('temporarily unavailable') ||
        text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('handshakeexception');
  }

  /// Backoff deterministe pour les pollers.
  ///
  /// Il n'y a volontairement pas de jitter : les tests de non-regression
  /// restent reproductibles, et le delai retourne a sa valeur de base des
  /// qu'une lecture reussit.
  static Duration retryDelay({
    required Duration baseDelay,
    required int consecutiveFailures,
    Duration maxDelay = defaultMaxBackoff,
  }) {
    final int failures = consecutiveFailures.clamp(0, 10).toInt();
    final int multiplier = 1 << failures;
    final int milliseconds = baseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds.clamp(
        baseDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );
  }

  /// Rejoue uniquement une operation idempotente lors d'une panne transitoire.
  ///
  /// Ne jamais utiliser cette methode autour d'une ecriture non idempotente.
  static Future<T> retryIdempotent<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 350),
    Duration maxDelay = const Duration(seconds: 4),
  }) async {
    final int attempts = maxAttempts.clamp(1, 5).toInt();
    for (int attempt = 0; attempt < attempts; attempt++) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        final bool canRetry = canRetryRead(error) && attempt + 1 < attempts;
        if (!canRetry) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await Future<void>.delayed(
          retryDelay(
            baseDelay: baseDelay,
            consecutiveFailures: attempt,
            maxDelay: maxDelay,
          ),
        );
      }
    }
    throw StateError('Unreachable retry state.');
  }

  static String safeCode(Object error) {
    if (error is FirebaseException) {
      return 'firebase:${error.code}';
    }
    if (error is PostgrestException) {
      final String code = (error.code ?? '').trim();
      return code.isEmpty ? 'postgrest' : 'postgrest:$code';
    }
    if (error is AuthException) {
      return 'supabase-auth:${error.runtimeType}';
    }
    final String type = error.runtimeType.toString().toLowerCase();
    if (type.contains('realtimesubscribeexception')) {
      return 'supabase-realtime:subscribe';
    }
    if (type.contains('websocket')) return 'websocket';
    if (type.contains('fetch') ||
        error.toString().toLowerCase().contains('xmlhttprequest error')) {
      return 'web-transport';
    }
    return error.runtimeType.toString();
  }
}
