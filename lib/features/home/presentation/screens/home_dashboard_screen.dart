import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_text.dart';
import '../../../pet/presentation/screens/pet_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../ai/presentation/screens/ai_conversations_screen.dart';
import '../../../diary/presentation/screens/diary_screen.dart';
import '../../../mood/presentation/screens/mood_screen.dart';
import '../../../location/presentation/screens/couple_map_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/screens/profile_screen.dart';
import '../../../notifications/presentation/providers/inbox_providers.dart';
import '../../../notifications/presentation/screens/notification_inbox_screen.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../couple/domain/entities/love_duration.dart';
import '../../../mood/domain/entities/mood_entry.dart';
import '../../../mood/presentation/providers/mood_providers.dart';
import '../../../presence/domain/entities/presence.dart';
import '../../../presence/presentation/providers/presence_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/notification_providers.dart';
import '../../../streak/presentation/providers/streak_providers.dart';
import '../../../gamification/presentation/providers/pet_providers.dart';
import '../../../gamification/domain/entities/pet_entity.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../services/widget_service.dart';
import '../widgets/lovehub_bottom_nav.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    // Lazily clean up expired unlinks on app open
    ref.read(autoFinalizeUnlinkProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _navIndex,
                children: [
                  _HomeContent(
                    onPetTap: () => setState(() => _navIndex = 2),
                    onMapTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CoupleMapScreen()),
                    ),
                    onMoodTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MoodScreen()),
                    ),
                  ),
                  const DiaryScreen(),
                  const PetScreen(),
                  const FinanceScreen(),
                  const AIConversationsScreen(),
                ],
              ),
            ),
            LoveHubBottomNav(
              currentIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME CONTENT ─────────────────────────────────────────────────────────────
class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.onPetTap,
    required this.onMapTap,
    required this.onMoodTap,
  });

  final VoidCallback onPetTap;
  final VoidCallback onMapTap;
  final VoidCallback onMoodTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleId = ref.watch(currentCoupleIdProvider);
    final coupleAsync = coupleId != null ? ref.watch(watchCoupleProvider(coupleId)) : null;
    final couple = coupleAsync?.valueOrNull;
    final isPending = couple?.isPendingUnlink == true;
    final daysLeft = couple?.daysLeftToRecover ?? 0;

    // Push to the home-screen widget whenever the counter changes
    ref.listen(loveDurationProvider, (prev, next) {
      if (next == null) return;
      final authUser = ref.read(authStateProvider).valueOrNull;
      final partnerProfile = ref.read(partnerProfileProvider).valueOrNull;
      final yourName = authUser?.displayName ?? '';
      final partnerName = partnerProfile?.displayName ?? 'common.partner'.tr();
      final names = couple != null ? '$yourName & $partnerName' : '';
      WidgetService.updateLoveWidget(days: next.days, names: names);
    });

    // Cache startDate + names + notifEnabled to SharedPreferences for the
    // WorkManager background task (Firebase-free).
    ref.watch(loveCounterBackgroundCacheProvider);
    // Also push foreground notification updates when the counter changes.
    ref.watch(loveCounterNotificationUpdaterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const _TopBar(),
          const SizedBox(height: AppSpacing.lg),

          // Recovery banner — shown when unlink is pending
          if (isPending) ...[
            _RecoveryBanner(daysLeft: daysLeft),
            const SizedBox(height: AppSpacing.md),
          ],

          const _CoupleHero(),
          const SizedBox(height: AppSpacing.md),
          const _DayCounterCard(),
          const SizedBox(height: AppSpacing.md),
          const _StatsRow(),
          const SizedBox(height: AppSpacing.md),
          _PetPreviewCard(onTap: onPetTap),
          const SizedBox(height: AppSpacing.md),
          _QuickActions(onMapTap: onMapTap, onMoodTap: onMoodTap),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── 1. TOP BAR ──────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final name = authUser?.displayName ?? authUser?.email ?? '';
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              border: Border.all(color: AppColors.borderSubtle, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: UserAvatar(
                photoUrl: authUser?.photoUrl,
                name: name,
                size: double.infinity,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: GradientText('home.title'.tr()),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
          ),
          child: _BellWithBadge(),
        ),
      ],
    );
  }
}

// ─── BELL WITH BADGE ─────────────────────────────────────────────────────────
class _BellWithBadge extends ConsumerWidget {
  const _BellWithBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationUnreadCountProvider);

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundCard,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 2. COUPLE HERO ───────────────────────────────────────────────────────────
class _CoupleHero extends ConsumerWidget {
  const _CoupleHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partner = partnerProfile.valueOrNull;
    final partnerPresence = ref.watch(partnerPresenceProvider);
    final presence = partnerPresence.valueOrNull ?? Presence.offline;
    // Live-tied: any save by either partner causes this stream to
    // re-emit, which rebuilds the bubbles below.
    final dailyAsync = ref.watch(watchTodayMoodProvider);
    final daily = dailyAsync.valueOrNull;

    final yourName = authUser?.displayName ?? authUser?.email ?? '';
    final partnerName = partner?.displayName ?? partner?.email ?? '';
    final yourInitial = UserAvatar.displayName(yourName);
    final partnerInitial = UserAvatar.displayName(partnerName);

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Your avatar + left-aligned mood bubble.
          _AvatarWithMoodBubble(
            avatar: UserAvatar(
              photoUrl: authUser?.photoUrl,
              name: yourName,
              size: AppRadius.avatarLarge,
            ),
            entry: daily?.mine,
            isMine: true,
            fallbackName:
                yourInitial.isNotEmpty ? yourInitial : 'common.you'.tr(),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Partner avatar + right-aligned mood bubble.
          partnerProfile.when(
            data: (_) => _AvatarWithMoodBubble(
              avatar: UserAvatar(
                photoUrl: partner?.photoUrl,
                name: partnerName,
                size: AppRadius.avatarLarge,
              ),
              entry: daily?.partner,
              isMine: false,
              fallbackName: partnerInitial.isNotEmpty
                  ? partnerInitial
                  : 'common.partner'.tr(),
            ),
            loading: () => _AvatarWithMoodBubble(
              avatar: UserAvatar(
                photoUrl: null,
                name: partnerName.isNotEmpty ? partnerName : '?',
                size: AppRadius.avatarLarge,
              ),
              entry: null,
              isMine: false,
              fallbackName: '?',
            ),
            error: (_, __) => _AvatarWithMoodBubble(
              avatar: UserAvatar(
                photoUrl: null,
                name: partnerInitial.isNotEmpty ? partnerInitial : '?',
                size: AppRadius.avatarLarge,
              ),
              entry: null,
              isMine: false,
              fallbackName: partnerInitial.isNotEmpty ? partnerInitial : '?',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _OnlineIndicator(
            presence: presence,
            yourName: yourInitial,
            partnerName: partnerInitial,
            isPartnerLoading: partnerProfile.isLoading,
          ),
        ],
      ),
    );
  }
}

/// Stacks an avatar with a small mood "feeling" bubble that
/// overlaps the avatar's inner edge. Left avatar's bubble points
/// right; right avatar's bubble points left, so the two bubbles
/// meet in the middle over the & symbol.
class _AvatarWithMoodBubble extends StatelessWidget {
  const _AvatarWithMoodBubble({
    required this.avatar,
    required this.entry,
    required this.isMine,
    required this.fallbackName,
  });

  final Widget avatar;
  final MoodEntry? entry;
  final bool isMine;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          // Outer side for left avatar (bubble to the right of the
          // avatar), inner side for right avatar (bubble to the left).
          // 6 px protrusion — meets the partner's bubble in the
          // middle of the inter-avatar gap without overlapping it.
          right: isMine ? -6 : null,
          left: !isMine ? -6 : null,
          bottom: -2,
          child: _MoodBubble(
            entry: entry,
            isMine: isMine,
            fallbackName: fallbackName,
          ),
        ),
      ],
    );
  }
}

/// A small chat-style bubble that shows the user's current mood.
///
/// Visual states:
///   * Has mood: rounded pill with the mood emoji, slight shadow,
///     small accent dot in the lower-corner color of the matching
///     "you vs partner" style. Tapping shows a small bottom sheet
///     with the label + note.
///   * No mood: faded "·" inside a transparent pill, so the slot
///     is visible without distracting from the avatar.
///   * Loading: tiny inline spinner.
class _MoodBubble extends StatelessWidget {
  const _MoodBubble({
    required this.entry,
    required this.isMine,
    required this.fallbackName,
  });

  final MoodEntry? entry;
  final bool isMine;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final hasMood = entry != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMoodSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasMood
                ? AppColors.backgroundPrimary
                : AppColors.backgroundCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: hasMood
                  ? (isMine ? AppColors.gradientEnd : AppColors.onlineGreen)
                  : AppColors.borderSubtle,
              width: hasMood ? 1.5 : 1,
            ),
            boxShadow: hasMood
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: hasMood
                ? Text(
                    entry!.emoji,
                    style: const TextStyle(fontSize: 18, height: 1),
                  )
                : Text(
                    '·',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showMoodSheet(BuildContext context) {
    final has = entry != null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.gradientEnd : AppColors.onlineGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$fallbackName's mood",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (has) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(entry!.emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry!.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry!.note != null && entry!.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '"${entry!.note}"',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ] else
                Text(
                  'home.moodBubble.noMood'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineIndicator extends StatelessWidget {
  const _OnlineIndicator({
    required this.presence,
    required this.yourName,
    required this.partnerName,
    required this.isPartnerLoading,
  });

  final Presence presence;
  final String yourName;
  final String partnerName;
  final bool isPartnerLoading;

  @override
  Widget build(BuildContext context) {
    final isOnline = presence.isOnline;
    final lastSeenText = presence.relativeLastSeen();

    String namesLabel;
    if (isPartnerLoading) {
      namesLabel = 'common.loading'.tr();
    } else if (yourName.isNotEmpty && partnerName.isNotEmpty) {
      namesLabel = '$yourName & $partnerName';
    } else if (yourName.isNotEmpty) {
      namesLabel = '${'common.you'.tr()} & ${'common.partner'.tr()}';
    } else {
      namesLabel = '${'common.you'.tr()} & ${'common.partner'.tr()}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppRadius.onlineDot,
              height: AppRadius.onlineDot,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.onlineGreen : AppColors.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.backgroundCard, width: 2),
                boxShadow: isOnline
                    ? [BoxShadow(color: AppColors.onlineGreen.withValues(alpha: 0.5), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnline
                  ? 'checkin.status_active'.tr()
                  : 'checkin.status_offline'.tr(),
              style: AppTypography.labelSmall.copyWith(
                color: isOnline ? AppColors.onlineGreen : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (!isOnline && lastSeenText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'checkin.active_time'.tr(namedArgs: {'time': lastSeenText}),
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ),
        ],
        const SizedBox(height: 4),
        Text(namesLabel, style: AppTypography.headlineMedium),
      ],
    );
  }
}

// ─── 3. DAY COUNTER CARD ─────────────────────────────────────────────────────
class _DayCounterCard extends ConsumerWidget {
  const _DayCounterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleId = ref.watch(currentCoupleIdProvider);

    // No coupleId → prompt to link
    if (coupleId == null) {
      return _DayCounterPrompt(onTap: () => context.go(AppRoutes.linking));
    }

    // Watch couple doc for loading/error state
    final coupleAsync = ref.watch(watchCoupleProvider(coupleId));

    return coupleAsync.when(
      data: (couple) {
        // startDate not yet set → show prompt
        if (couple == null || couple.startDate == null) {
          return _DayCounterPrompt(onTap: () => _showDatePicker(context, ref, coupleId));
        }
        // Live counter — loveDurationProvider recomputes every second via ticker
        final duration = ref.watch(loveDurationProvider);
        return _DayCounterLive(duration: duration, coupleId: coupleId);
      },
      loading: () => const _DayCounterShimmer(),
      error: (_, __) => _DayCounterPrompt(onTap: () => _showDatePicker(context, ref, coupleId)),
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref, String coupleId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
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

    if (picked != null) {
      final success = await ref
          .read(updateStartDateControllerProvider.notifier)
          .setStartDate(coupleId, picked);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.errors.cannotUpdateDate'.tr())),
        );
      }
    }
  }
}

class _DayCounterPrompt extends StatelessWidget {
  const _DayCounterPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gradientEnd.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.favorite_border_rounded, size: 40, color: AppColors.gradientEnd),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'home.anniversaryPrompt.title'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'home.anniversaryPrompt.subtitle'.tr(),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCounterShimmer extends StatelessWidget {
  const _DayCounterShimmer();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 160,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCounterLive extends ConsumerWidget {
  const _DayCounterLive({required this.duration, required this.coupleId});

  final LoveDuration? duration;
  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-watch ticker to get live updates every second
    ref.watch(tickerProvider);

    final days = duration?.days ?? 0;
    final hhmmss = duration?.hhmmss ?? '00:00:00';

    return GestureDetector(
      onTap: () => _showDatePicker(context, ref),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        child: Column(
          children: [
            GradientText(
              '$days',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, height: 1),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _DaysTogetherLabel(),
            const SizedBox(height: AppSpacing.xs),
            // Live hhmmss counter
            Text(
              hhmmss,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.gradientEnd,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'home.tapToChangeDate'.tr(),
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: duration?.days ?? 0)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
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

    if (picked != null) {
      final success = await ref
          .read(updateStartDateControllerProvider.notifier)
          .setStartDate(coupleId, picked);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.errors.cannotUpdateDate'.tr())),
        );
      }
    }
  }
}

// ─── RECOVERY BANNER ───────────────────────────────────────────────────────────
class _RecoveryBanner extends ConsumerWidget {
  const _RecoveryBanner({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecovering = ref.watch(unlinkControllerProvider).isLoading;

    return Container(
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
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('💔', style: TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'home.recoveryBanner.title'.tr(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'home.recoveryBanner.subtitle'.tr(namedArgs: {'days': '$daysLeft'}),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
              ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isRecovering ? null : () async {
              final coupleId = ref.read(currentCoupleIdProvider);
              if (coupleId == null) return;
              final ok = await ref.read(unlinkControllerProvider.notifier).recover(coupleId: coupleId);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('settings.errors.cannotRecover'.tr())),
                );
              }
            },
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
                        const Text('↩', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('home.recoveryBanner.recover'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysTogetherLabel extends StatelessWidget {
  const _DaysTogetherLabel();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        'home.daysTogether'.tr(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── 4. STATS ROW ─────────────────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(watchStreakProvider);
    final streakValue = streakAsync.valueOrNull?.currentStreak;
    final petAsync = ref.watch(watchPetProvider);
    final lovePoints = petAsync.valueOrNull?.lovePoints ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            emoji: '🔥',
            value: streakValue != null ? '$streakValue' : '--',
            label: 'home.stats.streak'.tr(),
            onTap: () => context.push(AppRoutes.streak),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _StatCard(
            emoji: '💕',
            value: petAsync.valueOrNull != null ? '$lovePoints' : '--',
            label: 'home.stats.lovePoints'.tr(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _StatCard(
            emoji: '🛡️',
            value: streakValue != null
                ? '${streakAsync.valueOrNull?.recoveryTokens ?? 0}/4'
                : '--',
            label: 'home.stats.tokens'.tr(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String emoji;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ─── 5. PET PREVIEW CARD ──────────────────────────────────────────────────────
class _PetPreviewCard extends ConsumerWidget {
  const _PetPreviewCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(watchPetProvider);
    final pet = petAsync.valueOrNull;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _PetAvatar(pet: pet),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _PetInfo(pet: pet)),
          ],
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.pet});

  final dynamic pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: AppColors.pinkGlow(intensity: 6),
      ),
      child: Center(
        child: Text(pet?.type?.emoji ?? '🐱', style: const TextStyle(fontSize: 40)),
      ),
    );
  }
}

class _PetInfo extends StatelessWidget {
  const _PetInfo({required this.pet});

  final dynamic pet;

  String get _levelText =>
      pet != null ? 'Lv.${pet.level}' : 'home.pet.levelUnknown'.tr();
  String get _hpText =>
      pet != null ? '${pet.hp}/${PetEntity.maxHp}' : 'home.pet.hpUnknown'.tr();

  @override
  Widget build(BuildContext context) {
    final hpFraction = pet != null ? pet.hp / PetEntity.maxHp : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${pet?.type.displayName ?? 'home.pet.unknownName'.tr()} ',
                style: AppTypography.titleLarge),
            Text(pet?.type.emoji ?? '🐱', style: const TextStyle(fontSize: 18)),
          ],
        ),
        Text(_levelText, style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        _HomeHpBar(hpFraction: hpFraction, hpText: _hpText),
      ],
    );
  }
}

class _HomeHpBar extends StatelessWidget {
  const _HomeHpBar({required this.hpFraction, required this.hpText});

  final double hpFraction;
  final String hpText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('home.pet.hpLabel'.tr(), style: AppTypography.labelSmall),
            Text(hpText, style: AppTypography.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: FractionallySizedBox(
              widthFactor: hpFraction.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.hpGradient,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onlineGreen.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 6. QUICK ACTIONS ───────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onMapTap, required this.onMoodTap});

  final VoidCallback onMapTap;
  final VoidCallback onMoodTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickActionButton(
          emoji: '📖',
          label: 'home.quickActions.diary'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DiaryScreen()),
          ),
        ),
        _QuickActionButton(
          emoji: '🗺️',
          label: 'home.quickActions.map'.tr(),
          onTap: onMapTap,
        ),
        _QuickActionButton(
          emoji: '😊',
          label: 'home.quickActions.mood'.tr(),
          onTap: onMoodTap,
        ),
        _QuickActionButton(
          emoji: '🤖',
          label: 'home.quickActions.ai'.tr(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AIConversationsScreen()),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppRadius.quickAction,
            height: AppRadius.quickAction,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.pinkGlow(intensity: 12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}
