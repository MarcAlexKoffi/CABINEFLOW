import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:flutter/material.dart';

/// Design system Web du back-office IzyTel.
///
/// Règle BO officielle : le Web staff reprend la même identité que le mobile
/// IzyTel. La base est donc claire, blanche et bleue, sans navigation sombre.
/// Les futurs modules BO-* doivent réutiliser ces tokens au lieu d'introduire
/// une palette parallèle.
class BackofficePalette {
  const BackofficePalette._();

  static const Color canvas = IzyTelColors.background;
  static const Color canvasStrong = IzyTelColors.surfaceStrong;
  static const Color surface = IzyTelColors.surface;
  static const Color surfaceAlt = IzyTelColors.surfaceMuted;
  static const Color field = Color(0xFFFBFCFE);

  // Sidebar volontairement claire : continuité visuelle avec l'app mobile.
  static const Color sidebar = IzyTelColors.surface;
  static const Color sidebarRaised = IzyTelColors.primarySoft;
  static const Color sidebarLine = IzyTelColors.outline;
  static const Color sidebarText = IzyTelColors.textPrimary;
  static const Color sidebarMuted = IzyTelColors.textSecondary;

  static const Color primary = IzyTelColors.primary;
  static const Color primaryStrong = IzyTelColors.primaryStrong;
  static const Color primarySoft = IzyTelColors.primarySoft;
  static const Color cyan = IzyTelColors.secondary;
  // Alias historique conservé pour les composants BO-1 ; il reste bleu.
  static const Color violet = IzyTelColors.primaryStrong;

  static const Color ink = IzyTelColors.textPrimary;
  static const Color muted = IzyTelColors.textSecondary;
  static const Color faint = IzyTelColors.textMuted;
  static const Color line = IzyTelColors.outline;
  static const Color lineStrong = IzyTelColors.outlineStrong;

  static const Color success = IzyTelColors.success;
  static const Color warning = IzyTelColors.warning;
  static const Color danger = IzyTelColors.error;
}

class BackofficeGradients {
  const BackofficeGradients._();

  /// Signature principale IzyTel : uniquement des bleus de la marque.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      IzyTelColors.primaryStrong,
      IzyTelColors.primary,
      IzyTelColors.secondary,
    ],
    stops: <double>[0, .58, 1],
  );

  /// Hero lumineux — jamais navy/noir — pour rester cohérent avec le mobile.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF1D4ED8),
      Color(0xFF2E63EB),
      Color(0xFF38BDF8),
    ],
    stops: <double>[0, .58, 1],
  );

  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFF3F7FF),
    ],
  );

  static const LinearGradient selectedNav = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      Color(0xFFEAF1FF),
      Color(0xFFF5F9FF),
    ],
  );
}

class BackofficeShadows {
  const BackofficeShadows._();

  static const List<BoxShadow> panel = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D1D4ED8),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(
      color: Color(0x141D4ED8),
      blurRadius: 38,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(
      color: Color(0x262E63EB),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

class BackofficeTheme {
  const BackofficeTheme._();

  static ThemeData get light {
    final ThemeData base = AppTheme.light;
    final TextTheme text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: BackofficePalette.ink,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -.75,
        color: BackofficePalette.ink,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -.45,
        color: BackofficePalette.ink,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: BackofficePalette.ink,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: BackofficePalette.ink,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: BackofficePalette.ink,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: BackofficePalette.muted,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: BackofficePalette.muted,
      ),
    );

    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: BackofficePalette.canvas,
      textTheme: text,
      primaryTextTheme: text,
      dividerColor: BackofficePalette.line,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: BackofficePalette.surface,
        foregroundColor: BackofficePalette.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: BackofficePalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: BackofficePalette.line),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: BackofficePalette.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(BackofficePalette.lineStrong),
        enabledBorder: border(BackofficePalette.lineStrong),
        focusedBorder: border(BackofficePalette.primary, width: 1.6),
        errorBorder: border(BackofficePalette.danger),
        focusedErrorBorder: border(BackofficePalette.danger, width: 1.5),
        prefixIconColor: BackofficePalette.primary,
        suffixIconColor: BackofficePalette.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          backgroundColor: BackofficePalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BackofficePalette.primary.withValues(alpha: .42),
          disabledForegroundColor: Colors.white.withValues(alpha: .82),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: text.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          foregroundColor: BackofficePalette.primaryStrong,
          side: const BorderSide(color: BackofficePalette.lineStrong),
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: BackofficePalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: BackofficePalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: const Color(0x181D4ED8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll<Color>(
          Color(0xFFF7F9FC),
        ),
        headingTextStyle: text.labelMedium?.copyWith(
          color: BackofficePalette.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: .12,
        ),
        dataTextStyle: text.bodyMedium?.copyWith(
          color: BackofficePalette.ink,
        ),
        dividerThickness: 1,
        dataRowMinHeight: 62,
        dataRowMaxHeight: 72,
        headingRowHeight: 52,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BackofficePalette.primary,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: BackofficePalette.primaryStrong,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: BackofficePalette.primary,
        primaryContainer: BackofficePalette.primarySoft,
        secondary: BackofficePalette.cyan,
        surface: BackofficePalette.surface,
        onSurface: BackofficePalette.ink,
        outline: BackofficePalette.lineStrong,
        outlineVariant: BackofficePalette.line,
        error: BackofficePalette.danger,
      ),
    );
  }
}

BoxDecoration backofficePanelDecoration({
  Color color = BackofficePalette.surface,
  double radius = 18,
  bool elevated = false,
}) {
  return BoxDecoration(
    color: color,
    border: Border.all(color: BackofficePalette.line),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: elevated ? BackofficeShadows.panel : const <BoxShadow>[],
  );
}
