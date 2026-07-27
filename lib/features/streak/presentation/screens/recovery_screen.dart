import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  static const _brokenStreak = 47;
  static const _brokenDate = 'June 8, 2024';
  static const _recoveryHours = 48;
  static const _tokensAvailable = 3;
  static const _tokensMax = 4;
  static const _daysThisWeek = 3;

  // Recovery window: 48 hours from the broken date
  late final DateTime _brokenAt;
  late final DateTime _recoveryDeadline;
  late Timer _timer;
  int _secondsLeft = 0;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    // Simulate broken 24 hours ago, so ~24h left (86400 seconds)
    _brokenAt = DateTime.now().subtract(const Duration(hours: 24));
    _recoveryDeadline = _brokenAt.add(const Duration(hours: _recoveryHours));
    _secondsLeft = _recoveryDeadline.difference(DateTime.now()).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _secondsLeft = _recoveryDeadline.difference(DateTime.now()).inSeconds;
          if (_secondsLeft < 0) _secondsLeft = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown() {
    if (_secondsLeft <= 0) return '00:00:00';
    final h = (_secondsLeft ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secondsLeft % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _useToken() {
    // Simulate token use — in real app this would be a Firestore transaction
    setState(() => _isSuccess = true);
  }

  void _startFresh() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('checkin.recovery.startFreshTitle'.tr(), style: const TextStyle(color: Colors.red)),
        content: Text(
          'checkin.recovery.startFreshBody'.tr(args: ['47']),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.home);
            },
            child: Text('checkin.recovery.startFreshConfirm'.tr(), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _continueHome() {
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _SuccessOverlay(onContinue: _continueHome);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              _buildHeader(),
              const SizedBox(height: AppSpacing.lg),
              _buildBrokenStreakCard(),
              const SizedBox(height: AppSpacing.md),
              _tokensAvailable > 0 ? _buildTokenCard() : _buildNoTokensCard(),
              const SizedBox(height: AppSpacing.md),
              _buildDeclineOption(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        Text('💔 ${'checkin.recovery.title'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildBrokenStreakCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.shade400.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: GlassCard(
        child: Column(
          children: [
            // Heart breaking animation
            const Text('💔', style: TextStyle(fontSize: 72))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: const Duration(milliseconds: 800), curve: Curves.easeInOut),
            const SizedBox(height: AppSpacing.sm),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.red.shade300, Colors.red.shade600],
              ).createShader(bounds),
              child: Text(
                'checkin.recovery.streakBroken'.tr(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text('checkin.recovery.youHad'.tr(args: ['$_brokenStreak']), style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: 4),
            Text('checkin.recovery.brokenOn'.tr(args: ['$_brokenDate']), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),

            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderSubtle.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.sm),

            // Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⏰', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'checkin.recovery.windowCloses'.tr(),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ).createShader(bounds),
              child: Text(
                _formatCountdown(),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard() {
    final tokensAfter = _tokensAvailable - 1;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('checkin.recovery.useTokenTitle'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),

          // Token balance
          Row(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text('checkin.recovery.tokensAvailable'.tr(args: ['$_tokensAvailable']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Shield visual
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_tokensAvailable, (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('🛡️', style: TextStyle(fontSize: 36)),
            )),
          ),
          const SizedBox(height: AppSpacing.sm),

          Center(
            child: Text('checkin.recovery.oneTokenUsed'.tr(), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.borderSubtle.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.sm),

          // Result preview
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('checkin.recovery.streakRestored'.tr(args: ['$_brokenStreak']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('checkin.recovery.tokensRemaining'.tr(args: ['$tokensAfter', '$_tokensMax']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Use token button
          GestureDetector(
            onTap: _useToken,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text('checkin.recovery.useTokenBtn'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('checkin.recovery.tokenConsumed'.tr(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTokensCard() {
    return GlassCard(
      child: Column(
        children: [
          Text('checkin.recovery.noTokens'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'checkin.recovery.earnTokens'.tr(),
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),

          // Week progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('checkin.recovery.currentWeek'.tr(args: ['$_daysThisWeek']), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8))),
              const SizedBox(height: 6),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_daysThisWeek / 7).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          GestureDetector(
            onTap: _startFresh,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.gradientEnd, width: 1.5),
              ),
              child: const Center(child: Text('Start fresh →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gradientEnd))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineOption() {
    return GestureDetector(
      onTap: _startFresh,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'checkin.recovery.startFreshLink'.tr(),
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── SUCCESS OVERLAY ───────────────────────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Confetti animation
              SizedBox(
                width: 300, height: 200,
                child: Lottie.asset(
                  'assets/animations/confetti.json',
                  repeat: false,
                  errorBuilder: (_, __, ___) => const _ConfettiFallback(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Checkmark with glow
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 8),
                  ],
                ),
                child: const Center(child: Text('✅', style: TextStyle(fontSize: 48))),
              )
                  .animate()
                  .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack)
                  .shimmer(duration: const Duration(milliseconds: 800), color: Colors.white.withValues(alpha: 0.3)),

              const SizedBox(height: AppSpacing.xl),

              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  'Streak Restored! 🎉',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 300)),

              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your 47-day streak continues! 🔥',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 450)),

              const SizedBox(height: AppSpacing.sm),
              Text(
                '+0 tokens remaining',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 550)),

              const SizedBox(height: AppSpacing.xxl),

              GestureDetector(
                onTap: onContinue,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Text('checkin.recovery.keepGoing'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 650))
                  .slideY(begin: 0.1, end: 0, delay: const Duration(milliseconds: 650)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CONFETTI FALLBACK (no asset found) ──────────────────────────────────────
class _ConfettiFallback extends StatelessWidget {
  const _ConfettiFallback();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        '💖', '💕', '💗', '✨', '🎉', '💖', '💕', '💗',
      ]
          .asMap()
          .entries
          .map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              e.value,
              style: const TextStyle(fontSize: 28),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -20, delay: Duration(milliseconds: e.key * 80), duration: const Duration(milliseconds: 600)),
          ))
          .toList(),
    );
  }
}
