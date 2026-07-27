import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../notifications/presentation/helpers/notify_partner_activity.dart';
import '../../domain/entities/streak_entity.dart';
import '../providers/streak_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import 'streak_history_screen.dart';
import '../../../../shared/widgets/user_avatar.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(watchStreakProvider);
    final checkInState = ref.watch(checkInControllerProvider);
    final recoverState = ref.watch(useRecoveryTokenControllerProvider);
    final bgState = ref.watch(checkinBackgroundControllerProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final coupleId = ref.watch(currentCoupleIdProvider);
    final bgAsync = ref.watch(watchCheckinBackgroundProvider);
    final bgUrl = bgAsync.valueOrNull;

    final canEditBg = coupleId != null && authUser != null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 0) Base dark→purple gradient — sits under everything so
            //    the screen always feels like it belongs to the same
            //    home-screen visual world, even without a custom
            //    background photo.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundPrimary, // 0xFF0D0812 — black
                      Color(0xFF1A0A2E),            // dark purple
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // 1) Background image (or fall back to the gradient above).
            if (bgUrl != null && bgUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: bgUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 250),
                  placeholder: (_, __) => const ColoredBox(
                    color: AppColors.backgroundPrimary,
                  ),
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: AppColors.backgroundPrimary,
                  ),
                ),
              ),
            // 2) Scrim — keeps the white cards / text readable over
            //    any photo. A vertical gradient feels softer than a
            //    flat 50% black.
            if (bgUrl != null && bgUrl.isNotEmpty)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99000000), // top: 60% black
                        Color(0xB3000000), // middle: 70% black
                        Color(0xE6000000), // bottom: 90% black
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            // 3) Foreground content. The existing SingleChildScrollView
            //    with all the cards sits on top of the scrim.
            streakAsync.when(
              data: (streak) => _StreakContent(
                entity: streak,
                authUser: authUser,
                partner: partner,
                checkInState: checkInState,
                recoverState: recoverState,
                bgState: bgState,
                bgUrl: bgUrl,
                onCheckIn: streak != null && authUser != null && partner != null
                    ? () => _doCheckIn(streak, authUser.uid, partner.uid)
                    : null,
                onRecover: streak != null && authUser != null && partner != null
                    ? () => _doRecover(streak, authUser.uid, partner.uid)
                    : null,
                onPickBackground: canEditBg ? _pickBackground : null,
                onRemoveBackground:
                    canEditBg && bgUrl != null ? _removeBackground : null,
              ),
              loading: () => _StreakContent(
                entity: null,
                authUser: authUser,
                partner: partner,
                checkInState: checkInState,
                recoverState: recoverState,
                bgState: bgState,
                bgUrl: bgUrl,
                onCheckIn: null,
                onRecover: null,
                onPickBackground: canEditBg ? _pickBackground : null,
                onRemoveBackground:
                    canEditBg && bgUrl != null ? _removeBackground : null,
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackground() async {
    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    debugPrint('CHK_BG_DBG: open image picker');
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null) {
      debugPrint('CHK_BG_DBG: user cancelled picker');
      return;
    }
    if (!mounted) return;
    _showUploadingSheet();
    final err = await ref
        .read(checkinBackgroundControllerProvider.notifier)
        .setBackground(coupleId: coupleId, image: File(picked.path));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss sheet
    if (err != null) {
      debugPrint('CHK_BG_DBG: upload failed: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkin.background.uploadFailed'.tr(namedArgs: {'error': '$err'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }
    debugPrint('CHK_BG_DBG: upload ok — stream will refresh');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('checkin.background.uploadSuccess'.tr()),
        backgroundColor: AppColors.onlineGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Future<void> _removeBackground() async {
    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    final err = await ref
        .read(checkinBackgroundControllerProvider.notifier)
        .removeBackground(coupleId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkin.background.removeFailed'.tr(namedArgs: {'error': '$err'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('checkin.background.removeSuccess'.tr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  /// Shows a small "Uploading…" sheet while the Cloudinary request
  /// is in flight. `_pickBackground` pops it once the request
  /// settles. We use a modal so the user can't tap the back-arrow
  /// mid-upload and lose their context.
  void _showUploadingSheet() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.gradientEnd,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'checkin.background.uploading'.tr(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _doCheckIn(StreakEntity entity, String myUid, String partnerId) async {
    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    final err = await ref.read(checkInControllerProvider.notifier).checkIn(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
    if (!mounted) return;
    if (err != null) {
      // Surface the failure so the user knows it didn't land.
      debugPrint('CHECKIN_DBG: _doCheckIn failed: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkin.checkinFailed'.tr(namedArgs: {'error': '$err'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }
    // Success: brief visual confirmation. The avatar / button reflect
    // the new state as soon as the Firestore stream re-emits.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('checkin.checked'.tr()),
        backgroundColor: AppColors.onlineGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
    // Notify the partner that this user just checked in.
    final me = ref.read(authStateProvider).valueOrNull;
    final myName = me?.displayName ?? 'common.partner'.tr();
    notifyPartnerActivity(
      ref,
      title: 'LoveHub',
      message: '$myName just checked in 💕',
      data: {
        'type': 'checkin',
        'coupleId': coupleId,
        'fromUid': myUid,
      },
    );
  }

  void _doRecover(StreakEntity entity, String myUid, String partnerId) {
    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    ref.read(useRecoveryTokenControllerProvider.notifier).useRecoveryToken(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
  }
}

// ─── CONTENT WRAPPER ──────────────────────────────────────────────────────────
class _StreakContent extends StatelessWidget {
  const _StreakContent({
    required this.entity,
    required this.authUser,
    required this.partner,
    required this.checkInState,
    required this.recoverState,
    required this.bgState,
    required this.bgUrl,
    required this.onCheckIn,
    required this.onRecover,
    required this.onPickBackground,
    required this.onRemoveBackground,
  });

  final StreakEntity? entity;
  final dynamic authUser;
  final dynamic partner;
  final AsyncValue<void> checkInState;
  final AsyncValue<void> recoverState;
  final AsyncValue<void> bgState;
  final String? bgUrl;
  final VoidCallback? onCheckIn;
  final VoidCallback? onRecover;
  final VoidCallback? onPickBackground;
  final VoidCallback? onRemoveBackground;

  @override
  Widget build(BuildContext context) {
    final meInitials = _initials(authUser?.displayName ?? authUser?.email ?? 'Y');
    final partnerInitials = _initials(partner?.displayName ?? 'P');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _Header(
            onPickBackground: onPickBackground,
            onRemoveBackground: onRemoveBackground,
            hasCustomBackground: bgUrl != null,
            isUploading: bgState.isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),
          _StreakHero(
            entity: entity,
            authUser: authUser,
          ),
          const SizedBox(height: AppSpacing.md),
          _RecoveryTokensCard(entity: entity),
          const SizedBox(height: AppSpacing.md),
          _Last7DaysRow(
            entity: entity,
            myUid: authUser?.uid,
            partnerId: entity?.partnerId,
            onViewAll: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StreakHistoryScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CheckinSection(
            entity: entity,
            myInitials: meInitials,
            partnerInitials: partnerInitials,
            myPhotoUrl: authUser?.photoUrl,
            partnerPhotoUrl: partner?.photoUrl,
            myLabel: authUser?.displayName ?? 'common.you'.tr(),
            partnerLabel: partner?.displayName ?? 'common.partner'.tr(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (entity?.status == StreakStatus.broken)
            _RecoverySection(
              entity: entity!,
              onRecover: onRecover,
              onCheckIn: onCheckIn,
            ),
          if (entity?.status != StreakStatus.broken) ...[
            const SizedBox(height: AppSpacing.lg),
            _CheckinCTA(
              entity: entity,
              checkInState: checkInState,
              onCheckIn: onCheckIn,
            ),
            const SizedBox(height: AppSpacing.md),
            _MotivationalText(entity: entity),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── SECTION 1: HEADER ───────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.onPickBackground,
    required this.onRemoveBackground,
    required this.hasCustomBackground,
    required this.isUploading,
  });

  final VoidCallback? onPickBackground;
  final VoidCallback? onRemoveBackground;
  final bool hasCustomBackground;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
          ),
        ),
        Expanded(
          child: Text(
            'checkin.title'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium,
          ),
        ),
        // Right-side action: change / remove the background image.
        // While an upload is in flight we show a small spinner
        // instead of the icon so the user knows the request is
        // running.
        _BackgroundMenuButton(
          hasCustomBackground: hasCustomBackground,
          isUploading: isUploading,
          onPick: onPickBackground,
          onRemove: onRemoveBackground,
        ),
      ],
    );
  }
}

class _BackgroundMenuButton extends StatelessWidget {
  const _BackgroundMenuButton({
    required this.hasCustomBackground,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  final bool hasCustomBackground;
  final bool isUploading;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (onPick == null) {
      return const SizedBox(width: 40);
    }
    if (isUploading) {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gradientEnd,
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: hasCustomBackground
              ? AppColors.gradientEnd
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: PopupMenuButton<_BgAction>(
        tooltip: 'checkin.background.changeBgTooltip'.tr(),
        position: PopupMenuPosition.under,
        color: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        onSelected: (action) {
          switch (action) {
            case _BgAction.change:
              onPick?.call();
              break;
            case _BgAction.remove:
              onRemove?.call();
              break;
          }
        },
        itemBuilder: (ctx) => <PopupMenuEntry<_BgAction>>[
          PopupMenuItem<_BgAction>(
            value: _BgAction.change,
            child: Row(
              children: [
                const Icon(Icons.image_outlined, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 10),
                Text(
                  'checkin.background.changeBackground'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (hasCustomBackground && onRemove != null)
            PopupMenuItem<_BgAction>(
              value: _BgAction.remove,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE57373)),
                  const SizedBox(width: 10),
                  Text(
                    'checkin.background.removeBackground'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: const Icon(
          Icons.image_outlined,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

enum _BgAction { change, remove }

// ─── SECTION 2: STREAK HERO ──────────────────────────────────────────────────
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.entity, required this.authUser});

  final StreakEntity? entity;
  final dynamic authUser;

  @override
  Widget build(BuildContext context) {
    final streak = entity?.currentStreak ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StreakHistoryScreen()),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 48)),
                const SizedBox(width: 8),
                _GoldGradientText(
                  '$streak',
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, height: 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: const Text(
                'days streak',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  'checkin.longestStreakPrefix'.tr(namedArgs: {'streak': '$streak'}),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.accentGold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldGradientText extends StatelessWidget {
  const _GoldGradientText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFFD700)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// ─── SECTION 3: RECOVERY TOKENS ─────────────────────────────────────────────
class _RecoveryTokensCard extends StatelessWidget {
  const _RecoveryTokensCard({required this.entity});

  final StreakEntity? entity;

  @override
  Widget build(BuildContext context) {
    final tokensAvailable = entity?.recoveryTokens ?? 0;
    const tokensMax = 4;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.xs),
              Text('checkin.recoveryTokens'.tr(), style: AppTypography.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(tokensMax, (i) {
              final filled = i < tokensAvailable;
              return Padding(
                padding: EdgeInsets.only(right: i < tokensMax - 1 ? AppSpacing.sm : 0),
                child: _ShieldIcon(filled: filled),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'checkin.tokensInfo'.tr(namedArgs: {
              'available': '$tokensAvailable',
              'max': '$tokensMax',
            }),
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'checkin.tokensUseRule'.tr(),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldIcon extends StatelessWidget {
  const _ShieldIcon({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: filled
            ? AppColors.accentGold.withValues(alpha: 0.15)
            : AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: filled ? AppColors.accentGold : AppColors.borderSubtle,
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.shield_rounded,
        color: filled
            ? AppColors.accentGold
            : AppColors.textSecondary.withValues(alpha: 0.4),
        size: 24,
      ),
    );
  }
}

// ─── SECTION 4: CALENDAR HEATMAP ────────────────────────────────────────────
class _Last7DaysRow extends StatelessWidget {
  const _Last7DaysRow({
    required this.entity,
    required this.myUid,
    required this.partnerId,
    required this.onViewAll,
  });

  final StreakEntity? entity;
  final String? myUid;
  final String? partnerId;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final myId = myUid;
    final pId = partnerId;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅 ', style: TextStyle(fontSize: 18)),
              Text('checkin.last7Days'.tr(), style: AppTypography.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gradientEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'checkin.viewFullHistory'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(7, (i) {
              final date = today.subtract(Duration(days: 6 - i));
              final dateStr = _dateStr(date);
              final isToday = i == 6;
              final uids = entity?.checkins[dateStr] ?? const <String>{};
              final meOn = myId != null && uids.contains(myId);
              final partnerOn = pId != null && uids.contains(pId);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayCell(
                    weekday: _weekdayLabel(date.weekday),
                    day: date.day,
                    isToday: isToday,
                    meOn: meOn,
                    partnerOn: partnerOn,
                    past: date.isBefore(today),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          const _HeatmapLegend(),
        ],
      ),
    );
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _weekdayLabel(int weekday) {
    // DateTime.weekday: Monday=1..Sunday=7
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[(weekday - 1).clamp(0, 6)];
  }
}

enum _DayState { both, one, missed, today, future }

_DayState _resolveDayState({
  required bool meOn,
  required bool partnerOn,
  required bool isToday,
  required bool past,
}) {
  if (isToday) return _DayState.today;
  if (!past) return _DayState.future;
  if (meOn && partnerOn) return _DayState.both;
  if (meOn || partnerOn) return _DayState.one;
  return _DayState.missed;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.meOn,
    required this.partnerOn,
    required this.past,
  });

  final String weekday;
  final int day;
  final bool isToday;
  final bool meOn;
  final bool partnerOn;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final state = _resolveDayState(
      meOn: meOn,
      partnerOn: partnerOn,
      isToday: isToday,
      past: past,
    );

    final Color fill;
    switch (state) {
      case _DayState.both:
        fill = AppColors.gradientEnd.withValues(alpha: 0.25);
        break;
      case _DayState.one:
        fill = AppColors.gradientEnd.withValues(alpha: 0.12);
        break;
      case _DayState.missed:
        fill = AppColors.backgroundPrimary.withValues(alpha: 0.6);
        break;
      case _DayState.today:
        fill = AppColors.backgroundCard;
        break;
      case _DayState.future:
        fill = AppColors.backgroundCard.withValues(alpha: 0.4);
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekday,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: AppColors.gradientEnd, width: 2)
                  : null,
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: AppColors.gradientEnd.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _DayHeart(
                state: state,
                meOn: meOn,
                partnerOn: partnerOn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday
                ? AppColors.gradientEnd
                : AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Renders the on-brand heart symbol for a day in the last-7 strip.
///   * Both checked in      → filled pink/magenta heart
///   * Only one person      → muted-pink outline (half-heart)
///   * Missed               → grey, low-opacity broken heart
///   * Today / Future       → neutral dot so the cell still has a glyph
class _DayHeart extends StatelessWidget {
  const _DayHeart({
    required this.state,
    required this.meOn,
    required this.partnerOn,
  });

  final _DayState state;
  final bool meOn;
  final bool partnerOn;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DayState.both:
        return const Icon(
          Icons.favorite_rounded,
          size: 20,
          color: AppColors.gradientEnd,
        );
      case _DayState.one:
        return Icon(
          Icons.favorite_outline_rounded,
          size: 20,
          color: AppColors.gradientEnd.withValues(alpha: 0.55),
        );
      case _DayState.missed:
        return Icon(
          Icons.heart_broken_rounded,
          size: 18,
          color: AppColors.textSecondary.withValues(alpha: 0.35),
        );
      case _DayState.today:
        if (meOn || partnerOn) {
          return Icon(
            meOn && partnerOn
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            size: 20,
            color: AppColors.gradientEnd,
          );
        }
        return Icon(
          Icons.favorite_outline_rounded,
          size: 20,
          color: AppColors.textSecondary.withValues(alpha: 0.45),
        );
      case _DayState.future:
        return const SizedBox.shrink();
    }
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LegendHeart(
          icon: Icons.favorite_rounded,
          color: AppColors.gradientEnd,
        ),
        const SizedBox(width: 5),
        Text('checkin.legendBoth'.tr(), style: AppTypography.labelSmall),
        const SizedBox(width: AppSpacing.lg),
        const _LegendHeart(
          icon: Icons.favorite_outline_rounded,
          color: Color(0xFFE91E8C),
        ),
        const SizedBox(width: 5),
        Text('checkin.legendOne'.tr(), style: AppTypography.labelSmall),
        const SizedBox(width: AppSpacing.lg),
        const _LegendHeart(
          icon: Icons.heart_broken_rounded,
          color: Color(0xFF7A6E85),
        ),
        const SizedBox(width: 5),
        Text('checkin.legendMissed'.tr(), style: AppTypography.labelSmall),
      ],
    );
  }
}

class _LegendHeart extends StatelessWidget {
  const _LegendHeart({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 14, color: color);
  }
}

// ─── SECTION 5: TODAY CHECK-IN ───────────────────────────────────────────────
class _CheckinSection extends StatelessWidget {
  const _CheckinSection({
    required this.entity,
    required this.myInitials,
    required this.partnerInitials,
    required this.myPhotoUrl,
    required this.partnerPhotoUrl,
    required this.myLabel,
    required this.partnerLabel,
  });

  final StreakEntity? entity;
  final String myInitials;
  final String partnerInitials;
  final String? myPhotoUrl;
  final String? partnerPhotoUrl;
  final String myLabel;
  final String partnerLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text("Today's Check-In", style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: _CheckinCircle(
                  label: myLabel,
                  name: myLabel,
                  initials: myInitials,
                  photoUrl: myPhotoUrl,
                  checked: entity?.meCheckedToday ?? false,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(child: _HeartConnector()),
              const SizedBox(width: 8),
              Flexible(
                child: _CheckinCircle(
                  label: partnerLabel,
                  name: partnerLabel,
                  initials: partnerInitials,
                  photoUrl: partnerPhotoUrl,
                  checked: entity?.partnerCheckedToday ?? false,
                ),
              ),
            ],
          ),
          if (entity != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _StatusChip(entity: entity!),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entity});

  final StreakEntity entity;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (entity.status) {
      StreakStatus.active => ('checkin.statusActive'.tr(), AppColors.onlineGreen),
      StreakStatus.atRisk => ('checkin.statusAtRisk'.tr(), const Color(0xFFFFD54F)),
      StreakStatus.broken => ('checkin.statusBroken'.tr(), const Color(0xFFE53935)),
      StreakStatus.idle => ('checkin.statusIdle'.tr(), AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CheckinCircle extends StatefulWidget {
  const _CheckinCircle({
    required this.label,
    required this.name,
    required this.initials,
    required this.photoUrl,
    required this.checked,
  });

  final String label;
  final String name;
  final String initials;
  final String? photoUrl;
  final bool checked;

  @override
  State<_CheckinCircle> createState() => _CheckinCircleState();
}

class _CheckinCircleState extends State<_CheckinCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // If we mount already checked, play the pop once so the glow lands.
    if (widget.checked) _pop.forward();
  }

  @override
  void didUpdateWidget(covariant _CheckinCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition false→true: replay the pop. true→false: reset.
    if (widget.checked && !oldWidget.checked) {
      _pop.forward(from: 0);
    } else if (!widget.checked && oldWidget.checked) {
      _pop.reverse();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.checked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110, maxHeight: 110),
            child: AnimatedBuilder(
              animation: _pop,
              builder: (context, child) {
                // 0.0 → 1.0: scale up to 1.08, glow bright; settle back to 1.0
                final t = _pop.value;
                final scale = 1.0 + (0.08 * t);
                final glowAlpha = 0.25 + (0.55 * t);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!checked) const _PulsingRing(),
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.backgroundPrimary,
                          border: Border.all(
                            color: checked
                                ? AppColors.gradientEnd
                                : AppColors.borderSubtle,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gradientEnd
                                  .withValues(alpha: glowAlpha),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.5),
                          child: UserAvatar(
                            photoUrl: widget.photoUrl,
                            name: widget.name,
                            size: double.infinity,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (checked)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.gradientEnd,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.backgroundCard,
                              width: 2,
                            ),
                            boxShadow: AppColors.pinkGlow(intensity: 6),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          checked ? '${widget.label} \u2713' : '${widget.label} \u2764\ufe0f',
          style: AppTypography.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.gradientEnd.withValues(alpha: _animation.value),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

class _HeartConnector extends StatefulWidget {
  const _HeartConnector();

  @override
  State<_HeartConnector> createState() => _HeartConnectorState();
}

class _HeartConnectorState extends State<_HeartConnector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1.5, width: 10, color: AppColors.borderSubtle),
        const SizedBox(width: 4),
        ScaleTransition(
          scale: _scale,
          child: const Text(
            '\u2764\ufe0f',
            style: TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(width: 4),
        Container(height: 1.5, width: 10, color: AppColors.borderSubtle),
      ],
    );
  }
}

// ─── SECTION 6: CTA ──────────────────────────────────────────────────────────
class _CheckinCTA extends StatelessWidget {
  const _CheckinCTA({
    required this.entity,
    required this.checkInState,
    required this.onCheckIn,
  });

  final StreakEntity? entity;
  final AsyncValue<void> checkInState;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final alreadyChecked = entity?.meCheckedToday ?? false;
    final isLoading = checkInState.isLoading;
    final bothChecked = entity?.bothCheckedToday ?? false;

    return GestureDetector(
      onTap: alreadyChecked || isLoading ? null : () => onCheckIn?.call(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 56,
        decoration: BoxDecoration(
          gradient: alreadyChecked
              ? LinearGradient(
                  colors: [
                    AppColors.onlineGreen.withValues(alpha: 0.7),
                    const Color(0xFF2E7D32),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
                ),
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: alreadyChecked ? null : AppColors.pinkGlow(intensity: 16),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  bothChecked
                      ? 'checkin.bothCheckedInLabel'.tr()
                      : alreadyChecked
                          ? 'checkin.alreadyCheckedInLabel'.tr()
                          : 'checkin.checkinNowLabel'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── SECTION 7: MOTIVATIONAL TEXT ────────────────────────────────────────────
class _MotivationalText extends StatelessWidget {
  const _MotivationalText({required this.entity});

  final StreakEntity? entity;

  @override
  Widget build(BuildContext context) {
    final text = switch (entity?.status) {
      StreakStatus.active => "You're both on fire! Keep the flame burning! ",
      StreakStatus.atRisk => "Waiting on your love \u2014 don't let it go cold! ",
      StreakStatus.broken => "The streak broke, but love never does \u2014 start again! ",
      _ => "Tap check-in and keep the chain alive! ",
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Text('🔥', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}

// ─── RECOVERY SECTION (shown when streak is broken) ──────────────────────────
// Converts to ConsumerStatefulWidget so it can:
//   - watch `recoverState` directly via ref.watch (not as a constructor
//     prop, which caused repeated callback registration on every rebuild).
//   - guard snackbars with a `_snackbarShown` flag so they fire at most once.
//   - always show a normal "Check in now" button so the user can start a
//     fresh streak even when recovery tokens are exhausted.
class _RecoverySection extends ConsumerStatefulWidget {
  const _RecoverySection({
    required this.entity,
    required this.onRecover,
    required this.onCheckIn,
  });

  final StreakEntity entity;
  final VoidCallback? onRecover;
  final VoidCallback? onCheckIn;

  @override
  ConsumerState<_RecoverySection> createState() => _RecoverySectionState();
}

class _RecoverySectionState extends ConsumerState<_RecoverySection> {
  // BUG 2 fix: guard so the snackbar for recovery success fires at most
  // once per time the widget is mounted — not on every rebuild.
  bool _recoverSuccessSnackbarShown = false;
  bool _recoverErrorSnackbarShown = false;

  @override
  Widget build(BuildContext context) {
    // Watch the providers directly so this widget rebuilds reactively,
    // and the callbacks below are registered exactly once per mount
    // (on the initial build after the StatefulWidget is inserted).
    final recoverState = ref.watch(useRecoveryTokenControllerProvider);
    final checkInState = ref.watch(checkInControllerProvider);

    // ── Recovery success snackbar (guarded by _recoverSuccessSnackbarShown) ──
    recoverState.whenData((_) {
      if (_recoverSuccessSnackbarShown) return;
      _recoverSuccessSnackbarShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'checkin.streakRecovered'.tr(
                namedArgs: {'days': '${widget.entity.streakBeforeBreak}'},
              ),
            ),
            backgroundColor: AppColors.onlineGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      });
    });

    // ── Recovery error snackbar (guarded by _recoverErrorSnackbarShown) ──────
    recoverState.when(
      data: (_) {},
      loading: () {},
      error: (msg, _) {
        if (_recoverErrorSnackbarShown) return;
        _recoverErrorSnackbarShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.toString()),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          );
        });
      },
    );

    final canRecover = widget.entity.canRecover;
    final isRecoverLoading = recoverState.isLoading;
    final isCheckInLoading = checkInState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Column(
            children: [
              const Text('💔', style: TextStyle(fontSize: 48)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'checkin.streakBroken'.tr(),
                style: AppTypography.titleMedium.copyWith(
                  color: const Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'checkin.previousStreak'.tr(
                  namedArgs: {'days': '${widget.entity.streakBeforeBreak}'},
                ),
                style: AppTypography.bodySmall,
              ),
              if (!canRecover && widget.entity.recoveryTokens == 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'checkin.noTokensToRecover'.tr(),
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ),
              if (!canRecover && widget.entity.brokenAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '48 hours have passed',
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // BUG 1 fix: always show the normal check-in button so the user
        // can start a fresh streak even when they have 0 recovery tokens.
        // The check-in flow naturally resets the broken state — a subsequent
        // check-in (when both partners check in) makes the streak = 1.
        if (widget.onCheckIn != null) ...[
          const SizedBox(height: AppSpacing.md),
          _BrokenCheckinCTA(
            isLoading: isCheckInLoading,
            onTap: () => widget.onCheckIn?.call(),
          ),
        ],

        if (canRecover) ...[
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: isRecoverLoading ? null : () => widget.onRecover?.call(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              decoration: BoxDecoration(
                gradient: isRecoverLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                color: isRecoverLoading ? AppColors.textSecondary : null,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: isRecoverLoading
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: Center(
                child: isRecoverLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '↩ Use token to recover streak (${widget.entity.streakBeforeBreak} days)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A normal "Check in now" button shown inside the broken-streak card.
/// Identical visual treatment to the regular _CheckinCTA so the user
/// knows it's the same action — they can always start a fresh streak.
class _BrokenCheckinCTA extends StatelessWidget {
  const _BrokenCheckinCTA({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppColors.pinkGlow(intensity: 16),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'checkin.checkinNowLabel'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
