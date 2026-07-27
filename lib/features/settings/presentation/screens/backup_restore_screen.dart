import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/backup_json_codec.dart';
import '../providers/backup_provider.dart';
import '../../domain/entities/backup_data.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  // ─── Export ─────────────────────────────────────────────────────────────────

  Future<void> _onExport() async {
    setState(() => _isExporting = true);

    final controller = ref.read(backupControllerProvider.notifier);
    final error = await controller.exportBackup();

    if (!mounted) return;
    setState(() => _isExporting = false);

    if (error == null) {
      _showSnackBar('settings.backupSuccess'.tr(), isError: false);
    } else {
      _showSnackBar('${'settings.backupError'.tr()}: $error', isError: true);
    }
  }

  // ─── Import ─────────────────────────────────────────────────────────────────

  /// Picks a file, previews its summary, then asks confirmation before importing.
  Future<void> _onImportPick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final path = result.files.single.path;
    if (path == null) return;

    String jsonString;
    try {
      jsonString = await File(path).readAsString();
    } catch (e) {
      _showSnackBar('settings.restoreError'.tr(), isError: true);
      return;
    }

    // Quick parse to show preview in dialog
      BackupData? previewData;
    String? parseError;
    try {
      previewData = BackupJsonCodec.decode(jsonString);
    } on FormatException {
      parseError = 'Invalid backup file format.';
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await _showRestoreConfirmDialog(previewData, parseError);
    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    final controller = ref.read(backupControllerProvider.notifier);
    final error = await controller.importBackup();

    if (!mounted) return;
    setState(() => _isImporting = false);

    if (error == null) {
      _showSnackBar('settings.restoreSuccess'.tr(), isError: false);
    } else if (error != 'Cancelled') {
      _showSnackBar('${'settings.restoreError'.tr()}: $error', isError: true);
    }
  }

  Future<bool?> _showRestoreConfirmDialog(
      BackupData? data, String? parseError) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'settings.restoreConfirmTitle'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parseError != null)
              _WarningText(parseError)
            else if (data != null) ...[
              Text(
                'settings.restoreConfirmBody'.tr(),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _BackupPreview(data: data),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          if (parseError == null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'settings.restoreConfirmBtn'.tr(),
                style: const TextStyle(
                  color: AppColors.gradientEnd,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFC62828) : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
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
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'settings.backupRestore'.tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // Info card
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.gradientEnd, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'settings.backupInfo'.tr(),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Export card
                    _ActionCard(
                      icon: Icons.upload_file_rounded,
                      iconColor: AppColors.gradientEnd,
                      title: 'settings.backupData'.tr(),
                      subtitle: 'settings.backupDataSubtitle'.tr(),
                      buttonLabel: 'settings.backupDataBtn'.tr(),
                      isLoading: _isExporting,
                      onTap: _isExporting ? null : _onExport,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Import card
                    _ActionCard(
                      icon: Icons.download_rounded,
                      iconColor: const Color(0xFF4FACFE),
                      title: 'settings.restoreData'.tr(),
                      subtitle: 'settings.restoreDataSubtitle'.tr(),
                      buttonLabel: 'settings.restoreDataBtn'.tr(),
                      isLoading: _isImporting,
                      onTap: _isImporting ? null : _onImportPick,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // What's included
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'settings.backupIncludes'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._buildIncludeItems(),
                        ],
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

  List<Widget> _buildIncludeItems() {
    final items = [
      ('👤', 'settings.includeItem.user'.tr()),
      ('💕', 'settings.includeItem.streak'.tr()),
      ('🐱', 'settings.includeItem.pet'.tr()),
      ('😊', 'settings.includeItem.moods'.tr()),
      ('📸', 'settings.includeItem.memories'.tr()),
      ('🐷', 'settings.includeItem.savingJars'.tr()),
      ('⭐', 'settings.includeItem.milestones'.tr()),
      ('📍', 'settings.includeItem.location'.tr()),
    ];

    return [
      for (final (emoji, label) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

// ─── Reusable action card ────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: isLoading ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isLoading
                      ? null
                      : LinearGradient(
                          colors: [iconColor, iconColor.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isLoading ? AppColors.textSecondary.withValues(alpha: 0.3) : null,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: isLoading
                      ? null
                      : [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.white),
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

// ─── Backup preview widget ─────────────────────────────────────────────────────
class _BackupPreview extends StatelessWidget {
  const _BackupPreview({required this.data});

  final BackupData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewRow('${'settings.previewVersion'.tr()}:', '${data.version}'),
        _PreviewRow('${'settings.previewExported'.tr()}:', data.exportedAt),
        _PreviewRow('${'settings.previewUser'.tr()}:', data.user.displayName),
        _PreviewRow('${'settings.previewStreak'.tr()}:',
            '${data.streak.currentStreak} days'),
        _PreviewRow('${'settings.previewMemories'.tr()}:', '${data.memories.length}'),
        _PreviewRow('${'settings.previewJars'.tr()}:', '${data.savingJars.length}'),
        _PreviewRow('${'settings.previewMoods'.tr()}:', '${data.moods.length}'),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Warning text ─────────────────────────────────────────────────────────────
class _WarningText extends StatelessWidget {
  const _WarningText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
