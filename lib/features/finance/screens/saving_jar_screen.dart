import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_text.dart';
import '../domain/entities/contribution.dart';
import '../domain/entities/saving_jar.dart';
import '../presentation/providers/finance_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../couple/presentation/providers/couple_providers.dart';
import '../../../../services/pending_contribution_service.dart';

class SavingJarScreen extends ConsumerStatefulWidget {
  const SavingJarScreen({
    super.key,
    required this.coupleId,
    required this.jarId,
    this.initialName,
    this.initialEmoji,
  });

  final String coupleId;
  final String jarId;
  final String? initialName;
  final String? initialEmoji;

  @override
  ConsumerState<SavingJarScreen> createState() => _SavingJarScreenState();
}

class _SavingJarScreenState extends ConsumerState<SavingJarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  /// Formats a fraction (0.0–1.0) as a percentage string.
  /// Shows one decimal for tiny fractions < 1%, rounded integer otherwise.
  /// Guards against NaN/Infinity from divide-by-zero edge cases.
  String _formatPercent(double fraction) {
    final pct = (fraction * 100);
    if (pct.isNaN || pct.isInfinite) return '0%';
    if (pct > 0 && pct < 1.0) return '${pct.toStringAsFixed(1)}%';
    return '${pct.round()}%';
  }

  SavingJar? _findJar(List<SavingJar> jars) {
    for (final j in jars) {
      if (j.id == widget.jarId) return j;
    }
    return null;
  }

  Future<void> _recordContribution({
    required int amount,
    String? note,
    required String method,
  }) async {
    final myUser = ref.read(authStateProvider).valueOrNull;
    if (myUser == null) return;

    final result = await ref.read(contributeControllerProvider.notifier).contribute(
          coupleId: widget.coupleId,
          jarId: widget.jarId,
          userId: myUser.uid,
          userName: myUser.displayName?.isNotEmpty == true ? myUser.displayName! : myUser.email,
          amount: amount,
          note: note,
          method: method,
        );

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('finance.saveError'.tr()),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      (_) {
        _progressController
          ..reset()
          ..forward();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('finance.addedAmount'.tr(args: [formatVND(amount)])),
            backgroundColor: const Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      },
    );
  }

  void _showContributeSheet(SavingJar jar) {
    final coupleId = ref.read(currentCoupleIdProvider) ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VietQRSheet(
        jar: jar,
        coupleId: coupleId,
        onConfirmed: (amount) => _recordContribution(
          amount: amount,
          note: null,
          method: 'qr',
        ),
        onRecordManual: (amount, note) => _recordContribution(
          amount: amount,
          note: note,
          method: 'manual',
        ),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showManualSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ManualContributeSheet(
        onRecord: (amount, note) => _recordContribution(
          amount: amount,
          note: note,
          method: 'manual',
        ),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jarsAsync = ref.watch(watchJarsProvider);
    final jar = jarsAsync.valueOrNull == null ? null : _findJar(jarsAsync.valueOrNull!);

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
                    _buildHeader(jar),
                    const SizedBox(height: AppSpacing.lg),
                    jarsAsync.when(
                      loading: () => const _LoadingHero(),
                      error: (e, _) => GlassCard(
                        child: Text('Error: $e', style: const TextStyle(color: AppColors.textPrimary)),
                      ),
                      data: (jars) {
                        if (jar == null) {
                          return GlassCard(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'finance.jarMissing'.tr(),
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(jar: jar),
                            const SizedBox(height: AppSpacing.md),
                            _buildContributionSummary(jar: jar),
                            const SizedBox(height: AppSpacing.md),
                            _buildHistory(jar: jar),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomActions(jar),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SavingJar? jar) {
    final title = jar != null ? '${jar.emoji} ${jar.name}' : '🐷 Saving Jar';
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
        Expanded(
          child: GradientText(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _confirmDelete(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Center(
              child: Text('•••', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero({required SavingJar jar}) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.pinkGlow(intensity: 16),
            ),
            child: Center(
              child: Text(
                jar.emoji.isNotEmpty ? jar.emoji : '🐷',
                style: const TextStyle(fontSize: 40),
              ),
            ),
          )
              .animate(controller: _progressController)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.elasticOut),

          const SizedBox(height: AppSpacing.md),

          Text(
            jar.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (jar.deadline != null) ...[
            const SizedBox(height: 4),
            Text(
              'finance.targetDate'.tr(args: [DateFormat('MMM d, y').format(jar.deadline!)]),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              final animated = jar.progress * _progressController.value;
              return Column(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: animated,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      GradientText(
                        formatVND(jar.currentAmount * _progressController.value),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '/ ${formatVND(jar.targetAmount)}',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          _formatPercent(animated),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD700)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'finance.confetti'.tr(),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionSummary({required SavingJar jar}) {
    final contribsAsync = ref.watch(watchContributionsProvider(jar.id));
    final myUser = ref.watch(authStateProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final myUid = myUser?.uid;
    final partnerUid = partner?.uid;

    final contribs = contribsAsync.valueOrNull ?? const <Contribution>[];

    int myTotal = 0;
    int partnerTotal = 0;
    for (final c in contribs) {
      if (c.userId == '__creator__') continue;
      if (c.userId == myUid) {
        myTotal += c.amount;
      } else if (c.userId == partnerUid) {
        partnerTotal += c.amount;
      }
    }

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _PartnerContribution(
              initial: (myUser?.displayName?.isNotEmpty == true) ? myUser!.displayName![0].toUpperCase() : 'Y',
              name: 'common.you'.tr(),
              amount: myTotal,
              color: AppColors.gradientEnd,
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.borderSubtle.withValues(alpha: 0.3)),
          Expanded(
            child: _PartnerContribution(
              initial: (partner?.displayName?.isNotEmpty == true) ? partner!.displayName![0].toUpperCase() : 'P',
              name: partner?.displayName ?? 'common.partner'.tr(),
              amount: partnerTotal,
              color: const Color(0xFF00897B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory({required SavingJar jar}) {
    final contribsAsync = ref.watch(watchContributionsProvider(jar.id));
    final myUser = ref.watch(authStateProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final myUid = myUser?.uid;
    final partnerName = partner?.displayName ?? 'common.partner'.tr();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('finance.history'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          contribsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gradientEnd, strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.textPrimary)),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'finance.historyEmpty'.tr(),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  ),
                );
              }
              return Column(
                children: items.map((c) {
                  final isCreator = c.userId == '__creator__';
                  final isMe = c.userId == myUid && !isCreator;
                  // Use userName from Firestore if available, else fall back
                  final name = isCreator
                      ? 'finance.contribution.initial'.tr()
                      : (isMe ? 'common.you'.tr() : partnerName);
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _HistoryRow(
                      initial: initial,
                      name: name,
                      amount: c.amount,
                      date: c.createdAt,
                      note: c.note,
                      method: c.method,
                      isUser: isMe,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(SavingJar? jar) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OutlinedButton(
              label: '➕ ${'finance.addManually'.tr()}',
              color: const Color(0xFF00897B),
              onTap: _showManualSheet,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ContributeButton(
              onTap: jar != null ? () => _showContributeSheet(jar) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
              title: Text('finance.deleteJar'.tr(), style: const TextStyle(color: Color(0xFFE53935))),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text('common.cancel'.tr()),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    final success = await ref.read(deleteJarControllerProvider.notifier).deleteJar(
          coupleId: widget.coupleId,
          jarId: widget.jarId,
        );
    if (!mounted) return;
    if (success) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('finance.deleteFailed'.tr()), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }
}

// ─── VIETQR CONTRIBUTE SHEET (AUTO + MANUAL DUAL MODE) ────────────────────────
/// SePay-linked account used for auto-confirm mode.
/// When the jar's accountNumber matches this, we use the auto flow with a
/// pending doc and a Firestore listener; otherwise we use the manual flow.
const kAutoConfirmAccountNumber = '0787974265';

class _VietQRSheet extends ConsumerStatefulWidget {
  const _VietQRSheet({
    required this.jar,
    required this.coupleId,
    required this.onConfirmed,
    required this.onRecordManual,
    required this.onClose,
  });

  final SavingJar jar;
  final String coupleId;
  /// Called when a contribution has been auto-confirmed (adds history row + updates jar).
  final void Function(int amount) onConfirmed;
  final void Function(int amount, String? note) onRecordManual;
  final VoidCallback onClose;

  @override
  ConsumerState<_VietQRSheet> createState() => _VietQRSheetState();
}

class _VietQRSheetState extends ConsumerState<_VietQRSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  // ── Step machine ───────────────────────────────────────────────────────────
  // 0 = amount input
  // 1 = auto-mode QR waiting
  // 2 = success
  // 3 = auto-mode expired
  // 4 = manual-mode QR displayed
  int _step = 0;

  String? _transferCode;
  String? _qrUrl;
  StreamSubscription? _pendingSub;
  Timer? _expiryTimer;
  int _secondsLeft = 5 * 60;
  bool _applied = false;

  late final PendingContributionService _service;

  // Captured once at flow-start so the listener closure is self-contained.
  late final String _initiatorUid;
  late final String _initiatorName;
  late final int _pendingAmount;

  @override
  void initState() {
    super.initState();
    _service = PendingContributionService(
      firestore: ref.read(firestoreProvider),
    );
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _expiryTimer?.cancel();
    _successAutoClose?.cancel();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Closes the sheet — cancels any listener/timer in auto mode, then dismisses.
  void _cancel() {
    _pendingSub?.cancel();
    _expiryTimer?.cancel();
    _successAutoClose?.cancel();
    widget.onClose();
  }

  // ── AUTO MODE ──────────────────────────────────────────────────────────────

  void _startListening(String code) {
    _pendingSub?.cancel();

    _pendingSub = _service.watchPending(code).listen(
      (pending) {
        debugPrint(
          'CONTRIB_LISTEN: code=$code status=${pending.status} '
          'applied=${pending.applied} _applied=$_applied _step=$_step',
        );
        if (!mounted || _step != 1) return;

        if (pending.status == 'confirmed' && !pending.applied && !_applied) {
          debugPrint('CONTRIB_LISTEN: confirmed! firing _applyConfirmed');
          _applied = true;
          _expiryTimer?.cancel();
          // Wrap in try-catch so a thrown exception doesn't kill the stream.
          try {
            _applyConfirmed(
              code: code,
              jarId: widget.jar.id,
              coupleId: widget.coupleId,
              byUid: _initiatorUid,
              byName: _initiatorName,
              amount: _pendingAmount,
            );
          } catch (e, st) {
            debugPrint('CONTRIB_LISTEN: _applyConfirmed threw: $e\n$st');
          }
        }
      },
      onError: (e) {
        debugPrint('CONTRIB_LISTEN: stream error code=$code error=$e');
      },
    );
  }

  Future<void> _startAutoFlow() async {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;
    if (amount <= 0) {
      _showSnack('finance.errors.amountRequired'.tr());
      return;
    }

    final myUser = ref.read(authStateProvider).valueOrNull;
    if (myUser == null) {
      _showSnack('finance.errors.notSignedIn'.tr());
      return;
    }

    _initiatorUid = myUser.uid;
    _initiatorName = myUser.displayName?.isNotEmpty == true ? myUser.displayName! : myUser.email;
    _pendingAmount = amount;

    final code = _service.generateCode();
    debugPrint('CONTRIB_LISTEN: creating pending doc code=$code');

    try {
      await _service.createPending(
        code: code,
        jarId: widget.jar.id,
        coupleId: widget.coupleId,
        byUid: myUser.uid,
        byName: myUser.displayName?.isNotEmpty == true ? myUser.displayName! : myUser.email,
        amount: amount,
      );
    } catch (e) {
      _showSnack('finance.errors.pendingCreateFailed'.tr());
      return;
    }

    debugPrint('CONTRIB_LISTEN: pending doc created, code=$code');

    final bankCode = widget.jar.bankCode ?? '';
    final accountNumber = widget.jar.bankAccountNumber ?? '';
    final accountName = widget.jar.bankAccountName ?? '';
    final encodedAccountName = Uri.encodeComponent(accountName);

    // addInfo is the transfer code so SePay can match it
    final qrUrl = 'https://img.vietqr.io/image/'
        '${Uri.encodeComponent(bankCode)}-${Uri.encodeComponent(accountNumber)}'
        '-compact2.png?'
        'amount=$amount'
        '&addInfo=${Uri.encodeComponent(code)}'
        '&accountName=$encodedAccountName';

    setState(() {
      _transferCode = code;
      _qrUrl = qrUrl;
      _step = 1;
      _secondsLeft = 5 * 60;
      _applied = false;
    });

    _startListening(code);

    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) { _expiryTimer?.cancel(); return; }
      final next = _secondsLeft - 1;
      if (next <= 0) {
        _expiryTimer?.cancel();
        if (_step == 1) _onExpiry(code);
      } else {
        setState(() => _secondsLeft = next);
      }
    });
  }

  Future<void> _onExpiry(String code) async {
    debugPrint('CONTRIB_LISTEN: expiry fired for code=$code');
    _pendingSub?.cancel();
    await _service.markExpired(code);
    if (!mounted) return;
    setState(() => _step = 3);
  }

  // ── MANUAL MODE ────────────────────────────────────────────────────────────

  Future<void> _startManualFlow() async {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;
    if (amount <= 0) {
      _showSnack('finance.errors.amountRequired'.tr());
      return;
    }

    final bankCode = widget.jar.bankCode ?? '';
    final accountNumber = widget.jar.bankAccountNumber ?? '';
    final accountName = widget.jar.bankAccountName ?? '';
    final encodedAccountName = Uri.encodeComponent(accountName);

    final note = _noteController.text.trim().isEmpty
        ? 'LoveHub ${widget.jar.name}'
        : _noteController.text.trim();
    final qrUrl = 'https://img.vietqr.io/image/'
        '${Uri.encodeComponent(bankCode)}-${Uri.encodeComponent(accountNumber)}'
        '-compact2.png?'
        'amount=$amount'
        '&addInfo=${Uri.encodeComponent(note)}'
        '&accountName=$encodedAccountName';

    setState(() {
      _qrUrl = qrUrl;
      _step = 4;
    });
  }

  void _confirmManual() {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    widget.onRecordManual(amount, note);
    widget.onConfirmed(amount);
    widget.onClose();
  }

  // ── SHARED ────────────────────────────────────────────────────────────────

  Future<void> _applyConfirmed({
    required String code,
    required String jarId,
    required String coupleId,
    required String byUid,
    required String byName,
    required int amount,
  }) async {
    debugPrint('CONTRIB_LISTEN: applyConfirmed called for code=$code');

    final ok = await _service.applyToJar(
      code: code,
      jarId: jarId,
      coupleId: coupleId,
      byUid: byUid,
      byName: byName,
      amount: amount,
    );

    if (!mounted) return;

    if (ok) {
      debugPrint('CONTRIB_LISTEN: applyToJar returned ok=true — transitioning to step 2');
      setState(() {
        _step = 2;
      });
      _onSuccessAutoClose();
      return;
    }

    // Transaction returned false — check whether the doc was already applied
    // (e.g. another device/process already handled it). In that case the
    // contribution IS in the jar; just show the success UI.
    final alreadyApplied = await _service.isAlreadyApplied(code);
    debugPrint('CONTRIB_LISTEN: applyToJar returned ok=false — isAlreadyApplied=$alreadyApplied');

    if (alreadyApplied) {
      debugPrint('CONTRIB_LISTEN: already applied — showing success UI');
      setState(() => _step = 2);
      _onSuccessAutoClose();
    } else {
      _showSnack('finance.errors.applyFailed'.tr());
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.gradientEnd,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == 0) _buildAmountInput(),
                    if (_step == 1) _buildAutoWaiting(),
                    if (_step == 2) _buildSuccess(),
                    if (_step == 3) _buildExpired(),
                    if (_step == 4) _buildManualQr(),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: Center(
              child: GradientText(
                '💰 ${'finance.contributeTitle'.tr()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            // Hủy closes immediately in any mode — auto listener/timer are cleaned
            // up by _cancel() before the sheet dismisses.
            onPressed: _cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    final hasBank = widget.jar.hasBankInfo;
    final isAutoAccount = widget.jar.bankAccountNumber == kAutoConfirmAccountNumber;

    if (!hasBank) {
      return GlassCard(
        child: Column(
          children: [
            Text('🏦', style: TextStyle(fontSize: 40, color: AppColors.textSecondary.withValues(alpha: 0.5))),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'finance.noBankSetup'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'finance.noBankSetupHint'.tr(),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            _FilledButton(
              label: '➕ ${'finance.addManually'.tr()}',
              color: AppColors.gradientEnd,
              onTap: () => _showManualSheet(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bank info
        GlassCard(
          child: Row(
            children: [
              Text('🏦', style: TextStyle(fontSize: 18, color: AppColors.textSecondary.withValues(alpha: 0.7))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.jar.bankCode} ···${_mask(widget.jar.bankAccountNumber ?? '')}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      widget.jar.bankAccountName ?? '',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              if (isAutoAccount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'AUTO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00897B),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Amount input
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'finance.amountHint'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Text(
                    'VND',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Note input (optional)
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _noteController,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'finance.noteHint'.tr(),
              hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Primary action: auto or manual QR based on account type
        if (isAutoAccount) ...[
          _FilledButton(
            label: '📱 ${'finance.qrAutoConfirm'.tr()}',
            color: AppColors.gradientEnd,
            onTap: _startAutoFlow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _startManualFlow,
              child: Text(
                'finance.addManuallyInstead'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ] else ...[
          _FilledButton(
            label: '📱 ${'finance.showQr'.tr()}',
            color: AppColors.gradientEnd,
            onTap: _startManualFlow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => _showManualSheet(),
              child: Text(
                'finance.addManuallyInstead'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAutoWaiting() {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;
    final mins = _secondsLeft ~/ 60;
    final secs = _secondsLeft % 60;
    final countdown = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isUrgent = _secondsLeft <= 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: spinner + countdown
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gradientEnd),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'finance.waitingForPayment'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                      : AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: isUrgent ? const Color(0xFFFFD700) : AppColors.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: isUrgent ? const Color(0xFFFFD700) : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      countdown,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isUrgent ? const Color(0xFFFFD700) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // QR card
        GlassCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: _qrUrl != null
                    ? Image.network(
                        _qrUrl!,
                        width: 200, height: 200,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            width: 200, height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.gradientEnd,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 200, height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2, size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'finance.qrLoadFailed'.tr(),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: 200, height: 200),
              ),
              const SizedBox(height: AppSpacing.md),

              // Transfer code badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      'finance.transferCode'.tr(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _transferCode ?? '',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'finance.qrAutoHint'.tr(),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientText(
                    formatVND(amount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Text('VND', style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Hủy — stops listener/timer and closes sheet immediately
              TextButton(
                onPressed: _cancel,
                child: Text(
                  'finance.huy'.tr(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualQr() {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;
    final note = _noteController.text.trim().isEmpty
        ? 'LoveHub ${widget.jar.name}'
        : _noteController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'finance.manualQrDesc'.tr(),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        GlassCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: _qrUrl != null
                    ? Image.network(
                        _qrUrl!,
                        width: 200, height: 200,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            width: 200, height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.gradientEnd,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 200, height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2, size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'finance.qrLoadFailed'.tr(),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: 200, height: 200),
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientText(
                    formatVND(amount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Text('VND', style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'finance.transferTo'.tr(args: [note]),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // "Tôi đã chuyển" — records contribution immediately, no pending doc
              _FilledButton(
                label: '✅ ${'finance.iTransferred'.tr()}',
                color: const Color(0xFF00897B),
                onTap: _confirmManual,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Hủy — just closes, no pending doc to clean up
              TextButton(
                onPressed: _cancel,
                child: Text(
                  'finance.huy'.tr(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = int.tryParse(digits) ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.pinkGlow(intensity: 16),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: const Duration(milliseconds: 600),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'finance.paymentReceived'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'finance.paymentReceivedDesc'.tr(args: [formatVND(amount)]),
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilledButton(
            label: '✅ ${'finance.done'.tr()}',
            color: const Color(0xFF00897B),
            onTap: _cancel, // auto-close already called onConfirmed; just dismiss
          ),
        ],
      ),
    );
  }

  Widget _buildExpired() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 2),
            ),
            child: Icon(Icons.timer_off_outlined, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 48),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'finance.qrExpired'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'finance.qrExpiredHint'.tr(),
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilledButton(
            label: '📱 ${'finance.regenerateQr'.tr()}',
            color: AppColors.gradientEnd,
            onTap: () {
              setState(() {
                _step = 0;
                _transferCode = null;
                _qrUrl = null;
                _applied = false;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _cancel,
            child: Text(
              'finance.huy'.tr(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ManualContributeSheet(
        onRecord: (amount, note) {
          widget.onRecordManual(amount, note);
          widget.onClose();
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  String _mask(String s) {
    if (s.length <= 4) return s;
    return s.substring(s.length - 4);
  }

  // Timer that auto-closes the sheet 2 seconds after showing success.
  Timer? _successAutoClose;

  void _onSuccessAutoClose() {
    _successAutoClose?.cancel();
    _successAutoClose = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onConfirmed(_pendingAmount);
        widget.onClose();
      }
    });
  }
}

// ─── MANUAL CONTRIBUTE SHEET ────────────────────────────────────────────────
class _ManualContributeSheet extends StatefulWidget {
  const _ManualContributeSheet({
    required this.onRecord,
    required this.onClose,
  });
  final void Function(int amount, String? note) onRecord;
  final VoidCallback onClose;

  @override
  State<_ManualContributeSheet> createState() => _ManualContributeSheetState();
}

class _ManualContributeSheetState extends State<_ManualContributeSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Header
          Row(
            children: [
              Text('➕ ${'finance.addManual'.tr()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: 'VND',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    suffixStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.gradientEnd, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    final n = int.tryParse(digits) ?? 0;
                    if (n <= 0) return 'finance.errors.amountRequired'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'finance.noteHint'.tr(),
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.gradientEnd, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilledButton(
            label: 'common.add'.tr(),
            color: const Color(0xFF00897B),
            onTap: () {
              if (_formKey.currentState?.validate() == true) {
                final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
                final amount = int.tryParse(digits) ?? 0;
                final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
                widget.onClose();
                widget.onRecord(amount, note);
              }
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─── SUPPORTING WIDGETS ──────────────────────────────────────────────────────
class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.gradientEnd, strokeWidth: 2),
        ),
      ),
    );
  }
}

class _PartnerContribution extends StatelessWidget {
  const _PartnerContribution({
    required this.initial,
    required this.name,
    required this.amount,
    required this.color,
  });

  final String initial;
  final String name;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          formatVND(amount),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.initial,
    required this.name,
    required this.amount,
    required this.date,
    required this.note,
    required this.method,
    required this.isUser,
  });

  final String initial;
  final String name;
  final int amount;
  final DateTime date;
  final String? note;
  final String method;
  final bool isUser;

  String _shortDate(DateTime d) {
    return DateFormat('MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final color = isUser ? AppColors.gradientEnd : const Color(0xFF00897B);
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            gradient: isUser ? AppColors.primaryGradient : const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF4DB6AC)]),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(initial, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: ' +${formatVND(amount)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    _shortDate(date),
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                  ),
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "• '$note'",
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            method == 'qr' ? 'finance.qrBadge'.tr() : 'finance.manualBadge'.tr(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}

class _ContributeButton extends StatelessWidget {
  const _ContributeButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientEnd.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'finance.contribute'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}
