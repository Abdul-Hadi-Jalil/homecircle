import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF4263EB);
  static const primaryDark = Color(0xFF2948C7);
  static const lightBlue = Color(0xFFEDF2FF);
  static const background = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C2434);
  static const muted = Color(0xFF718096);
  static const success = Color(0xFF21A675);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFE85D65);
  static const border = Color(0xFFE6EBF2);
}

abstract final class AppSpacing {
  static const unit = 8.0;
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const radius = 16.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lightBlue,
      onPrimaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.muted,
      error: AppColors.danger,
      outline: AppColors.border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBlue,
        contentPadding: const EdgeInsetsDirectional.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: shape,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lightBlue,
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelSmall),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        backgroundColor: AppColors.text,
      ),
    );
  }
}
