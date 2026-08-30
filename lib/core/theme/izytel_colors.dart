import 'package:flutter/material.dart';

/// Palette officielle de la refonte IzyTel.
///
/// Elle coexiste temporairement avec [AppColors] le temps de migrer l'ancien
/// thème sombre écran par écran. Les nouveaux écrans doivent utiliser cette
/// palette afin d'éviter les régressions visuelles pendant la transition.
class IzyTelColors {
  const IzyTelColors._();

  static const Color background = Color(0xFFF6F8FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceStrong = Color(0xFFEAF1FF);

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryStrong = Color(0xFF1748C7);
  static const Color primarySoft = Color(0xFFE8F0FF);
  static const Color secondary = Color(0xFF38BDF8);

  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);

  static const Color outline = Color(0xFFE4E7EC);
  static const Color outlineStrong = Color(0xFFD0D5DD);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFEAF8EF);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFF6E5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFFECEC);

  static const Color orange = Color(0xFFFF7900);
  static const Color mtn = Color(0xFFFFCC00);
  static const Color moov = Color(0xFF0055A5);
  static const Color wave = Color(0xFF17C8EE);

  static const Color shadow = Color(0x140F172A);
}
