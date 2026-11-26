import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF2248D1);
  static const primaryContainer = Color(0xFF4263EB);
  static const primaryDark = Color(0xFF2948C7);
  static const primaryFixed = Color(0xFFDDE1FF);
  static const onPrimaryFixed = Color(0xFF001356);
  static const onPrimaryFixedVariant = Color(0xFF0035BE);
  static const surfaceLow = Color(0xFFF1F3FF);
  static const surfaceContainer = Color(0xFFE8EDFF);
  static const surfaceHigh = Color(0xFFE0E8FE);
  static const surfaceHighest = Color(0xFFDBE2F8);
  static const secondary = Color(0xFF006C49);
  static const secondaryContainer = Color(0xFF7FF6BF);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const secondaryFixed = Color(0xFF82F9C1);
  static const tertiary = Color(0xFF794E00);
  static const tertiaryContainer = Color(0xFF9A6400);
  static const tertiaryFixed = Color(0xFFFFDDB5);
  static const onTertiaryFixed = Color(0xFF2A1800);
  static const lightBlue = Color(0xFFEDF2FF);
  static const background = Color(0xFFF9F9FF);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF131C2B);
  static const muted = Color(0xFF444654);
  static const success = Color(0xFF21A675);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFBA1A1A);
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
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
    );
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
        fillColor: AppColors.surfaceLow,
        focusColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF747686)),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
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

/// Tailwind-equivalent shadows used by the design mockups.
abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
  ];
}

/// Typography tokens from the Warm Household Modern design system.
abstract final class AppText {
  static const _f = 'Inter';
  static const headlineLg = TextStyle(
    fontFamily: _f,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.39,
  );
  static const headlineMd = TextStyle(
    fontFamily: _f,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const headlineSm = TextStyle(
    fontFamily: _f,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const titleMd = TextStyle(
    fontFamily: _f,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );
  static const bodyLg = TextStyle(
    fontFamily: _f,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  static const bodyMd = TextStyle(
    fontFamily: _f,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const bodySm = TextStyle(
    fontFamily: _f,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );
  static const labelLg = TextStyle(
    fontFamily: _f,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const labelMd = TextStyle(
    fontFamily: _f,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.24,
  );
  static const labelSm = TextStyle(
    fontFamily: _f,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.44,
  );
}
