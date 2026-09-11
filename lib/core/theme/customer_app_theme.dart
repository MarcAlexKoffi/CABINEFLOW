import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomerAppTheme {
  const CustomerAppTheme._();

  static ThemeData get light {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: CustomerAppColors.primary,
      onPrimary: CustomerAppColors.onPrimary,
      primaryContainer: CustomerAppColors.primaryContainer,
      onPrimaryContainer: CustomerAppColors.primaryDeep,
      secondary: CustomerAppColors.cyanAccent,
      surface: CustomerAppColors.surfaceContainerLowest,
      onSurface: CustomerAppColors.onSurface,
      error: CustomerAppColors.error,
      outline: CustomerAppColors.outline,
      outlineVariant: CustomerAppColors.outlineVariant,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CustomerAppColors.background,
    );

    final TextTheme typography = GoogleFonts.manropeTextTheme(
      baseTheme.textTheme,
    ).copyWith(
      displaySmall: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.25,
      ),
      headlineMedium: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 27,
        height: 1.16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.65,
      ),
      headlineSmall: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 21,
        height: 1.24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      titleMedium: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 15,
        height: 1.32,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.manrope(
        color: CustomerAppColors.onSurfaceVariant,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: GoogleFonts.manrope(
        color: CustomerAppColors.onSurfaceVariant,
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.manrope(
        color: CustomerAppColors.muted,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.manrope(
        color: CustomerAppColors.onSurface,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.manrope(
        color: CustomerAppColors.onSurfaceVariant,
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.manrope(
        color: CustomerAppColors.muted,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
    );

    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CustomerAppColors.outlineVariant),
    );

    return baseTheme.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      scaffoldBackgroundColor: CustomerAppColors.background,
      dividerColor: CustomerAppColors.outlineSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: CustomerAppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: CustomerAppColors.surfaceContainerLowest,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: CustomerAppColors.outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CustomerAppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        hintStyle: typography.bodyMedium?.copyWith(
          color: CustomerAppColors.outline,
        ),
        helperStyle: typography.bodySmall,
        labelStyle: typography.labelMedium,
        prefixIconColor: CustomerAppColors.onSurfaceVariant,
        suffixIconColor: CustomerAppColors.onSurfaceVariant,
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
        errorStyle: typography.bodySmall?.copyWith(
          color: CustomerAppColors.error,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: typography.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: CustomerAppColors.primaryDeep,
          side: const BorderSide(
            color: CustomerAppColors.outlineVariant,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: typography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CustomerAppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: typography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: CustomerAppColors.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CustomerAppColors.surfaceContainerLowest,
        selectedColor: CustomerAppColors.primaryContainer,
        disabledColor: CustomerAppColors.surfaceContainerLow,
        side: const BorderSide(color: CustomerAppColors.outlineSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: typography.labelMedium,
        secondaryLabelStyle: typography.labelMedium?.copyWith(
          color: CustomerAppColors.primaryDeep,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CustomerAppColors.primary,
        linearTrackColor: CustomerAppColors.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CustomerAppColors.onSurface,
        contentTextStyle: typography.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CustomerAppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: CustomerAppColors.onSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: typography.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
