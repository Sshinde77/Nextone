import 'package:flutter/material.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/constants/app_colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authProvider = AuthProvider();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String _selectedRole = 'sales_executive';

  final List<Map<String, String>> _roles = [
    {
      'value': 'super_admin',
      'label': 'Super Admin',
      'icon': 'admin_panel_settings',
    },
    {'value': 'admin', 'label': 'Admin', 'icon': 'security'},
    {
      'value': 'sales_manager',
      'label': 'Sales Manager',
      'icon': 'manage_accounts',
    },
    {'value': 'sales_executive', 'label': 'Sales Executive', 'icon': 'person'},
    {'value': 'external_caller', 'label': 'External Caller', 'icon': 'call'},
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'manage_accounts':
        return Icons.manage_accounts_outlined;
      case 'person':
        return Icons.person_outline;
      case 'call':
        return Icons.call_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final errorMessage = await _authProvider.register(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (!mounted) {
        return;
      }

      if (errorMessage != null) {
        _showSnackBar(errorMessage);
        return;
      }

      _showSnackBar('Account created successfully. Please login.');
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to connect to the server. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.background,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: isSmallScreen ? 50 : 60,
                        height: isSmallScreen ? 50 : 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Join Next One', style: textTheme.titleLarge),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Account',
                                style: textTheme.titleLarge,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'FIRST NAME',
                                          style: textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _firstNameController,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            hintText: 'John',
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value?.trim() ?? '').isEmpty) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LAST NAME',
                                          style: textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _lastNameController,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            hintText: 'Doe',
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value?.trim() ?? '').isEmpty) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'EMAIL ADDRESS',
                                style: textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'john@example.com',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
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
                              const SizedBox(height: 24),
                              Text('PHONE NUMBER', style: textTheme.labelLarge),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: '+1234567890',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: (value) {
                                  if ((value?.trim() ?? '').isEmpty) {
                                    return 'Phone number is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              Text('SELECT ROLE', style: textTheme.labelLarge),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                items: _roles.map((role) {
                                  return DropdownMenuItem(
                                    value: role['value'],
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getIconData(role['icon']!),
                                          size: 20,
                                          color: AppColors.primary.withOpacity(
                                            0.7,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(role['label']!),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRole = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              Text('PASSWORD', style: textTheme.labelLarge),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isSubmitting) {
                                    _submitRegister();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: '********',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Password is required.';
                                  }
                                  if ((value ?? '').length < 6) {
                                    return 'Password must be at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitRegister,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isSubmitting) ...[
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    const Text('Create Account'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Already have an account? Login',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
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
