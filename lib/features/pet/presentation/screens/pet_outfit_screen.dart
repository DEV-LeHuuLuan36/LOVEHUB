import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class PetOutfitScreen extends StatefulWidget {
  const PetOutfitScreen({super.key});

  @override
  State<PetOutfitScreen> createState() => _PetOutfitScreenState();
}

class _PetOutfitScreenState extends State<PetOutfitScreen> {
  int _selectedCategory = 0;
  int _equippedIndex = 0;

  static const _categoryKeys = [
    'pet.outfitScreen.catAll',
    'pet.outfitScreen.catDefault',
    'pet.outfitScreen.catSeasonal',
    'pet.outfitScreen.catSpecial',
    'pet.outfitScreen.catLocked',
  ];

  static const _allOutfits = [
    _OutfitItem(name: 'Default 🐱', status: _OutfitStatus.equipped, category: 1),
    _OutfitItem(name: 'Cherry Blossom 🌸', status: _OutfitStatus.owned, category: 2),
    _OutfitItem(name: 'Halloween 🎃', status: _OutfitStatus.locked, category: 3, lockCondition: '200 days'),
    _OutfitItem(name: 'Christmas 🎄', status: _OutfitStatus.locked, category: 3, lockCondition: '1 year'),
    _OutfitItem(name: 'Beach ☀️', status: _OutfitStatus.locked, category: 3, lockCondition: 'Lv.8'),
    _OutfitItem(name: 'Royal 👑', status: _OutfitStatus.locked, category: 4, lockCondition: '500 days'),
    _OutfitItem(name: 'Valentine 💕', status: _OutfitStatus.locked, category: 2, lockCondition: 'Feb 14'),
    _OutfitItem(name: 'New Year 🎆', status: _OutfitStatus.locked, category: 2, lockCondition: 'Jan 1'),
  ];

  List<_OutfitItem> get _filtered {
    if (_selectedCategory == 0) return _allOutfits;
    return _allOutfits.where((o) => o.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
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
                    _buildPetPreview(),
                    const SizedBox(height: AppSpacing.md),
                    _buildCategoryChips(),
                    const SizedBox(height: AppSpacing.md),
                    _buildOutfitGrid(),
                    const SizedBox(height: AppSpacing.md),
                    _buildUnlockProgress(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
        Text('👗 ${'pet.outfitScreen.title'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: const Color(0xFFFFD700), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('💕', style: TextStyle(fontSize: 13)),
              SizedBox(width: 4),
              Text('1,240 LP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetPreview() {
    final outfit = _allOutfits[_equippedIndex];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gradientEnd.withValues(alpha: 0.2),
                        AppColors.gradientEnd.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const Text('(^・ω・^)', style: TextStyle(fontSize: 64))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -6, duration: const Duration(milliseconds: 1600), curve: Curves.easeInOut),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(outfit.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isActive = i == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: isActive ? null : Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                _categoryKeys[i].tr(),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutfitGrid() {
    final outfits = _filtered;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.95,
      ),
      itemCount: outfits.length,
      itemBuilder: (context, i) {
        return _OutfitCard(
          outfit: outfits[i],
          isEquipped: outfits[i] == _allOutfits[_equippedIndex],
          onEquip: () {
            setState(() => _equippedIndex = _allOutfits.indexOf(outfits[i]));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('pet.outfitScreen.equippedName'.tr(args: [outfits[i].name])),
                backgroundColor: AppColors.gradientEnd,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnlockProgress() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.outfitScreen.nextUnlock'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('pet.outfitScreen.cherryBlossom'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('pet.outfitScreen.unlocksAt'.tr(args: ['100']), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8))),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (65 / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('pet.outfitScreen.daysProgress'.tr(args: ['65', '100']), style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _OutfitStatus { equipped, owned, locked }

class _OutfitItem {
  const _OutfitItem({required this.name, required this.status, required this.category, this.lockCondition});
  final String name;
  final _OutfitStatus status;
  final int category;
  final String? lockCondition;
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.outfit, required this.isEquipped, required this.onEquip});
  final _OutfitItem outfit;
  final bool isEquipped;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pet thumbnail
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEquipped ? AppColors.gradientEnd : AppColors.borderSubtle,
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: const Center(
              child: Text('(^-ω-^)', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            outfit.name,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          _buildStatusChip(),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    switch (outfit.status) {
      case _OutfitStatus.equipped:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text('pet.outfitScreen.equipped'.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        );
      case _OutfitStatus.owned:
        return GestureDetector(
          onTap: onEquip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.gradientEnd, width: 1),
            ),
            child: Text('pet.outfitScreen.equip'.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.gradientEnd)),
          ),
        );
      case _OutfitStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '🔒 ${outfit.lockCondition ?? ""}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFFD700)),
          ),
        );
    }
  }
}
