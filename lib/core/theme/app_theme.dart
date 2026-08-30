import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const ColorScheme scheme = ColorScheme.light(
      primary: IzyTelColors.primary,
      onPrimary: Colors.white,
      primaryContainer: IzyTelColors.primarySoft,
      onPrimaryContainer: IzyTelColors.primaryStrong,
      secondary: IzyTelColors.secondary,
      surface: IzyTelColors.surface,
      onSurface: IzyTelColors.textPrimary,
      error: IzyTelColors.error,
      onError: Colors.white,
      outline: IzyTelColors.outlineStrong,
      outlineVariant: IzyTelColors.outline,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: IzyTelColors.background,
    );

    // Hiérarchie exacte retenue pour la maquette IzyTel :
    // 28/700 · 22/700 · 18/600 · 15/500 · 13/500 · 12/400.
    final TextTheme typography = GoogleFonts.manropeTextTheme(base.textTheme)
        .copyWith(
          displaySmall: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.title1,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.55,
            color: IzyTelColors.textPrimary,
          ),
          headlineLarge: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.title1,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.55,
            color: IzyTelColors.textPrimary,
          ),
          headlineMedium: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.title2,
            height: 1.22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            color: IzyTelColors.textPrimary,
          ),
          titleLarge: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.title3,
            height: 1.28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.18,
            color: IzyTelColors.textPrimary,
          ),
          titleMedium: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.cardTitle,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.12,
            color: IzyTelColors.textPrimary,
          ),
          bodyLarge: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.text,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: IzyTelColors.textPrimary,
          ),
          bodyMedium: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.text,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: IzyTelColors.textSecondary,
          ),
          bodySmall: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.micro,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: IzyTelColors.textSecondary,
          ),
          labelLarge: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.label,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: IzyTelColors.textPrimary,
          ),
          labelMedium: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.label,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: IzyTelColors.textSecondary,
          ),
          labelSmall: GoogleFonts.manrope(
            fontSize: IzyTelTypeScale.micro,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: IzyTelColors.textMuted,
          ),
        );

    const OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.input)),
      borderSide: BorderSide(color: IzyTelColors.outlineStrong),
    );

    return base.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: IzyTelColors.surface,
        foregroundColor: IzyTelColors.textPrimary,
        centerTitle: false,
        titleTextStyle: typography.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: IzyTelColors.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.card)),
          side: BorderSide(color: IzyTelColors.outline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: IzyTelColors.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IzyTelColors.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: typography.bodyMedium?.copyWith(
          color: IzyTelColors.textMuted,
        ),
        labelStyle: typography.labelMedium?.copyWith(
          color: IzyTelColors.textSecondary,
        ),
        prefixIconColor: IzyTelColors.textSecondary,
        suffixIconColor: IzyTelColors.textSecondary,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.input)),
          borderSide: BorderSide(color: IzyTelColors.primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.input)),
          borderSide: BorderSide(color: IzyTelColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.input)),
          borderSide: BorderSide(color: IzyTelColors.error, width: 1.5),
        ),
        errorStyle: typography.bodySmall?.copyWith(color: IzyTelColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          backgroundColor: IzyTelColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: IzyTelColors.primary.withAlpha(85),
          disabledForegroundColor: Colors.white.withAlpha(190),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IzyTelRadii.button),
          ),
          textStyle: typography.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          foregroundColor: IzyTelColors.primary,
          side: const BorderSide(color: IzyTelColors.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IzyTelRadii.button),
          ),
          textStyle: typography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IzyTelColors.primary,
          textStyle: typography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: IzyTelColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: IzyTelColors.textPrimary,
        contentTextStyle: typography.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: IzyTelColors.primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: IzyTelColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(IzyTelRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: IzyTelColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: typography.titleLarge,
        contentTextStyle: typography.bodyMedium,
      ),
    );
  }

  /// Ancien thème conservé uniquement pour les écrans pas encore migrés.
  static ThemeData get dark {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
      onError: Color(0xFF690005),
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
    );
  }
}
