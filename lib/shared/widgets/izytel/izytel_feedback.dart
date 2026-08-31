import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum IzyTelFeedbackTone { neutral, success, warning, error }

/// Notification compacte, non bloquante et affichée en haut de l'écran.
///
/// Contrairement à un SnackBar en bas de page, elle ne recouvre jamais les
/// boutons de validation ni la navigation inférieure. IgnorePointer laisse
/// également passer tous les gestes vers l'interface située derrière.
class IzyTelFeedback {
  IzyTelFeedback._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IzyTelFeedbackTone tone = IzyTelFeedbackTone.neutral,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();

    final IzyTelFeedbackTone resolvedTone = tone == IzyTelFeedbackTone.neutral
        ? _toneForMessage(message)
        : tone;

    final (
      Color accent,
      Color background,
      IconData icon,
    ) = switch (resolvedTone) {
      IzyTelFeedbackTone.success => (
        IzyTelColors.success,
        IzyTelColors.successSoft,
        Symbols.check_circle_rounded,
      ),
      IzyTelFeedbackTone.warning => (
        IzyTelColors.warning,
        IzyTelColors.warningSoft,
        Symbols.warning_rounded,
      ),
      IzyTelFeedbackTone.error => (
        IzyTelColors.error,
        IzyTelColors.errorSoft,
        Symbols.error_rounded,
      ),
      IzyTelFeedbackTone.neutral => (
        IzyTelColors.primary,
        IzyTelColors.surface,
        Symbols.info_rounded,
      ),
    };

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Positioned(
          top: MediaQuery.paddingOf(overlayContext).top + 10,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withAlpha(70)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: IzyTelColors.shadow,
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(icon, color: accent, size: 20),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(overlayContext)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: IzyTelColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      if (identical(_entry, entry)) {
        _entry = null;
      }
      entry.remove();
    });
  }

  static IzyTelFeedbackTone _toneForMessage(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('permission-denied') ||
        normalized.contains('refuse') ||
        normalized.contains('impossible') ||
        normalized.contains('erreur') ||
        normalized.contains('échou') ||
        normalized.contains('echec')) {
      return IzyTelFeedbackTone.error;
    }
    if (normalized.contains('attention') ||
        normalized.contains('en attente') ||
        normalized.contains('à vérifier') ||
        normalized.contains('a verifier')) {
      return IzyTelFeedbackTone.warning;
    }
    if (normalized.contains('enregistr') ||
        normalized.contains('créé') ||
        normalized.contains('cree') ||
        normalized.contains('validé') ||
        normalized.contains('valide') ||
        normalized.contains('effectué') ||
        normalized.contains('effectue') ||
        normalized.contains('réussi') ||
        normalized.contains('reussi') ||
        normalized.contains('mis à jour') ||
        normalized.contains('mise à jour') ||
        normalized.contains('terminée') ||
        normalized.contains('terminee')) {
      return IzyTelFeedbackTone.success;
    }
    return IzyTelFeedbackTone.neutral;
  }

  static void success(BuildContext context, String message) {
    show(context, message, tone: IzyTelFeedbackTone.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, tone: IzyTelFeedbackTone.error);
  }
}
