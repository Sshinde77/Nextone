import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class TeamMemberCreationResult {
  final String fullName;
  final String roleLabel;

  const TeamMemberCreationResult({
    required this.fullName,
    required this.roleLabel,
  });
}

class AddTeamMemberPage extends StatefulWidget {
  final String? memberId;
  final Map<String, dynamic>? memberData;

  const AddTeamMemberPage({
    super.key,
    this.memberId,
    this.memberData,
  });

  bool get isEditMode => memberId != null && memberId!.trim().isNotEmpty;

  @override
  State<AddTeamMemberPage> createState() => _AddTeamMemberPageState();
}

class _AddTeamMemberPageState extends State<AddTeamMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authProvider = AuthProvider();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _selectedRoleValue = 'admin';

  final List<_RoleOption> _roles = const [
    _RoleOption(label: 'Admin', value: 'admin'),
    _RoleOption(label: 'Sales Manager', value: 'sales_manager'),
    _RoleOption(label: 'Sales Executive', value: 'sales_executive'),
    _RoleOption(label: 'External Caller', value: 'external_caller'),
  ];

  bool get _isEditMode => widget.isEditMode;
  String? get _memberId => widget.memberId?.trim();

  @override
  void initState() {
    super.initState();
    _prefillDataForEdit();
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

  void _prefillDataForEdit() {
    final data = widget.memberData;
    if (!_isEditMode || data == null) {
      return;
    }

    _firstNameController.text = _readString(
      data['first_name'] ?? data['firstName'] ?? data['firstname'],
    );
    _lastNameController.text = _readString(
      data['last_name'] ?? data['lastName'] ?? data['lastname'],
    );
    _emailController.text = _readString(data['email']);
    _phoneController.text = _readString(
      data['phone_number'] ?? data['phoneNumber'],
    );

    final incomingRole = _readString(data['role']);
    if (incomingRole.isNotEmpty &&
        _roles.any((role) => role.value == incomingRole)) {
      _selectedRoleValue = incomingRole;
    }
  }

  _RoleOption get _selectedRole {
    return _roles.firstWhere((role) => role.value == _selectedRoleValue);
  }

  Future<void> _submitMember() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditMode) {
        final memberId = _memberId;
        if (memberId == null || memberId.isEmpty) {
          _showSnackBar('Unable to update member: missing user id.');
          return;
        }

        await _authProvider.editUser(
          id: memberId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          token: _authProvider.currentAuthToken,
        );

        if (!mounted) {
          return;
        }

        _showSnackBar('Team member updated successfully.');
        Navigator.pop(
          context,
          TeamMemberCreationResult(
            fullName:
                '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
            roleLabel: _selectedRole.label,
          ),
        );
        return;
      }

      final error = await _authProvider.register(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _selectedRoleValue,
        token: _authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }

      if (error != null) {
        _showSnackBar(error);
        return;
      }

      _showSnackBar('Team member created successfully.');
      Navigator.pop(
        context,
        TeamMemberCreationResult(
          fullName:
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          roleLabel: _selectedRole.label,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openRoleMenu(BuildContext context) async {
    final fieldContext = context;
    final renderBox = fieldContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final overlay = Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomLeft = renderBox.localToGlobal(
      Offset(0, renderBox.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<String>(
      context: fieldContext,
      color: Colors.white,
      elevation: 4,
      constraints: BoxConstraints.tightFor(width: renderBox.size.width),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomLeft.dy + 6,
        overlay.size.width - topLeft.dx - renderBox.size.width,
        overlay.size.height - bottomLeft.dy,
      ),
      items: _roles
          .map(
            (role) => PopupMenuItem<String>(
              value: role.value,
              child: Text(role.label),
            ),
          )
          .toList(),
    );

    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedRoleValue = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = _isEditMode ? 'Edit Team Member' : 'Add Team Member';
    final sectionTitle = _isEditMode
        ? 'Update Team Member'
        : 'Create New Team Member';
    final submitLabel = _isEditMode ? 'Update Member' : 'Create Member';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: pageTitle,
        showBackButton: true,
        showNotificationIcon: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('FIRST NAME'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _firstNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Harsh',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'First name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('LAST NAME'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lastNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Joshi',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'Last name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    readOnly: _isEditMode,
                    enabled: !_isEditMode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'harsh@gmail.com',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      if (_isEditMode) {
                        return null;
                      }
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
                  const SizedBox(height: 16),
                  _buildLabel('PHONE NUMBER'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: '+917900122449',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'Phone number is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('ROLE'),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (fieldContext) {
                      return GestureDetector(
                        onTap: (_isEditMode || _isSubmitting)
                            ? null
                            : () => _openRoleMenu(fieldContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedRole.label,
                                style: const TextStyle(color: Colors.black),
                              ),
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (!_isEditMode) ...[
                    const SizedBox(height: 16),
                    _buildLabel('PASSWORD'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submitMember();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Harsh@123',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
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
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitMember,
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
                          Text(submitLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _RoleOption {
  final String label;
  final String value;

  const _RoleOption({required this.label, required this.value});
}
