import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        type.contains('handshakeexception') ||
        type.contains('connectionclosed')) {
      return true;
    }

    return _looksTransientText(error.toString());
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
    return error.runtimeType.toString();
  }
}
