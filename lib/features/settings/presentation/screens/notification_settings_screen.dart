import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/onesignal_providers.dart';
import '../../../notifications/presentation/providers/partner_activity_provider.dart';
import '../providers/notification_providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _allEnabled = true;
  // The Checkin + Mood Reminder rows are wired to providers backed
  // by flutter_local_notifications. The other toggles are local UI
  // state for now (they're not yet backed by real notifications).
  bool _streakMilestones = true;
  bool _petAttention = true;
  bool _savingGoal = true;
  bool _partnerMoney = true;
  bool _quietHoursEnabled = false;

  Future<void> _setCheckinReminder(bool value) async {
    final notifier = ref.read(checkinReminderEnabledProvider.notifier);
    final ok = await notifier.set(value);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.errors.permissionRequired'.tr()),
        ),
      );
    }
  }

  Future<void> _setMoodReminder(bool value) async {
    final notifier = ref.read(moodReminderEnabledProvider.notifier);
    final ok = await notifier.set(value);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.errors.permissionRequired'.tr()),
        ),
      );
    }
  }

  /// Toggle for "Partner Activity" (OneSignal push to the partner).
  ///   ON  → persist the preference, then make sure OneSignal is
  ///         linked to the current Firebase uid and the OS push
  ///         permission is granted (so the device can actually
  ///         *receive* partner pushes). The user can revoke the
  ///         OS permission in system settings; in that case the
  ///         OneSignal repo's requestPermission() will return
  ///         false and we show a snackbar.
  ///   OFF → just persist the preference. The activity trigger
  ///         sites gate on this provider, so no partner pushes
  ///         will be sent until it's turned back on.
  Future<void> _setPartnerActivity(bool value) async {
    debugPrint(
      'ONESIGNAL_DBG: Partner Activity toggle → value=$value',
    );

    // 1. Persist the preference first so the UI reflects intent
    //    even if a later step (login / permission) fails.
    await ref.read(partnerActivityEnabledProvider.notifier).set(value);

    if (!value) {
      debugPrint(
        'ONESIGNAL_DBG: Partner Activity OFF — no OneSignal calls, '
        'no permission request',
      );
      return;
    }

    // 2. Make sure OneSignal is linked to the current user and the
    //    OS has push permission for this app.
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final repo = ref.read(oneSignalRepositoryProvider);

    if (uid == null) {
      debugPrint(
        'ONESIGNAL_DBG: Partner Activity ON but no signed-in user — '
        'requesting permission only',
      );
    } else {
      debugPrint(
        'ONESIGNAL_DBG: Partner Activity ON, uid=$uid — '
        'OneSignal.login + requestPermission',
      );
      try {
        await repo.loginUser(uid);
      } catch (e) {
        debugPrint('ONESIGNAL_DBG: loginUser failed: $e');
      }
    }

    final granted = await repo.requestPermission();
    if (mounted && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.errors.permissionDenied'.tr()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkinEnabled = ref.watch(checkinReminderEnabledProvider);
    final moodEnabled = ref.watch(moodReminderEnabledProvider);

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

              // Master toggle
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔔', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'notifications.enableAll'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _allEnabled,
                          onChanged: (v) =>
                              setState(() => _allEnabled = v),
                          activeColor: AppColors.gradientEnd,
                          activeTrackColor:
                              AppColors.gradientEnd.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'notifications.enableAllHint'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Daily Reminders card
              _NotificationCard(
                title: 'notifications.section.daily'.tr(),
                children: [
                  _NotificationRow(
                    label: 'notifications.checkinReminder'.tr(),
                    value: checkinEnabled,
                    time: '9:00 PM',
                    onChanged: _setCheckinReminder,
                    onTimeTap: () => _showTimePicker(context),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _NotificationRow(
                    label: 'notifications.moodReminder'.tr(),
                    value: moodEnabled,
                    time: '9:00 PM',
                    onChanged: _setMoodReminder,
                    onTimeTap: () => _showTimePicker(context),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _NotificationRow(
                    label: 'notifications.partnerActivity'.tr(),
                    value: ref.watch(partnerActivityEnabledProvider),
                    onChanged: _setPartnerActivity,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Milestone Alerts card
              _NotificationCard(
                title: 'notifications.section.milestone'.tr(),
                children: [
                  _ChipRow(
                    label: 'notifications.birthdayReminder'.tr(),
                    chip: 'notifications.daysBefore3'.tr(),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _ChipRow(
                    label: 'notifications.anniversaryAlert'.tr(),
                    chip: 'notifications.daysBefore7'.tr(),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _NotificationRow(
                    label: 'notifications.streakMilestones'.tr(),
                    value: _streakMilestones,
                    onChanged: (v) => setState(() => _streakMilestones = v),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _NotificationRow(
                    label: 'notifications.petNeedsAttention'.tr(),
                    value: _petAttention,
                    onChanged: (v) => setState(() => _petAttention = v),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Finance card
              _NotificationCard(
                title: 'notifications.section.finance'.tr(),
                children: [
                  _NotificationRow(
                    label: 'notifications.savingGoalReached'.tr(),
                    value: _savingGoal,
                    onChanged: (v) => setState(() => _savingGoal = v),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  _NotificationRow(
                    label: 'notifications.partnerAddedMoney'.tr(),
                    value: _partnerMoney,
                    onChanged: (v) => setState(() => _partnerMoney = v),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Quiet Hours card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌙 ${'notifications.section.quietHours'.tr()}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'notifications.enableQuietHours'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _quietHoursEnabled,
                          onChanged: (v) =>
                              setState(() => _quietHoursEnabled = v),
                          activeColor: AppColors.gradientEnd,
                          activeTrackColor:
                              AppColors.gradientEnd.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    if (_quietHoursEnabled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeRangePickerButton(
                              label: 'notifications.start'.tr(),
                              time: '10:00 PM',
                              onTap: () => _showTimePicker(context),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '→',
                              style: TextStyle(
                                fontSize: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _TimeRangePickerButton(
                              label: 'notifications.end'.tr(),
                              time: '8:00 AM',
                              onTap: () => _showTimePicker(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final now = TimeOfDay.now();
    await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.gradientEnd,
              onPrimary: Colors.white,
              surface: AppColors.backgroundCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

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
        Text('🔔 ${'notifications.title'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  _NotificationRow({
    required this.label, required this.value,
    this.time, this.onTimeTap, required this.onChanged,
  });

  final String label;
  final bool value;
  final String? time;
  final VoidCallback? onTimeTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          if (time != null) ...[
            GestureDetector(
              onTap: onTimeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8))),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 11, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.gradientEnd,
            activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.chip});

  final String label;
  final String chip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient.scale(0.5),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(chip, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TimeRangePickerButton extends StatelessWidget {
  const _TimeRangePickerButton({required this.label, required this.time, required this.onTap});

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
