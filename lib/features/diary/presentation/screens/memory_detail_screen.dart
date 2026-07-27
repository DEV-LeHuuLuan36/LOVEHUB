import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../domain/entities/memory.dart';
import '../providers/memory_providers.dart';

class MemoryDetailScreen extends ConsumerWidget {
  const MemoryDetailScreen({super.key, required this.memoryId});

  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(watchMemoriesProvider).valueOrNull ?? [];
    final memory = memories.where((m) => m.id == memoryId).firstOrNull;

    if (memory == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text('memory.notFound'.tr(), style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7))),
        ),
      );
    }

    final myUser = ref.watch(authStateProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final isAuthor = myUser?.uid == memory.authorUid;
    final authorName = isAuthor ? (myUser?.displayName ?? 'common.you'.tr()) : (partner?.displayName ?? 'common.partner'.tr());

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroPhotoSection(memory: memory),
              _ContentSection(memory: memory, authorName: authorName),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPhotoSection extends StatelessWidget {
  const _HeroPhotoSection({required this.memory});
  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: memory.photoUrls.isNotEmpty
              ? PageView.builder(
                  itemCount: memory.photoUrls.length,
                  itemBuilder: (context, i) {
                    return CachedNetworkImage(
                      imageUrl: memory.photoUrls[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.backgroundCard,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gradientEnd.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.backgroundCard,
                        child: const Center(child: Text('📸', style: TextStyle(fontSize: 64))),
                      ),
                    );
                  },
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.gradientEnd.withValues(alpha: 0.6), AppColors.gradientStart.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(child: Text('📸', style: TextStyle(fontSize: 64))),
                ),
        ),

        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  _MenuButton(memory: memory),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: AppSpacing.md,
          left: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              memory.category.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),

        Positioned(
          bottom: AppSpacing.md,
          right: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(memory.formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends ConsumerWidget {
  const _MenuButton({required this.memory});
  final Memory memory;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text('memory.deleteConfirm'.tr()),
        content: Text('memory.deleteConfirmDesc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) return;
    final success = await ref.read(deleteMemoryControllerProvider.notifier).deleteMemory(
      coupleId: coupleId,
      memoryId: memory.id,
    );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('memory.deleted'.tr()), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppColors.backgroundCard,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
                  title: Text('memory.deleteBtn'.tr(), style: const TextStyle(color: Color(0xFFE53935))),
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text('common.cancel'.tr()),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
        if (selected == 'delete' && context.mounted) {
          await _confirmDelete(context, ref);
        }
      },
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
        child: const Center(
          child: Text('•••', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.memory, required this.authorName});
  final Memory memory;
  final String authorName;

  // Returns (trKey, count) so the caller can call .tr(namedArgs: {'count': '$n'})
  (String key, int count) _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return ('common.justNow', 0);
    if (diff.inMinutes < 60) return ('common.minutesAgo', diff.inMinutes);
    if (diff.inHours < 24) return ('common.hoursAgo', diff.inHours);
    if (diff.inDays < 7) return ('common.daysAgo', diff.inDays);
    if (diff.inDays < 30) return ('common.weeksAgo', diff.inDays ~/ 7);
    return ('common.monthsAgo', diff.inDays ~/ 30);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memory.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            if (memory.mood != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(memory.mood!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'memory.youFelt'.tr(args: [memory.mood!]),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderSubtle.withValues(alpha: 0.4), height: 1),
            if (memory.story != null && memory.story!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                memory.story!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final (key, count) = _relativeTime(memory.createdAt);
                      final timeStr = key.tr(namedArgs: {'count': '$count'});
                      return Text(
                        'common.addedBy'.tr(namedArgs: {'name': authorName, 'time': timeStr}),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
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
