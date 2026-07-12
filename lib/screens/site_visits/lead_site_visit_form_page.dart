// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';

class LeadSiteVisitFormPage extends StatefulWidget {
  const LeadSiteVisitFormPage({super.key});

  @override
  State<LeadSiteVisitFormPage> createState() => _LeadSiteVisitFormPageState();
}

enum _LeadSiteVisitSection { leadDetails, siteVisit }

class _LeadSiteVisitFormPageState extends State<LeadSiteVisitFormPage> {
  static const List<String> _configurationOptions = <String>[
    '1RK',
    '1BHK',
    '2BHK',
    '3BHK',
    '4BHK',
    'Penta House / Duplex',
    'Commercial shop',
    'Office space',
  ];

  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationPreferenceController = TextEditingController();
  final _configurationController = TextEditingController();
  final _callbackTimeController = TextEditingController();
  final _nextFollowUpTimeController = TextEditingController();
  final _leadNotesController = TextEditingController();
  final _notesController = TextEditingController();
  final _projectNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingAssignees = true;
  bool _isLoadingLeadSources = true;
  bool _isLoadingProjects = true;
  bool _isLoadingUserContext = true;
  bool _transportArranged = false;
  bool _useManualProjectInput = false;

  String? _assigneeLoadError;
  String? _leadSourceLoadError;
  String? _projectLoadError;
  String? _selectedAssigneeId;
  String? _selectedLeadSource;
  String? _selectedProjectId;
  String _currentUserRole = '';
  String? _currentUserId;
  DateTime? _selectedCallbackTime;
  DateTime? _selectedNextFollowUpTime;
  DateTime? _selectedVisitDate;
  TimeOfDay? _selectedVisitTime;
  List<String> _selectedConfigurations = <String>[];
  _LeadSiteVisitSection _selectedSection = _LeadSiteVisitSection.leadDetails;

  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_LeadSourceOption> _leadSourceOptions = const <_LeadSourceOption>[];
  List<_ProjectOption> _projectOptions = const <_ProjectOption>[];

  bool get _isLeadSection =>
      _selectedSection == _LeadSiteVisitSection.leadDetails;

  @override
  void initState() {
    super.initState();
    _projectNameController.addListener(_syncProjectSelectionMode);
    _loadCurrentUserContext();
    _loadAssigneeOptions();
    _loadLeadSourceOptions();
    _loadProjectOptions();
  }

  @override
  void dispose() {
    _projectNameController.removeListener(_syncProjectSelectionMode);
    _nameController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _emailController.dispose();
    _budgetController.dispose();
    _locationPreferenceController.dispose();
    _configurationController.dispose();
    _callbackTimeController.dispose();
    _nextFollowUpTimeController.dispose();
    _leadNotesController.dispose();
    _notesController.dispose();
    _projectNameController.dispose();
    super.dispose();
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
        _isLoadingUserContext = false;
        _selectedAssigneeId = _resolveAssigneeSelection(_assigneeOptions);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingUserContext = false;
      });
    }
  }

  Future<void> _loadAssigneeOptions() async {
    setState(() {
      _isLoadingAssignees = true;
      _assigneeLoadError = null;
    });

    try {
      final users = await _authProvider.assignmentUsers(
        token: _authProvider.currentAuthToken,
      );
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

      if (!mounted) {
        return;
      }
      setState(() {
        _assigneeOptions = uniqueOptions;
        _selectedAssigneeId ??= _resolveAssigneeSelection(uniqueOptions);
        _isLoadingAssignees = false;
      });
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

  Future<void> _openDateTimePicker({
    required void Function(DateTime value) onSelected,
    DateTime? initialDateTime,
  }) async {
    final now = DateTime.now();
    final seed = initialDateTime ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(now) ? now : seed,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null || !mounted) {
      return;
    }

    onSelected(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  Future<void> _pickCallbackTime() async {
    await _openDateTimePicker(
      initialDateTime: _selectedCallbackTime,
      onSelected: (value) {
        setState(() {
          _selectedCallbackTime = value;
          _callbackTimeController.text = _formatDateTime(value);
        });
      },
    );
  }

  Future<void> _pickNextFollowUpTime() async {
    await _openDateTimePicker(
      initialDateTime: _selectedNextFollowUpTime,
      onSelected: (value) {
        setState(() {
          _selectedNextFollowUpTime = value;
          _nextFollowUpTimeController.text = _formatDateTime(value);
        });
      },
    );
  }

  Future<void> _pickVisitDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedVisitDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedVisitDate = picked;
    });
  }

  Future<void> _pickVisitTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedVisitTime ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedVisitTime = picked;
    });
  }

  Future<void> _continueToVisitSection() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedSection = _LeadSiteVisitSection.siteVisit;
    });
  }

  Future<void> _submit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    final assignedTo = _resolveAssignedToForCreate();
    final projectId = _resolveSelectedProjectId();
    final projectName = _resolveSelectedProjectName();

    if (projectId.isEmpty) {
      if (projectName.isEmpty) {
        _showSnackBar('Project is required.');
        return;
      }

      final hasMatchingProject = _projectOptions.any(
        (project) =>
            project.name.trim().toLowerCase() == projectName.toLowerCase(),
      );
      if (_projectOptions.isNotEmpty && !hasMatchingProject) {
        _showSnackBar('Project not found, please select from the list');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _authProvider.createSiteVisitWithLead(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        alternatePhoneNumber: _alternatePhoneController.text.trim(),
        email: _emailController.text.trim(),
        source: _selectedLeadSource?.trim() ?? '',
        projectId: projectId,
        projectName: projectName,
        assignedTo: assignedTo,
        budget: _budgetController.text.trim(),
        locationPreference: _locationPreferenceController.text.trim(),
        configuration: _selectedConfigurations.join(', '),
        leadNotes: _leadNotesController.text.trim(),
        callbackTime: _callbackTimeController.text.trim(),
        nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
        visitDate: _selectedVisitDate == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(_selectedVisitDate!),
        visitTime: _selectedVisitTime == null
            ? ''
            : '${_selectedVisitTime!.hour.toString().padLeft(2, '0')}:${_selectedVisitTime!.minute.toString().padLeft(2, '0')}',
        notes: _notesController.text.trim(),
        transportArranged: _transportArranged,
        token: _authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(<String, dynamic>{
        ...response,
        'assigned_to_name': _selectedAssigneeLabel(assignedTo.trim()),
        'assigned_to': assignedTo.trim(),
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = AppErrorHandler.friendlyMessage(error);
      if (projectId.isEmpty &&
          projectName.isNotEmpty &&
          message == AppErrorHandler.notFoundMessage) {
        _showSnackBar('Project not found, please select from the list');
      } else {
        _showSnackBar(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final isActive = _readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    );
    if (!isActive) {
      return null;
    }

    final id = _readString(
      user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid'],
    );
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final combinedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    final displayName = combinedName.isNotEmpty
        ? combinedName
        : _readString(user['name'] ??
            user['full_name'] ??
            user['fullName'] ??
            user['email']);
    final roleLabel = _readRoleLabel(user);

    final baseName = displayName.isEmpty ? 'User $id' : displayName;
    return _AssigneeOption(
      id: id,
      name: roleLabel.isEmpty ? baseName : '$baseName ($roleLabel)',
    );
  }

  String _readRoleLabel(Map<String, dynamic> user) {
    final rawRole = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
    );
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

  String? _extractUserId(Map<String, dynamic> source) {
    for (final key in const ['id', 'user_id', 'userId', 'uuid']) {
      final value = _readString(source[key]);
      if (value.isNotEmpty) {
        return value;
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
    final shouldAssignToSelf = normalizedRole.isNotEmpty &&
        normalizedRole != RoleAccess.admin &&
        normalizedRole != RoleAccess.superAdmin &&
        (_currentUserId?.trim().isNotEmpty ?? false);

    if (shouldAssignToSelf) {
      return _currentUserId!.trim();
    }

    return '';
  }

  String _resolveSelectedProjectId() {
    if (_useManualProjectInput) {
      return '';
    }
    return _selectedProjectId?.trim() ?? '';
  }

  String _resolveSelectedProjectName() {
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

  String? _resolveAssigneeSelection(List<_AssigneeOption> options) {
    final currentSelection = _selectedAssigneeId;
    if (currentSelection != null &&
        options.any((option) => option.id == currentSelection)) {
      return currentSelection;
    }

    final shouldAssignToSelf = !RoleAccess.isSuperAdmin(_currentUserRole) &&
        !RoleAccess.isAdmin(_currentUserRole) &&
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

  String _selectedAssigneeLabel(String assigneeId) {
    for (final option in _assigneeOptions) {
      if (option.id == assigneeId) {
        return option.name;
      }
    }
    return 'You';
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

  String _formatDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  Future<void> _openConfigurationSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final selected = List<String>.from(_selectedConfigurations);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Configuration',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select one or more configurations.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _configurationOptions.length,
                          itemBuilder: (context, index) {
                            final option = _configurationOptions[index];
                            final isSelected = selected.contains(option);
                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                option,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    if (!selected.contains(option)) {
                                      selected.add(option);
                                    }
                                  } else {
                                    selected.remove(option);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(sheetContext)
                                  .pop(List<String>.from(selected)),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedConfigurations = result;
      _configurationController.text = result.join(', ');
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSectionTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _sectionTabItem(
              label: 'Lead Details',
              isActive: _isLeadSection,
              onTap: () {
                if (_isLeadSection) return;
                setState(() {
                  _selectedSection = _LeadSiteVisitSection.leadDetails;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _sectionTabItem(
              label: 'Site Visit',
              isActive: !_isLeadSection,
              onTap: () {
                if (!_isLeadSection) return;
                setState(() {
                  _selectedSection = _LeadSiteVisitSection.siteVisit;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTabItem({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _twoFields(
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hintText: 'Jane Smith',
              ),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hintText: '+919876543212',
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 12),
            _twoFields(
              _buildTextField(
                controller: _alternatePhoneController,
                label: 'Alternate Phone',
                hintText: '+919876543213',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'jane.smith@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 12),
            _twoFields(
              _buildTextField(
                controller: _budgetController,
                label: 'Budget',
                hintText: '1Cr+',
              ),
              _buildTextField(
                controller: _locationPreferenceController,
                label: 'Finding Location',
                hintText: 'Bandra',
              ),
            ),
            const SizedBox(height: 12),
            _buildConfigurationDropdown(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                    : (value) => _setManualProjectMode(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_useManualProjectInput)
              _buildProjectNameField()
            else
              _buildProjectDropdown(),
            const SizedBox(height: 12),
            _twoFields(
              _buildDateTimeField(
                controller: _callbackTimeController,
                label: 'Callback Time',
                hintText: 'dd-mm-yyyy --:--',
                onTap: _pickCallbackTime,
              ),
              _buildDateTimeField(
                controller: _nextFollowUpTimeController,
                label: 'Next Follow-up',
                hintText: 'dd-mm-yyyy --:--',
                onTap: _pickNextFollowUpTime,
              ),
            ),
            const SizedBox(height: 12),
            _buildLeadSourceDropdown(),
            const SizedBox(height: 12),
            _buildAssigneeDropdown(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _leadNotesController,
              label: 'Lead Notes',
              hintText: 'Interested in 3BHK units',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _continueToVisitSection,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Next'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitSection() {
    final visitDateText = _selectedVisitDate == null
        ? 'dd-mm-yyyy'
        : DateFormat('dd-MM-yyyy').format(_selectedVisitDate!);
    final visitTimeText = _selectedVisitTime == null
        ? '--:--'
        : _selectedVisitTime!.format(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _buildProjectDropdown(),
            const SizedBox(height: 12),
            _twoFields(
              _buildPickerField(
                label: 'Visit Date',
                text: visitDateText,
                icon: Icons.calendar_today_outlined,
                onTap: _pickVisitDate,
              ),
              _buildPickerField(
                label: 'Visit Time',
                text: visitTimeText,
                icon: Icons.access_time,
                onTap: _pickVisitTime,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text(
                  'Transport arranged for client',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                value: _transportArranged,
                onChanged: _isSubmitting
                    ? null
                    : (val) => setState(() {
                          _transportArranged = val ?? false;
                        }),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hintText: 'Bring brochure and price list',
              minLines: 4,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _selectedSection =
                                  _LeadSiteVisitSection.leadDetails;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _twoFields(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
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
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required VoidCallback onTap,
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
          onTap: _isSubmitting ? null : onTap,
          decoration: _fieldDecoration(hintText: hintText).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerField({
    required String label,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
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
        InkWell(
          onTap: _isSubmitting ? null : onTap,
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
        ),
      ],
    );
  }

  Widget _buildLeadSourceDropdown() {
    return SearchableDropdownField<String>(
      label: 'Lead Source',
      value: _selectedLeadSource,
      hintText: _isLoadingLeadSources
          ? 'Loading lead sources...'
          : _leadSourceOptions.isEmpty
              ? 'No lead sources available'
              : 'Select lead source',
      items: _leadSourceOptions
          .map(
            (option) => SearchableDropdownItem<String>(
              value: option.name,
              label: option.name,
            ),
          )
          .toList(),
      isLoading: _isLoadingLeadSources,
      errorText: _leadSourceLoadError,
      onRetry: _loadLeadSourceOptions,
      onChanged: (value) {
        setState(() {
          _selectedLeadSource = value;
        });
      },
    );
  }

  Widget _buildAssigneeDropdown() {
    return SearchableDropdownField<String>(
      label: 'Assign To',
      value: _selectedAssigneeId,
      hintText: _isLoadingAssignees
          ? 'Loading assignees...'
          : _assigneeOptions.isEmpty
              ? 'No assignee options available'
              : 'Select team member',
      items: _assigneeOptions
          .map(
            (user) => SearchableDropdownItem<String>(
              value: user.id,
              label: user.name,
            ),
          )
          .toList(),
      isLoading: _isLoadingAssignees,
      errorText: _assigneeLoadError,
      helperText: _isLoadingUserContext ? 'Loading team members...' : null,
      onRetry: _loadAssigneeOptions,
      onChanged: (value) {
        setState(() {
          _selectedAssigneeId = value;
        });
      },
    );
  }

  Widget _buildProjectDropdown() {
    return SearchableDropdownField<String>(
      label: 'Project Name',
      value: _selectedProjectId,
      hintText: _isLoadingProjects
          ? 'Loading projects...'
          : _projectOptions.isEmpty
              ? 'No projects available'
              : 'Type to search projects...',
      items: _projectOptions
          .map(
            (project) => SearchableDropdownItem<String>(
              value: project.id,
              label: project.name,
            ),
          )
          .toList(),
      isLoading: _isLoadingProjects,
      errorText: _projectLoadError,
      onRetry: _loadProjectOptions,
      onClear: () {
        setState(() {
          _selectedProjectId = null;
        });
      },
      onChanged: (value) {
        setState(() {
          _selectedProjectId = value;
          if (value != null && value.isNotEmpty) {
            _projectNameController.clear();
          }
        });
      },
    );
  }

  Widget _buildConfigurationDropdown() {
    final hasSelection = _selectedConfigurations.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuration',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isSubmitting ? null : _openConfigurationSheet,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(
              hintText: 'Select configuration',
            ).copyWith(
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSelection)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Clear selection',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedConfigurations = <String>[];
                                _configurationController.clear();
                              });
                            },
                    ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            child: Text(
              hasSelection
                  ? _selectedConfigurations.join(', ')
                  : 'Select configuration',
              style: TextStyle(
                color: hasSelection
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual Project Name',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
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
          decoration: _fieldDecoration(
            hintText: 'Type project name here',
          ),
        ),
      ],
    );
  }

  void _syncProjectSelectionMode() {
    if (_projectNameController.text.trim().isNotEmpty &&
        (_selectedProjectId?.isNotEmpty ?? false)) {
      setState(() {
        _selectedProjectId = null;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: 'Create Lead + Site Visit',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildSectionTabs(),
            ),
            Expanded(
              child: IndexedStack(
                index: _isLeadSection ? 0 : 1,
                children: [
                  _buildLeadSection(),
                  _buildVisitSection(),
                ],
              ),
            ),
          ],
        ),
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
