import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../notifications/presentation/helpers/notify_partner_activity.dart';
import '../../domain/entities/memory.dart';
import '../providers/memory_providers.dart';

class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _selectedCategory = 0;
  int _selectedMood = 4;
  final List<File> _photos = [];

  static const _moods = ['😢', '😕', '😐', '😊', '🥰'];
  // Mood labels for [_moods] index 3 & 4. Kept as a translation key map
  // resolved at render time (see _moodLabel() below). The first 3 are
  // intentionally empty because the UI hides labels for sad/neutral moods.
  static const _moodLabelKeys = <String>['', '', '', 'mood.happy', 'mood.inLove'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 10) {
      _showSnack('Maximum 10 photos');
      return;
    }
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    final remaining = 10 - _photos.length;
    final toAdd = images.take(remaining);
    setState(() {
      _photos.addAll(toAdd.map((x) => File(x.path)));
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('memory.errors.titleRequired'.tr());
      return;
    }

    final coupleId = ref.read(currentCoupleIdProvider);
    final myUser = ref.read(authStateProvider).valueOrNull;
    if (coupleId == null || myUser == null) {
      _showSnack('memory.errors.notSignedIn'.tr());
      return;
    }

    final mood = _moodLabelKeys[_selectedMood].isEmpty ? null : _moods[_selectedMood];
    final result = await ref.read(addMemoryControllerProvider.notifier).addMemory(
      coupleId: coupleId,
      authorUid: myUser.uid,
      title: _titleController.text.trim(),
      story: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      category: memoryCategories[_selectedCategory].id,
      date: _selectedDate,
      mood: mood,
      photos: List.of(_photos),
    );

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('💾 ', style: TextStyle(fontSize: 16)),
              Text('memory.savedSuccess'.tr()),
            ],
          ),
          backgroundColor: AppColors.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          duration: const Duration(seconds: 2),
        ),
      );
      // Notify the partner that a new memory was added.
      final myName = myUser.displayName ?? 'Your partner';
      notifyPartnerActivity(
        ref,
        title: 'LoveHub',
        message: 'memory.pushMessage'.tr(args: [myName]),
        data: {
          'type': 'memory',
          'coupleId': coupleId,
          'fromUid': myUser.uid,
          'memoryId': result.id,
        },
      );
      Navigator.of(context).pop();
    } else {
      final err = ref.read(addMemoryControllerProvider);
      err.whenOrNull(error: (msg, _) {
        if (mounted) _showSnack('Upload failed: $msg');
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(addMemoryControllerProvider).isLoading;

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
                    _buildPhotoSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildDetailsForm(),
                    const SizedBox(height: AppSpacing.md),
                    _buildMoodSection(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            _buildBottomSave(isLoading: isLoading),
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
        Text('memory.newMemory'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () => _save(),
          child: Text('common.save'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gradientEnd)),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('memory.photos'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${_photos.length} / 10',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_photos.isEmpty)
            GestureDetector(
              onTap: _pickPhotos,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.gradientEnd.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 4),
                    Text('memory.addPhotos'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    Text('memory.photoLimit'.tr(), style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: _photos.length + (_photos.length < 10 ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _photos.length) {
                  return GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Icon(Icons.add, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(_photos[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsForm() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('memory.title'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _titleController,
              maxLength: 50,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'memory.titleHint'.tr(),
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_titleController.text.length}/50', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text('memory.date'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                  const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text('memory.categoryLabel'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: memoryCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isActive = i == _selectedCategory;
                final cat = memoryCategories[i];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      color: isActive ? null : AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: isActive ? null : Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          cat.labelKey.tr(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text('memory.story'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'memory.storyHint'.tr(),
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '${_descriptionController.text.length}/200',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('memory.howDidYouFeel'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_moods.length, (i) {
              final isSelected = i == _selectedMood;
              return GestureDetector(
                onTap: () => setState(() => _selectedMood = i),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 52 : 44,
                      height: isSelected ? 52 : 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.gradientEnd.withValues(alpha: 0.2) : AppColors.backgroundPrimary,
                        border: Border.all(
                          color: isSelected ? AppColors.gradientEnd : AppColors.borderSubtle,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.3), blurRadius: 8)] : null,
                      ),
                      child: Center(child: Text(_moods[i], style: TextStyle(fontSize: isSelected ? 26 : 22))),
                    ),
                    if (_moodLabelKeys[i].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _moodLabelKeys[i].tr(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? AppColors.gradientEnd : AppColors.textSecondary.withValues(alpha: 0.6)),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSave({required bool isLoading}) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.3))),
      ),
      child: GestureDetector(
        onTap: isLoading ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isLoading ? null : AppColors.primaryGradient,
            color: isLoading ? AppColors.borderSubtle.withValues(alpha: 0.3) : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: isLoading ? null : [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('memory.saveBtn'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
