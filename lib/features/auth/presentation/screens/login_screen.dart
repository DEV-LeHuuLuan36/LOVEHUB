import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _showEmailForm = false;
  bool _showSignUpForm = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      ),
    );
    ref.read(authControllerProvider.notifier).clearError();
  }

  void _onSignInEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('auth.login.errorFillAll'.tr());
      return;
    }
    final success = await ref.read(authControllerProvider.notifier).signInEmail(
          email: email,
          password: password,
        );
    if (!success && mounted) {
      final state = ref.read(authControllerProvider);
      state.whenOrNull(error: (Object msg, _) => _showError(msg.toString()));
    }
  }

  void _onSignUpEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showError('auth.login.errorFillAll'.tr());
      return;
    }
    if (password.length < 6) {
      _showError('auth.login.errorPasswordTooShort'.tr());
      return;
    }
    final success = await ref.read(authControllerProvider.notifier).signUpEmail(
          email: email,
          password: password,
          displayName: name,
        );
    if (!success && mounted) {
      final state = ref.read(authControllerProvider);
      state.whenOrNull(error: (Object msg, _) => _showError(msg.toString()));
    }
  }

  void _onSignInGoogle() async {
    final success = await ref.read(authControllerProvider.notifier).signInGoogle();
    if (!success && mounted) {
      final state = ref.read(authControllerProvider);
      state.whenOrNull(error: (Object msg, _) => _showError(msg.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Small logo
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: const Center(child: Text('💕', style: TextStyle(fontSize: 24))),
              )
                  .animate()
                  .fadeIn()
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: const Duration(milliseconds: 400)),

              const SizedBox(height: AppSpacing.lg),

              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFFE91E8C)],
                ).createShader(bounds),
                child: Text(
                  _showSignUpForm
                      ? 'auth.login.createAccount'.tr()
                      : 'auth.login.welcomeBack'.tr(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 150)),

              const SizedBox(height: 8),

              Text(
                _showSignUpForm
                    ? 'auth.login.subtitle_signup'.tr()
                    : 'auth.login.subtitle_signin'.tr(),
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 250)),

              const SizedBox(height: AppSpacing.xl),

              // Hearts illustration (hidden when form is open)
              if (!_showEmailForm && !_showSignUpForm)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeartBubble(emoji: '💖', size: 72, offsetY: -10),
                    const SizedBox(width: 4),
                    _HeartBubble(emoji: '💕', size: 88, offsetY: 0),
                    const SizedBox(width: 4),
                    _HeartBubble(emoji: '💗', size: 72, offsetY: -10),
                  ],
                )
                    .animate()
                    .fadeIn(delay: const Duration(milliseconds: 350)),

              if (!_showEmailForm && !_showSignUpForm) const SizedBox(height: AppSpacing.xl),

              // Google sign in (top level)
              if (!_showEmailForm && !_showSignUpForm) ...[
                _GoogleSignInButton(
                  onTap: isLoading ? () {} : _onSignInGoogle,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Phone sign in
                _PhoneSignInButton(
                  onTap: () {},
                  isLoading: isLoading,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text('common.or'.tr(), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                    ),
                    Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5))),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
              ],

              // Email/Password form card
              if (_showEmailForm || _showSignUpForm)
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showSignUpForm) ...[
                        // Name field
                        _FormField(
                          controller: _nameController,
                          hint: 'auth.login.yourName'.tr(),
                          icon: '💕',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // Email field
                      _FormField(
                        controller: _emailController,
                        hint: 'auth.login.email'.tr(),
                        icon: '📧',
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Password field
                      _FormField(
                        controller: _passwordController,
                        hint: 'auth.login.password'.tr(),
                        icon: '🔒',
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _showSignUpForm ? _onSignUpEmail() : _onSignInEmail(),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Submit button
                      GestureDetector(
                        onTap: isLoading
                            ? () {}
                            : (_showSignUpForm ? _onSignUpEmail : _onSignInEmail),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _showSignUpForm
                                        ? 'auth.login.createAccountBtn'.tr()
                                        : 'auth.login.signIn'.tr(),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Back to login link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSignUpForm = false;
                              _showEmailForm = false;
                              _emailController.clear();
                              _passwordController.clear();
                              _nameController.clear();
                            });
                            ref.read(authControllerProvider.notifier).clearError();
                          },
                          child: Text(
                            _showSignUpForm ? 'auth.login.backToSignIn'.tr() : '',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gradientEnd),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: const Duration(milliseconds: 200))
                    .slideY(begin: 0.1, end: 0),

              // Show email form button (when no form visible)
              if (!_showEmailForm && !_showSignUpForm) ...[
                // "Sign in with email" text button
                GestureDetector(
                  onTap: () => setState(() => _showEmailForm = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: AppColors.borderSubtle, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Text('📧', style: TextStyle(fontSize: 20)),
                        const Spacer(),
                        Text(
                          'auth.login.continueWithEmail'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const Spacer(),
                        const SizedBox(width: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text('common.or'.tr(), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                    ),
                    Expanded(child: Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5))),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
              ],

              // Create account link
              if (!_showSignUpForm)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'auth.login.newHere'.tr(),
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showSignUpForm = true),
                      child: Text(
                        'auth.login.createAccountLink'.tr(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gradientEnd),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.lg),

              // Terms
              Text(
                'auth.login.termsNotice'.tr(),
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────
class _HeartBubble extends StatelessWidget {
  const _HeartBubble({required this.emoji, required this.size, required this.offsetY});
  final String emoji;
  final double size;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient.scale(0.25),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: offsetY.abs() == 0 ? -8 : offsetY - 4,
          duration: const Duration(milliseconds: 2000),
          curve: Curves.easeInOut,
        );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onTap, required this.isLoading});
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('G', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
              ),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              Flexible(
                child: Text(
                  'auth.login.continueWithGoogle'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _PhoneSignInButton extends StatelessWidget {
  const _PhoneSignInButton({required this.onTap, required this.isLoading});
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.gradientEnd, width: 1.5),
        ),
        child: Row(
          children: [
            const Text('📱', style: TextStyle(fontSize: 20)),
            const Spacer(),
            if (isLoading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gradientEnd))
            else
              Flexible(
                child: Text(
                  'auth.login.continueWithPhone'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gradientEnd),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction = TextInputAction.next,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String hint;
  final String icon;
  final FocusNode? focusNode;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          if (suffixIcon != null) Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon),
        ],
      ),
    );
  }
}
