import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class CustomerAppTheme {
  const CustomerAppTheme._();

  static ThemeData get light {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: CustomerAppColors.primary,
      onPrimary: CustomerAppColors.onPrimary,
      primaryContainer: CustomerAppColors.primaryContainer,
      surface: CustomerAppColors.surface,
      onSurface: CustomerAppColors.onSurface,
      error: CustomerAppColors.error,
      outline: CustomerAppColors.outline,
      outlineVariant: CustomerAppColors.outlineVariant,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      fontFamilyFallback: const <String>['Roboto', 'Arial', 'sans-serif'],
    );

    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CustomerAppColors.outlineVariant),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: CustomerAppColors.background,
      dividerColor: CustomerAppColors.outlineSoft,
      textTheme: baseTheme.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
        headlineMedium: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 27,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 21,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 16,
          height: 1.55,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          color: CustomerAppColors.muted,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: CustomerAppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CustomerAppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: CustomerAppColors.outline,
          fontSize: 14,
        ),
        helperStyle: const TextStyle(
          color: CustomerAppColors.muted,
          fontSize: 11,
          height: 1.35,
        ),
        prefixIconColor: CustomerAppColors.onSurfaceVariant,
        border: defaultBorder,
        enabledBorder: defaultBorder,
        focusedBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(
            color: CustomerAppColors.primary,
            width: 1.8,
          ),
        ),
        errorBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(color: CustomerAppColors.error),
        ),
        focusedErrorBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(
            color: CustomerAppColors.error,
            width: 1.8,
          ),
        ),
        errorStyle: const TextStyle(
          color: CustomerAppColors.error,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: CustomerAppColors.primary,
          foregroundColor: CustomerAppColors.onPrimary,
          elevation: 0,
          disabledBackgroundColor: CustomerAppColors.primary.withValues(
            alpha: 0.35,
          ),
          disabledForegroundColor: CustomerAppColors.onPrimary.withValues(
            alpha: 0.82,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: CustomerAppColors.primary,
          side: const BorderSide(color: CustomerAppColors.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CustomerAppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CustomerAppColors.primary,
        linearTrackColor: CustomerAppColors.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CustomerAppColors.onSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
