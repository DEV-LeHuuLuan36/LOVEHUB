import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  // Light-mode color aliases. We intentionally DO NOT replace
  // AppColors.backgroundPrimary etc. — that's used widely as a
  // hardcoded constant in widgets. These constants exist for
  // themes / new code that wants light-mode-specific surface colors.
  static const Color _lightBackground = Color(0xFFFFF5F8); // soft pink-white
  static const Color _lightSurface = Color(0xFFFFFFFF); // pure white card
  static const Color _lightTextPrimary = Color(0xFF2A0E1F); // deep wine
  static const Color _lightBorderSubtle = Color(0x33C2185B); // pink @ ~20%

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        fontFamily: AppTypography.fontFamily,
        colorScheme: ColorScheme.dark(
          primary: AppColors.gradientStart,
          secondary: AppColors.gradientEnd,
          surface: AppColors.backgroundCard,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: AppColors.backgroundCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.backgroundCard,
          contentTextStyle: AppTypography.bodyMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

  /// Soft pink/white light theme matching the LoveHub brand gradient.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBackground,
        fontFamily: AppTypography.fontFamily,
        colorScheme: ColorScheme.light(
          primary: AppColors.gradientStart,
          secondary: AppColors.gradientEnd,
          surface: _lightSurface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: _lightTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: _lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _lightBorderSubtle, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _lightSurface,
          contentTextStyle: AppTypography.bodyMedium.copyWith(
            color: _lightTextPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}