import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/theme.dart';

/// Pre-canned "Quick questions" the user can fire off with one tap. The
/// [promptKey] is a translation key resolved at render time; the
/// [icon] + [color] decorate the row in the bottom sheet.
class QuickQuestion {
  const QuickQuestion({
    required this.promptKey,
    required this.icon,
    required this.color,
  });
  final String promptKey;
  final IconData icon;
  final Color color;
}

/// Default quick-question catalog. The order here is the display order.
/// `promptKey` is a translation key under `ai.quickQuestions.*`.
const List<QuickQuestion> kDefaultQuickQuestions = [
  QuickQuestion(
    promptKey: 'ai.quickQuestions.anniversary',
    icon: Icons.celebration_rounded,
    color: Color(0xFFE91E8C),
  ),
  QuickQuestion(
    promptKey: 'ai.quickQuestions.streak',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFFA000),
  ),
  QuickQuestion(
    promptKey: 'ai.quickQuestions.partnerMood',
    icon: Icons.mood_rounded,
    color: Color(0xFFCE93D8),
  ),
  QuickQuestion(
    promptKey: 'ai.quickQuestions.pet',
    icon: Icons.pets_rounded,
    color: Color(0xFF66BB6A),
  ),
  QuickQuestion(
    promptKey: 'ai.quickQuestions.date',
    icon: Icons.event_rounded,
    color: Color(0xFF4FC3F7),
  ),
  QuickQuestion(
    promptKey: 'ai.quickQuestions.milestone',
    icon: Icons.timeline_rounded,
    color: Color(0xFFFFD54F),
  ),
];

/// Show the "Quick questions" bottom sheet. Returns the prompt the user
/// tapped, or `null` if they dismissed the sheet.
Future<String?> showQuickQuestionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    showDragHandle: false,
    useSafeArea: true,
    builder: (ctx) => const _QuickQuestionsSheet(),
  );
}

class _QuickQuestionsSheet extends StatelessWidget {
  const _QuickQuestionsSheet();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(AppRadius.xl + 4),
          bottom: const Radius.circular(AppRadius.lg),
        ),
        border: Border.all(
          color: AppColors.borderSubtle.withValues(alpha: 0.4),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientStart.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Grabber(),
          const _Header(),
          const SizedBox(height: AppSpacing.xs),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              itemCount: kDefaultQuickQuestions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final q = kDefaultQuickQuestions[i];
                return _QuickQuestionTile(
                  question: q,
                  index: i,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppColors.pinkGlow(intensity: 10),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ai.quickQuestions.title'.tr(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ai.quickQuestions.subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'common.close'.tr(),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickQuestionTile extends StatelessWidget {
  const _QuickQuestionTile({required this.question, required this.index});
  final QuickQuestion question;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(question.promptKey.tr()),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.borderSubtle.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: question.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: question.color.withValues(alpha: 0.5),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(
                    question.icon,
                    color: question.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    question.promptKey.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 40 * index), duration: 220.ms)
        .slideY(begin: 0.08, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
  }
}
