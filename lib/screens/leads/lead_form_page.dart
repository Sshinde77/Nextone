// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';

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
  final _callbackTimeController = TextEditingController();
  final _nextFollowUpTimeController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationPreferenceController = TextEditingController();
  final _configurationController = TextEditingController();
  final _followUpTaskTitleController = TextEditingController();
  final _paymentProofUrlController = TextEditingController();
  final _paymentProofAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _projectNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingAssignees = true;
  bool _isLoadingLeadSources = true;
  bool _isLoadingLeadStatuses = true;
  bool _isLoadingProjects = true;
  bool _isLoadingLeadDetails = false;
  String? _assigneeLoadError;
  String? _leadSourceLoadError;
  String? _leadStatusLoadError;
  String? _projectLoadError;
  String? _selectedAssigneeId;
  String? _selectedLeadSource;
  String? _selectedLeadStatus;
  String? _selectedProjectId;
  bool _useManualProjectInput = false;
  String _currentUserRole = '';
  String? _currentUserId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_LeadSourceOption> _leadSourceOptions = const <_LeadSourceOption>[];
  List<_LeadStatusOption> _leadStatusOptions = const <_LeadStatusOption>[];
  List<_ProjectOption> _projectOptions = const <_ProjectOption>[];
  List<String> _selectedConfigurations = <String>[];
  PlatformFile? _selectedCallRecordingFile;
  List<PlatformFile> _selectedPaymentProofFiles = const <PlatformFile>[];
  List<PlatformFile> _selectedPhotoFiles = const <PlatformFile>[];
  DateTime? _selectedSiteVisitDate;
  TimeOfDay? _selectedSiteVisitTime;
  bool _transportArranged = false;
  DateTime? _selectedFollowUpDueDate;
  String _selectedFollowUpPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _prefillLeadData();
    _projectNameController.addListener(_syncProjectSelectionMode);
    _loadLeadDetails();
    _loadCurrentUserContext();
    _loadAssigneeOptions();
    _loadLeadSourceOptions();
    _loadLeadStatusOptions();
    _loadProjectOptions();
  }

  @override
  void dispose() {
    _projectNameController.removeListener(_syncProjectSelectionMode);
    _nameController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _emailController.dispose();
    _callbackTimeController.dispose();
    _nextFollowUpTimeController.dispose();
    _budgetController.dispose();
    _locationPreferenceController.dispose();
    _configurationController.dispose();
    _followUpTaskTitleController.dispose();
    _paymentProofUrlController.dispose();
    _paymentProofAmountController.dispose();
    _notesController.dispose();
    _projectNameController.dispose();
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
    _selectedLeadStatus = _readString(data['status'] ?? data['stage']);
    _callbackTimeController.text = _readString(
      data['callback_time'] ?? data['callbackTime'],
    );
    _nextFollowUpTimeController.text = _readString(
      data['next_followup_time'] ??
          data['next_follow_up_time'] ??
          data['nextFollowUpTime'],
    );
    _selectedSiteVisitDate = _tryParseDate(
      data['visit_date'] ?? data['visitDate'],
    );
    _selectedSiteVisitTime = _tryParseTime(
      data['visit_time'] ?? data['visitTime'],
    );
    _transportArranged =
        _readBool(data['transport_arranged'] ?? data['transportArranged']);
    _followUpTaskTitleController.text = _readString(
      data['title'] ?? data['task_title'] ?? data['taskTitle'],
    );
    _selectedFollowUpDueDate = _tryParseDateTime(
      _readString(data['due_date'] ?? data['dueDate']),
    );
    final normalizedPriority =
        _readString(data['priority']).trim().toLowerCase();
    if (normalizedPriority == 'high' ||
        normalizedPriority == 'medium' ||
        normalizedPriority == 'low') {
      _selectedFollowUpPriority = normalizedPriority;
    }
    _budgetController.text = _readString(
      data['budget'] ?? data['budget_value'] ?? data['budget_range'],
    );
    _locationPreferenceController.text = _readString(
      data['location_preference'] ?? data['locationPreference'],
    );
    _selectedConfigurations = _normalizeConfigurationValues(
      data['configuration'] ?? data['configurations'],
    );
    _configurationController.text = _selectedConfigurations.join(', ');
    _paymentProofUrlController.text = _readString(
      data['payment_proof_url'] ??
          data['paymentProofUrl'] ??
          data['payment_proof'],
    );
    _paymentProofAmountController.text = _readString(
      data['payment_proof_amount'] ??
          data['paymentProofAmount'] ??
          data['amount'],
    );
    _notesController.text = _readString(data['notes']);

    final paymentProofs = data['payment_proofs'] ?? data['paymentProofs'];
    if (_paymentProofUrlController.text.isEmpty && paymentProofs is List) {
      for (final item in paymentProofs.whereType<Map>()) {
        final proof = item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final proofUrl = _readString(
          proof['url'] ??
              proof['payment_proof_url'] ??
              proof['file_url'] ??
              proof['path'],
        );
        if (proofUrl.isNotEmpty) {
          _paymentProofUrlController.text = proofUrl;
        }
        final proofAmount = _readString(
          proof['amount'] ?? proof['payment_proof_amount'],
        );
        if (_paymentProofAmountController.text.isEmpty &&
            proofAmount.isNotEmpty) {
          _paymentProofAmountController.text = proofAmount;
        }
        if (_paymentProofUrlController.text.isNotEmpty ||
            _paymentProofAmountController.text.isNotEmpty) {
          break;
        }
      }
    }

    final project = data['project'];
    if (project is Map<String, dynamic>) {
      _selectedProjectId = _readString(
        project['id'] ??
            project['project_id'] ??
            project['projectId'] ??
            project['uuid'],
      );
      _projectNameController.text = _readString(
        project['name'] ?? project['project_name'],
      );
    } else {
      _selectedProjectId = _readString(
        data['project_id'] ?? data['projectId'] ?? data['project_uuid'],
      );
      _projectNameController.text = _readString(
        data['project_name'] ?? data['projectName'],
      );
    }
    if (_selectedProjectId != null && _selectedProjectId!.isEmpty) {
      _selectedProjectId = null;
    }
    if (_projectNameController.text.isEmpty) {
      _projectNameController.text = _readString(
        data['project_name'] ?? data['projectName'],
      );
    }
    _useManualProjectInput =
        _selectedProjectId == null || _selectedProjectId!.trim().isEmpty;

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

  Future<void> _loadLeadStatusOptions() async {
    setState(() {
      _isLoadingLeadStatuses = true;
      _leadStatusLoadError = null;
    });

    try {
      final items = await _authProvider.leadStatusesConfig(
        token: _authProvider.currentAuthToken,
      );
      final options = items
          .map(_LeadStatusOption.fromApi)
          .where((option) => option.isActive && option.label.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) {
        return;
      }

      setState(() {
        _leadStatusOptions = options;
        _isLoadingLeadStatuses = false;
        if (_selectedLeadStatus != null &&
            _selectedLeadStatus!.isNotEmpty &&
            !options.any(
              (option) =>
                  option.key == _selectedLeadStatus ||
                  option.label == _selectedLeadStatus,
            )) {
          _selectedLeadStatus = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLeadStatuses = false;
        _leadStatusOptions = const <_LeadStatusOption>[];
        _leadStatusLoadError = AppErrorHandler.friendlyMessage(error);
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
    final shouldAssignToSelf = normalizedRole.isNotEmpty &&
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

  void _syncProjectSelectionMode() {
    if (_useManualProjectInput &&
        _projectNameController.text.trim().isNotEmpty &&
        (_selectedProjectId?.isNotEmpty ?? false)) {
      setState(() {
        _selectedProjectId = null;
      });
    }
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

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final isActive = _readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    );
    if (!isActive) {
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

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    return '';
  }

  List<String> _normalizeConfigurationValues(dynamic value) {
    String? matchOption(String candidate) {
      final normalizedCandidate = candidate.trim().toLowerCase();
      for (final option in _configurationOptions) {
        if (option.toLowerCase() == normalizedCandidate) {
          return option;
        }
      }
      return null;
    }

    final resolved = <String>[];

    void addIfValid(String candidate) {
      final matchedOption = matchOption(candidate);
      if (matchedOption != null && !resolved.contains(matchedOption)) {
        resolved.add(matchedOption);
      }
    }

    if (value is List) {
      for (final item in value) {
        addIfValid(_readString(item));
      }
      return resolved;
    }

    final normalized = _readString(value);
    if (normalized.isEmpty) {
      return resolved;
    }

    for (final item in normalized.split(',')) {
      addIfValid(item);
    }
    return resolved;
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

  Future<void> _pickCallRecordingFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>[
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'webm'
      ],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedCallRecordingFile = picked.files.first;
    });
  }

  Future<void> _pickPaymentProofFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>[
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _selectedPaymentProofFiles = List<PlatformFile>.from(picked.files);
      if (_paymentProofUrlController.text.trim().isEmpty) {
        _paymentProofUrlController.text =
            picked.files.first.path?.trim() ?? _paymentProofUrlController.text;
      }
    });
  }

  Future<void> _pickPhotoFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _selectedPhotoFiles = List<PlatformFile>.from(picked.files);
    });
  }

  bool get _isEoiStatus {
    final normalized = (_selectedLeadStatus ?? '').trim().toLowerCase();
    return normalized == 'eoi';
  }

  String get _normalizedSelectedStatusLabel {
    final selectedValue = (_selectedLeadStatus ?? '').trim();
    if (selectedValue.isEmpty) {
      return '';
    }

    for (final option in _leadStatusOptions) {
      if (option.key == selectedValue || option.label == selectedValue) {
        return option.label.trim().toLowerCase();
      }
    }

    return selectedValue.toLowerCase();
  }

  bool get _isSiteVisitScheduledStatus {
    final normalizedKey = (_selectedLeadStatus ?? '').trim().toLowerCase();
    final normalizedLabel = _normalizedSelectedStatusLabel;
    return (normalizedKey.contains('site') &&
            normalizedKey.contains('visit') &&
            (normalizedKey.contains('schedule') ||
                normalizedKey.contains('scheduled'))) ||
        (normalizedLabel.contains('site') &&
            normalizedLabel.contains('visit') &&
            (normalizedLabel.contains('schedule') ||
                normalizedLabel.contains('scheduled')));
  }

  bool get _isFollowUpStatus {
    final normalizedKey = (_selectedLeadStatus ?? '').trim().toLowerCase();
    final normalizedLabel = _normalizedSelectedStatusLabel;
    return normalizedKey == 'followup' ||
        normalizedKey.contains('follow_up') ||
        normalizedKey.contains('follow-up') ||
        normalizedKey.contains('follow up') ||
        normalizedLabel == 'followup' ||
        normalizedLabel.contains('follow-up') ||
        normalizedLabel.contains('follow up');
  }

  List<Map<String, dynamic>> _buildPaymentProofPayload() {
    return _selectedPaymentProofFiles
        .map(
          (file) => <String, dynamic>{
            'url': file.path?.trim() ?? '',
            'name': file.name.trim(),
            'amount': _paymentProofAmountController.text.trim(),
          },
        )
        .where((item) => (_readString(item['url'])).isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildPhotoPayload() {
    return _selectedPhotoFiles
        .map(
          (file) => <String, dynamic>{
            'url': file.path?.trim() ?? '',
            'name': file.name.trim(),
          },
        )
        .where((item) => (_readString(item['url'])).isNotEmpty)
        .toList(growable: false);
  }

  String? _extractLeadId(dynamic value) {
    if (value is Map<String, dynamic>) {
      final direct = _readString(
        value['id'] ?? value['lead_id'] ?? value['leadId'] ?? value['uuid'],
      );
      if (direct.isNotEmpty) {
        return direct;
      }
      final nested = value['data'];
      if (nested is Map<String, dynamic>) {
        return _extractLeadId(nested);
      }
    }
    return null;
  }

  Future<void> _uploadSelectedCallRecording(String leadId) async {
    final file = _selectedCallRecordingFile;
    if (file == null) {
      return;
    }

    final path = file.path?.trim() ?? '';
    if (path.isEmpty) {
      throw Exception('Unable to access the selected audio file.');
    }

    await _authProvider.uploadLeadCallRecording(
      id: leadId,
      filePath: path,
      phoneNumber: _phoneController.text.trim(),
      name: file.name.trim().isEmpty ? 'Call recording' : file.name.trim(),
      token: _authProvider.currentAuthToken,
    );
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
      final assignedTo = widget.isEditMode
          ? _selectedAssigneeId?.trim() ?? ''
          : _resolveAssignedToForCreate();
      final projectId = _resolveSelectedProjectId();
      final projectName = _resolveSelectedProjectName();

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
          status: _selectedLeadStatus?.trim() ?? '',
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          assignedTo: assignedTo,
          projectId: projectId,
          projectName: projectName,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          configuration: _configurationController.text.trim(),
          paymentProofUrl:
              _isEoiStatus ? _paymentProofUrlController.text.trim() : '',
          paymentProofAmount:
              _isEoiStatus ? _paymentProofAmountController.text.trim() : '',
          paymentProof: _isEoiStatus ? _buildPaymentProofPayload() : const [],
          photos: _isEoiStatus ? _buildPhotoPayload() : const [],
          token: _authProvider.currentAuthToken,
        );
        await _uploadSelectedCallRecording(leadId);
      } else if (_isSiteVisitScheduledStatus) {
        if (_selectedSiteVisitDate == null) {
          _showSnackBar('Please select the visit date.');
          return;
        }
        if (_selectedSiteVisitTime == null) {
          _showSnackBar('Please select the visit time.');
          return;
        }

        final createdLead = await _authProvider.createSiteVisitWithLead(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          alternatePhoneNumber: _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _resolveSelectedLeadSource(),
          projectId: projectId,
          projectName: projectName,
          assignedTo: assignedTo,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          configuration: _configurationController.text.trim(),
          leadNotes: _notesController.text.trim(),
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          visitDate: _formatDateOnly(_selectedSiteVisitDate!),
          visitTime: _formatTimeOfDay(_selectedSiteVisitTime!),
          notes: _notesController.text.trim(),
          transportArranged: _transportArranged,
          token: _authProvider.currentAuthToken,
        );
        final createdLeadId = _extractLeadId(createdLead);
        if (createdLeadId == null || createdLeadId.isEmpty) {
          throw Exception(
              'Lead created but call recording could not be attached.');
        }
        await _uploadSelectedCallRecording(createdLeadId);
      } else if (_isFollowUpStatus) {
        if (_followUpTaskTitleController.text.trim().isEmpty) {
          _showSnackBar('Please enter the follow-up task title.');
          return;
        }
        if (_selectedFollowUpDueDate == null) {
          _showSnackBar('Please select the follow-up due date and time.');
          return;
        }

        final createdLead = await _authProvider.createLeadWithFollowUp(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          alternatePhoneNumber: _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _resolveSelectedLeadSource(),
          projectId: projectId,
          projectName: projectName,
          assignedTo: assignedTo,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          configuration: _configurationController.text.trim(),
          leadNotes: _notesController.text.trim(),
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          title: _followUpTaskTitleController.text.trim(),
          dueDate: _formatDateTime(_selectedFollowUpDueDate!),
          priority: _selectedFollowUpPriority,
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
        final createdLeadId = _extractLeadId(createdLead);
        if (createdLeadId == null || createdLeadId.isEmpty) {
          throw Exception(
              'Lead created but call recording could not be attached.');
        }
        await _uploadSelectedCallRecording(createdLeadId);
      } else {
        final createdLead = await _authProvider.createLead(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          alternatePhoneNumber: _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          source: _resolveSelectedLeadSource(),
          status: _selectedLeadStatus?.trim() ?? '',
          callbackTime: _callbackTimeController.text.trim(),
          nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
          assignedTo: assignedTo,
          projectId: projectId,
          projectName: projectName,
          budget: _budgetController.text.trim(),
          locationPreference: _locationPreferenceController.text.trim(),
          configuration: _configurationController.text.trim(),
          notes: _notesController.text.trim(),
          paymentProofUrl:
              _isEoiStatus ? _paymentProofUrlController.text.trim() : '',
          paymentProofAmount:
              _isEoiStatus ? _paymentProofAmountController.text.trim() : '',
          paymentProof: _isEoiStatus ? _buildPaymentProofPayload() : const [],
          photos: _isEoiStatus ? _buildPhotoPayload() : const [],
          token: _authProvider.currentAuthToken,
        );
        final createdLeadId = _extractLeadId(createdLead);
        if (createdLeadId == null || createdLeadId.isEmpty) {
          throw Exception(
              'Lead created but call recording could not be attached.');
        }
        await _uploadSelectedCallRecording(createdLeadId);
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

  DateTime? _tryParseDate(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  TimeOfDay? _tryParseTime(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return null;
    }
    final parts = raw.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  String _formatDateOnly(DateTime value) {
    final localDate = DateTime(value.year, value.month, value.day);
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickSiteVisitDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedSiteVisitDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    setState(() {
      _selectedSiteVisitDate = pickedDate;
    });
  }

  Future<void> _pickSiteVisitTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedSiteVisitTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    setState(() {
      _selectedSiteVisitTime = pickedTime;
    });
  }

  Future<void> _pickFollowUpDueDateTime() async {
    final now = DateTime.now();
    final seed = _selectedFollowUpDueDate ?? now.add(const Duration(hours: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(now) ? now : seed,
      firstDate: DateTime(now.year, now.month, now.day),
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

    final dueDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (dueDate.isBefore(now)) {
      _showSnackBar('Please select a future date and time.');
      return;
    }

    setState(() {
      _selectedFollowUpDueDate = dueDate;
      _nextFollowUpTimeController.text = _formatDateTime(dueDate);
    });
  }

  String _formatDisplayDate(DateTime? value) {
    if (value == null) {
      return 'Select date';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDisplayTime(TimeOfDay? value) {
    if (value == null) {
      return '10:00';
    }
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _resetConditionalStatusFields() {
    _selectedSiteVisitDate = null;
    _selectedSiteVisitTime = null;
    _transportArranged = false;
    _selectedFollowUpDueDate = null;
    _selectedFollowUpPriority = 'medium';
    _followUpTaskTitleController.clear();
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
                            : (value) => _setManualProjectMode(value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_useManualProjectInput)
                      _buildTextField(
                        controller: _projectNameController,
                        label: 'Project Name',
                        hintText: 'Type project name here',
                        validator: (value) {
                          if (!_useManualProjectInput) {
                            return null;
                          }
                          if ((value ?? '').trim().isEmpty) {
                            return 'Project name is required';
                          }
                          return null;
                        },
                      )
                    else
                      _buildProjectDropdown(),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
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
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      label: 'Status',
                      value: _selectedLeadStatus,
                      hintText: _isLoadingLeadStatuses
                          ? 'Loading statuses...'
                          : _leadStatusOptions.isEmpty
                              ? 'No statuses available'
                              : 'Select status',
                      items: _leadStatusOptions
                          .map(
                            (option) => SearchableDropdownItem<String>(
                              value: option.key,
                              label: option.label,
                            ),
                          )
                          .toList(),
                      isLoading: _isLoadingLeadStatuses,
                      errorText: _leadStatusLoadError,
                      onRetry: _loadLeadStatusOptions,
                      onChanged: (value) {
                        setState(() {
                          final previousIsSiteVisit = _isSiteVisitScheduledStatus;
                          final previousIsFollowUp = _isFollowUpStatus;
                          _selectedLeadStatus = value;
                          final nextIsSiteVisit = _isSiteVisitScheduledStatus;
                          final nextIsFollowUp = _isFollowUpStatus;
                          if ((!nextIsSiteVisit && previousIsSiteVisit) ||
                              (!nextIsFollowUp && previousIsFollowUp)) {
                            _resetConditionalStatusFields();
                          }
                          if (!_isEoiStatus) {
                            _paymentProofUrlController.clear();
                            _paymentProofAmountController.clear();
                            _selectedPaymentProofFiles = const <PlatformFile>[];
                            _selectedPhotoFiles = const <PlatformFile>[];
                          }
                        });
                      },
                    ),
                    if (_isSiteVisitScheduledStatus) ...[
                      const SizedBox(height: 12),
                      _buildSiteVisitDetailsCard(),
                    ],
                    if (_isFollowUpStatus) ...[
                      const SizedBox(height: 12),
                      _buildFollowUpDetailsCard(),
                    ],
                    if (_isEoiStatus) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFE3A3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EOI Documents',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildFilePickerCard(
                              title: 'EOI Front Page Photo',
                              subtitle: 'Optional',
                              buttonLabel: 'Upload EOI Front Page Photo',
                              emptyText: 'No front page photo selected',
                              files: _selectedPhotoFiles,
                              onPick: _pickPhotoFiles,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _paymentProofUrlController,
                              label: 'Payment Proof URL',
                              hintText:
                                  '/uploads/payment-proofs/payment_proof_receipt_123.jpg',
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _paymentProofAmountController,
                              label: 'Payment Proof Amount',
                              hintText: '50000',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            _buildFilePickerCard(
                              title: 'Payment Proof',
                              subtitle: 'Optional',
                              buttonLabel: 'Upload Payment Proof',
                              emptyText: 'No payment proof selected',
                              files: _selectedPaymentProofFiles,
                              onPick: _pickPaymentProofFiles,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_isSiteVisitScheduledStatus && !_isFollowUpStatus) ...[
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
                    ],
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
                      label: 'Finding Location',
                      hintText: 'Andheri West',
                    ),
                    const SizedBox(height: 12),
                    _buildConfigurationDropdown(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Remark',
                      hintText: 'Interested buyer, wants sea view',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Call Recording',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _pickCallRecordingFile,
                                icon: const Icon(Icons.attach_file_rounded),
                                label: const Text('Upload File'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCallRecordingFile?.name ??
                                'No file selected',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
    return SearchableDropdownField<String>(
      label: 'Assigned To',
      value: _selectedAssigneeId,
      hintText: _isLoadingAssignees
          ? 'Loading assignees...'
          : _assigneeOptions.isEmpty
              ? 'No assignee options available'
              : 'Select assignee',
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
      helperText: _isLoadingAssignees ? 'Loading team members...' : null,
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
              : 'Select project',
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

  Widget _buildSiteVisitDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Site Visit Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPickerField(
                  label: 'Visit Date *',
                  value: _formatDisplayDate(_selectedSiteVisitDate),
                  isPlaceholder: _selectedSiteVisitDate == null,
                  onTap: _pickSiteVisitDate,
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPickerField(
                  label: 'Visit Time',
                  value: _formatDisplayTime(_selectedSiteVisitTime),
                  isPlaceholder: _selectedSiteVisitTime == null,
                  onTap: _pickSiteVisitTime,
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _transportArranged,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _transportArranged = value ?? false;
                    });
                  },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Transport arranged for client',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.call_rounded, size: 18, color: Color(0xFF9333EA)),
              SizedBox(width: 8),
              Text(
                'Follow-up Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9333EA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _followUpTaskTitleController,
            label: 'Task Title',
            hintText: 'Follow up with lead',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPickerField(
                  label: 'Due Date *',
                  value: _formatDisplayDate(_selectedFollowUpDueDate),
                  isPlaceholder: _selectedFollowUpDueDate == null,
                  onTap: _pickFollowUpDueDateTime,
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPickerField(
                  label: 'Due Time',
                  value: _selectedFollowUpDueDate == null
                      ? '10:00'
                      : _formatDisplayTime(
                          TimeOfDay.fromDateTime(_selectedFollowUpDueDate!),
                        ),
                  isPlaceholder: _selectedFollowUpDueDate == null,
                  onTap: _pickFollowUpDueDateTime,
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchableDropdownField<String>(
            label: 'Priority',
            value: _selectedFollowUpPriority,
            hintText: 'Select priority',
            items: const <SearchableDropdownItem<String>>[
              SearchableDropdownItem<String>(value: 'high', label: 'High'),
              SearchableDropdownItem<String>(value: 'medium', label: 'Medium'),
              SearchableDropdownItem<String>(value: 'low', label: 'Low'),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFollowUpPriority = value ?? 'medium';
              });
            },
          ),
        ],
      ),
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

  Widget _buildPickerField({
    required String label,
    required String value,
    required bool isPlaceholder,
    required VoidCallback onTap,
    required IconData icon,
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
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(hintText: value).copyWith(
              suffixIcon: Icon(icon, size: 18),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isPlaceholder
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

  Widget _buildFilePickerCard({
    required String title,
    required String buttonLabel,
    required String emptyText,
    required List<PlatformFile> files,
    required VoidCallback onPick,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isSubmitting ? null : onPick,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(buttonLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (files.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
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

class _LeadStatusOption {
  const _LeadStatusOption({
    required this.key,
    required this.label,
    required this.sortOrder,
    required this.isActive,
  });

  final String key;
  final String label;
  final int sortOrder;
  final bool isActive;

  factory _LeadStatusOption.fromApi(Map<String, dynamic> json) {
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
      final normalized = readString(value).toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    int readInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(readString(value)) ?? 0;
    }

    final key = readString(json['key']);
    final label = readString(json['label']);

    return _LeadStatusOption(
      key: key,
      label: label.isEmpty ? key : label,
      sortOrder: readInt(json['sort_order'] ?? json['sortOrder']),
      isActive: readBool(json['is_active'] ?? json['isActive'] ?? true),
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
