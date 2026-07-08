import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';

class SiteVisitFormPage extends StatefulWidget {
  final String? visitId;
  final Map<String, dynamic>? visitData;
  final String? initialLeadId;

  const SiteVisitFormPage({
    super.key,
    this.visitId,
    this.visitData,
    this.initialLeadId,
  });

  bool get isEditMode => visitId != null && visitId!.trim().isNotEmpty;

  @override
  State<SiteVisitFormPage> createState() => _SiteVisitFormPageState();
}

class _SiteVisitFormPageState extends State<SiteVisitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _authProvider = AuthProvider();

  bool _isSubmitting = false;
  bool _isLoadingDropdowns = true;
  bool _transportArranged = false;
  bool _useManualProjectInput = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Dropdown data
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _teamMembers = [];

  String? _selectedLeadId;
  String? _selectedProjectId;
  String? _selectedAssigneeId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final token = _authProvider.currentAuthToken;
      final leadsResult = await _authProvider.leads(token: token, perPage: 100);
      final projectsResult =
          await _authProvider.projects(token: token, perPage: 100);
      final usersList = await _authProvider.assignmentUsers(token: token);

      setState(() {
        _leads = leadsResult.items;
        _projects = projectsResult.items;
        _teamMembers = usersList;
        _isLoadingDropdowns = false;
      });

      if (widget.isEditMode && widget.visitData != null) {
        _prefillData();
      } else {
        final initialLeadId = widget.initialLeadId?.trim() ?? '';
        if (initialLeadId.isNotEmpty) {
          final matchedLead = _resolveLeadValue(initialLeadId);
          if (matchedLead != null && mounted) {
            setState(() {
              _selectedLeadId = matchedLead;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final message = AppErrorHandler.friendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message == AppErrorHandler.notFoundMessage &&
                      _useManualProjectInput &&
                      _projectNameController.text.trim().isNotEmpty
                  ? 'Project not found, please select from the list'
                  : message,
            ),
          ),
        );
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  void _prefillData() {
    final data = widget.visitData!;
    _notesController.text = data['notes'] ?? '';
    _transportArranged = data['transport_arranged'] ?? false;
    _selectedLeadId = data['lead_id']?.toString();
    _selectedProjectId = data['project_id']?.toString();
    _selectedAssigneeId = data['assigned_to']?.toString();

    // If the incoming values are names (not IDs), resolve them against loaded options.
    _selectedLeadId = _resolveLeadValue(
      _selectedLeadId,
      fallbackName: data['lead_name']?.toString(),
    );
    _selectedProjectId = _resolveProjectValue(
      _selectedProjectId,
      fallbackName: data['project_name']?.toString(),
    );
    if (_selectedProjectId == null &&
        (data['project_name']?.toString().trim().isNotEmpty ?? false)) {
      _useManualProjectInput = true;
      _projectNameController.text = data['project_name'].toString();
    }
    _selectedAssigneeId = _resolveAssigneeValue(
      _selectedAssigneeId,
      fallbackName: data['assignee_name']?.toString(),
    );

    if (data['visit_date'] != null) {
      _selectedDate = DateTime.tryParse(data['visit_date']);
    }
    if (data['visit_time'] != null) {
      final parts = data['visit_time'].toString().split(':');
      if (parts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  String _resolveProjectIdForSubmit() {
    if (_useManualProjectInput) {
      return '';
    }
    return _selectedProjectId?.trim() ?? '';
  }

  String _resolveProjectNameForSubmit() {
    if (_useManualProjectInput) {
      return _projectNameController.text.trim();
    }
    return '';
  }

  void _setManualProjectMode(bool enabled) {
    setState(() {
      _useManualProjectInput = enabled;
      if (enabled) {
        _selectedProjectId = null;
      } else {
        _projectNameController.clear();
      }
    });
  }

  String? _resolveLeadValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final lead in _leads) {
        if (lead['id']?.toString() == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final lead in _leads) {
      final name = (lead['name'] ?? '').toString().trim().toLowerCase();
      if (name == candidateName) {
        return lead['id']?.toString();
      }
    }
    return null;
  }

  String? _resolveProjectValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final project in _projects) {
        if (project['id']?.toString() == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final project in _projects) {
      final name = (project['name'] ?? '').toString().trim().toLowerCase();
      if (name == candidateName) {
        return project['id']?.toString();
      }
    }
    return null;
  }

  String? _resolveAssigneeValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final member in _teamMembers) {
        if (_readUserId(member) == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final member in _teamMembers) {
      final fullName = _readUserName(member).toLowerCase();
      final directName =
          ((member['name'] ?? member['full_name'] ?? member['fullName']) ?? '')
              .toString()
              .trim()
              .toLowerCase();
      if (fullName == candidateName || directName == candidateName) {
        return _readUserId(member);
      }
    }
    return null;
  }

  List<SearchableDropdownItem<String>> _buildAssigneeOptions() {
    final unique = <String, SearchableDropdownItem<String>>{};
    for (final member in _teamMembers) {
      if (!_readUserActive(member)) {
        continue;
      }

      final id = _readUserId(member);
      if (id.isEmpty) {
        continue;
      }

      final name = _readUserName(member);
      if (name.isEmpty) {
        continue;
      }

      final roleLabel = _readUserRoleLabel(member);
      unique[id] = SearchableDropdownItem<String>(
        value: id,
        label: roleLabel.isEmpty ? name : '$name ($roleLabel)',
      );
    }

    final options = unique.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  String _readUserId(Map<String, dynamic> user) {
    return (user['id'] ??
            user['user_id'] ??
            user['userId'] ??
            user['uuid'] ??
            '')
        .toString()
        .trim();
  }

  String _readUserName(Map<String, dynamic> user) {
    final first =
        (user['first_name'] ?? user['firstName'] ?? '').toString().trim();
    final last =
        (user['last_name'] ?? user['lastName'] ?? '').toString().trim();
    final combined = [if (first.isNotEmpty) first, if (last.isNotEmpty) last]
        .join(' ')
        .trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    return (user['full_name'] ??
            user['fullName'] ??
            user['name'] ??
            user['email'] ??
            '')
        .toString()
        .trim();
  }

  bool _readUserActive(Map<String, dynamic> user) {
    final value = user['is_active'] ??
        user['isActive'] ??
        user['active'] ??
        user['status'];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  String _readUserRoleLabel(Map<String, dynamic> user) {
    final rawRole = (user['role'] ??
            user['user_role'] ??
            user['userRole'] ??
            user['designation'] ??
            '')
        .toString()
        .trim();
    if (rawRole.isEmpty) {
      return '';
    }
    return rawRole
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: widget.isEditMode ? 'edit' : 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final formattedDate = _selectedDate == null
          ? ''
          : '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final formattedTime = _selectedTime == null
          ? ''
          : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      Map<String, dynamic> responseData;
      if (widget.isEditMode) {
        responseData = await _authProvider.editSiteVisit(
          id: widget.visitId!.trim(),
          visitDate: formattedDate.isEmpty ? null : formattedDate,
          visitTime: formattedTime.isEmpty ? null : formattedTime,
          rescheduleReason: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      } else {
        final projectId = _resolveProjectIdForSubmit();
        final projectName = _resolveProjectNameForSubmit();
        responseData = await _authProvider.createSiteVisit(
          leadId: (_selectedLeadId ?? '').trim(),
          projectId: projectId,
          projectName: projectName,
          visitDate: formattedDate,
          visitTime: formattedTime,
          assignedTo: (_selectedAssigneeId ?? '').trim(),
          notes: _notesController.text.trim(),
          transportArranged: _transportArranged,
          token: _authProvider.currentAuthToken,
        );
      }

      if (mounted) {
        Navigator.pop(context, responseData);
      }
    } catch (e) {
      if (mounted) {
        final message = AppErrorHandler.friendlyMessage(e);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                message == AppErrorHandler.notFoundMessage &&
                        _useManualProjectInput &&
                        _projectNameController.text.trim().isNotEmpty
                    ? 'Project not found, please select from the list'
                    : message,
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? 'Edit Site Visit' : 'Schedule Site Visit';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(title: title, showBackButton: true),
      body: _isLoadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
                          widget.isEditMode
                              ? 'Update Details'
                              : 'Visit Details',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildLabel('LEAD *'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          sheetTitle: 'Lead',
                          value: _selectedLeadId,
                          hint: 'Select lead...',
                          items: _leads
                              .map(
                                (e) => SearchableDropdownItem<String>(
                                  value: e['id'].toString(),
                                  label: (e['name'] ?? 'Unknown').toString(),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedLeadId = val),
                          validator: (val) =>
                              val == null ? 'Lead is required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('PROJECT *'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: CheckboxListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text(
                              'Use manual project name',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              _useManualProjectInput
                                  ? 'Type the project name yourself'
                                  : 'Select a project from the list',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: _useManualProjectInput,
                            onChanged: _isSubmitting
                                ? null
                                : (value) =>
                                    _setManualProjectMode(value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_useManualProjectInput)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Project Name *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _projectNameController,
                                enabled: !_isSubmitting,
                                validator: (value) {
                                  if (!_useManualProjectInput) {
                                    return null;
                                  }
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Project name is required';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Type project name...',
                                ),
                              ),
                            ],
                          )
                        else
                          _buildDropdown(
                            sheetTitle: 'Project',
                            value: _selectedProjectId,
                            hint: 'Select project...',
                            items: _projects
                                .map(
                                  (e) => SearchableDropdownItem<String>(
                                    value: e['id'].toString(),
                                    label: (e['name'] ?? 'Unknown').toString(),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedProjectId = val),
                            validator: (val) =>
                                val == null ? 'Project is required' : null,
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('VISIT DATE'),
                                  const SizedBox(height: 8),
                                  _buildPickerField(
                                    text: _selectedDate == null
                                        ? 'dd-mm-yyyy'
                                        : '${_selectedDate!.day.toString().padLeft(2, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.year}',
                                    icon: Icons.calendar_today_outlined,
                                    onTap: _selectDate,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('VISIT TIME'),
                                  const SizedBox(height: 8),
                                  _buildPickerField(
                                    text: _selectedTime == null
                                        ? '-- : --'
                                        : _selectedTime!.format(context),
                                    icon: Icons.access_time,
                                    onTap: _selectTime,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('ASSIGN TO'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          sheetTitle: 'Assign To',
                          value: _selectedAssigneeId,
                          hint: 'Select team member...',
                          items: _buildAssigneeOptions(),
                          onChanged: (val) =>
                              setState(() => _selectedAssigneeId = val),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: CheckboxListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text(
                              'Transport arranged for client',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary),
                            ),
                            value: _transportArranged,
                            onChanged: (val) => setState(
                                () => _transportArranged = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('NOTES'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Add any specific requirements or notes...',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text(widget.isEditMode
                                        ? 'Update Visit'
                                        : 'Schedule Visit'),
                              ),
                            ),
                          ],
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

  Widget _buildDropdown({
    required String sheetTitle,
    required String? value,
    required String hint,
    required List<SearchableDropdownItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return SearchableDropdownField<String>(
      label: sheetTitle,
      sheetTitle: sheetTitle,
      showFieldLabel: false,
      value: value,
      hintText: hint,
      items: items,
      enabled: !_isSubmitting && !_isLoadingDropdowns && items.isNotEmpty,
      isLoading: _isLoadingDropdowns,
      fieldValidator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildPickerField({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: (text.contains('-') ||
                          text.contains(':') ||
                          text.contains('AM') ||
                          text.contains('PM'))
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
