import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum IzyTelFeedbackTone { neutral, success, warning, error }

class _IzyTelFeedbackPayload {
  const _IzyTelFeedbackPayload({
    required this.message,
    required this.tone,
    required this.top,
  });

  final String message;
  final IzyTelFeedbackTone tone;
  final double top;
}

/// Notification compacte, non bloquante et affichée en haut de l'écran.
///
/// Une seule OverlayEntry est conservée et son contenu est mis à jour quand
/// plusieurs messages arrivent rapidement. Cela évite de retirer/réinsérer
/// plusieurs entrées d'Overlay dans la même frame, ce qui pouvait provoquer
/// des assertions InheritedElement lors d'une validation suivie d'un rebuild.
class IzyTelFeedback {
  IzyTelFeedback._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final ValueNotifier<_IzyTelFeedbackPayload?> _payload =
      ValueNotifier<_IzyTelFeedbackPayload?>(null);

  static void show(
    BuildContext context,
    String message, {
    IzyTelFeedbackTone tone = IzyTelFeedbackTone.neutral,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final IzyTelFeedbackTone resolvedTone = tone == IzyTelFeedbackTone.neutral
        ? _toneForMessage(message)
        : tone;
    final double top = MediaQuery.paddingOf(context).top + 10;

    _payload.value = _IzyTelFeedbackPayload(
      message: message,
      tone: resolvedTone,
      top: top,
    );

    if (_entry == null || !_entry!.mounted) {
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (BuildContext overlayContext) {
          return ValueListenableBuilder<_IzyTelFeedbackPayload?>(
            valueListenable: _payload,
            builder: (
              BuildContext context,
              _IzyTelFeedbackPayload? value,
              Widget? child,
            ) {
              if (value == null) return const SizedBox.shrink();
              return _FeedbackOverlay(payload: value);
            },
          );
        },
      );
      _entry = entry;
      overlay.insert(entry);
    }

    _timer?.cancel();
    final OverlayEntry? scheduledEntry = _entry;
    _timer = Timer(duration, () {
      if (!identical(_entry, scheduledEntry)) return;
      _entry = null;
      if (scheduledEntry?.mounted == true) {
        scheduledEntry!.remove();
      }
      // Après le retrait : aucun listener monté n'est réveillé inutilement.
      _payload.value = null;
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

class _FeedbackOverlay extends StatelessWidget {
  const _FeedbackOverlay({required this.payload});

  final _IzyTelFeedbackPayload payload;

  @override
  Widget build(BuildContext context) {
    final (
      Color accent,
      Color background,
      IconData icon,
    ) = switch (payload.tone) {
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

    return Positioned(
      top: payload.top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            type: MaterialType.transparency,
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
                            payload.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: IzyTelColors.textPrimary,
                              fontSize: 14,
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
      ),
    );
  }
}
