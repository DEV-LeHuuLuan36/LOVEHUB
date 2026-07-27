import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../gamification/domain/entities/pet_entity.dart';
import '../../../gamification/presentation/providers/pet_providers.dart';
import '../../../gamification/presentation/widgets/rive_pet.dart';
import '../../../notifications/presentation/helpers/notify_partner_activity.dart';
import 'pet_outfit_screen.dart';
import 'pet_missions_screen.dart';

class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});

  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  final _rivePetKey = GlobalKey<RivePetState>();

  void _onPetTapped(PetEntity? pet) async {
    if (pet == null) return;
    final outcome = await ref.read(patControllerProvider.notifier).pat(pet.coupleId);
    if (!mounted) return;

    if (outcome == PatOutcome.awarded) {
      _rivePetKey.currentState?.triggerReaction();
      _showFloatingFeedback('+2 LP', Colors.amber);
    } else {
      _showFloatingFeedback('Max pats today (${PetEntity.maxPatPerDay}/${PetEntity.maxPatPerDay})', Colors.white54);
    }
  }

  void _showFloatingFeedback(String text, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  void _doFeed(PetEntity pet) {
    ref.read(feedPetControllerProvider.notifier).feed(pet.coupleId).then((ok) {
      if (!mounted) return;
      if (!ok) {
        final err = ref.read(feedPetControllerProvider);
        err.whenOrNull(error: (msg, _) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg.toString()),
                backgroundColor: const Color(0xFFE53935),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            );
          }
        });
      } else {
        if (mounted) {
          _rivePetKey.currentState?.triggerReaction();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('pet.fedSuccess'.tr()),
              backgroundColor: AppColors.onlineGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          );
          // Notify the partner that the pet was fed.
          final myUser = ref.read(authStateProvider).valueOrNull;
          final myName = myUser?.displayName ?? 'common.partner'.tr();
          notifyPartnerActivity(
            ref,
            title: 'LoveHub',
            message: '$myName fed your pet 🍖',
            data: {
              'type': 'pet',
              'coupleId': pet.coupleId,
              'fromUid': myUser?.uid,
            },
          );
        }
      }
    });
  }

  void _selectPet(PetEntity pet, PetType type) async {
    if (!pet.isTypeUnlocked(type)) {
      _showLockedSnackBar(type.unlockLevel);
      return;
    }
    if (pet.type == type) return;
    final ok = await ref.read(setPetTypeControllerProvider.notifier).setPetType(
      pet.coupleId,
      type,
      pet.unlockedPetTypes,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(setPetTypeControllerProvider);
      err.whenOrNull(error: (msg, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      });
    }
  }

  void _showLockedSnackBar(int level) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('pet.reachLevelToUnlock'.tr(args: ['$level'])),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(watchPetProvider);
    final feedState = ref.watch(feedPetControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: petAsync.when(
          data: (pet) => _PetContent(
            rivePetKey: _rivePetKey,
            pet: pet,
            feedState: feedState,
            onFeed: pet != null && pet.canFeed ? () => _doFeed(pet) : null,
            onPetTapped: pet != null ? () => _onPetTapped(pet) : null,
            onSelectPet: pet != null ? (type) => _selectPet(pet, type) : null,
          ),
          loading: () => _PetContent(
            rivePetKey: _rivePetKey,
            pet: null,
            feedState: feedState,
            onFeed: null,
            onPetTapped: null,
            onSelectPet: null,
          ),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _PetContent extends StatelessWidget {
  const _PetContent({
    required this.rivePetKey,
    required this.pet,
    required this.feedState,
    required this.onFeed,
    required this.onPetTapped,
    required this.onSelectPet,
  });

  final GlobalKey<RivePetState> rivePetKey;
  final PetEntity? pet;
  final AsyncValue<void> feedState;
  final VoidCallback? onFeed;
  final VoidCallback? onPetTapped;
  final void Function(PetType)? onSelectPet;

  @override
  Widget build(BuildContext context) {
    final currentType = pet?.type ?? PetType.cat;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _Header(
            lovePoints: pet?.lovePoints ?? 0,
            food: pet?.food ?? 0,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PetDisplayArea(
            rivePetKey: rivePetKey,
            currentType: currentType,
            onPetTapped: onPetTapped,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PetStatsCard(pet: pet),
          const SizedBox(height: AppSpacing.md),
          _PetSelector(
            pet: pet,
            onSelectPet: onSelectPet,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionButtons(
            pet: pet,
            feedState: feedState,
            onFeed: onFeed,
          ),
          const SizedBox(height: AppSpacing.md),
          const _RecentActivity(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.lovePoints, required this.food});

  final int lovePoints;
  final int food;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 40, height: 40),
        Expanded(
          child: Text(
            'pet.title'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.accentGold, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💕', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$lovePoints LP',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PetDisplayArea extends ConsumerStatefulWidget {
  const _PetDisplayArea({
    required this.rivePetKey,
    required this.currentType,
    required this.onPetTapped,
  });

  final GlobalKey<RivePetState> rivePetKey;
  final PetType currentType;
  final VoidCallback? onPetTapped;

  @override
  ConsumerState<_PetDisplayArea> createState() => _PetDisplayAreaState();
}

class _PetDisplayAreaState extends ConsumerState<_PetDisplayArea> {
  /// Bumped on each tap so we can drive a quick scale animation that
  /// gives the user visible feedback even when the underlying Rive
  /// State Machine has no inputs (see `RivePet.triggerReaction`).
  double _tapScale = 1.0;

  void _bumpTapTick() {
    setState(() => _tapScale = 0.94);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _tapScale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(watchPetProvider).valueOrNull;
    final level = pet?.level ?? 1;

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            _bumpTapTick();
            widget.onPetTapped?.call();
          },
          child: AnimatedScale(
            scale: _tapScale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: RivePet(
              key: widget.rivePetKey,
              petType: widget.currentType,
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  'Lv.$level',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1025),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PetStatsCard extends StatelessWidget {
  const _PetStatsCard({required this.pet});

  final PetEntity? pet;

  @override
  Widget build(BuildContext context) {
    final level = pet?.level ?? 1;
    final hp = pet?.hp ?? 0;
    final maxHp = PetEntity.maxHp;
    final expIntoLevel = pet?.expIntoLevel ?? 0;
    final expForLevel = pet?.expForThisLevel ?? 100;
    final food = pet?.food ?? 0;
    final typeName = pet?.type.displayName ?? 'home.pet.unknownName'.tr();

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(typeName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'Lv.$level',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1025)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _HpBar(current: hp, max: maxHp),
          const SizedBox(height: AppSpacing.sm),
          _ExpBar(expIntoLevel: expIntoLevel, expForLevel: expForLevel, level: level),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍖', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$food food', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  const _HpBar({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? current / max : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('❤️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('HP   $current / $max', style: AppTypography.labelMedium),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: const Color(0xFF66BB6A).withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpBar extends StatelessWidget {
  const _ExpBar({required this.expIntoLevel, required this.expForLevel, required this.level});

  final int expIntoLevel;
  final int expForLevel;
  final int level;

  @override
  Widget build(BuildContext context) {
    final fraction = level >= 10 ? 1.0 : (expForLevel > 0 ? expIntoLevel / expForLevel : 0.0);
    final label = level >= 10
        ? 'pet.expMax'.tr()
        : 'pet.expProgress'.tr(namedArgs: {'current': '$expIntoLevel', 'max': '$expForLevel'});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: const Color(0xFF9C27B0).withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({required this.pet, required this.onSelectPet});

  final PetEntity? pet;
  final void Function(PetType)? onSelectPet;

  @override
  Widget build(BuildContext context) {
    final currentType = pet?.type ?? PetType.cat;
    final unlocked = pet?.unlockedPetTypes ?? [PetType.cat];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            'pet.selectorLabel'.tr(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in PetType.values) ...[
                if (type != PetType.cat) const SizedBox(width: AppSpacing.sm),
                _PetOption(
                  type: type,
                  isSelected: currentType == type,
                  isLocked: !unlocked.contains(type),
                  unlockLevel: type.unlockLevel,
                  onTap: () => onSelectPet?.call(type),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PetOption extends StatelessWidget {
  const _PetOption({
    required this.type,
    required this.isSelected,
    required this.isLocked,
    required this.unlockLevel,
    required this.onTap,
  });

  final PetType type;
  final bool isSelected;
  final bool isLocked;
  final int unlockLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC2185B).withValues(alpha: 0.15)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? AppColors.gradientEnd
                : (isLocked ? AppColors.borderSubtle : AppColors.backgroundCard),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              isLocked ? '🔒' : _typeEmoji(type),
              style: TextStyle(fontSize: 32, color: isLocked ? Colors.white38 : null),
            ),
            const SizedBox(height: 4),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isLocked)
              Text(
                'pet.lockedLevel'.tr(args: ['$unlockLevel']),
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            if (!isLocked)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.gradientEnd : Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _typeEmoji(PetType t) => t.emoji;
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.pet, required this.feedState, required this.onFeed});

  final PetEntity? pet;
  final AsyncValue<void> feedState;
  final VoidCallback? onFeed;

  @override
  Widget build(BuildContext context) {
    final isFeeding = feedState.isLoading;
    final canFeed = pet?.canFeed ?? false;
    final food = pet?.food ?? 0;

    return Row(
      children: [
        Expanded(
          child: _FeedActionCard(
            canFeed: canFeed,
            food: food,
            isLoading: isFeeding,
            onTap: (canFeed && !isFeeding) ? onFeed : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionCard(
            emoji: '👗',
            label: 'pet.outfit'.tr(),
            borderColor: const Color(0xFFFFD54F),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PetOutfitScreen()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionCard(
            emoji: '📋',
            label: 'pet.missions'.tr(),
            borderColor: const Color(0xFF00897B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PetMissionsScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedActionCard extends StatelessWidget {
  const _FeedActionCard({
    required this.canFeed,
    required this.food,
    required this.isLoading,
    this.onTap,
  });

  final bool canFeed;
  final int food;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: canFeed && !isLoading ? AppColors.backgroundCard : AppColors.backgroundCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: canFeed && !isLoading ? const Color(0xFFC2185B) : AppColors.borderSubtle,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            if (isLoading)
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC2185B)),
              )
            else
              const Text('🍖', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              'pet.feed'.tr(),
              style: AppTypography.labelLarge.copyWith(
                color: canFeed && !isLoading ? const Color(0xFFC2185B) : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            _MiniChip(
              label: food > 0 ? 'pet.feedCost'.tr() : 'pet.noFood'.tr(),
              color: canFeed && !isLoading ? const Color(0xFFE53935) : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            _MiniChip(
              label: 'pet.feedReward'.tr(),
              color: canFeed && !isLoading ? const Color(0xFF43A047) : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.emoji, required this.label, required this.borderColor, required this.onTap});

  final String emoji;
  final String label;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.2), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(color: borderColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  static const _activities = [
    _ActivityItem(emoji: '💕', textKey: 'pet.activity.checkedIn', effect: '+10 LP', timeKey: 'common.timeAgo.hoursAgoShort', timeArg: '2'),
    _ActivityItem(emoji: '😊', textKey: 'pet.activity.happyMood', effect: '+15 LP bonus', timeKey: 'common.timeAgo.hoursAgoShort', timeArg: '5'),
    _ActivityItem(emoji: '🍖', textKey: 'pet.activity.fedPet', effect: '+1 food (streak)', timeKey: 'common.timeAgo.yesterday'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.recentActivity'.tr(), style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ..._activities.map((a) => _ActivityRow(activity: a)),
        ],
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.emoji,
    required this.textKey,
    required this.effect,
    required this.timeKey,
    this.timeArg,
  });
  final String emoji;
  final String textKey;
  final String effect;
  final String timeKey;
  final String? timeArg;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final _ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final timeText = activity.timeArg == null
        ? activity.timeKey.tr()
        : activity.timeKey.tr(args: [activity.timeArg!]);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Center(child: Text(activity.emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(activity.textKey.tr(), style: AppTypography.bodyMedium),
                    const SizedBox(width: 6),
                    Text('\u2192 ${activity.effect}', style: AppTypography.bodySmall.copyWith(color: AppColors.onlineGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(timeText, style: AppTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
