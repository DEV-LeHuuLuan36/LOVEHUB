import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!mounted) return;
    if (!hasOnboarded) {
      context.go(AppRoutes.onboarding);
    } else if (!isLoggedIn) {
      context.go(AppRoutes.login);
    } else {
      final isLinked = prefs.getBool('is_linked') ?? false;
      if (!mounted) return;
      context.go(isLinked ? AppRoutes.home : AppRoutes.linking);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0812),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated heart logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gradientEnd.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Center(child: Text('💕', style: TextStyle(fontSize: 40))),
            )
                .animate()
                .scaleXY(
                  begin: 0,
                  end: 1,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                )
                .then()
                .shimmer(
                  duration: const Duration(milliseconds: 1200),
                  color: Colors.white.withValues(alpha: 0.3),
                ),
            const SizedBox(height: 24),
            // App name
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'auth.splash.title'.tr(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 400), duration: const Duration(milliseconds: 500)),
            const SizedBox(height: 8),
            Text(
              'auth.splash.subtitle'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFFB39DDB).withValues(alpha: 0.8),
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 700), duration: const Duration(milliseconds: 500)),
          ],
        ),
      ),
    );
  }
}
