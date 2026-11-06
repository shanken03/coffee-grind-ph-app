import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/auth_error_formatter.dart';
import '../../providers/branch_session_provider.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            _emailController.text.trim(),
            _passwordController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final sessionError = context.watch<BranchSessionProvider>().verificationError;
    final displayError = _errorMessage ?? sessionError;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.latteBeige, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkCoffee.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Coffee Brand Logo / Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.darkCoffee.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.latteBeige,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.coffee_rounded,
                          size: 44,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'COFFEE GRIND PH',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayTitle(
                        fontSize: 22,
                        letterSpacing: 2.0,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Branch Device Sign In',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 20,
                      buildCounter: (
                        BuildContext context, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) => null,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),
                      ],
                      style: AppTextStyles.inputField(),
                      decoration: InputDecoration(
                        labelText: 'Branch Account Email',
                        labelStyle: AppTextStyles.formLabel(),
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
                        if (email.length > 20) {
                          return 'Email cannot exceed 20 characters';
                        }
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Enter a valid email address containing "@".';
                        }
                        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!emailRegex.hasMatch(email)) {
                          return 'Enter a valid email address containing "@".';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      maxLength: 20,
                      buildCounter: (
                        BuildContext context, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) => null,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),
                      ],
                      style: AppTextStyles.inputField(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppTextStyles.formLabel(),
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
                        if (val.length > 20) {
                          return 'Password cannot exceed 20 characters';
                        }
                        return null;
                      },
                    ),

                    if (displayError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mutedRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.mutedRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.mutedRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayError,
                                style: AppTextStyles.caption(color: AppColors.mutedRed, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign In Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.darkCoffee,
                        foregroundColor: AppColors.surfaceWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surfaceWhite,
                              ),
                            )
                          : Text(
                              'Sign In Branch Device',
                              style: AppTextStyles.button(color: AppColors.surfaceWhite, fontSize: 15),
                            ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Coffee Grind PH',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
