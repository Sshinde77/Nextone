import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class LeadFormPage extends StatefulWidget {
  const LeadFormPage({
    super.key,
    this.leadId,
    this.leadData,
  });

  final String? leadId;
  final Map<String, dynamic>? leadData;

  bool get isEditMode => leadId != null && leadId!.trim().isNotEmpty;

  @override
  State<LeadFormPage> createState() => _LeadFormPageState();
}

class _LeadFormPageState extends State<LeadFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _sourceController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationPreferenceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingAssignees = true;
  String? _assigneeLoadError;
  String? _selectedAssigneeId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];

  @override
  void initState() {
    super.initState();
    _prefillLeadData();
    _loadAssigneeOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _sourceController.dispose();
    _budgetController.dispose();
    _locationPreferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillLeadData() {
    final data = widget.leadData;
    if (data == null) {
      return;
    }

    _nameController.text = _readString(
      data['name'] ?? data['full_name'] ?? data['fullName'] ?? data['contact_name'],
    );
    _phoneController.text = _readString(
      data['phone'] ?? data['phone_number'] ?? data['phoneNumber'] ?? data['mobile'],
    );
    _emailController.text = _readString(data['email']);
    _sourceController.text = _readString(data['source']);
    _budgetController.text = _readString(
      data['budget'] ?? data['budget_value'] ?? data['budget_range'],
    );
    _locationPreferenceController.text = _readString(
      data['location_preference'] ?? data['locationPreference'],
    );
    _notesController.text = _readString(data['notes']);

    final assigned = data['assigned_to'] ?? data['assignee'];
    if (assigned is Map<String, dynamic>) {
      _selectedAssigneeId = _readString(
        assigned['id'] ?? assigned['user_id'] ?? assigned['userId'] ?? assigned['uuid'],
      );
    } else {
      _selectedAssigneeId = _readString(assigned);
    }
    if (_selectedAssigneeId != null && _selectedAssigneeId!.isEmpty) {
      _selectedAssigneeId = null;
    }
  }

  Future<void> _loadAssigneeOptions() async {
    setState(() {
      _isLoadingAssignees = true;
      _assigneeLoadError = null;
    });

    try {
      final users = await _authProvider.users(token: _authProvider.currentAuthToken);
      final filtered = users
          .map(_assigneeFromApi)
          .where((user) => user != null)
          .cast<_AssigneeOption>()
          .toList();
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final validSelection =
          _selectedAssigneeId != null &&
              filtered.any((option) => option.id == _selectedAssigneeId)
          ? _selectedAssigneeId
          : null;

      if (!mounted) {
        return;
      }
      setState(() {
        _assigneeOptions = filtered;
        _selectedAssigneeId = validSelection;
        _isLoadingAssignees = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAssignees = false;
        _assigneeOptions = const <_AssigneeOption>[];
        _assigneeLoadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final roleRaw = _readString(
      user['role'] ?? user['user_role'] ?? user['userRole'] ?? user['designation'],
    );
    final normalizedRole = _normalizeRole(roleRaw);
    if (normalizedRole != 'sale_executive' && normalizedRole != 'sales_manager') {
      return null;
    }

    final id = _readString(user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final combinedName = [if (firstName.isNotEmpty) firstName, if (lastName.isNotEmpty) lastName]
        .join(' ')
        .trim();

    final displayName = combinedName.isNotEmpty
        ? combinedName
        : _readString(user['name'] ?? user['full_name'] ?? user['fullName'] ?? user['email']);

    return _AssigneeOption(id: id, name: displayName.isEmpty ? 'User $id' : displayName);
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'sales_executive') {
      return 'sale_executive';
    }
    return normalized;
  }

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    return '';
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_selectedAssigneeId == null || _selectedAssigneeId!.isEmpty) {
      _showSnackBar('Please select an assignee.');
      return;
    }

    if (_isLoadingAssignees) {
      _showSnackBar('Please wait while assignees are loading.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.isEditMode) {
        final leadId = widget.leadId?.trim();
        if (leadId == null || leadId.isEmpty) {
          _showSnackBar('Unable to update lead: missing lead id.');
          return;
        }
        await _authProvider.editLead(
          id: leadId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _sourceController.text.trim(),
          assignedTo: _selectedAssigneeId!,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      } else {
        await _authProvider.createLead(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _sourceController.text.trim(),
          assignedTo: _selectedAssigneeId!,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      }

      if (!mounted) {
        return;
      }
      _showSnackBar(widget.isEditMode ? 'Lead updated successfully.' : 'Lead created successfully.');
      Navigator.of(context).pop(true);
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(title: widget.isEditMode ? 'Edit Lead' : 'Create Lead'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        hintText: 'Suresh Patel',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone',
                        hintText: '+919876543210',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'suresh.patel@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Email is required.';
                          }
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(text)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _sourceController,
                        label: 'Source',
                        hintText: 'Facebook',
                      ),
                      const SizedBox(height: 12),
                      _buildAssigneeDropdown(),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _budgetController,
                        label: 'Budget',
                        hintText: '80-100L',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _locationPreferenceController,
                        label: 'Location Preference',
                        hintText: 'Andheri West',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hintText: 'Interested in 2BHK, wants sea view',
                        minLines: 3,
                        maxLines: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isEditMode ? 'Update Lead' : 'Create Lead'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildAssigneeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned To',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedAssigneeId,
          isExpanded: true,
          decoration: _fieldDecoration(hintText: 'Select assignee'),
          items: _assigneeOptions
              .map(
                (user) => DropdownMenuItem<String>(
                  value: user.id,
                  child: Text(user.name),
                ),
              )
              .toList(),
          onChanged: (_isSubmitting || _isLoadingAssignees)
              ? null
              : (value) {
                  setState(() {
                    _selectedAssigneeId = value;
                  });
                },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select assignee.';
            }
            return null;
          },
        ),
        if (_isLoadingAssignees) ...[
          const SizedBox(height: 8),
          const Text(
            'Loading sale_executive and sales_manager users...',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        if (_assigneeLoadError != null) ...[
          const SizedBox(height: 8),
          Text(
            _assigneeLoadError!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loadAssigneeOptions,
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          enabled: !_isSubmitting,
          validator: validator ??
              (value) {
                if ((value?.trim().isEmpty ?? true)) {
                  return '$label is required.';
                }
                return null;
              },
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}

class _AssigneeOption {
  const _AssigneeOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
