import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_text.dart';
import 'package:lovehub/features/auth/presentation/providers/auth_providers.dart';
import 'package:lovehub/features/couple/presentation/providers/couple_providers.dart';

/// Matches: LOVE-XXXX-XXXX (with or without dashes/spaces)
bool _isValidCode(String raw) {
  final normalized = raw.toUpperCase().replaceAll(RegExp(r'[\-\s]'), '');
  return normalized.length == 12 && normalized.startsWith('LOVE');
}

String _normalizeCode(String raw) {
  return raw.toUpperCase().replaceAll(RegExp(r'[\-\s]'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
class CoupleLinkingScreen extends ConsumerStatefulWidget {
  const CoupleLinkingScreen({super.key});

  @override
  ConsumerState<CoupleLinkingScreen> createState() => _CoupleLinkingScreenState();
}

class _CoupleLinkingScreenState extends ConsumerState<CoupleLinkingScreen> {
  int _mode = 0;

  // ── Enter-code state ──────────────────────────────────────────────────────
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _clipboardHintShown = false;
  String? _lastAutofillCode;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _switchMode(int m) {
    setState(() {
      _mode = m;
      _clipboardHintShown = false;
      _lastAutofillCode = null;
    });
    if (m == 1) {
      _checkClipboard();
    } else {
      _codeController.clear();
    }
  }

  Future<void> _checkClipboard() async {
    if (_clipboardHintShown) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (_isValidCode(text)) {
        final normalized = _normalizeCode(text);
        if (normalized != _lastAutofillCode) {
          _lastAutofillCode = normalized;
          _codeController.text = text;
          _clipboardHintShown = true;
          setState(() {});
          // Auto-connect
          _joinNow(text);
        }
      }
    } catch (_) {
      // Clipboard not available — ignore
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      _codeController.text = text;
      _codeFocusNode.unfocus();
    } catch (_) {}
  }

  void _joinNow([String? overrideCode]) {
    final code = overrideCode ?? _codeController.text.trim();
    if (!_isValidCode(code)) return;
    ref.read(coupleControllerProvider.notifier).joinWithCode(
          userId: ref.read(authStateProvider).value!.uid,
          code: code,
        );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('linking.codeCopied'.tr()),
        backgroundColor: const Color(0xFF00897B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleCtrl = ref.watch(coupleControllerProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    String? displayCode;
    bool isCreatingCode = false;
    bool isJoining = coupleCtrl.isLoading;
    bool isSuccess = false;

    if (_mode == 0) {
      final coupleData = coupleCtrl.valueOrNull;
      if (coupleData != null) {
        displayCode = coupleData.code;
        final watchState = ref.watch(watchCoupleProvider(coupleData.id));
        final liveCouple = watchState.valueOrNull;
        if (liveCouple?.isComplete == true) {
          isSuccess = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.invalidate(authStateProvider);
              context.go(AppRoutes.home);
            }
          });
        }
      }
      isCreatingCode = coupleCtrl.isLoading;
    } else {
      if (coupleCtrl.hasValue && coupleCtrl.valueOrNull?.isComplete == true) {
        isSuccess = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.invalidate(authStateProvider);
            context.go(AppRoutes.home);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              const GradientText(
                '💕 Connect with your partner',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'linking.subtitle'.tr(),
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _HeartIllustration(),
              const SizedBox(height: AppSpacing.lg),

              // Mode toggle
              GlassCard(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _ModePill(
                      label: '🔗 Create code',
                      mode: 0,
                      selectedMode: _mode,
                      onTap: () => _switchMode(0),
                    )),
                    Expanded(child: _ModePill(
                      label: '⌨️ Enter code',
                      mode: 1,
                      selectedMode: _mode,
                      onTap: () => _switchMode(1),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Mode body
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: _mode == 0
                    ? KeyedSubtree(
                        key: const ValueKey('create'),
                        child: _CreateCodeView(
                          displayCode: displayCode,
                          isCreating: isCreatingCode,
                          isSuccess: isSuccess,
                          onCreate: authUser != null
                              ? () => ref.read(coupleControllerProvider.notifier).createCode(authUser.uid)
                              : null,
                          onCopy: displayCode != null ? () => _copyCode(displayCode!) : null,
                          onShare: () {},
                          onContinue: () {},
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('enter'),
                        child: _EnterCodeView(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          isConnecting: isJoining,
                          clipboardHintShown: _clipboardHintShown,
                          onPaste: _pasteFromClipboard,
                          onConnect: () => _joinNow(),
                        ),
                      ),
              ),

              // Error message for enter-code mode
              if (_mode == 1 && coupleCtrl.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    coupleCtrl.error.toString(),
                    style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'linking.onlyOneNeedsCode'.tr(),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEART ILLUSTRATION ────────────────────────────────────────────────────────
class _HeartIllustration extends StatelessWidget {
  const _HeartIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('💗', style: const TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _DashedLine(),
                const Text('✨', style: TextStyle(fontSize: 20)),
                _DashedLine(),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.5, end: 1.0, duration: const Duration(milliseconds: 1500)),
          Text('🤍', style: const TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (_) => Container(
        width: 4, height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.gradientEnd.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(1),
        ),
      )),
    );
  }
}

// ─── MODE PILL ────────────────────────────────────────────────────────────────
class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.mode, required this.selectedMode, required this.onTap});

  final String label;
  final int mode;
  final int selectedMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selectedMode;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CREATE CODE VIEW ──────────────────────────────────────────────────────────
class _CreateCodeView extends StatelessWidget {
  const _CreateCodeView({
    required this.displayCode,
    required this.isCreating,
    required this.isSuccess,
    required this.onCreate,
    required this.onCopy,
    required this.onShare,
    required this.onContinue,
  });

  final String? displayCode;
  final bool isCreating;
  final bool isSuccess;
  final VoidCallback? onCreate;
  final VoidCallback? onCopy;
  final VoidCallback onShare;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    // Step 1: Generate button
    if (displayCode == null && !isCreating) {
      return Column(
        key: key,
        children: [
          GlassCard(
            child: Column(
              children: [
                Text(
                  'linking.generateDesc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: onCreate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('✨ Generate Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'linking.partnerEntersCode'.tr(),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    }

    // Step 2: Loading
    if (isCreating) {
      return Column(
        key: key,
        children: [
          GlassCard(
            child: Column(
              children: [
                Text(
                  'linking.creatingCode'.tr(),
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.md),
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.gradientEnd),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    }

    // Step 3: Success
    if (isSuccess) {
      return _SuccessCard(onContinue: onContinue);
    }

    // Step 4: Code displayed + waiting
    return Column(
      key: key,
      children: [
        GlassCard(
          child: Column(
            children: [
              Text(
                'linking.yourLoveCode'.tr(),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppSpacing.sm),
              GradientText(
                displayCode!,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _OutlinedButton(
                      label: '📋 Copy',
                      color: const Color(0xFF00897B),
                      onTap: onCopy ?? () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _GradientButton(
                      label: '📤 Share',
                      onTap: onShare,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Send this code to your partner — it will auto-detect!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _WaitingIndicator(),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ─── ENTER CODE VIEW ──────────────────────────────────────────────────────────
class _EnterCodeView extends StatefulWidget {
  const _EnterCodeView({
    required this.controller,
    required this.focusNode,
    required this.isConnecting,
    required this.clipboardHintShown,
    required this.onPaste,
    required this.onConnect,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isConnecting;
  final bool clipboardHintShown;
  final VoidCallback onPaste;
  final VoidCallback onConnect;

  @override
  State<_EnterCodeView> createState() => _EnterCodeViewState();
}

class _EnterCodeViewState extends State<_EnterCodeView> {
  late TextEditingController _localController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _localController = widget.controller;
    _hasText = _localController.text.isNotEmpty;
    _localController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _localController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = _localController.text.isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  bool get _isValid {
    final text = _localController.text.trim();
    if (text.isEmpty) return false;
    // Quick check: at least LOVE prefix + 8 alphanum
    final normalized = text.toUpperCase().replaceAll(RegExp(r'[\-\s]'), '');
    return normalized.startsWith('LOVE') && normalized.length == 12;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: widget.key,
      children: [
        GlassCard(
          child: Column(
            children: [
              Text(
                "Enter partner's code",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Single TextField with paste button ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CodeTextField(
                      controller: _localController,
                      focusNode: widget.focusNode,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PasteButton(onTap: widget.onPaste),
                ],
              ),

              // Clipboard hint
              if (widget.clipboardHintShown) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: AppColors.gradientEnd.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Code found in clipboard ✨',
                      style: TextStyle(fontSize: 11, color: AppColors.gradientEnd.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Connect button
              GestureDetector(
                onTap: (_isValid && !widget.isConnecting) ? widget.onConnect : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _isValid && !widget.isConnecting ? AppColors.primaryGradient : null,
                    color: (_isValid && !widget.isConnecting) ? null : AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: (_isValid && !widget.isConnecting) ? null : Border.all(color: AppColors.borderSubtle),
                    boxShadow: _isValid && !widget.isConnecting
                        ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Center(
                    child: widget.isConnecting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '🔗 Connect',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: _isValid ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ─── CODE TEXT FIELD ──────────────────────────────────────────────────────────
class _CodeTextField extends StatelessWidget {
  const _CodeTextField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color: focusNode.hasFocus ? AppColors.gradientEnd : AppColors.borderSubtle,
          width: focusNode.hasFocus ? 2 : 1,
        ),
        boxShadow: focusNode.hasFocus
            ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.2), blurRadius: 8)]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: 'Paste or enter code: LOVE-XXXX-XXXX',
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9\\-\\s]')),
          LengthLimitingTextInputFormatter(20),
        ],
      ),
    );
  }
}

// ─── PASTE BUTTON ─────────────────────────────────────────────────────────────
class _PasteButton extends StatelessWidget {
  const _PasteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gradientEnd.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: AppColors.gradientEnd.withValues(alpha: 0.3)),
        ),
        child: Text('📋 Paste', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gradientEnd)),
      ),
    );
  }
}

// ─── WAITING INDICATOR ─────────────────────────────────────────────────────────
class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(3, (i) => Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gradientEnd.withValues(alpha: 0.8),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              delay: Duration(milliseconds: 200 * i),
              duration: const Duration(milliseconds: 600),
            )
            .fade(begin: 0.3, end: 1.0, delay: Duration(milliseconds: 200 * i))),
        const SizedBox(width: 8),
        Text(
          'linking.waitingForPartner'.tr(),
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

// ─── SUCCESS CARD ──────────────────────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
              boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
            ),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 36))),
          )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
              )
              .shimmer(
                duration: const Duration(milliseconds: 1000),
                color: Colors.white.withValues(alpha: 0.3),
              ),
          const SizedBox(height: AppSpacing.md),
          GradientText('linking.connected'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'linking.connectedDesc'.tr(),
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('linking.continue'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 400))
              .slideY(begin: 0.1, end: 0, delay: const Duration(milliseconds: 400)),
        ],
      ),
    );
  }
}

// ─── BUTTON HELPERS ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
