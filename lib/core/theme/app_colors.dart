import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // Backgrounds
  static const Color backgroundPrimary = Color(0xFF0D0812);
  static const Color backgroundCard = Color(0xFF1A1025);

  // Gradient
  static const Color gradientStart = Color(0xFFC2185B);
  static const Color gradientEnd = Color(0xFFE91E8C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accent
  static const Color accentGold = Color(0xFFFFD54F);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB39DDB);

  // Status
  static const Color onlineGreen = Color(0xFF66BB6A);

  // Borders
  static const Color borderSubtle = Color(0x4DC2185B); // rgba(194, 24, 91, 0.3)

  // HP bar gradient
  static const LinearGradient hpGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Glow shadow
  static List<BoxShadow> pinkGlow({double intensity = 12}) => [
        BoxShadow(
          color: gradientStart.withValues(alpha: 0.4),
          blurRadius: intensity,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: gradientEnd.withValues(alpha: 0.2),
          blurRadius: intensity * 2,
          spreadRadius: 0,
        ),
      ];
}
