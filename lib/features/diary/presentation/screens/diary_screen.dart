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

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  static const int _allYears = -1;
  int _selectedYear = _allYears;

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(watchMemoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: memoriesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gradientEnd),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'memory.errorLoading'.tr(namedArgs: {'error': '$e'}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
          data: (memories) => _buildContent(memories),
        ),
      ),
      floatingActionButton: _FloatingAddButton(onTap: () => _openAddMemory(context)),
    );
  }

  Widget _buildContent(List<Memory> memories) {
    final sorted = [...memories]..sort((a, b) => b.date.compareTo(a.date));
    final years = _availableYears(sorted);
    final activeYear = years.contains(_selectedYear) || _selectedYear == _allYears
        ? _selectedYear
        : _allYears;
    final filtered = activeYear == _allYears
        ? sorted
        : sorted.where((m) => m.date.year == activeYear).toList();
    final yearGroups = _groupByYearMonth(filtered);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _Header(),
                const SizedBox(height: AppSpacing.md),
                if (years.length > 1) _YearFilterBar(years: years, selected: activeYear, onSelect: (y) => setState(() => _selectedYear = y)),
                if (years.length > 1) const SizedBox(height: AppSpacing.md),
                if (sorted.isEmpty)
                  const _NoMemoriesEmptyState()
                else if (filtered.isEmpty)
                  _NoMemoriesInYearEmptyState(year: activeYear)
                else
                  ...yearGroups.entries.expand((yearEntry) {
                    final year = yearEntry.key;
                    final months = yearEntry.value;
                    return [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm, top: AppSpacing.lg),
                        child: Text(
                          '$year ✨',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      ...months.entries.expand((monthEntry) {
                        final monthLabel = monthEntry.key;
                        final items = monthEntry.value;
                        return [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: AppSpacing.sm, bottom: AppSpacing.sm),
                            child: Text(
                              monthLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gradientEnd,
                              ),
                            ),
                          ),
                          ...items.asMap().entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _MemoryCard(memory: entry.value),
                              )),
                        ];
                      }),
                    ];
                  }),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<int> _availableYears(List<Memory> memories) {
    final years = memories.map((m) => m.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    return years;
  }

  Map<int, Map<String, List<Memory>>> _groupByYearMonth(List<Memory> memories) {
    final result = <int, Map<String, List<Memory>>>{};
    for (final m in memories) {
      result.putIfAbsent(m.date.year, () => {});
      result[m.date.year]!.putIfAbsent(m.monthYear, () => []).add(m);
    }
    return result;
  }
}

void _openAddMemory(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
  );
}

// ─── HEADER ───────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // BUG FIX: symmetric Spacer() — Flexible() — Spacer() layout squeezes
        // the title to "N..." on small screens.  The leading Spacer() creates
        // equal flex pressure from both sides; removing it lets the title take
        // all available space up to its intrinsic width, then ellipsis kicks in.
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 0),
            child: Text(
              '📖 ${'memory.diaryTitle'.tr()}',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _openAddMemory(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  'memory.addBtn'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── YEAR FILTER BAR ──────────────────────────────────────────────────────
class _YearFilterBar extends StatelessWidget {
  const _YearFilterBar({required this.years, required this.selected, required this.onSelect});

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _YearChip(label: 'memory.filterAll'.tr(), selected: selected == -1, onTap: () => onSelect(-1)),
          ...years.map((y) => _YearChip(
                label: '$y',
                selected: selected == y,
                onTap: () => onSelect(y),
              )),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── EMPTY STATES ─────────────────────────────────────────────────────────
class _NoMemoriesEmptyState extends StatelessWidget {
  const _NoMemoriesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: const Duration(milliseconds: 2000)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'memory.empty'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'memory.addHint'.tr(),
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMemoriesInYearEmptyState extends StatelessWidget {
  const _NoMemoriesInYearEmptyState({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_outlined,
                size: 36,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'memory.emptyInYear'.tr(namedArgs: {'year': '$year'}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'memory.filterAllHint'.tr(),
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MEMORY CARD ──────────────────────────────────────────────────────────
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = memory.photoUrls.isNotEmpty;
    final hasStory = (memory.story ?? '').trim().isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MemoryDetailScreen(memoryId: memory.id)),
      ),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: memory.photoUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                            child: Center(
                              child: Text(memory.categoryEmoji, style: const TextStyle(fontSize: 60, color: Colors.white24)),
                            ),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                          child: Center(
                            child: Text(memory.categoryEmoji, style: const TextStyle(fontSize: 60, color: Colors.white24)),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      DateFormat('MMM d, y').format(memory.date),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1025)),
                    ),
                  ),
                ),
                if (memory.photoUrls.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${memory.photoUrls.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  if (hasStory) ...[
                    const SizedBox(height: 4),
                    Text(
                      memory.story!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(memory.categoryEmoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 3),
                      Text(memory.categoryLabel.tr(), style: AppTypography.labelSmall),
                      if (memory.mood != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        Text(memory.mood!, style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB ──────────────────────────────────────────────────────────────────
class _FloatingAddButton extends StatelessWidget {
  const _FloatingAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 1),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
