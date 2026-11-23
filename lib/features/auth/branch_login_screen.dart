import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/auth_error_formatter.dart';
import '../../core/widgets/app_animations.dart';
import '../../providers/branch_session_provider.dart';
import '../profile/privacy_policy_screen.dart';

class BranchLoginScreen extends StatefulWidget {
  const BranchLoginScreen({super.key});

  @override
  State<BranchLoginScreen> createState() => _BranchLoginScreenState();
}

class _BranchLoginScreenState extends State<BranchLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  DateTime? _lastResetRequestTime;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int get _cooldownRemainingSeconds {
    if (_lastResetRequestTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastResetRequestTime!).inSeconds;
    final remaining = 60 - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<BranchSessionProvider>().signIn(
            _emailController.text.trim().toLowerCase(),
            _passwordController.text, // NEVER trim, lowercase, or modify password
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = formatAuthError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final prefilledEmail = _emailController.text.trim().toLowerCase();
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: prefilledEmail,
        initialCooldown: _cooldownRemainingSeconds,
        onSendReset: (email) => context.read<BranchSessionProvider>().sendPasswordReset(email),
        onResetSent: () {
          setState(() {
            _lastResetRequestTime = DateTime.now();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionError = context.watch<BranchSessionProvider>().verificationError;
    final displayError = _errorMessage ?? sessionError;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: AppFadeSlideScale(
              duration: const Duration(milliseconds: 420),
              beginOffset: const Offset(0, 10),
              beginScale: 0.98,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                  boxShadow: AppColors.softShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Official Coffee Grind PH Logo with subtle fade & scale entrance
                      Center(
                        child: AppFadeSlideScale(
                          duration: const Duration(milliseconds: 520),
                          beginOffset: Offset.zero,
                          beginScale: 0.86,
                          curve: Curves.easeOutBack,
                          child: Image.asset(
                            'assets/images/coffee_grind_logo.png',
                            height: 95,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppFadeSlideScale(
                        duration: const Duration(milliseconds: 460),
                        startInterval: 0.08,
                        beginOffset: const Offset(0, 8),
                        beginScale: 0.99,
                        child: Text(
                          'Branch Device Sign In',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email field (Up to 50 characters, trimmed, live validation)
                      AppFadeSlideScale(
                        duration: const Duration(milliseconds: 480),
                        startInterval: 0.14,
                        beginOffset: const Offset(0, 8),
                        beginScale: 0.99,
                        child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 50,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: AppTextStyles.inputField(),
                      decoration: InputDecoration(
                        labelText: 'Branch Account Email',
                        labelStyle: AppTextStyles.formLabel(),
                        counterText: '',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.darkCoffee),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                      validator: (val) {
                        final email = val?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Enter branch account email';
                        }
                        if (email.length > 50) {
                          return 'Email cannot exceed 50 characters';
                        }
                        if (!email.contains('@')) {
                          return 'Enter a valid email address containing "@".';
                        }
                        return null;
                      },
                    ),
                    ),

                    const SizedBox(height: 18),

                    // Password field (Up to 50 characters, verbatim, live validation)
                    AppFadeSlideScale(
                      duration: const Duration(milliseconds: 520),
                      startInterval: 0.20,
                      beginOffset: const Offset(0, 8),
                      beginScale: 0.99,
                      child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      maxLength: 50,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: AppTextStyles.inputField(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppTextStyles.formLabel(),
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.darkCoffee),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter password';
                        }
                        if (val.length > 50) {
                          return 'Password cannot exceed 50 characters';
                        }
                        return null;
                      },
                    ),
                    ),

                    const SizedBox(height: 8),

                    // Forgot Password action
                    AppFadeSlideScale(
                      duration: const Duration(milliseconds: 540),
                      startInterval: 0.24,
                      beginOffset: const Offset(0, 6),
                      beginScale: 0.99,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : () => _showForgotPasswordDialog(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: AppTextStyles.caption(
                              color: AppColors.darkCoffee,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (displayError != null) ...[
                      const SizedBox(height: 14),
                      AppFadeSlideScale(
                        key: ValueKey<String>('login_error_$displayError'),
                        duration: const Duration(milliseconds: 220),
                        beginOffset: const Offset(0, 8),
                        beginScale: 0.98,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.mutedRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.mutedRed.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.mutedRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayError,
                                  style: AppTextStyles.caption(color: AppColors.mutedRed, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign In Button
                    AppFadeSlideScale(
                      duration: const Duration(milliseconds: 560),
                      startInterval: 0.28,
                      beginOffset: const Offset(0, 8),
                      beginScale: 0.99,
                      child: AppPressableScale(
                        enabled: !_isLoading,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.darkCoffee,
                            foregroundColor: AppColors.surfaceWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: AnimatedSwitcher(
                            duration: AppMotion.resolveDuration(
                              context,
                              const Duration(milliseconds: 240),
                            ),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _isLoading
                                ? Row(
                                    key: const ValueKey<String>('signing_in'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: AppColors.surfaceWhite,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Signing in...',
                                        style: AppTextStyles.button(
                                          color: AppColors.surfaceWhite,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Sign In Branch Device',
                                    key: const ValueKey<String>('sign_in_label'),
                                    style: AppTextStyles.button(
                                      color: AppColors.surfaceWhite,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Coffee Grind PH',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Privacy Policy',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(
                          fontSize: 12,
                          color: AppColors.warmBronze,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.warmBronze,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final int initialCooldown;
  final Future<void> Function(String email) onSendReset;
  final VoidCallback onResetSent;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.initialCooldown,
    required this.onSendReset,
    required this.onResetSent,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  late int _countdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _countdown = widget.initialCooldown;
    if (_countdown > 0) {
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitReset() async {
    if (_isSubmitting || _countdown > 0) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await widget.onSendReset(_emailController.text.trim().toLowerCase());
      widget.onResetSent();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successMessage =
              'If an account is associated with this email, a password reset link has been requested. Please check your inbox and spam folder.';
          _countdown = 60;
        });
        _startCountdownTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = formatPasswordResetError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.darkCoffee.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.darkCoffee,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Reset Password',
            style: AppTextStyles.dialogTitle(
              color: AppColors.darkCoffee,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your branch account Gmail address. A secure password reset link will be sent to your inbox.',
                style: AppTextStyles.body(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isSubmitting,
                maxLength: 50,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: AppTextStyles.inputField(),
                decoration: InputDecoration(
                  labelText: 'Branch Account Email',
                  labelStyle: AppTextStyles.formLabel(),
                  counterText: '',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.darkCoffee),
                ),
                validator: (val) {
                  final email = val?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Enter branch account email';
                  }
                  if (email.length > 50) {
                    return 'Email cannot exceed 50 characters';
                  }
                  if (!email.contains('@')) {
                    return 'Enter a valid email address containing "@".';
                  }
                  return null;
                },
              ),
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.forestGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.forestGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: AppTextStyles.caption(
                            color: AppColors.forestGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mutedRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.mutedRed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.mutedRed,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption(
                            color: AppColors.mutedRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_countdown > 0 && _successMessage == null) ...[
                const SizedBox(height: 12),
                Text(
                  'Please wait ${_countdown}s before requesting another reset link.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: AppTextStyles.button(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkCoffee,
            foregroundColor: AppColors.surfaceWhite,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: (_isSubmitting || _countdown > 0) ? null : _submitReset,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surfaceWhite,
                  ),
                )
              : Text(
                  _countdown > 0 ? 'Resend (${_countdown}s)' : 'Send Reset Link',
                  style: AppTextStyles.button(
                    color: AppColors.surfaceWhite,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }
}
