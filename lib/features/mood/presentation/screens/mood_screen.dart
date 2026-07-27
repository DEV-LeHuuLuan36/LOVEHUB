import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../notifications/presentation/helpers/notify_partner_activity.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/entities/mood_option.dart';
import '../providers/mood_providers.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  MoodOption? _selectedOption;
  final _noteController = TextEditingController();

  /// True only for ~4 seconds after a successful save that turned
  /// the couple into a "both feeling great" pair. The banner is
  /// never re-shown by rebuilds, the stream, or future opens.
  bool _showMatchBanner = false;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  MoodOption? _findOption(String emoji) {
    return moodOptions.where((o) => o.emoji == emoji).firstOrNull;
  }

  void _showMatchBannerFor4Seconds() {
    _bannerTimer?.cancel();
    setState(() => _showMatchBanner = true);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showMatchBanner = false);
    });
  }

  void _dismissMatchBanner() {
    _bannerTimer?.cancel();
    if (!_showMatchBanner) return;
    setState(() => _showMatchBanner = false);
  }

  Future<void> _saveMood() async {
    if (_selectedOption == null) return;
    final coupleId = ref.read(currentCoupleIdProvider);
    final myUser = ref.read(authStateProvider).valueOrNull;
    if (coupleId == null || myUser == null) return;

    final note = _noteController.text.trim();
    final selected = _selectedOption!;
    final result = await ref.read(setMoodControllerProvider.notifier).setMood(
      coupleId: coupleId,
      uid: myUser.uid,
      emoji: selected.emoji,
      label: selected.label,
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;
    if (result != null) {
      // Notify the partner about the mood update.
      final myName = myUser.displayName ?? 'common.partner'.tr();
      notifyPartnerActivity(
        ref,
        title: 'LoveHub',
        message: '$myName is feeling ${selected.label} ${selected.emoji}',
        data: {
          'type': 'mood',
          'coupleId': coupleId,
          'fromUid': myUser.uid,
          'moodEmoji': selected.emoji,
          'moodLabel': selected.label,
        },
      );

      // Trigger the "you're both feeling great" banner *only* if
      // this very save produced the match. We can't yet read the
      // post-write DailyMood from the stream (it may not have
      // re-emitted), so we combine the just-saved label with the
      // partner's last-known mood from the cached stream value.
      final today = ref.read(watchTodayMoodProvider).valueOrNull;
      final partnerWasPositive = today?.partner?.isPositive ?? false;
      final meIsPositive = selected.label == 'Happy' || selected.label == 'In Love';
      if (meIsPositive && partnerWasPositive) {
        _showMatchBannerFor4Seconds();
      }

      if (result.lpAwarded) {
        _showFeedback('mood.savedSuccess'.tr(), AppColors.accentGold);
      } else {
        _showFeedback('mood.savedSuccess'.tr(), AppColors.gradientEnd);
      }
    }
  }

  void _showFeedback(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodAsync = ref.watch(watchTodayMoodProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: moodAsync.when(
          data: (daily) => _buildContent(daily),
          loading: () => _buildContent(null),
          error: (e, _) => _buildContent(null),
        ),
      ),
    );
  }

  Widget _buildContent(DailyMood? daily) {
    final mine = daily?.mine;
    final partner = daily?.partner;
    final partnerName = ref.watch(partnerProfileProvider).valueOrNull?.displayName ?? 'common.partner'.tr();
    final myDisplayName = ref.watch(authStateProvider).valueOrNull?.displayName ?? 'common.you'.tr();

    // If user already set mood today, pre-select it
    final preselected = mine != null ? _findOption(mine.emoji) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const _Header(),
          const SizedBox(height: AppSpacing.lg),
          _TodayMoodCard(
            preselected: preselected,
            selectedOption: _selectedOption,
            noteController: _noteController,
            lpAvailable: mine == null,
            onSelect: (opt) => setState(() => _selectedOption = opt),
            onSave: _saveMood,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PartnerMoodCard(
            partnerName: partnerName,
            partner: partner,
          ),
          if (_showMatchBanner) ...[
            const SizedBox(height: AppSpacing.sm),
            _MoodMatchBanner(
              myName: myDisplayName,
              partnerName: partnerName,
              onDismiss: _dismissMatchBanner,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const _NotificationCard(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── SECTION 1: HEADER ───────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
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
        Column(
          children: [
            Text('mood.title'.tr(), style: AppTypography.headlineMedium),
            const SizedBox(height: 2),
            Text('mood.subtitle'.tr(),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

// ─── SECTION 2: TODAY MOOD CARD ───────────────────────────────────────────────
class _TodayMoodCard extends StatelessWidget {
  const _TodayMoodCard({
    required this.preselected,
    required this.selectedOption,
    required this.noteController,
    required this.lpAvailable,
    required this.onSelect,
    required this.onSave,
  });

  final MoodOption? preselected;
  final MoodOption? selectedOption;
  final TextEditingController noteController;
  final bool lpAvailable;
  final ValueChanged<MoodOption> onSelect;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final active = selectedOption ?? preselected;
    final isLoading = false;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'mood.title'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moodOptions.map((opt) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _MoodButton(
                    emoji: opt.emoji,
                    label: opt.label,
                    selected: active?.emoji == opt.emoji,
                    onTap: () => onSelect(opt),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _NoteField(controller: noteController),
          const SizedBox(height: AppSpacing.md),
          if (lpAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '+5 LP for your first mood today',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accentGold.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _SaveMoodButton(
            enabled: active != null && !isLoading,
            isLoading: isLoading,
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 100,
      maxLines: 2,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'mood.noteHint'.tr(),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
        counterStyle: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.backgroundPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.gradientEnd, width: 1.5),
        ),
      ),
    );
  }
}

// ─── SECTION 3: PARTNER MOOD CARD ─────────────────────────────────────────────
class _PartnerMoodCard extends StatelessWidget {
  const _PartnerMoodCard({required this.partnerName, required this.partner});

  final String partnerName;
  final MoodEntry? partner;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Text("$partnerName's mood today ", style: AppTypography.titleMedium),
              const Text('', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (partner != null) ...[
            Text(partner!.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 6),
            Text(
              partner!.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gradientEnd),
            ),
            if (partner!.note != null && partner!.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '"${partner!.note}"',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Active ${_relativeTime(partner!.updatedAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ] else ...[
            Text('😶', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 6),
            Text(
              'mood.partnerNoMood'.tr(),
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 4),
            Text(
              'mood.waiting'.tr(namedArgs: {'name': partnerName}),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── SECTION 4: MOOD MATCH BANNER ─────────────────────────────────────────────
class _MoodMatchBanner extends StatelessWidget {
  const _MoodMatchBanner({required this.myName, required this.partnerName, required this.onDismiss});

  final String myName;
  final String partnerName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('', style: TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're both feeling great today!",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1025)),
                ),
                const SizedBox(height: 2),
                const Text(
                  '+15 LP bonus for your pet!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00897B)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Color(0xFF1A1025)),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: const Duration(milliseconds: 300));
  }
}

// ─── SECTION 7: NOTIFICATION REMINDER CARD ────────────────────────────────────
class _NotificationCard extends StatefulWidget {
  const _NotificationCard();

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _reminderOn = true;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Text('', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('mood.reminder.subtitle'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'mood.reminder.desc'.tr(),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Switch(
            value: _reminderOn,
            onChanged: (v) => setState(() => _reminderOn = v),
            activeColor: AppColors.gradientEnd,
            activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS ───────────────────────────────────────────────────────────────
class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.emoji, required this.label, required this.selected, required this.onTap});

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          // Monotonic curve (no overshoot) on the container so the
          // implicit tween of `boxShadow` from null → BoxShadow(...)
          // never drives `blurRadius` past 14 — `easeOutBack`'s overshoot
          // was producing a brief negative shadow blur at line 536,
          // crashing the mood screen with "Text shadow blur radius
          // should be non-negative".
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: selected ? 72 : 60,
          height: selected ? 80 : 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.backgroundPrimary,
            border: Border.all(
              color: selected ? AppColors.gradientEnd : AppColors.borderSubtle,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gradientEnd.withValues(alpha: 0.45),
                      // Defensive: even if a future change animates
                      // this value, the rendered blur can never go
                      // negative.
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: selected ? 28 : 22),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: selected ? 10 : 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.gradientEnd : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveMoodButton extends StatelessWidget {
  const _SaveMoodButton({required this.enabled, required this.isLoading, required this.onTap});

  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !isLoading ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.borderSubtle.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.gradientEnd.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'mood.saveBtn'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : AppColors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}
