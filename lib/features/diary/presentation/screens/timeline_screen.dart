import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/memory.dart';
import '../providers/memory_providers.dart';
import 'add_memory_screen.dart';
import 'memory_detail_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(watchMemoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: memoriesAsync.when(
          data: (memories) => _buildContent(memories),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gradientEnd)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textPrimary))),
        ),
      ),
    );
  }

  Widget _buildContent(List<Memory> memories) {
    final yearGroups = _groupByYear(memories);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _buildHeader(),
                const SizedBox(height: AppSpacing.lg),

                if (memories.isEmpty)
                  const _EmptyState()
                else
                  ...yearGroups.entries.expand((yearEntry) {
                    final year = yearEntry.key;
                    final months = yearEntry.value;
                    return [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm, top: AppSpacing.lg),
                        child: Text(
                          '$year ✨',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textSecondary.withValues(alpha: 0.2)),
                        ),
                      ),
                      ...months.entries.map((monthEntry) => _MonthSection(monthLabel: monthEntry.key, memories: monthEntry.value)),
                    ];
                  }),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        if (memories.isNotEmpty) _buildStatsBar(memories),
      ],
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
        Text('memory.timeline'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
          ),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(List<Memory> memories) {
    final photos = memories.fold<int>(0, (sum, m) => sum + m.photoUrls.length);
    final stats = [
      '📊 ${memories.length} memories',
      '📸 $photos photos',
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: stats.map((s) => Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          )).toList(),
        ),
      ),
    );
  }

  Map<int, Map<String, List<Memory>>> _groupByYear(List<Memory> memories) {
    final result = <int, Map<String, List<Memory>>>{};
    for (final m in memories) {
      result.putIfAbsent(m.date.year, () => {});
      result[m.date.year]!.putIfAbsent(m.monthYear, () => []).add(m);
    }
    return result;
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({required this.monthLabel, required this.memories});
  final String monthLabel;
  final List<Memory> memories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm, top: AppSpacing.sm),
          child: Text(monthLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gradientEnd)),
        ),
        ...memories.asMap().entries.map((entry) {
          final i = entry.key;
          final memory = entry.value;
          return _MemoryRow(
            memory: memory,
            isFirst: i == 0,
            isLast: i == memories.length - 1,
          );
        }),
      ],
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.memory, required this.isFirst, required this.isLast});
  final Memory memory;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 1, height: 12, color: AppColors.borderSubtle.withValues(alpha: 0.4)),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.gradientEnd,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 6)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: AppColors.borderSubtle.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MemoryDetailScreen(memoryId: memory.id)),
                ),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 52, height: 52,
                          child: memory.photoUrls.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: memory.photoUrls.first,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: AppColors.backgroundPrimary),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.backgroundPrimary,
                                    child: Center(child: Text(memory.categoryEmoji, style: const TextStyle(fontSize: 24))),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                                  child: Center(child: Text(memory.categoryEmoji, style: const TextStyle(fontSize: 24))),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d').format(memory.date),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                            ),
                            Text(
                              memory.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (memory.mood != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(memory.mood!, style: const TextStyle(fontSize: 10)),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      memory.categoryLabel.tr(),
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.backgroundCard, shape: BoxShape.circle),
              child: Icon(Icons.calendar_today_outlined, size: 36, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: const Duration(milliseconds: 2000)),
            const SizedBox(height: AppSpacing.lg),
            Text('memory.empty'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: AppSpacing.sm),
            Text('memory.emptyCta'.tr(), style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.6))),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.button)),
                child: Text('memory.addBtn'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
