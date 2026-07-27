import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class LinkingScreen extends StatefulWidget {
  const LinkingScreen({super.key});

  @override
  State<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends State<LinkingScreen> {
  static const _myCode = 'LOVE-9K2M';
  final _partnerController = TextEditingController();
  bool _isLinking = false;
  bool _isSuccess = false;
  String? _partnerName;
  bool _howItWorksOpen = false;

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  Future<void> _linkNow() async {
    final code = _partnerController.text.trim().toUpperCase();
    if (code.isEmpty || code.length < 8) {
      _showSnackBar('linking.errors.invalidCode'.tr());
      return;
    }

    setState(() => _isLinking = true);

    // Simulate linking delay
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_linked', true);

    if (mounted) {
      setState(() {
        _isLinking = false;
        _isSuccess = true;
        _partnerName = 'Linh';
      });
    }
  }

  void _copyCode() {
    Clipboard.setData(const ClipboardData(text: _myCode));
    _showSnackBar('Code copied! 📋');
  }

  void _shareCode() {
    _showSnackBar('Share your code: $_myCode 📤');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.gradientEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  void _startJourney() {
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: _isSuccess
            ? _SuccessView(partnerName: _partnerName ?? 'your partner', onStart: _startJourney)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    // Header
                    const _LinkingHeader(),
                    const SizedBox(height: AppSpacing.lg),

                    if (_isLinking) ...[
                      _LinkingLoadingView(),
                    ] else ...[
                      // Your code card
                      _YourCodeCard(
                        code: _myCode,
                        onCopy: _copyCode,
                        onShare: _shareCode,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.4))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: Text(
                              '— or enter partner\'s code —',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.4))),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Enter code card
                      _EnterCodeCard(
                        controller: _partnerController,
                        onLink: _linkNow,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // How it works
                      _HowItWorksCard(
                        isOpen: _howItWorksOpen,
                        onToggle: () => setState(() => _howItWorksOpen = !_howItWorksOpen),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LinkingHeader extends StatelessWidget {
  const _LinkingHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'linking.title'.tr(),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      textAlign: TextAlign.center,
    );
  }
}

// ─── YOUR CODE CARD ───────────────────────────────────────────────────────────
class _YourCodeCard extends StatelessWidget {
  const _YourCodeCard({required this.code, required this.onCopy, required this.onShare});

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text('linking.yourCode'.tr(), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.sm),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
            ).createShader(bounds),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('linking.shareWithPartner'.tr(), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: AppColors.gradientEnd, width: 1.5),
                    ),
                    child: Center(
                      child: Text('linking.copyCode'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gradientEnd)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: onShare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 10)],
                    ),
                    child: Center(
                      child: Text('linking.share'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ENTER CODE CARD ──────────────────────────────────────────────────────────
class _EnterCodeCard extends StatelessWidget {
  const _EnterCodeCard({required this.controller, required this.onLink});

  final TextEditingController controller;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Partner's Code", style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.sm),
          _CodeTextField(controller: controller),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: onLink,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('linking.linkNow'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTextField extends StatelessWidget {
  const _CodeTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          fontFamily: 'monospace',
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'linking.codeHint'.tr(),
          hintStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            fontFamily: 'monospace',
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        maxLength: 9,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(9),
        ],
        onChanged: (v) => controller.value = TextEditingValue(
          text: v.toUpperCase(),
          selection: controller.selection,
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

// ─── HOW IT WORKS ─────────────────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.isOpen, required this.onToggle});

  final bool isOpen;
  final VoidCallback onToggle;

  static const _stepKeys = [
    'linking.steps.s1',
    'linking.steps.s2',
    'linking.steps.s3',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text('linking.howDoesItWork'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gradientEnd)),
                const Spacer(),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, color: AppColors.gradientEnd),
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            ..._stepKeys.asMap().entries.map((e) {
              final i = e.key;
              final stepKey = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(stepKey.tr(), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.9)))),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── LINKING LOADING STATE ─────────────────────────────────────────────────────
class _LinkingLoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💖', style: TextStyle(fontSize: 48))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: 0, end: 30, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut),
            const Text(' 💕 ', style: TextStyle(fontSize: 64))
                .animate(onPlay: (c) => c.repeat())
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: const Duration(milliseconds: 400)),
            const Text('💗', style: TextStyle(fontSize: 48))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: 0, end: -30, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Linking hearts... 💕',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ─── SUCCESS STATE ────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.partnerName, required this.onStart});

  final String partnerName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 8),
                ],
              ),
              child: const Center(child: Text('✅', style: TextStyle(fontSize: 48))),
            )
                .animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1),
                    duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack)
                .shimmer(duration: const Duration(milliseconds: 800), color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.xl),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
              ).createShader(bounds),
              child: Text(
                'Connected with $partnerName! 💕',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 300)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Welcome to your love story 🌟',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 450)),
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Text('linking.startJourney'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 600))
                .slideY(begin: 0.1, end: 0, delay: const Duration(milliseconds: 600)),
          ],
        ),
      ),
    );
  }
}
