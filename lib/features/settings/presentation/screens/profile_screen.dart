import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../diary/presentation/providers/memory_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../streak/presentation/providers/streak_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  /// While non-null, the avatar (and any "current photo" check)
  /// uses this URL instead of `user.photoUrl`. The pending value
  /// is committed to Firestore when the user taps "Lưu" in the
  /// header (see [_onSave]).
  String? _pendingPhotoUrl;

  /// True while an image is being picked + compressed + uploaded
  /// to Cloudinary. Drives the loading overlay on the avatar.
  bool _isUploadingPhoto = false;

  /// `true` whenever any savable field differs from what was
  /// loaded from the server. Drives the unsaved-changes warning
  /// shown when the user tries to leave the screen.
  bool _hasUnsavedChanges = false;

  /// Gates the controller listeners so the post-frame initial
  /// load (in [_initControllers]) doesn't flip the dirty flag.
  /// Only user-typed edits set `_hasUnsavedChanges = true`.
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    // Start with the hint; the real value (or an empty string)
    // is loaded asynchronously by [_initControllers]. We avoid
    // pre-filling with the hint if a bio already exists on the
    // user document, otherwise the field would briefly flash
    // the hint and then snap to the real text.
    _bioController = TextEditingController();
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _initControllers();
  }

  /// Called for every keystroke in the name / bio fields. We
  /// ignore writes that happen during the initial load (before
  /// [_controllersInitialized] flips) so opening the screen
  /// doesn't mark the form as dirty.
  void _onFieldChanged() {
    if (!_controllersInitialized) return;
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _initControllers() {
    // Read initial values from auth state (only runs once on init)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).valueOrNull;
      if (mounted) {
        setState(() {
          _nameController.text = user?.displayName ?? user?.email ?? '';
          // If the user has a bio, show it; otherwise show the hint.
          _bioController.text =
              (user?.bio != null && user!.bio!.isNotEmpty)
                  ? user.bio!
                  : 'profile.bioHint'.tr();
          // From now on, controller edits count as user changes.
          _controllersInitialized = true;
          _hasUnsavedChanges = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Resolves the photo URL to display on the avatar: prefer the
  /// just-uploaded pending value, fall back to the Firestore value
  /// on the user document.
  String? _displayPhotoUrl(String? firestorePhotoUrl) {
    return _pendingPhotoUrl ?? firestorePhotoUrl;
  }

  /// Single back-press handler used by BOTH the top-left back
  /// button and the system back gesture (via [PopScope]). When
  /// there are no unsaved changes, leave immediately. Otherwise
  /// show the confirmation dialog and act on the user's choice.
  void _handleBackPress() {
    if (!_hasUnsavedChanges) {
      _leaveScreen();
      return;
    }
    _showUnsavedChangesDialog();
  }

  /// Pop the current route. Used after the user confirms they
  /// want to discard changes, or when there are no changes to
  /// begin with.
  void _leaveScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _showUnsavedChangesDialog() async {
    final action = await showDialog<_UnsavedAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => const _UnsavedChangesDialog(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _UnsavedAction.cancel:
        // Stay on screen — do nothing.
        break;
      case _UnsavedAction.discard:
        _leaveScreen();
        break;
      case _UnsavedAction.saveAndLeave:
        // _onSave pops the screen on success; if it fails it
        // shows a snackbar and the user remains here.
        await _onSave();
        break;
    }
  }

  Future<void> _onChangePhoto() async {
    final source = await _showPhotoSourceSheet();
    if (source == null || !mounted) return;
    await _pickAndUpload(source);
  }

  /// Bottom sheet with two options: gallery / camera. Returns the
  /// chosen [ImageSource], or `null` if the user dismissed the sheet.
  Future<ImageSource?> _showPhotoSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'profile.photoSheetTitle'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SheetOption(
                icon: Icons.photo_library_outlined,
                label: 'profile.pickFromGallery'.tr(),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              _SheetOption(
                icon: Icons.photo_camera_outlined,
                label: 'profile.takePhoto'.tr(),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1280,
        maxHeight: 1280,
      );
    } catch (e) {
      // Picker can throw on devices without a camera, denied
      // permissions, etc. — surface as a snackbar but never crash.
      if (!mounted) return;
      _showError('profile.photoUploadFailed'.tr(namedArgs: {'error': '$e'}));
      return;
    }

    if (picked == null) {
      // User cancelled — do nothing, per spec.
      return;
    }
    if (!mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await ref
          .read(cloudinaryServiceProvider)
          .uploadImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _pendingPhotoUrl = url;
        _isUploadingPhoto = false;
        // A freshly uploaded photo is pending until the user
        // taps "Lưu" — counts as unsaved.
        _hasUnsavedChanges = true;
      });
      _showSuccess('profile.photoUploadSuccess'.tr());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showError('profile.photoUploadFailed'.tr(namedArgs: {'error': '$e'}));
    }
  }

  /// Persist pending fields (photoUrl, displayName, bio) to the
  /// user document. Uses `set(..., merge: true)` so we never
  /// overwrite unrelated fields like `coupleId` or `email`. After
  /// the write succeeds, the `authStateProvider` stream refreshes
  /// and the rest of the app sees the new values automatically.
  ///
  /// Returns `true` on success (the screen is also popped), or
  /// `false` on error (a snackbar is shown and the screen stays).
  /// The unsaved-changes dialog uses the return value to decide
  /// whether to pop the route.
  Future<bool> _onSave() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _showError('common.error'.tr());
      return false;
    }

    final firestore = ref.read(firestoreProvider);
    final pendingName = _nameController.text.trim();

    // For bio: only persist if the user actually changed it. If
    // the field still shows the hint, treat it as "no bio".
    final bioRaw = _bioController.text.trim();
    final isBioHint = bioRaw == 'profile.bioHint'.tr();
    final pendingBio = isBioHint ? null : (bioRaw.isEmpty ? '' : bioRaw);

    final writeData = <String, dynamic>{
      if (_pendingPhotoUrl != null) 'photoUrl': _pendingPhotoUrl,
      if (pendingName.isNotEmpty) 'displayName': pendingName,
      // Always include bio if it changed (incl. explicit empty),
      // so the user can clear their bio by deleting the text.
      if (pendingBio != null) 'bio': pendingBio,
    };

    if (writeData.isEmpty) {
      // Nothing to persist — just pop with a success toast.
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.saved'.tr()),
          backgroundColor: AppColors.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      _hasUnsavedChanges = false;
      context.pop();
      return true;
    }

    try {
      await firestore
          .doc(FirestorePaths.user(user.uid))
          .set(writeData, SetOptions(merge: true));
      if (!mounted) return false;
      // Force a refresh of the auth state so the rest of the app
      // sees the new photoUrl right away.
      ref.invalidate(authStateProvider);
      // The form is now in sync with Firestore — clear the
      // dirty flag before the route is popped.
      _hasUnsavedChanges = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.saved'.tr()),
          backgroundColor: AppColors.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      context.pop();
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showError('profile.saveFailed'.tr());
      return false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.gradientEnd,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final displayName = user?.displayName ?? user?.email ?? '';
    final displayedPhoto = _displayPhotoUrl(user?.photoUrl);

    // Read the couple so we can show the real relationship-start
    // date and pipe accurate values to the stats card.
    final coupleId = ref.watch(currentCoupleIdProvider);
    final coupleAsync = coupleId == null
        ? null
        : ref.watch(watchCoupleProvider(coupleId));
    final couple = coupleAsync?.valueOrNull;
    final startDate = couple?.startDate;
    final startDateLabel = startDate == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(startDate);

    // Stats values — all reuse the same providers the rest of the
    // app uses (home screen day counter, check-in streak, diary
    // memory count, finance saving jars).
    final loveDuration = ref.watch(loveDurationProvider);
    final daysTogether = loveDuration?.days ?? 0;
    final streak = ref.watch(watchStreakProvider).valueOrNull;
    final bestStreak = streak?.currentStreak ?? 0;
    final memories = ref.watch(watchMemoriesProvider).valueOrNull ?? const [];
    final jars = ref.watch(watchJarsProvider).valueOrNull ?? const [];
    final totalSaved = jars.fold<int>(0, (sum, j) => sum + j.currentAmount);

    return PopScope(
      // Block the system back gesture while there are unsaved
      // changes — [_handleBackPress] shows the confirmation
      // dialog and only then allows the pop.
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Already popped (canPop was true).
        _handleBackPress();
      },
      child: Scaffold(
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
                    _Header(onSave: _onSave, onBack: _handleBackPress),
                    const SizedBox(height: AppSpacing.xl),
                    _AvatarSection(
                      photoUrl: displayedPhoto,
                      displayName: displayName,
                      isUploading: _isUploadingPhoto,
                      onTapChangePhoto: _isUploadingPhoto ? null : _onChangePhoto,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileFieldCard(
                      icon: Icons.person_outline,
                      label: 'profile.displayName'.tr(),
                      controller: _nameController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ProfileDateCard(
                      icon: '📧',
                      label: 'profile.email'.tr(),
                      value: user?.email ?? '—',
                      // Email is display-only — no chevron.
                      showChevron: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ProfileBioCard(
                      label: 'Bio 💬',
                      controller: _bioController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ProfileDateCard(
                      icon: '💕',
                      label: 'profile.relationshipStart'.tr(),
                      value: startDateLabel,
                      // Relationship start is read-only here — no chevron.
                      showChevron: false,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatsCard(
                      daysTogether: daysTogether,
                      bestStreak: bestStreak,
                      memoriesCount: memories.length,
                      totalSaved: totalSaved,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSave, required this.onBack});

  final VoidCallback onSave;
  final VoidCallback onBack;

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
        Text('profile.title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: onSave,
          child: Text(
            'common.save'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gradientEnd),
          ),
        ),
      ],
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.photoUrl,
    required this.displayName,
    required this.isUploading,
    required this.onTapChangePhoto,
  });

  final String? photoUrl;
  final String displayName;
  final bool isUploading;
  final VoidCallback? onTapChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.backgroundPrimary,
                ),
                child: ClipOval(
                  child: UserAvatar(
                    photoUrl: photoUrl,
                    name: displayName,
                    size: 94,
                  ),
                ),
              ),
            ),
            if (isUploading)
              Positioned.fill(
                child: ClipOval(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTapChangePhoto,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundPrimary, width: 2),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTapChangePhoto,
          child: Text(
            'profile.changePhoto'.tr(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gradientEnd),
          ),
        ),
      ],
    );
  }
}

/// Single row in the photo-source bottom sheet.
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gradientEnd, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldCard extends StatelessWidget {
  const _ProfileFieldCard({required this.icon, required this.label, required this.controller});

  final IconData icon;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.gradientEnd, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDateCard extends StatelessWidget {
  const _ProfileDateCard({
    required this.icon,
    required this.label,
    required this.value,
    this.showChevron = true,
  });

  final String icon;
  final String label;
  final String value;

  /// Set to `false` for display-only rows (email, relationship
  /// start date) so the trailing chevron doesn't imply a tap action.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                Text(value, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _ProfileBioCard extends StatelessWidget {
  const _ProfileBioCard({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.daysTogether,
    required this.bestStreak,
    required this.memoriesCount,
    required this.totalSaved,
  });

  final int daysTogether;
  final int bestStreak;
  final int memoriesCount;
  final int totalSaved;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('profile.yourStats'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.5,
            children: [
              _StatTile(
                emoji: '💕',
                value: '$daysTogether',
                labelKey: 'profile.stat.together',
              ),
              _StatTile(
                emoji: '🔥',
                value: '$bestStreak',
                labelKey: 'profile.stat.bestStreak',
              ),
              _StatTile(
                emoji: '📖',
                value: '$memoriesCount',
                labelKey: 'profile.stat.memoriesAdded',
              ),
              _StatTile(
                emoji: '💰',
                value: formatVND(totalSaved),
                labelKey: 'profile.stat.savedTogether',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.value, required this.labelKey});

  final String emoji;
  final String value;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            labelKey.tr(),
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// What the user picked in the unsaved-changes dialog.
enum _UnsavedAction { saveAndLeave, discard, cancel }

/// Confirmation dialog shown when the user tries to leave the
/// profile screen with unsaved edits. Same dark-purple +
/// pink-glowing-border styling as the rest of the app's dialogs
/// (see _RecoverConfirmDialog / _UnlinkConfirmDialog).
class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: GlassCard(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.accentGold,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              'profile.unsavedTitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'profile.unsavedBody'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            // Primary action: "Lưu" — save then leave.
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: AppColors.pinkGlow(intensity: 10),
                ),
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_UnsavedAction.saveAndLeave),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: Text(
                    'common.save'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Secondary action: "Thoát" — discard and leave.
            // Slightly destructive tint so it doesn't read as a
            // primary CTA, but still readable on the dark card.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_UnsavedAction.discard),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    side: const BorderSide(
                      color: Color(0x4DE57373), // pinkish-red at 30%
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'profile.leave'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFE57373),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Tertiary action: "Hủy" — stay on the screen.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_UnsavedAction.cancel),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    side: const BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'profile.stay'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
