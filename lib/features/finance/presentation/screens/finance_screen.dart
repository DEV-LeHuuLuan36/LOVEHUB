import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_text.dart';
import '../../domain/entities/saving_jar.dart';
import '../providers/finance_providers.dart';
import '../../screens/create_jar_screen.dart';
import '../../screens/saving_jar_screen.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jarsAsync = ref.watch(watchJarsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const _Header(),
              const SizedBox(height: AppSpacing.lg),
              jarsAsync.when(
                loading: () => const _SummarySkeleton(),
                error: (e, _) => GlassCard(
                  child: Text(
                    'Error loading jars: $e',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                data: (jars) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(jars: jars),
                    const SizedBox(height: AppSpacing.md),
                    if (jars.isEmpty)
                      const _EmptyJarsHint()
                    else
                      ...jars.map((jar) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _JarCard(jar: jar),
                          )),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // BUG FIX: symmetric Spacer() — Flexible() — Spacer() layout squeezes
        // the title to "T..." on small screens.  Removing the leading Spacer()
        // lets the title take all space up to its intrinsic width, then
        // ellipsis truncates only after the button is laid out.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 0),
            child: Text(
              '💰 ${'finance.title'.tr()}',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _OutlinedPinkButton(
          label: 'finance.addBtn'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateJarScreen()),
          ),
        ),
      ],
    );
  }
}

class _OutlinedPinkButton extends StatelessWidget {
  const _OutlinedPinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.gradientEnd, width: 1.2),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.gradientEnd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── SUMMARY CARD ───────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.jars});

  final List<SavingJar> jars;

  @override
  Widget build(BuildContext context) {
    final total = jars.fold<int>(0, (sum, j) => sum + j.currentAmount);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Text('finance.totalSavedTogether'.tr(), style: AppTypography.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          GradientText(
            formatVND(total),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            jars.isEmpty
                ? 'finance.noJars'.tr()
                : 'finance.jarCount'.tr(args: ['${jars.length}']),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
      child: SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.gradientEnd, strokeWidth: 2),
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ─────────────────────────────────────────────────────────────
class _EmptyJarsHint extends StatelessWidget {
  const _EmptyJarsHint();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text('🐷', style: TextStyle(fontSize: 40, color: AppColors.textSecondary.withValues(alpha: 0.5))),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'finance.noJars'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'finance.emptyHint'.tr(),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── JAR CARD ────────────────────────────────────────────────────────────────
class _JarCard extends StatelessWidget {
  const _JarCard({required this.jar});

  final SavingJar jar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SavingJarScreen(
            coupleId: jar.coupleId,
            jarId: jar.id,
            initialName: jar.name,
            initialEmoji: jar.emoji,
          ),
        ),
      ),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(jar.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jar.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatVND(jar.currentAmount)} / ${formatVND(jar.targetAmount)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _PercentBadge(percent: jar.progress),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ProgressBar(fraction: jar.progress),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _OutlinedButton(
                    label: 'finance.addToJar'.tr(),
                    color: AppColors.gradientEnd,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavingJarScreen(
                          coupleId: jar.coupleId,
                          jarId: jar.id,
                          initialName: jar.name,
                          initialEmoji: jar.emoji,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _FilledButton(
                    label: '🏦 ${'finance.qrShortcut'.tr()}',
                    color: const Color(0xFF00897B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavingJarScreen(
                          coupleId: jar.coupleId,
                          jarId: jar.id,
                          initialName: jar.name,
                          initialEmoji: jar.emoji,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.accentGold, width: 1),
      ),
      child: Text(
        percent > 0 && percent < 1.0
            ? '${percent.toStringAsFixed(1)}%'
            : '${percent.round()}%',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientEnd.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── BUTTONS ─────────────────────────────────────────────────────────────────
class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
