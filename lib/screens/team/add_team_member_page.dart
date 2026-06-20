import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
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
  final _emergencyContactController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authProvider = AuthProvider();

  bool _isSubmitting = false;
  bool _isLoadingRoles = false;
  bool _obscurePassword = true;
  String? _selectedRoleValue;
  String _currentRole = '';
  String _incomingRoleValue = '';

  static const List<_RoleOption> _fallbackRoles = <_RoleOption>[
    _RoleOption(label: 'Admin', value: 'admin'),
    _RoleOption(label: 'Sales Manager', value: 'sales_manager'),
    _RoleOption(label: 'Sales Executive', value: 'sales_executive'),
    _RoleOption(label: 'External Caller', value: 'external_caller'),
  ];
  List<_RoleOption> _roles = List<_RoleOption>.from(_fallbackRoles);

  bool get _isEditMode => widget.isEditMode;
  String? get _memberId => widget.memberId?.trim();
  List<_RoleOption> get _availableRoles => _roles
      .where((role) => RoleAccess.canChangeRole(_currentRole, role.value))
      .toList();

  @override
  void initState() {
    super.initState();
    _prefillDataForEdit();
    _initializeRoleData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
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
    _emergencyContactController.text = _readString(
      data['emergency_contact'] ?? data['emergencyContact'],
    );
    _addressController.text = _readString(
      data['residential_address'] ?? data['residentialAddress'] ?? data['address'],
    );

    _incomingRoleValue = _readString(data['role']);
    if (_incomingRoleValue.isNotEmpty &&
        _roles.any((role) => role.value == _incomingRoleValue)) {
      _selectedRoleValue = _incomingRoleValue;
    }
  }

  Future<void> _initializeRoleData() async {
    setState(() {
      _isLoadingRoles = true;
    });
    await _loadAccess();
    await _loadRoles();
    if (!mounted) return;
    setState(() {
      _isLoadingRoles = false;
    });
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Role menu remains empty if access cannot be resolved.
    }
  }

  Future<void> _loadRoles() async {
    try {
      final data =
          await _authProvider.usersRoles(token: _authProvider.currentAuthToken);
      if (!mounted) return;

      final mapped = data
          .map((entry) {
            final value = _readString(entry['value']);
            final label = _readString(entry['label']);
            if (value.isEmpty || label.isEmpty) {
              return null;
            }
            return _RoleOption(value: value, label: label);
          })
          .whereType<_RoleOption>()
          .toList();

      if (mapped.isEmpty) {
        return;
      }

      final uniqueByValue = <String, _RoleOption>{};
      for (final role in mapped) {
        uniqueByValue[role.value] = role;
      }
      final roles = uniqueByValue.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      setState(() {
        _roles = roles;
        if (_incomingRoleValue.isNotEmpty &&
            _roles.any((role) => role.value == _incomingRoleValue)) {
          _selectedRoleValue = _incomingRoleValue;
        }
        if ((_selectedRoleValue ?? '').isNotEmpty &&
            !_roles.any((role) => role.value == _selectedRoleValue)) {
          _selectedRoleValue = null;
        }
      });
    } catch (_) {
      // Keep fallback roles if API fails.
    }
  }

  _RoleOption? get _selectedRole {
    final selected = _selectedRoleValue;
    if (selected == null || selected.isEmpty) {
      return null;
    }
    for (final role in _roles) {
      if (role.value == selected) {
        return role;
      }
    }
    return null;
  }

  Future<void> _submitMember() async {
    final form = _formKey.currentState;
    if (form != null) {
      form.save();
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
            roleLabel: _selectedRole?.label ?? '',
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
        role: _selectedRoleValue ?? '',
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
          roleLabel: _selectedRole?.label ?? '',
        ),
      );
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

    final overlay =
        Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
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
      items: _availableRoles
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
    final pageTitle = _isEditMode ? 'Edit User' : 'Register New User';
    final submitLabel = _isEditMode ? 'Update User' : 'Register User';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: pageTitle,
        showBackButton: true,
        showNotificationIcon: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pageTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'First Name',
                                controller: _firstNameController,
                                hintText: 'Priya',
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                hintText: 'Mehta',
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Email',
                          controller: _emailController,
                          hintText: 'priya@nextonerealty.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Phone Number',
                                controller: _phoneController,
                                hintText: '9123456789',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                helperText: 'Enter 10-digit number only, without +91',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Emergency Contact',
                                controller: _emergencyContactController,
                                hintText: '9876543211',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                helperText: 'Enter 10-digit number only, without +91',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Residential Address',
                          controller: _addressController,
                          hintText: '102, Andheri West, Mumbai - 400053',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                        const SizedBox(height: 16),
                        _buildRoleField(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitMember,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(submitLabel),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Min 8 characters',
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
        ),
      ],
    );
  }

  Widget _buildRoleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (fieldContext) {
            return GestureDetector(
              onTap: (_isSubmitting || _isLoadingRoles)
                  ? null
                  : () => _openRoleMenu(fieldContext),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoadingRoles
                            ? 'Loading roles...'
                            : (_selectedRole?.label ?? 'Select role'),
                        style: TextStyle(
                          color: _selectedRole == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RoleOption {
  final String label;
  final String value;

  const _RoleOption({required this.label, required this.value});
}
