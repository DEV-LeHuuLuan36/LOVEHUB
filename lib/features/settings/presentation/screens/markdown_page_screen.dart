import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/theme/theme.dart';

/// Shared scaffold for static legal/marketing pages. Renders a
/// scrollable Markdown body loaded from [assetPath] with the
/// "Last updated" line, a gradient back button, and a title.
class MarkdownPageScreen extends StatelessWidget {
  const MarkdownPageScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  /// [BUG_6] Pick a locale-specific copy of the markdown file.
  /// Tries `assets/legal/{lang}/<file>` first, falls back to the original
  /// `assetPath` (English) if no localized version exists.
  Future<String> _loadLocalizedAsset(BuildContext context, String basePath) async {
    final lang = context.locale.languageCode; // 'vi', 'en', etc.
    // basePath is e.g. "assets/legal/privacy_policy.md"
    final parts = basePath.split('/');
    if (parts.length >= 3 && parts[0] == 'assets' && parts[1] == 'legal') {
      final fileName = parts.last;
      final localizedPath = 'assets/legal/$lang/$fileName';
      try {
        return await rootBundle.loadString(localizedPath);
      } catch (_) {
        // Fall back to original (English) path
      }
    }
    return rootBundle.loadString(basePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: FutureBuilder<String>(
                future: _loadLocalizedAsset(context, assetPath),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gradientEnd,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Text(
                        'common.error'.tr(),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return Markdown(
                    controller: ScrollController(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    selectable: true,
                    data: snap.data!,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      h1: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                      h2: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      h3: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      listBullet: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      strong: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      a: const TextStyle(
                        color: AppColors.gradientEnd,
                        decoration: TextDecoration.underline,
                      ),
                      blockquote: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _BackButton(),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
