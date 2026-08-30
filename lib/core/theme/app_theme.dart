import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
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

    final TextTheme typography = GoogleFonts.manropeTextTheme(base.textTheme)
        .copyWith(
          displaySmall: GoogleFonts.manrope(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            color: IzyTelColors.textPrimary,
          ),
          headlineLarge: GoogleFonts.manrope(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.65,
            color: IzyTelColors.textPrimary,
          ),
          headlineMedium: GoogleFonts.manrope(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
            color: IzyTelColors.textPrimary,
          ),
          titleLarge: GoogleFonts.manrope(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            color: IzyTelColors.textPrimary,
          ),
          titleMedium: GoogleFonts.manrope(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: IzyTelColors.textPrimary,
          ),
          bodyLarge: GoogleFonts.manrope(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: IzyTelColors.textPrimary,
          ),
          bodyMedium: GoogleFonts.manrope(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: IzyTelColors.textSecondary,
          ),
          labelLarge: GoogleFonts.manrope(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: IzyTelColors.textPrimary,
          ),
          labelMedium: GoogleFonts.manrope(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: IzyTelColors.textSecondary,
          ),
        );

    const OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
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
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: typography.bodyMedium?.copyWith(
          color: IzyTelColors.textMuted,
        ),
        labelStyle: typography.bodyMedium?.copyWith(
          color: IzyTelColors.textSecondary,
        ),
        prefixIconColor: IzyTelColors.textSecondary,
        suffixIconColor: IzyTelColors.textSecondary,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: IzyTelColors.primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: IzyTelColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: IzyTelColors.error, width: 1.5),
        ),
        errorStyle: typography.labelMedium?.copyWith(color: IzyTelColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: IzyTelColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: IzyTelColors.primary.withAlpha(85),
          disabledForegroundColor: Colors.white.withAlpha(190),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: typography.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          foregroundColor: IzyTelColors.primaryStrong,
          side: const BorderSide(color: IzyTelColors.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
