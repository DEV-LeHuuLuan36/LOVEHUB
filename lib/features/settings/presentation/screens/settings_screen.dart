import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../services/background_refresh_service.dart';
import '../../../../services/foreground_notification_service.dart';
import '../../../../services/memory_pdf_export_service.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/domain/entities/couple.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../diary/presentation/providers/memory_providers.dart';
import '../../../settings/presentation/providers/font_scale_provider.dart';
import '../../../settings/presentation/providers/notification_providers.dart';
import '../../../../shared/widgets/user_avatar.dart';
import 'change_password_screen.dart';
import 'markdown_page_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final signOutState = ref.watch(authControllerProvider);
    final isSigningOut = signOutState.isLoading;
    final coupleId = ref.watch(currentCoupleIdProvider);
    final coupleAsync = coupleId != null ? ref.watch(watchCoupleProvider(coupleId)) : null;
    final couple = coupleAsync?.valueOrNull;
    final isPending = couple?.isPendingUnlink == true;
    // Only email/password accounts can change a password from
    // inside the app. Google sign-in users go through Google to
    // change credentials, so the row stays hidden for them.
    final isPasswordAccount = ref.watch(isPasswordAccountProvider);
    // Locale code at the moment (e.g. "en", "vi"). Used for the
    // trailing value on the App Language row.
    final currentLocale = context.locale.languageCode;

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

              // Recovery banner
              if (isPending)
                _SettingsRecoveryBanner(
                  daysLeft: couple?.daysLeftToRecover ?? 0,
                  onRecover: () async {
                    if (coupleId == null) return;
                    final ok = await ref.read(unlinkControllerProvider.notifier).recover(coupleId: coupleId);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('settings.recoverError'.tr())),
                      );
                    }
                  },
                ),

              // Account card
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _UserAvatar(user: user),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName?.isNotEmpty == true
                                ? user!.displayName!
                                : 'common.noName'.tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '...',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          _CoupleStatusChip(coupleId: user?.coupleId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Couple info card
              const _CoupleInfoCard(),

              const SizedBox(height: AppSpacing.md),

              // Notifications section
              _SectionHeader(title: 'settings.section_notifications'.tr()),
              _LoveCounterNotificationToggle(coupleId: coupleId),
              _NotificationToggleRow(
                icon: '⏰', label: 'settings.dailyCheckinReminder'.tr(), subtitle: 'settings.notification_dailyCheckinSubtitle'.tr(),
                value: true, onChanged: (_) {},
              ),
              _NotificationToggleRow(
                icon: '😊', label: 'settings.moodReminder'.tr(), subtitle: 'settings.notification_moodSubtitle'.tr(),
                value: true, onChanged: (_) {},
              ),
              _NotificationToggleRow(
                icon: '🎯', label: 'settings.milestoneAlerts'.tr(), value: true, onChanged: (_) {},
              ),
              _NotificationToggleRow(
                icon: '💕', label: 'settings.partnerActivity'.tr(), value: true, onChanged: (_) {},
              ),

              const SizedBox(height: AppSpacing.sm),

              // Appearance section
              _SectionHeader(title: 'settings.section_appearance'.tr()),
              _SettingsNavRow(
                label: 'settings.appearance_theme'.tr(),
                value: _themeModeLabel(ref.watch(themeModeProvider)),
                onTap: () => _showThemeModeDialog(context, ref),
              ),
              _SettingsNavRow(
                label: 'settings.appearance_language'.tr(),
                value: currentLocale == 'vi'
                    ? 'settings.language.vietnamese'.tr()
                    : 'settings.language.english'.tr(),
                onTap: () => _showLanguageDialog(context),
              ),
              _SettingsNavRow(
                  label: 'settings.appearance_fontSize'.tr(),
                  value: _fontSizeLabel(ref.watch(fontScaleProvider)),
                  onTap: () => _showFontSizeDialog(context, ref)),

              const SizedBox(height: AppSpacing.sm),

              // Data & Privacy section
              _SectionHeader(title: 'settings.section_dataPrivacy'.tr()),
              _SettingsNavRow(
                label: 'settings.backupData'.tr(),
                onTap: () => context.push(AppRoutes.backupRestore),
              ),
              _SettingsNavRow(
                label: 'settings.restoreData'.tr(),
                onTap: () => context.push(AppRoutes.backupRestore),
              ),
              _SettingsNavRow(
                label: 'settings.exportMemories'.tr(),
                onTap: () => _showExportYearPicker(context, ref),
              ),
              _SettingsNavRow(
                label: 'settings.privacyPolicy'.tr(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarkdownPageScreen(
                      title: 'settings.privacyPolicy'.tr(),
                      assetPath: 'assets/legal/privacy_policy.md',
                    ),
                  ),
                ),
              ),
              _SettingsNavRow(
                label: 'settings.termsOfService'.tr(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarkdownPageScreen(
                      title: 'settings.termsOfService'.tr(),
                      assetPath: 'assets/legal/terms_of_service.md',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Account section
              _SectionHeader(title: 'settings.section_account'.tr()),
              if (isPasswordAccount)
                _SettingsNavRow(
                  label: 'settings.changePassword'.tr(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
              _SettingsNavRow(
                label: isPending ? 'settings.recoverCouple'.tr() : 'settings.unlink'.tr(),
                isDanger: !isPending,
                onTap: () => _showUnlinkDialog(context, ref, user?.uid, coupleId, isPending),
              ),
              _SettingsNavRow(label: 'settings.deleteAccount'.tr(), isDanger: true, onTap: () => _showDeleteDialog(context, ref)),

              const SizedBox(height: AppSpacing.lg),

              // Sign out button
              _SignOutButton(
                isLoading: isSigningOut,
                onSignOut: () => _handleSignOut(context, ref),
              ),

              const SizedBox(height: AppSpacing.md),

              // App info
              Column(
                children: [
                  Text('settings.appInfo.version'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('settings.appInfo.madeWith'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // DEBUG: Rive multi-probe
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.pets, color: Color(0xFFFFD700)),
                  title: Text(
                    'settings.debug.riveProbeTitle'.tr(),
                    style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'settings.debug.riveProbeSubtitle'.tr(),
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => context.push(AppRoutes.riveMultiProbe),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('settings.signOutTitle'.tr(), style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'settings.signOutBody'.tr(),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Stop the persistent notification before signing out
              await ForegroundNotificationService.stop();
              // Cancel the WorkManager periodic task and clear registration
              await BackgroundRefreshService.cancelPeriodicTask();
              final success = await ref.read(authControllerProvider.notifier).signOut();
              if (!success && context.mounted) {
                final state = ref.read(authControllerProvider);
                state.whenOrNull(error: (msg, _) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(msg.toString())),
                        ],
                      ),
                      backgroundColor: const Color(0xFFC62828),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
                    ),
                  );
                });
              }
            },
            child: Text('settings.signOut'.tr(), style: const TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showUnlinkDialog(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    String? coupleId,
    bool isPending,
  ) {
    if (isPending) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (ctx) => _RecoverConfirmDialog(
          onCancel: () => Navigator.of(ctx).pop(),
          onConfirm: () async {
            Navigator.of(ctx).pop();
            if (coupleId == null) return;
            final ok = await ref.read(unlinkControllerProvider.notifier).recover(coupleId: coupleId);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('settings.recoverError'.tr())),
              );
            }
          },
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _UnlinkConfirmDialog(
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: () async {
          Navigator.of(ctx).pop();
          if (coupleId == null || userId == null) return;
          final ok = await ref.read(unlinkControllerProvider.notifier).requestUnlink(
                coupleId: coupleId,
                userId: userId,
              );
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('settings.unlinkError'.tr())),
            );
          }
        },
      ),
    );
  }

  /// Show a small dialog to switch the app language. Updates the
  /// whole tree via [EasyLocalization.setLocale]; persistence is
  /// handled by `saveLocale: true` on the `EasyLocalization`
  /// wrapper in main.dart.
  void _showLanguageDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final selected = context.locale.languageCode;
        return SimpleDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'settings.language.selectTitle'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          children: [
            _LanguageOption(
              code: 'en',
              label: 'settings.language.english'.tr(),
              selected: selected == 'en',
              onTap: () {
                Navigator.of(ctx).pop();
                context.setLocale(const Locale('en'));
              },
            ),
            _LanguageOption(
              code: 'vi',
              label: 'settings.language.vietnamese'.tr(),
              selected: selected == 'vi',
              onTap: () {
                Navigator.of(ctx).pop();
                context.setLocale(const Locale('vi'));
              },
            ),
          ],
        );
      },
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'settings.appearance_systemMode'.tr();
      case ThemeMode.light:
        return 'settings.appearance_lightMode'.tr();
      case ThemeMode.dark:
        return 'settings.appearance_darkMode'.tr();
    }
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final selected = ref.read(themeModeProvider);
        return SimpleDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'settings.appearance_theme'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          children: [
            _ThemeModeOption(
              mode: ThemeMode.system,
              label: 'settings.appearance_systemMode'.tr(),
              selected: selected == ThemeMode.system,
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
              },
            ),
            _ThemeModeOption(
              mode: ThemeMode.light,
              label: 'settings.appearance_lightMode'.tr(),
              selected: selected == ThemeMode.light,
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.light);
              },
            ),
            _ThemeModeOption(
              mode: ThemeMode.dark,
              label: 'settings.appearance_darkMode'.tr(),
              selected: selected == ThemeMode.dark,
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
              },
            ),
          ],
        );
      },
    );
  }

  String _fontSizeLabel(FontScaleLevel level) {
    switch (level) {
      case FontScaleLevel.small:
        return 'settings.fontSize.small'.tr();
      case FontScaleLevel.medium:
        return 'settings.fontSize.medium'.tr();
      case FontScaleLevel.large:
        return 'settings.fontSize.large'.tr();
    }
  }

  void _showFontSizeDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final current = ref.read(fontScaleProvider);
        return SimpleDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'settings.fontSize.selectTitle'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          children: [
            for (final level in FontScaleLevel.values)
              _FontSizeOption(
                level: level,
                selected: current == level,
                onTap: () {
                  ref.read(fontScaleProvider.notifier).set(level);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        );
      },
    );
  }

  void _showExportYearPicker(BuildContext context, WidgetRef ref) {
    final memories = ref.read(watchMemoriesProvider).valueOrNull ?? [];
    if (memories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.noMemories'.tr()),
          backgroundColor: AppColors.backgroundCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
        ),
      );
      return;
    }

    // Derive unique years from memories, sorted descending (newest first).
    final years = memories.map((m) => m.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));

    showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'settings.exportSelectYear'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        children: [
          for (final year in years)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(year),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.gradientEnd),
                    const SizedBox(width: 12),
                    Text(
                      '$year  (${memories.where((m) => m.date.year == year).length})',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).then((selectedYear) async {
      if (selectedYear == null || !context.mounted) return;

      // Show a loading dialog while generating.
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.gradientEnd, strokeWidth: 2),
                  const SizedBox(height: 16),
                  Text(
                    'settings.exportGenerating'.tr(),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final yearMemories = memories
            .where((m) => m.date.year == selectedYear)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        final user = ref.read(authStateProvider).valueOrNull;
        final partner = ref.read(partnerProfileProvider).valueOrNull;

        await MemoryPdfExportService.exportAndShare(
          year: selectedYear,
          memories: yearMemories,
          userName: user?.displayName,
          partnerName: partner?.displayName,
        );

        if (context.mounted) Navigator.of(context).pop(); // dismiss loading
      } catch (e, st) {
        debugPrint('[PDF EXPORT UI] Error during export: $e');
        debugPrint('[PDF EXPORT UI] Stacktrace: $st');
        if (context.mounted) {
          Navigator.of(context).pop(); // dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('settings.exportError'.tr())),
                ],
              ),
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
            ),
          );
        }
      }
    });
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: false,
      builder: (ctx) => _DeleteAccountDialog(
        onCancel: () => Navigator.of(ctx).pop(),
        onDeleted: () async {
          Navigator.of(ctx).pop();
          // Sign out (also clears GoogleSignIn session) and navigate
          // to the login screen, clearing the navigation stack so the
          // user cannot navigate back into the deleted account's
          // screens.
          try {
            await ref.read(authControllerProvider.notifier).signOut();
          } catch (_) {}
          if (!context.mounted) return;
          GoRouter.of(context).go(AppRoutes.login);
        },
      ),
    );
  }
}

// ─── Love Counter Notification Toggle ───────────────────────────────────────────
class _LoveCounterNotificationToggle extends ConsumerStatefulWidget {
  const _LoveCounterNotificationToggle({required this.coupleId});
  final String? coupleId;

  @override
  ConsumerState<_LoveCounterNotificationToggle> createState() => _LoveCounterNotificationToggleState();
}

class _LoveCounterNotificationToggleState extends ConsumerState<_LoveCounterNotificationToggle> {
  bool _isLoading = false;

  Future<void> _onToggle(bool value) async {
    setState(() => _isLoading = true);

    if (value) {
      // Show rationale dialog first
      final agreed = await _showRationaleDialog();
      if (!agreed) {
        setState(() => _isLoading = false);
        return;
      }

      // Request notification permission (Android 13+)
      final perm = await ForegroundNotificationService.checkPermission();
      if (perm == NotificationPermission.denied) {
        final result = await ForegroundNotificationService.requestPermission();
        if (result == NotificationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('settings.allowNotifications'.tr())),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Request ignore battery optimization
      await ForegroundNotificationService.requestIgnoreBatteryOptimization();

      // Start notification with current data
      final days = ref.read(loveDurationProvider)?.days ?? 0;
      final names = _buildNames();
      await ForegroundNotificationService.start(days: days, names: names);
    } else {
      await ForegroundNotificationService.stop();
    }

    // Persist toggle state via the shared notifier
    ref.read(loveCounterNotificationEnabledProvider.notifier).set(value);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<bool> _showRationaleDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text('settings.daysCounterTitle'.tr(), style: const TextStyle(color: AppColors.textPrimary)),
            content: Text(
              'settings.daysCounterBody'.tr(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('common.cancel'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('common.enable'.tr(), style: const TextStyle(color: AppColors.gradientEnd, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _buildNames() {
    final authUser = ref.read(authStateProvider).valueOrNull;
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    final yourName = authUser?.displayName ?? '';
    final partnerName = partner?.displayName ?? '';
    if (yourName.isNotEmpty && partnerName.isNotEmpty) {
      return '$yourName & $partnerName';
    }
    return yourName.isNotEmpty ? yourName : partnerName;
  }

  @override
  Widget build(BuildContext context) {
    final notifEnabled = ref.watch(loveCounterNotificationEnabledProvider);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Text('💕', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.showDaysCounter'.tr(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        'settings.showDaysCounterSubtitle'.tr(),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_isLoading)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gradientEnd),
            )
          else
            Switch(
              value: notifEnabled,
              onChanged: widget.coupleId != null ? _onToggle : null,
              activeColor: AppColors.gradientEnd,
              activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}

// ─── Settings Recovery Banner ──────────────────────────────────────────────────
class _SettingsRecoveryBanner extends ConsumerWidget {
  const _SettingsRecoveryBanner({required this.daysLeft, required this.onRecover});

  final int daysLeft;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecovering = ref.watch(unlinkControllerProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
              blurRadius: 12,
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
                    'home.recoveryBanner.title'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    'home.recoveryBanner.subtitle'.tr(namedArgs: {'days': '$daysLeft'}),
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: isRecovering ? null : onRecover,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: isRecovering
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('home.recoveryBanner.recover'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User avatar ───────────────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: AppColors.backgroundCard,
      );
    }
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Center(
        child: Text(
          (user?.displayName as String?)?.isNotEmpty == true
              ? user!.displayName![0].toUpperCase()
              : '?',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Couple status chip ────────────────────────────────────────────────────────
class _CoupleStatusChip extends StatelessWidget {
  const _CoupleStatusChip({required this.coupleId});
  final String? coupleId;

  @override
  Widget build(BuildContext context) {
    final isLinked = coupleId != null && coupleId!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLinked
            ? const Color(0xFF00897B).withValues(alpha: 0.15)
            : const Color(0xFFFFB300).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        isLinked ? 'settings.paired'.tr() : 'settings.notPaired'.tr(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isLinked ? const Color(0xFF4DB6AC) : const Color(0xFFFFCA28),
        ),
      ),
    );
  }
}

// ─── Sign out button ───────────────────────────────────────────────────────────
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.isLoading, required this.onSignOut});
  final bool isLoading;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? () {} : onSignOut,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Text('settings.signOut'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Reused sub-widgets ───────────────────────────────────────────────────────
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
        Text('settings.title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _CoupleInfoCard extends ConsumerWidget {
  const _CoupleInfoCard();

  /// Best-effort display name for an [AppUser] or email-only fallback.
  /// Returns the display name when set, else the email's local-part,
  /// else a neutral placeholder.
  static String _nameFor(AppUser? user) {
    if (user == null) return '...';
    final dn = user.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final email = user.email;
    if (email.isNotEmpty) {
      final at = email.indexOf('@');
      return at > 0 ? email.substring(0, at) : email;
    }
    return '...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleId = ref.watch(currentCoupleIdProvider);
    final me = ref.watch(authStateProvider).valueOrNull;
    final partnerAsync = ref.watch(partnerProfileProvider);
    final coupleAsync = coupleId == null
        ? const AsyncValue<Couple?>.data(null)
        : ref.watch(watchCoupleProvider(coupleId));
    final duration = ref.watch(loveDurationProvider);

    // Loading / unavailable state. We must not fall back to mock values
    // — show a shimmer instead. The card only renders real data when all
    // three pieces (couple code, both names, days) are available.
    final couple = coupleAsync.valueOrNull;
    final partner = partnerAsync.valueOrNull;
    final isLoading = coupleId == null ||
        coupleAsync.isLoading ||
        partnerAsync.isLoading ||
        couple == null ||
        couple.code.isEmpty ||
        me == null ||
        partner == null ||
        duration == null;

    if (isLoading) {
      return const _CoupleInfoCardShimmer();
    }

    final yourName = _nameFor(me);
    final partnerName = _nameFor(partner);
    final days = duration.days;
    final code = couple.code;

    return GlassCard(
      child: Column(
        children: [
          Text(
            'settings.ourRelationship'.tr(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MemberAvatar(user: me, gradient: AppColors.primaryGradient),
              Transform.translate(
                offset: const Offset(-8, 0),
                child: _MemberAvatar(
                  user: partner,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$yourName & $partnerName - ${'settings.daysTogether'.tr(namedArgs: {'days': '$days'})}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ).createShader(bounds),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('settings.coupleCard.copyCode'.tr(namedArgs: {'code': code})),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.gradientEnd, width: 1),
                  ),
                  child: Text(
                    'settings.coupleCard.copyBtn'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gradientEnd,
                      fontWeight: FontWeight.w600,
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

/// One half of the avatar pair in `_CoupleInfoCard`. Uses a real photo
/// when the user has one (via `UserAvatar`), otherwise falls back to the
/// user's first initial in the supplied gradient.
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.user, required this.gradient});
  final AppUser? user;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final size = 32.0;
    final name = _CoupleInfoCard._nameFor(user);
    final photoUrl = UserAvatar.photoUrlOrNull(user?.photoUrl);
    final hasPhoto = photoUrl != null;

    if (hasPhoto) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.backgroundCard, width: 2),
        ),
        child: UserAvatar(
          photoUrl: photoUrl,
          name: name,
          size: size,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.backgroundCard, width: 2),
      ),
      child: Center(
        child: Text(
          UserAvatar.displayName(name).isEmpty
              ? '?'
              : UserAvatar.displayName(name)[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder shown while any of the couple / partner / auth
/// streams are still loading. Matches the size of the real card.
class _CoupleInfoCardShimmer extends StatefulWidget {
  const _CoupleInfoCardShimmer();

  @override
  State<_CoupleInfoCardShimmer> createState() => _CoupleInfoCardShimmerState();
}

class _CoupleInfoCardShimmerState extends State<_CoupleInfoCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = 0.35 + (_ctrl.value * 0.25); // 0.35..0.6 alpha
        final color = Colors.white.withValues(alpha: t);
        final base = AppColors.backgroundCard;
        return GlassCard(
          child: Column(
            children: [
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _shimmerOverlay(color, base),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _shimmerCircle(32, color, base),
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: _shimmerCircle(32, color, base),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _shimmerOverlay(color, base),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _shimmerOverlay(color, base),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 22,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: _shimmerOverlay(color, base),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerCircle(double size, Color color, Color base) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: base,
        border: Border.all(color: AppColors.backgroundCard, width: 2),
      ),
      child: _shimmerOverlay(color, base),
    );
  }

  Widget _shimmerOverlay(Color color, Color base) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: color.withValues(alpha: 0.25),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    );
  }
}

class _NotificationToggleRow extends StatefulWidget {
  const _NotificationToggleRow({required this.icon, required this.label, this.subtitle, required this.value, required this.onChanged});

  final String icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_NotificationToggleRow> createState() => _NotificationToggleRowState();
}

class _NotificationToggleRowState extends State<_NotificationToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(widget.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (widget.subtitle != null)
                  Text(widget.subtitle!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: _value,
            onChanged: (v) { setState(() => _value = v); widget.onChanged(v); },
            activeColor: AppColors.gradientEnd,
            activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatefulWidget {
  const _SettingsToggleRow({required this.label, required this.value, required this.locked, required this.onChanged});
  final String label;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  State<_SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<_SettingsToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(widget.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          if (widget.locked) const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Switch(
            value: _value,
            onChanged: widget.locked ? null : (v) { setState(() => _value = v); widget.onChanged(v); },
            activeColor: AppColors.gradientEnd,
            activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({required this.label, this.value, this.isDanger = false, required this.onTap});

  final String label;
  final String? value;
  final bool isDanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDanger ? Colors.red.shade400 : AppColors.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7))),
            Icon(Icons.chevron_right, size: 20, color: isDanger ? Colors.red.shade400 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 22,
            alignment: Alignment.center,
            child: Text(
              code.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded,
                size: 18, color: AppColors.gradientEnd),
        ],
      ),
    );
  }
}

class _FontSizeOption extends StatelessWidget {
  const _FontSizeOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final FontScaleLevel level;
  final bool selected;
  final VoidCallback onTap;

  String get _label {
    switch (level) {
      case FontScaleLevel.small:
        return 'settings.fontSize.small'.tr();
      case FontScaleLevel.medium:
        return 'settings.fontSize.medium'.tr();
      case FontScaleLevel.large:
        return 'settings.fontSize.large'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded,
                size: 18, color: AppColors.gradientEnd),
        ],
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(_icon, size: 20, color: AppColors.gradientEnd),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded,
                size: 18, color: AppColors.gradientEnd),
        ],
      ),
    );
  }
}

// ─── RECOVER CONFIRMATION DIALOG ─────────────────────────────────────────────
class _RecoverConfirmDialog extends StatefulWidget {
  const _RecoverConfirmDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;

  @override
  State<_RecoverConfirmDialog> createState() => _RecoverConfirmDialogState();
}

class _RecoverConfirmDialogState extends State<_RecoverConfirmDialog>
    with TickerProviderStateMixin {
  late final AnimationController _healCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _comeTogether;
  late final Animation<double> _brighten;
  late final Animation<Color?> _colorTween;

  @override
  void initState() {
    super.initState();
    _healCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    // The two heart halves start 14 px apart and slide inward to meet.
    // Mirrors _UnlinkConfirmDialog's _breakApart (0 -> 14) in reverse.
    _comeTogether = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(parent: _healCtrl, curve: Curves.easeOutCubic),
    );
    // Subtle brighten from 0.65 -> 1.0 (reverse of unlink's 1 -> 0.65).
    _brighten = Tween<double>(begin: 0.65, end: 1).animate(
      CurvedAnimation(parent: _healCtrl, curve: Curves.easeOut),
    );
    // Muted greyish -> vibrant pink (reverse of unlink's pink -> greyish).
    _colorTween = ColorTween(
      begin: AppColors.textSecondary.withValues(alpha: 0.6),
      end: AppColors.gradientEnd,
    ).animate(CurvedAnimation(parent: _healCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _healCtrl.forward();
      if (!mounted) return;
      await _pulseCtrl.forward();
    });
  }

  @override
  void dispose() {
    _healCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: GlassCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: AnimatedBuilder(
                animation: Listenable.merge([_healCtrl, _pulseCtrl]),
                builder: (_, __) {
                  final t = _comeTogether.value;
                  final color =
                      _colorTween.value ?? AppColors.gradientEnd;
                  // Gentle scale pulse on the healed heart, centered.
                  final pulse = 1 +
                      (0.15 *
                          _pulseCtrl.value *
                          (1 - _pulseCtrl.value) *
                          4); // peaks at value=0.5
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(-t, 0),
                        child: Opacity(
                          opacity: _brighten.value,
                          child: Icon(
                            Icons.favorite,
                            size: 44,
                            color: color,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(t, 0),
                        child: Opacity(
                          opacity: _brighten.value,
                          child: Icon(
                            Icons.favorite_border,
                            size: 44,
                            color: color,
                          ),
                        ),
                      ),
                      if (_healCtrl.isCompleted)
                        Transform.scale(
                          scale: pulse,
                          child: const Icon(
                            Icons.favorite,
                            size: 44,
                            color: AppColors.gradientEnd,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'settings.recoverTitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'settings.recoverBody'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        side: const BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      'common.cancel'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: AppColors.pinkGlow(intensity: 10),
                    ),
                    child: TextButton(
                      onPressed: widget.onConfirm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(
                        'settings.recover'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

// ─── UNLINK CONFIRMATION DIALOG ────────────────────────────────────────────
class _UnlinkConfirmDialog extends StatefulWidget {
  const _UnlinkConfirmDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;

  @override
  State<_UnlinkConfirmDialog> createState() => _UnlinkConfirmDialogState();
}

class _UnlinkConfirmDialogState extends State<_UnlinkConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _breakApart;
  late final Animation<double> _fade;
  late final Animation<Color?> _colorTween;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _breakApart = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 1, end: 0.65).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _colorTween = ColorTween(
      begin: AppColors.gradientEnd,
      end: AppColors.textSecondary.withValues(alpha: 0.6),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: GlassCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _breakApart.value;
                  final color = _colorTween.value ?? AppColors.gradientEnd;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(-t, 0),
                        child: Opacity(
                          opacity: _fade.value,
                          child: Icon(
                            Icons.favorite,
                            size: 44,
                            color: color,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(t, 0),
                        child: Opacity(
                          opacity: _fade.value,
                          child: Icon(
                            Icons.favorite_border,
                            size: 44,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'settings.unlinkTitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'settings.unlinkBody'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gradientStart.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: AppColors.gradientEnd,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'settings.unlinkReassure'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        side: const BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      'common.cancel'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E8C), Color(0xFFD87093)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gradientEnd.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: widget.onConfirm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(
                        'settings.unlink'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

// ─── DELETE ACCOUNT CONFIRMATION DIALOG ──────────────────────────────────────
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({
    required this.onCancel,
    required this.onDeleted,
  });

  final VoidCallback onCancel;
  final Future<void> Function() onDeleted;

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _isDeleting = false;

  static const String _confirmWordVi = 'XÓA';
  static const String _confirmWordEn = 'DELETE';

  String get _confirmWord {
    final code = context.locale.languageCode;
    return code == 'vi' ? _confirmWordVi : _confirmWordEn;
  }

  bool get _confirmMatches =>
      _confirmCtrl.text.trim().toUpperCase() == _confirmWord.toUpperCase();

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (!_confirmMatches || _isDeleting) return;
    setState(() => _isDeleting = true);

    final error = await ref
        .read(deleteAccountControllerProvider.notifier)
        .deleteAccount();

    if (!mounted) return;

    if (error != null) {
      setState(() => _isDeleting = false);
      final code = context.locale.languageCode;
      String msg = error;
      final lowered = error.toLowerCase();
      if (lowered.contains('cancelled') || lowered.contains('canceled')) {
        msg = 'deleteAccount.errorCancelled'.tr();
      } else {
        msg = 'deleteAccount.errorGeneric'.tr();
      }
      // If the message we received hints at re-auth, give a clearer prompt.
      if (lowered.contains('requires-recent-login') ||
          lowered.contains('recent login') ||
          lowered.contains('reauthenticate')) {
        msg = code == 'vi'
            ? 'Để bảo mật, vui lòng đăng nhập lại bằng Google để tiếp tục.'
            : 'For your security, please sign in with Google again to continue.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    // Success — fire the caller-supplied callback (which pops the
    // dialog, signs out, and navigates to /login).
    await widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'settings.deleteAccountTitle'.tr(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'deleteAccount.warning'.tr(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gradientStart.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_outline,
                    size: 14,
                    color: AppColors.gradientEnd,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'deleteAccount.reassure'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'deleteAccount.confirmHint'
                  .tr(namedArgs: {'word': _confirmWord}),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCtrl,
              autofocus: true,
              enabled: !_isDeleting,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                hintText: _confirmWord,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
                filled: true,
                fillColor: AppColors.backgroundPrimary.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                    color: AppColors.gradientEnd,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isDeleting ? null : widget.onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        side: const BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      'common.cancel'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: (_confirmMatches && !_isDeleting) ? 1 : 0.45,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E8C), Color(0xFFD87093)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gradientEnd
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: (_confirmMatches && !_isDeleting)
                            ? _onConfirm
                            : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'common.delete'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isDeleting) ...[
              const SizedBox(height: 12),
              Text(
                'deleteAccount.inProgress'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
