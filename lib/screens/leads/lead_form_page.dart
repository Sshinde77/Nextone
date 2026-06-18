import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
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
  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _callbackTimeController = TextEditingController();
  final _nextFollowUpTimeController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationPreferenceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingAssignees = true;
  bool _isLoadingLeadSources = true;
  bool _isLoadingProjects = true;
  bool _isLoadingLeadDetails = false;
  String? _assigneeLoadError;
  String? _leadSourceLoadError;
  String? _projectLoadError;
  String? _selectedAssigneeId;
  String? _selectedLeadSource;
  String? _selectedProjectId;
  String _currentUserRole = '';
  String? _currentUserId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_LeadSourceOption> _leadSourceOptions = const <_LeadSourceOption>[];
  List<_ProjectOption> _projectOptions = const <_ProjectOption>[];

  @override
  void initState() {
    super.initState();
    _prefillLeadData();
    _loadLeadDetails();
    _loadCurrentUserContext();
    _loadAssigneeOptions();
    _loadLeadSourceOptions();
    _loadProjectOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _emailController.dispose();
    _callbackTimeController.dispose();
    _nextFollowUpTimeController.dispose();
    _budgetController.dispose();
    _locationPreferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillLeadData() {
    _applyLeadData(widget.leadData);
  }

  void _applyLeadData(Map<String, dynamic>? data) {
    if (data == null) {
      return;
    }

    _nameController.text = _readString(
      data['name'] ??
          data['full_name'] ??
          data['fullName'] ??
          data['contact_name'],
    );
    _phoneController.text = _readString(
      data['phone'] ??
          data['phone_number'] ??
          data['phoneNumber'] ??
          data['mobile'],
    );
    _alternatePhoneController.text = _readString(
      data['alternate_phone_number'] ??
          data['alternatePhoneNumber'] ??
          data['alternate_phone'],
    );
    _emailController.text = _readString(data['email']);
    _selectedLeadSource = _readString(data['source']);
    _callbackTimeController.text = _readString(
      data['callback_time'] ?? data['callbackTime'],
    );
    _nextFollowUpTimeController.text = _readString(
      data['next_followup_time'] ??
          data['next_follow_up_time'] ??
          data['nextFollowUpTime'],
    );
    _budgetController.text = _readString(
      data['budget'] ?? data['budget_value'] ?? data['budget_range'],
    );
    _locationPreferenceController.text = _readString(
      data['location_preference'] ?? data['locationPreference'],
    );
    _notesController.text = _readString(data['notes']);

    final project = data['project'];
    if (project is Map<String, dynamic>) {
      _selectedProjectId = _readString(
        project['id'] ??
            project['project_id'] ??
            project['projectId'] ??
            project['uuid'],
      );
    } else {
      _selectedProjectId = _readString(
        data['project_id'] ?? data['projectId'] ?? data['project_uuid'],
      );
    }
    if (_selectedProjectId != null && _selectedProjectId!.isEmpty) {
      _selectedProjectId = null;
    }

    final assigned = data['assigned_to'] ?? data['assignee'];
    if (assigned is Map<String, dynamic>) {
      _selectedAssigneeId = _readString(
        assigned['id'] ??
            assigned['user_id'] ??
            assigned['userId'] ??
            assigned['uuid'],
      );
    } else {
      _selectedAssigneeId = _readString(assigned);
    }
    if (_selectedAssigneeId != null && _selectedAssigneeId!.isEmpty) {
      _selectedAssigneeId = null;
    }
  }

  Future<void> _loadLeadDetails() async {
    if (!widget.isEditMode) {
      return;
    }

    final leadId = widget.leadId?.trim();
    if (leadId == null || leadId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingLeadDetails = true;
    });

    try {
      final details = await _authProvider.leadDetail(
        id: leadId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyLeadData(details);
      });
    } catch (_) {
      // Keep list-prefilled values as fallback when detail fetch fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLeadDetails = false;
        });
      }
    }
  }

  Future<void> _loadAssigneeOptions() async {
    setState(() {
      _isLoadingAssignees = true;
      _assigneeLoadError = null;
    });

    try {
      final users =
          await _authProvider.users(token: _authProvider.currentAuthToken);
      final filtered = users
          .map(_assigneeFromApi)
          .where((user) => user != null)
          .cast<_AssigneeOption>()
          .toList();
      final uniqueById = <String, _AssigneeOption>{};
      for (final option in filtered) {
        uniqueById[option.id] = option;
      }
      final uniqueOptions = uniqueById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final resolvedSelection = _resolveAssigneeSelection(uniqueOptions);

      if (!mounted) {
        return;
      }
      setState(() {
        _assigneeOptions = uniqueOptions;
        _selectedAssigneeId = resolvedSelection;
        _isLoadingAssignees = false;
      });
      if (uniqueOptions.isEmpty) {
        _showSnackBar('No assignee options available.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAssignees = false;
        _assigneeOptions = const <_AssigneeOption>[];
        _assigneeLoadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadLeadSourceOptions() async {
    setState(() {
      _isLoadingLeadSources = true;
      _leadSourceLoadError = null;
    });

    try {
      final items = await _authProvider.leadSourcesConfig(
        token: _authProvider.currentAuthToken,
      );
      final options = items
          .map(_LeadSourceOption.fromApi)
          .where((option) => option.isActive && option.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }

      setState(() {
        _leadSourceOptions = options;
        _isLoadingLeadSources = false;
        if (_selectedLeadSource != null &&
            _selectedLeadSource!.isNotEmpty &&
            !options.any((option) => option.name == _selectedLeadSource)) {
          _selectedLeadSource = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLeadSources = false;
        _leadSourceOptions = const <_LeadSourceOption>[];
        _leadSourceLoadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadProjectOptions() async {
    setState(() {
      _isLoadingProjects = true;
      _projectLoadError = null;
    });

    try {
      final result = await _authProvider.projects(
        token: _authProvider.currentAuthToken,
        page: 1,
        perPage: 200,
      );
      final options = result.items
          .map(_ProjectOption.tryFromApi)
          .where((option) => option != null)
          .cast<_ProjectOption>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }

      setState(() {
        _projectOptions = options;
        _isLoadingProjects = false;
        if (_selectedProjectId != null &&
            _selectedProjectId!.isNotEmpty &&
            !options.any((option) => option.id == _selectedProjectId)) {
          _selectedProjectId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingProjects = false;
        _projectOptions = const <_ProjectOption>[];
        _projectLoadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadCurrentUserContext() async {
    try {
      final permissions = await _authProvider.myPermissions(
        token: _authProvider.currentAuthToken,
      );
      final profile =
          await _authProvider.profile(token: _authProvider.currentAuthToken);
      final currentUserId = _extractUserId(profile.data);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserRole = permissions.role;
        _currentUserId = currentUserId;
        _selectedAssigneeId = _resolveAssigneeSelection(_assigneeOptions);
      });
    } catch (_) {
      // Keep the manual assignee flow when current user context cannot be resolved.
    }
  }

  String? _resolveAssigneeSelection(List<_AssigneeOption> options) {
    final currentSelection = _selectedAssigneeId;
    if (currentSelection != null &&
        options.any((option) => option.id == currentSelection)) {
      return currentSelection;
    }

    final shouldAssignToSelf = !widget.isEditMode &&
        RoleAccess.isSalesManager(_currentUserRole) &&
        (_currentUserId?.isNotEmpty ?? false);
    if (shouldAssignToSelf) {
      for (final option in options) {
        if (option.id == _currentUserId) {
          return option.id;
        }
      }
    }

    return null;
  }

  String _resolveAssignedToForCreate() {
    final selectedAssigneeId = _selectedAssigneeId?.trim() ?? '';
    if (selectedAssigneeId.isNotEmpty) {
      return selectedAssigneeId;
    }

    final normalizedRole = RoleAccess.normalize(_currentUserRole);
    final shouldAssignToSelf =
        normalizedRole.isNotEmpty &&
        normalizedRole != RoleAccess.admin &&
        normalizedRole != RoleAccess.superAdmin &&
        (_currentUserId?.trim().isNotEmpty ?? false);

    if (shouldAssignToSelf) {
      return _currentUserId!.trim();
    }

    return '';
  }

  String _resolveSelectedLeadSource() {
    return _selectedLeadSource?.trim() ?? '';
  }

  String _resolveSelectedProjectId() {
    return _selectedProjectId?.trim() ?? '';
  }

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final isActive = _readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    );
    if (!isActive) {
      return null;
    }

    final roleRaw = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
    );
    final normalizedRole = _normalizeRole(roleRaw);
    if (normalizedRole != 'sale_executive' &&
        normalizedRole != 'sales_manager' &&
        normalizedRole != 'external_caller') {
      return null;
    }

    final id = _readString(
        user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final combinedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName
    ].join(' ').trim();

    final displayName = combinedName.isNotEmpty
        ? combinedName
        : _readString(user['name'] ??
            user['full_name'] ??
            user['fullName'] ??
            user['email']);

    return _AssigneeOption(
        id: id, name: displayName.isEmpty ? 'User $id' : displayName);
  }

  String _normalizeRole(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'sales_executive') {
      return 'sale_executive';
    }
    return normalized;
  }

  String? _extractUserId(Map<String, dynamic> source) {
    for (final key in const ['id', 'user_id', 'userId', 'uuid']) {
      final value = _readString(source[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
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

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Future<void> _submit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: widget.isEditMode ? 'edit' : 'create',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    if (_isLoadingLeadDetails) {
      _showSnackBar('Please wait while lead details are loading.');
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
          phone: _phoneController.text.trim(),
          source: _resolveSelectedLeadSource(),
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          assignedTo: _selectedAssigneeId?.trim() ?? '',
          projectId: _resolveSelectedProjectId(),
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      } else {
        await _authProvider.createLead(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          alternatePhoneNumber: _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _resolveSelectedLeadSource(),
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          assignedTo: _resolveAssignedToForCreate(),
          projectId: _resolveSelectedProjectId(),
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      }

      if (!mounted) {
        return;
      }
      _showSnackBar(widget.isEditMode
          ? 'Lead updated successfully.'
          : 'Lead created successfully.');
      Navigator.of(context).pop(true);
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDateTimeForController({
    required TextEditingController controller,
    DateTime? initialDateTime,
  }) async {
    final now = DateTime.now();
    final seed = initialDateTime ?? _tryParseDateTime(controller.text) ?? now;
    final normalizedNowDate = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(now) ? now : seed,
      firstDate: normalizedNowDate,
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (dateTime.isBefore(now)) {
      _showSnackBar('Please select a future date and time.');
      return;
    }

    setState(() {
      controller.text = _formatDateTime(dateTime);
    });
  }

  DateTime? _tryParseDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  String _formatDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: widget.isEditMode ? 'Edit Lead' : 'Create Lead',
        showBackButton: true,
      ),
      body: SafeArea(
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
                      controller: _alternatePhoneController,
                      label: 'Alternate Phone Number',
                      hintText: '+919876543211',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hintText: 'suresh.patel@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildProjectDropdown(),
                    const SizedBox(height: 12),
                    _buildSelectionDropdown<String>(
                      label: 'Lead Source',
                      selectedValue: _selectedLeadSource,
                      selectedLabel: _selectedLeadSource,
                      placeholder: _isLoadingLeadSources
                          ? 'Loading lead sources...'
                          : _leadSourceOptions.isEmpty
                              ? 'No lead sources available'
                              : 'Select lead source',
                      options: _leadSourceOptions
                          .map(
                            (option) => _DropdownOption<String>(
                              value: option.name,
                              label: option.name,
                            ),
                          )
                          .toList(),
                      isLoading: _isLoadingLeadSources,
                      errorText: _leadSourceLoadError,
                      onRetry: _loadLeadSourceOptions,
                      onSelected: (value) {
                        setState(() {
                          _selectedLeadSource = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDateTimeField(
                      controller: _callbackTimeController,
                      label: 'Callback Time',
                      hintText: 'Select callback date & time',
                    ),
                    const SizedBox(height: 12),
                    _buildDateTimeField(
                      controller: _nextFollowUpTimeController,
                      label: 'Next Follow-up Time',
                      hintText: 'Select next follow-up date & time',
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
                      : Text(
                          widget.isEditMode ? 'Update Lead' : 'Create Lead'),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
    String? selectedLabel;
    for (final user in _assigneeOptions) {
      if (user.id == _selectedAssigneeId) {
        selectedLabel = user.name;
        break;
      }
    }

    return _buildSelectionDropdown<String>(
      label: 'Assigned To',
      selectedValue: _selectedAssigneeId,
      selectedLabel: selectedLabel,
      placeholder: _isLoadingAssignees
          ? 'Loading assignees...'
          : _assigneeOptions.isEmpty
              ? 'No assignee options available'
              : 'Select assignee',
      options: _assigneeOptions
          .map(
            (user) => _DropdownOption<String>(
              value: user.id,
              label: user.name,
            ),
          )
          .toList(),
      isLoading: _isLoadingAssignees,
      errorText: _assigneeLoadError,
      helperText: _isLoadingAssignees
          ? 'Loading sale_executive, sales_manager and external_caller users...'
          : null,
      onRetry: _loadAssigneeOptions,
      onSelected: (value) {
        setState(() {
          _selectedAssigneeId = value;
        });
      },
    );
  }

  Widget _buildProjectDropdown() {
    String? selectedLabel;
    for (final option in _projectOptions) {
      if (option.id == _selectedProjectId) {
        selectedLabel = option.name;
        break;
      }
    }

    return _buildSelectionDropdown<String>(
      label: 'Project Name',
      selectedValue: _selectedProjectId,
      selectedLabel: selectedLabel,
      placeholder: _isLoadingProjects
          ? 'Loading projects...'
          : _projectOptions.isEmpty
              ? 'No projects available'
              : 'Select project',
      options: _projectOptions
          .map(
            (project) => _DropdownOption<String>(
              value: project.id,
              label: project.name,
            ),
          )
          .toList(),
      isLoading: _isLoadingProjects,
      errorText: _projectLoadError,
      onRetry: _loadProjectOptions,
      onSelected: (value) {
        setState(() {
          _selectedProjectId = value;
        });
      },
    );
  }

  Widget _buildSelectionDropdown<T>({
    required String label,
    required T? selectedValue,
    required String? selectedLabel,
    required String placeholder,
    required List<_DropdownOption<T>> options,
    required ValueChanged<T?> onSelected,
    bool isLoading = false,
    String? errorText,
    String? helperText,
    Future<void> Function()? onRetry,
  }) {
    final hasSelectedValue =
        selectedValue != null && options.any((option) => option.value == selectedValue);
    T? dropdownValue;
    if (hasSelectedValue) {
      dropdownValue = selectedValue;
    }

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
        DropdownButtonFormField<T>(
          value: dropdownValue,
          isExpanded: true,
          decoration: _fieldDecoration(hintText: placeholder),
          items: options
              .map(
                (option) => DropdownMenuItem<T>(
                  value: option.value,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (_isSubmitting || isLoading || options.isEmpty)
              ? null
              : onSelected,
          hint: Text(
            selectedLabel?.isNotEmpty == true ? selectedLabel! : placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectedLabel?.isNotEmpty == true ? Colors.black : Colors.grey,
            ),
          ),
        ),
        if (helperText != null && helperText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
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
          validator: validator,
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required TextEditingController controller,
    required String label,
    required String hintText,
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
          readOnly: true,
          enabled: !_isSubmitting,
          onTap: _isSubmitting
              ? null
              : () => _pickDateTimeForController(controller: controller),
          decoration: _fieldDecoration(hintText: hintText).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
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

class _LeadSourceOption {
  const _LeadSourceOption({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory _LeadSourceOption.fromApi(Map<String, dynamic> json) {
    String readString(dynamic value) {
      if (value is String) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString().trim();
      }
      return '';
    }

    bool readBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    return _LeadSourceOption(
      id: readString(json['id'] ?? json['source_id'] ?? json['sourceId']),
      name: readString(json['name'] ?? json['source']),
      isActive: readBool(
        json['is_active'] ?? json['isActive'] ?? json['active'] ?? true,
      ),
    );
  }
}

class _ProjectOption {
  const _ProjectOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  static _ProjectOption? tryFromApi(Map<String, dynamic> json) {
    String readString(dynamic value) {
      if (value is String) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString().trim();
      }
      return '';
    }

    final id = readString(
      json['id'] ?? json['project_id'] ?? json['projectId'] ?? json['uuid'],
    );
    final name = readString(json['name'] ?? json['project_name']);
    if (id.isEmpty || name.isEmpty) {
      return null;
    }

    return _ProjectOption(id: id, name: name);
  }
}

class _DropdownOption<T> {
  const _DropdownOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}
