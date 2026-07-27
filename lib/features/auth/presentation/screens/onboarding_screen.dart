import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pageKeys = [
    ('auth.onboarding.slide1_title', 'auth.onboarding.slide1_subtitle'),
    ('auth.onboarding.slide2_title', 'auth.onboarding.slide2_subtitle'),
    ('auth.onboarding.slide3_title', 'auth.onboarding.slide3_subtitle'),
  ];

  static const _emojis = ['💑', '🐱', '💰'];

  void _nextPage() {
    if (_currentPage < _pageKeys.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded', true);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageKeys.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final (titleKey, subtitleKey) = _pageKeys[i];
                  return _OnboardPageView(
                    emoji: _emojis[i],
                    title: titleKey.tr(),
                    subtitle: subtitleKey.tr(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pageKeys.length, (i) {
                      final isActive = i == _currentPage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: isActive ? AppColors.primaryGradient : null,
                            color: isActive ? null : AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Actions row
                  Row(
                    children: [
                      if (_currentPage < _pageKeys.length - 1) ...[
                        GestureDetector(
                          onTap: _completeOnboarding,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'common.skip'.tr(),
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(width: 60),
                      const Spacer(),
                      if (_currentPage < _pageKeys.length - 1)
                        _NextButton(onTap: _nextPage)
                      else
                        _GetStartedButton(onTap: _completeOnboarding),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageView extends StatelessWidget {
  const _OnboardPageView({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration placeholder
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient.scale(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 80)),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
              )
              .fadeIn(),
          const SizedBox(height: AppSpacing.xxl),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 150)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 250)),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('common.next'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const Text('→', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            'auth.onboarding.getStarted'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
