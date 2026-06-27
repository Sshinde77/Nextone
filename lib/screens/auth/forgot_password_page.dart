import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';

enum _ForgotPasswordStep {
  verifyEmail,
  resetPassword,
  done,
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authProvider = AuthProvider();

  _ForgotPasswordStep _step = _ForgotPasswordStep.verifyEmail;
  bool _isSubmitting = false;
  String? _resetToken;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final form = _emailFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authProvider.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resetToken = result.token ?? result.resetToken;
        _step = _ForgotPasswordStep.resetPassword;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final form = _passwordFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final token = _resetToken?.trim() ?? '';
    if (token.isEmpty) {
      _showSnackBar('Please verify your email again.');
      setState(() {
        _step = _ForgotPasswordStep.verifyEmail;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final errorMessage = await _authProvider.resetPassword(
        token: token,
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      if (errorMessage != null) {
        _showSnackBar(errorMessage);
        return;
      }

      setState(() {
        _step = _ForgotPasswordStep.done;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _backToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF7FAFF),
              Color(0xFFEAF3FF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontalPadding = width < 420 ? 16.0 : 28.0;
              final cardWidth =
                  width < 700 ? width - (horizontalPadding * 2) : 560.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: _buildCard(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    Widget body;
    if (_step == _ForgotPasswordStep.verifyEmail) {
      body = _StepCard(
        key: const ValueKey('verifyEmail'),
        minHeight: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            _buildLogo(),
            const SizedBox(height: 34),
            Text(
              'Reset Password',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your email to verify your account',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 34),
            Form(
              key: _emailFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMAIL ADDRESS',
                    style: textTheme.labelLarge?.copyWith(
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInput(
                    controller: _emailController,
                    hintText: 'name@company.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) {
                        _verifyEmail();
                      }
                    },
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Email is required.';
                      }
                      if (!email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 26),
                  _buildPrimaryButton(
                    label: 'VERIFY EMAIL',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _verifyEmail,
                  ),
                  const SizedBox(height: 18),
                  _buildBackButton(),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      );
    } else if (_step == _ForgotPasswordStep.resetPassword) {
      body = _StepCard(
        key: const ValueKey('resetPassword'),
        minHeight: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            _buildLogo(),
            const SizedBox(height: 34),
            Text(
              'Reset Password',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Set your new password',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8EC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCDEFD4)),
              ),
              child: Text(
                'Email verified! Set your new password below.',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF0F9D58),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEW PASSWORD',
                    style: textTheme.labelLarge?.copyWith(
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInput(
                    controller: _newPasswordController,
                    hintText: 'Min 6 characters',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscureNewPassword,
                    textInputAction: TextInputAction.next,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF98A2B3),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      final password = value?.trim() ?? '';
                      if (password.isEmpty) {
                        return 'New password is required.';
                      }
                      if (password.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CONFIRM PASSWORD',
                    style: textTheme.labelLarge?.copyWith(
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInput(
                    controller: _confirmPasswordController,
                    hintText: 'Re-enter password',
                    prefixIcon: Icons.verified_user_outlined,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF98A2B3),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) {
                        _resetPassword();
                      }
                    },
                    validator: (value) {
                      final confirm = value?.trim() ?? '';
                      if (confirm.isEmpty) {
                        return 'Please confirm your password.';
                      }
                      if (confirm != _newPasswordController.text.trim()) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  _buildPrimaryButton(
                    label: 'RESET PASSWORD',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _resetPassword,
                  ),
                  const SizedBox(height: 18),
                  _buildBackButton(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      body = _StepCard(
        key: const ValueKey('done'),
        minHeight: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            _buildLogo(),
            const SizedBox(height: 34),
            Text(
              'All Done!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your password has been updated',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8EC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF22C55E),
                size: 44,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Your password has been reset successfully. You can now sign in with your new password.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 30),
            _buildPrimaryButton(
              label: 'BACK TO LOGIN',
              isLoading: false,
              onPressed: _backToLogin,
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: body,
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo/logo.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF98A2B3), size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7DCE3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7DCE3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: _backToLogin,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 18),
          SizedBox(width: 6),
          Text('Back to Login'),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.child,
    required this.minHeight,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 420 ? 18.0 : 32.0;
    final verticalPadding = width < 420 ? 22.0 : 32.0;

    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width < 420 ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
