/// Design System - App Theme
///
/// Combines colors, typography, and spacing into cohesive light and dark themes.
/// This is the main theme configuration used throughout the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// App theme configuration
class AppTheme {
  AppTheme._(); // Private constructor

  // ===========================
  // LIGHT THEME
  // ===========================

  static ThemeData get lightTheme {
    return ThemeData(
      // Core colors
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.secondaryDark,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
        outline: AppColors.borderLight,
        shadow: Colors.black.withValues(alpha: 0.1),
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // App bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryLight,
          size: AppSpacing.iconMd,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Typography
      textTheme: AppTypography.lightTextTheme,

      // Card
      cardTheme: CardThemeData(
        elevation: AppSpacing.elevationNone,
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.cardBorderRadius,
        ),
        margin: EdgeInsets.all(AppSpacing.cardMargin),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textPrimaryLight,
          textStyle: AppTypography.button,
          elevation: AppSpacing.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textDisabledLight,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondaryLight,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: AppSpacing.dividerThin,
        space: 0,
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: AppSpacing.elevationNone,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        elevation: AppSpacing.elevationLg,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.textPrimaryLight,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimaryLight,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.bottomSheetBorderRadius,
        ),
        elevation: AppSpacing.elevationXl,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        selectedColor: AppColors.primaryLight,
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: Colors.white, // White text on selected (primary color) chips
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: AppSpacing.iconMd,
      ),
    );
  }

  // ===========================
  // DARK THEME
  // ===========================

  static ThemeData get darkTheme {
    return ThemeData(
      // Core colors
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryDark,
        onSecondaryContainer: AppColors.secondaryLight,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.surfaceVariantDark,
        outline: AppColors.borderDark,
        shadow: Colors.black.withValues(alpha: 0.3),
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // App bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
          size: AppSpacing.iconMd,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Typography
      textTheme: AppTypography.darkTextTheme,

      // Card
      cardTheme: CardThemeData(
        elevation: AppSpacing.elevationNone,
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.cardBorderRadius,
        ),
        margin: EdgeInsets.all(AppSpacing.cardMargin),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimaryDark,
          textStyle: AppTypography.button,
          elevation: AppSpacing.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textDisabledDark,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondaryDark,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: AppSpacing.dividerThin,
        space: 0,
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: AppSpacing.elevationNone,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        elevation: AppSpacing.elevationLg,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.bottomSheetBorderRadius,
        ),
        elevation: AppSpacing.elevationXl,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantDark,
        selectedColor: AppColors.primary,
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: Colors.white, // White text on selected (primary color) chips
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: AppSpacing.iconMd,
      ),
    );
  }
}
