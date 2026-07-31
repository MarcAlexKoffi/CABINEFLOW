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
    );

    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: CustomerAppColors.outlineVariant,
      ),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: CustomerAppColors.background,
      textTheme: baseTheme.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 30,
          height: 1.27,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 24,
          height: 1.33,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        headlineSmall: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: const TextStyle(
          color: CustomerAppColors.onSurfaceVariant,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CustomerAppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        hintStyle: const TextStyle(
          color: CustomerAppColors.outline,
          fontSize: 14,
        ),
        prefixIconColor: CustomerAppColors.onSurfaceVariant,
        border: defaultBorder,
        enabledBorder: defaultBorder,
        focusedBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(
            color: CustomerAppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(
            color: CustomerAppColors.error,
          ),
        ),
        focusedErrorBorder: defaultBorder.copyWith(
          borderSide: const BorderSide(
            color: CustomerAppColors.error,
            width: 2,
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
          disabledBackgroundColor:
              CustomerAppColors.primary.withValues(alpha: 0.42),
          disabledForegroundColor:
              CustomerAppColors.onPrimary.withValues(alpha: 0.78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: CustomerAppColors.onSurfaceVariant,
          side: const BorderSide(
            color: CustomerAppColors.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CustomerAppColors.primary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CustomerAppColors.primary,
        linearTrackColor: CustomerAppColors.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CustomerAppColors.onSurface,
        contentTextStyle: const TextStyle(
          color: CustomerAppColors.surfaceContainerLowest,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
