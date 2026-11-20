import 'package:cabine_flow/app/core/resilience/backend_failure_policy.dart';
import 'package:flutter/foundation.dart';

/// Journal de diagnostic Phase 3.
///
/// Aucun contenu metier (token FCM, numero, reference de paiement, message
/// client, etc.) ne doit etre passe ici. Les diagnostics release sont optionnels.
///
/// Important : un journal de diagnostic ne doit jamais modifier le comportement
/// metier. Les StackTrace ne sont donc pas rendues par debugPrintStack : ce
/// dernier peut lever une assertion avec certaines traces asynchrones issues de
/// package:stack_trace pendant les tests Flutter. Le parametre reste accepte
/// pour conserver l'API des appelants, mais seul un code d'erreur neutralise est
/// emis.
class IzyTelLog {
  const IzyTelLog._();

  static void debug(String event) {
    if (!kDebugMode) return;
    try {
      debugPrint('[IzyTel][$event]');
    } catch (_) {
      // Le diagnostic ne doit jamais interrompre un flux applicatif.
    }
  }

  static void backendError(
    String event,
    Object error, {
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && !const bool.fromEnvironment('IZYTEL_DIAGNOSTICS')) {
      return;
    }
    try {
      debugPrint('[IzyTel][$event] ${BackendFailurePolicy.safeCode(error)}');
    } catch (_) {
      // Le diagnostic ne doit jamais interrompre un flux applicatif.
    }
  }
}
