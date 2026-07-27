import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class AddMilestoneScreen extends StatefulWidget {
  const AddMilestoneScreen({super.key});

  @override
  State<AddMilestoneScreen> createState() => _AddMilestoneScreenState();
}

class _AddMilestoneScreenState extends State<AddMilestoneScreen> {
  String _selectedEmoji = '💑';
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime(2025, 3, 9);
  bool _reminderEnabled = false;
  String _selectedReminder = '7 days before';

  static const _emojiOptions = ['💑', '🎂', '🌟', '💝', '🎯', '🏆', '🌈', '🎉', '💍', '✈️', '🐱', '🍜'];
  static const _reminderOptions = ['1 day before', '3 days before', '7 days before', '1 month before'];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('💾 ', style: TextStyle(fontSize: 16)),
            Text('milestone.saved'.tr()),
          ],
        ),
        backgroundColor: AppColors.gradientEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 2),
      ),
    );
    context.pop();
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  int _daysUntil(DateTime d) {
    return d.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.isEmpty ? 'milestone.placeholder'.tr() : _nameController.text;
    final daysLeft = _daysUntil(_selectedDate);

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
                    const _AddHeader(),
                    const SizedBox(height: AppSpacing.lg),

                    // Form card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Emoji picker
                          Text('milestone.chooseIcon'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _emojiOptions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final emoji = _emojiOptions[i];
                                final isSelected = emoji == _selectedEmoji;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedEmoji = emoji),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.backgroundPrimary,
                                      border: Border.all(
                                        color: isSelected ? AppColors.gradientEnd : AppColors.borderSubtle,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                                          : null,
                                    ),
                                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Name field
                          Text('milestone.name'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderSubtle, width: 1),
                            ),
                            child: TextField(
                              controller: _nameController,
                              maxLength: 30,
                              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'milestone.nameHint'.tr(),
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Date picker
                          Text('milestone.date'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.sm),
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
                          const SizedBox(height: AppSpacing.lg),

                          // Reminder toggle
                          Row(
                            children: [
                              Text('milestone.setReminder'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const Spacer(),
                              Switch(
                                value: _reminderEnabled,
                                onChanged: (v) => setState(() => _reminderEnabled = v),
                                activeColor: AppColors.gradientEnd,
                                activeTrackColor: AppColors.gradientEnd.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                          if (_reminderEnabled) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text('milestone.remindMe'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _reminderOptions.map((opt) {
                                final isSelected = opt == _selectedReminder;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedReminder = opt),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: isSelected ? AppColors.primaryGradient : null,
                                      color: isSelected ? null : AppColors.backgroundPrimary,
                                      borderRadius: BorderRadius.circular(AppRadius.full),
                                      border: isSelected ? null : Border.all(color: AppColors.borderSubtle),
                                    ),
                                    child: Text(
                                      opt,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),

                          // Notes field
                          Text('milestone.notesOptional'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderSubtle, width: 1),
                            ),
                            child: TextField(
                              controller: _notesController,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'milestone.noteHint'.tr(),
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Live preview card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('milestone.preview'.tr(), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient.scale(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(_selectedEmoji, style: const TextStyle(fontSize: 20))),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      Text(_formatDate(_selectedDate), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    'in $daysLeft days',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFD700)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Save button
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          boxShadow: [
                            BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Center(
                          child: Text('💾 ${'milestone.saveMilestone'.tr()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),

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
}

class _AddHeader extends StatelessWidget {
  const _AddHeader();

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
        Text('✨ ${'milestone.addTitle'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}
