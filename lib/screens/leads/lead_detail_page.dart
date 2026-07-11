// ignore_for_file: use_build_context_synchronously, unused_element

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/lead_detail_model.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailPage extends StatefulWidget {
  final String leadId;

  const LeadDetailPage({super.key, required this.leadId});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

enum _LeadTimelineTab { activity, recordings, reassignHistory }

class _LeadDetailPageState extends State<LeadDetailPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _statusNoteController = TextEditingController();
  final TextEditingController _reassignNoteController = TextEditingController();

  static const List<String> _statusFlow = <String>[
    'new',
    'contacted',
    'interested',
    'follow_up',
    'site_visit_scheduled',
    'site_visit_done',
    'negotiation',
    'booked',
    'lost',
  ];

  LeadDetailModel? _lead;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSubmittingStatus = false;
  bool _isSubmittingReassign = false;
  String? _selectedNextStatus;
  String? _selectedAssigneeId;
  String _currentRole = '';
  bool _hasPhoneAccess = false;
  bool _hasPendingPhoneRequest = false;
  String _accessiblePhone = '';
  bool _isPhoneVisible = false;
  bool _isCheckingPhoneAccess = false;
  bool _isLoadingTimeline = false;
  bool _isUploadingRecording = false;
  String? _timelineError;
  _LeadTimelineTab _selectedTimelineTab = _LeadTimelineTab.activity;
  final Set<String> _updatingRecordingIds = <String>{};
  final Set<String> _deletingRecordingIds = <String>{};
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_PipelineStatusOption> _pipelineStatuses =
      const <_PipelineStatusOption>[];
  List<_LeadActivityItem> _activityItems = const <_LeadActivityItem>[];
  List<_LeadRecordingItem> _recordingItems = const <_LeadRecordingItem>[];
  List<_LeadReassignmentItem> _reassignmentItems =
      const <_LeadReassignmentItem>[];
  String? _selectedPipelineStatusKey;

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _fetchLeadDetails();
    _loadAssigneeOptions();
    _loadPipelineStatuses();
    _loadLeadTimelineData();
  }

  @override
  void dispose() {
    _statusNoteController.dispose();
    _reassignNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeadDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final data = await _authProvider.leadDetail(id: widget.leadId);
      final lead = LeadDetailModel.fromJson(data);
      final normalizedCurrent = _normalizeStatus(lead.status);

      setState(() {
        _lead = lead;
        _selectedNextStatus ??= _firstStatusAfter(normalizedCurrent);
        _isPhoneVisible = false;
        _isLoading = false;
      });
      await _loadPhoneAccess();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppErrorHandler.friendlyMessage(e);
      });
    }
  }

  Future<void> _refreshPage() async {
    await _fetchLeadDetails();
    await _loadLeadTimelineData();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        if (_isAssociateRole &&
            _selectedTimelineTab == _LeadTimelineTab.reassignHistory) {
          _selectedTimelineTab = _LeadTimelineTab.activity;
        }
      });
      await _loadPhoneAccess();
    } catch (_) {
      // Phone visibility stays restricted if access cannot be resolved.
    }
  }

  Future<void> _loadPhoneAccess() async {
    if (_lead == null) {
      return;
    }
    final canViewByPermission = RoleAccess.canViewLeadPhones(_currentRole);
    if (canViewByPermission) {
      if (!mounted) return;
      setState(() {
        _hasPhoneAccess = true;
        _hasPendingPhoneRequest = false;
        _accessiblePhone = _lead!.phone;
        _isPhoneVisible = true;
      });
      return;
    }

    setState(() => _isCheckingPhoneAccess = true);
    try {
      final access = await _authProvider.phoneRevealCheck(
        leadId: widget.leadId,
        token: _authProvider.currentAuthToken,
      );
      final hasAccessRaw = access['has_access'];
      final hasAccess = hasAccessRaw is bool
          ? hasAccessRaw
          : (hasAccessRaw is num
              ? hasAccessRaw != 0
              : (hasAccessRaw is String &&
                  hasAccessRaw.trim().toLowerCase() == 'true'));
      final phone = _readString(
        access['phone'] ??
            access['lead_phone'] ??
            access['phone_number'] ??
            access['mobile'],
      );
      final hasPendingRequest = _isPendingRequest(access['request']);
      if (!mounted) return;
      setState(() {
        _hasPhoneAccess = hasAccess;
        _hasPendingPhoneRequest = hasPendingRequest;
        _accessiblePhone = phone.isNotEmpty ? phone : (_lead?.phone ?? '');
        if (hasAccess) {
          _isPhoneVisible = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPhoneAccess = false;
        _hasPendingPhoneRequest = false;
        _accessiblePhone = _lead?.phone ?? '';
        _isPhoneVisible = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingPhoneAccess = false);
      }
    }
  }

  bool get _isAssociateRole =>
      RoleAccess.normalize(_currentRole) == 'associate';

  Future<void> _loadLeadTimelineData() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingTimeline = true;
      _timelineError = null;
    });

    try {
      final activityFuture = _authProvider.leadActivity(
        id: widget.leadId,
        token: _authProvider.currentAuthToken,
      );
      final recordingsFuture = _authProvider.leadCallRecordings(
        id: widget.leadId,
        token: _authProvider.currentAuthToken,
      );
      final Future<List<Map<String, dynamic>>> reassignmentFuture =
          _isAssociateRole
              ? Future<List<Map<String, dynamic>>>.value(
                  const <Map<String, dynamic>>[],
                )
              : _authProvider
                  .leadReassignmentHistory(
                    id: widget.leadId,
                    token: _authProvider.currentAuthToken,
                    page: 1,
                    perPage: 20,
                  )
                  .then((result) => result.items);

      final activityResponse = await activityFuture;
      final recordingsResponse = await recordingsFuture;
      final reassignmentResult = await reassignmentFuture;

      final List<_LeadActivityItem> activity = activityResponse
          .map((item) => Map<String, dynamic>.from(item))
          .map(_LeadActivityItem.fromJson)
          .toList(growable: false);
      final List<_LeadRecordingItem> recordings = recordingsResponse
          .map((item) => Map<String, dynamic>.from(item))
          .map(_LeadRecordingItem.fromJson)
          .toList(growable: false);
      final List<_LeadReassignmentItem> reassignments = reassignmentResult
          .map((item) => Map<String, dynamic>.from(item))
          .map(_LeadReassignmentItem.fromJson)
          .toList(growable: false);

      if (!mounted) {
        return;
      }
      setState(() {
        _activityItems = activity;
        _recordingItems = recordings;
        _reassignmentItems = reassignments;
        _isLoadingTimeline = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTimeline = false;
        _timelineError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadAssigneeOptions() async {
    try {
      final users = await _authProvider.assignmentUsers(
        token: _authProvider.currentAuthToken,
      );
      final options = users
          .map(_assigneeFromApi)
          .where((u) => u != null)
          .cast<_AssigneeOption>()
          .toList();

      final uniqueById = <String, _AssigneeOption>{};
      for (final option in options) {
        uniqueById[option.id] = option;
      }
      final uniqueOptions = uniqueById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }
      setState(() {
        _assigneeOptions = uniqueOptions;
      });
    } catch (_) {
      // Keep UI usable even if users endpoint fails.
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

  Future<void> _makeCall(String phoneNumber) async {
    final launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail(String email) async {
    final launchUri = Uri(
      scheme: 'mailto',
      path: email.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendDetailsViaWhatsApp() async {
    final lead = _lead;
    if (lead == null) {
      return;
    }
    final phone = (_hasPhoneAccess ? _accessiblePhone : lead.phone).trim();
    if (phone.isEmpty || phone.toUpperCase() == 'N/A') {
      _showSnackBar('Phone number is not available.');
      return;
    }
    final message = Uri.encodeComponent(
      'Lead Details\n'
      'Name: ${lead.name}\n'
      'Phone: $phone\n'
      'Budget: ${lead.budget}\n'
      'Location: ${lead.locationPreference}\n'
      'Callback Time: ${_formatDateTimeValue(lead.callbackTime)}\n'
      'Next Follow-up: ${_formatDateTimeValue(lead.nextFollowupTime)}\n'
      'Status: ${lead.status}\n',
    );
    final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$sanitizedPhone?text=$message');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendDetailsViaEmail() async {
    final lead = _lead;
    if (lead == null) {
      return;
    }
    final email = lead.email.trim();
    if (email.isEmpty) {
      _showSnackBar('Email is not available.');
      return;
    }
    final subject = Uri.encodeComponent('Lead Details - ${lead.name}');
    final body = Uri.encodeComponent(
      'Lead Details\n\n'
      'Name: ${lead.name}\n'
      'Phone: ${_hasPhoneAccess ? _accessiblePhone : lead.phone}\n'
      'Budget: ${lead.budget}\n'
      'Location: ${lead.locationPreference}\n'
      'Callback Time: ${_formatDateTimeValue(lead.callbackTime)}\n'
      'Next Follow-up: ${_formatDateTimeValue(lead.nextFollowupTime)}\n'
      'Status: ${lead.status}\n',
    );
    final mailto = Uri.parse('mailto:$email?subject=$subject&body=$body');
    await launchUrl(mailto, mode: LaunchMode.externalApplication);
  }

  Future<void> _playRecording(_LeadRecordingItem item) async {
    final url = item.audioUrl.trim();
    if (url.isEmpty) {
      _showSnackBar('Recording file is not available.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('Recording link is not valid.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _uploadRecording() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed || _isUploadingRecording) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.first;
    final path = file.path?.trim() ?? '';
    if (path.isEmpty) {
      _showSnackBar('Unable to access the selected audio file.');
      return;
    }

    final defaultPhone = _lead?.phone.trim() ?? '';
    final defaultName =
        file.name.trim().isEmpty ? 'Call recording' : file.name.trim();

    setState(() {
      _isUploadingRecording = true;
    });

    try {
      await _authProvider.uploadLeadCallRecording(
        id: widget.leadId,
        filePath: path,
        phoneNumber: defaultPhone,
        name: defaultName,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Recording uploaded successfully.');
      await _loadLeadTimelineData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingRecording = false;
        });
      }
    }
  }

  Future<void> _openEditRecordingSheet(_LeadRecordingItem item) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) {
      return;
    }

    final nameController = TextEditingController(text: item.title);
    final phoneController = TextEditingController(text: item.phoneNumber);
    var isSaving = false;
    var shouldRefresh = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: 'Edit recording details',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: _fieldDecoration('Recording name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration('Phone e.g. +919876543210'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  FocusScope.of(sheetContext).unfocus();
                                  setSheetState(() {
                                    isSaving = true;
                                  });
                                  try {
                                    await _authProvider.updateLeadCallRecording(
                                      leadId: widget.leadId,
                                      recordingId: item.id,
                                      name: nameController.text.trim(),
                                      phoneNumber: phoneController.text.trim(),
                                      token: _authProvider.currentAuthToken,
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    shouldRefresh = true;
                                    Navigator.of(sheetContext).pop();
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    _showSnackBar(
                                      AppErrorHandler.friendlyMessage(error),
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {
                                        isSaving = false;
                                      });
                                    }
                                  } finally {}
                                },
                          child: Text(isSaving ? 'Saving...' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();

    if (!mounted || !shouldRefresh) {
      return;
    }

    _showSnackBar('Recording updated successfully.');
    await _loadLeadTimelineData();
  }

  Future<void> _deleteRecording(_LeadRecordingItem item) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Recording'),
          content: Text('Delete "${item.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingRecordingIds.add(item.id);
    });

    try {
      await _authProvider.deleteLeadCallRecording(
        leadId: widget.leadId,
        recordingId: item.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Recording deleted successfully.');
      await _loadLeadTimelineData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _deletingRecordingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _shareProjectDetails() async {
    final lead = _lead;
    if (lead == null) {
      return;
    }
    final details = 'Lead Details\n'
        'Name: ${lead.name}\n'
        'Phone: ${_hasPhoneAccess ? _accessiblePhone : lead.phone}\n'
        'Budget: ${lead.budget}\n'
        'Location: ${lead.locationPreference}\n'
        'Callback Time: ${_formatDateTimeValue(lead.callbackTime)}\n'
        'Next Follow-up: ${_formatDateTimeValue(lead.nextFollowupTime)}\n'
        'Status: ${lead.status}';
    await Clipboard.setData(ClipboardData(text: details));
    _showSnackBar('Project details copied to clipboard.');
  }

  Future<String?> _submitStatusChange() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return null;

    if (_selectedNextStatus == null || _selectedNextStatus!.isEmpty) {
      _showSnackBar('Please select the next status.');
      return null;
    }
    setState(() {
      _isSubmittingStatus = true;
    });

    try {
      final updatedStatus = _selectedNextStatus!;
      await _authProvider.updateLeadStatus(
        id: widget.leadId,
        status: updatedStatus,
        note: _statusNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _fetchLeadDetails();
      if (!mounted) {
        return null;
      }
      _showSnackBar('Lead status updated successfully.');
      return updatedStatus;
    } catch (e) {
      if (!mounted) {
        return null;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingStatus = false;
        });
      }
    }
  }

  Future<void> _submitReassignment() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    if (_selectedAssigneeId == null || _selectedAssigneeId!.isEmpty) {
      _showSnackBar('Please select an assignee.');
      return;
    }
    setState(() {
      _isSubmittingReassign = true;
    });

    try {
      await _authProvider.reassignLead(
        id: widget.leadId,
        assignedTo: _selectedAssigneeId!,
        note: _reassignNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _fetchLeadDetails();
      if (!mounted) {
        return;
      }
      _showSnackBar('Lead reassigned successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReassign = false;
        });
      }
    }
  }

  Future<void> _openStatusSheet() async {
    final current = _normalizeStatus(_lead?.status ?? '');
    final nextStatuses = _allowedTransitions(current);
    if (nextStatuses.isEmpty) {
      _showSnackBar('No further status transition available.');
      return;
    }

    if (_selectedNextStatus == null ||
        !nextStatuses.contains(_selectedNextStatus)) {
      _selectedNextStatus = nextStatuses.first;
    }
    _statusNoteController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildSheetContainer(
          title: 'Update Status',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdownField<String>(
                label: 'Status',
                sheetTitle: 'Update Status',
                value: _selectedNextStatus,
                hintText: 'Select status',
                items: nextStatuses
                    .map(
                      (status) => SearchableDropdownItem<String>(
                        value: status,
                        label: _prettyStatus(status),
                      ),
                    )
                    .toList(),
                enabled: !_isSubmittingStatus,
                onChanged: (value) =>
                    setState(() => _selectedNextStatus = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _statusNoteController,
                minLines: 2,
                maxLines: 3,
                decoration: _fieldDecoration('Add note (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmittingStatus
                      ? null
                      : () async {
                          final updatedStatus = await _submitStatusChange();
                          if (mounted && updatedStatus != null) {
                            Navigator.of(context).pop();
                            if (updatedStatus == 'follow_up') {
                              await _openCreateFollowUp();
                            } else if (updatedStatus ==
                                'site_visit_scheduled') {
                              await _openCreateSiteVisit();
                            }
                          }
                        },
                  child: Text(
                      _isSubmittingStatus ? 'Updating...' : 'Update Status'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openReassignSheet() async {
    if (_assigneeOptions.isEmpty) {
      _showSnackBar('No active assignee available.');
      return;
    }
    _reassignNoteController.clear();
    _selectedAssigneeId ??= _assigneeOptions.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildSheetContainer(
          title: 'Reassign Lead',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdownField<String>(
                label: 'Assignee',
                sheetTitle: 'Reassign Lead',
                value: _selectedAssigneeId,
                hintText: 'Select assignee',
                items: _assigneeOptions
                    .map(
                      (user) => SearchableDropdownItem<String>(
                        value: user.id,
                        label: user.name,
                      ),
                    )
                    .toList(),
                enabled: !_isSubmittingReassign,
                onChanged: (value) =>
                    setState(() => _selectedAssigneeId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reassignNoteController,
                minLines: 2,
                maxLines: 3,
                decoration: _fieldDecoration('Add note (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmittingReassign
                      ? null
                      : () async {
                          await _submitReassignment();
                          if (mounted) Navigator.of(context).pop();
                        },
                  child: Text(_isSubmittingReassign
                      ? 'Reassigning...'
                      : 'Reassign Lead'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateFollowUp() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'create',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowUpFormPage(initialLeadId: widget.leadId),
      ),
    );
    if (mounted) {
      await _fetchLeadDetails();
    }
  }

  Future<void> _openCreateSiteVisit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteVisitFormPage(initialLeadId: widget.leadId),
      ),
    );
    if (mounted) {
      await _fetchLeadDetails();
    }
  }

  Future<void> _loadPipelineStatuses() async {
    try {
      final items = await _authProvider.leadStatusesConfig(
        token: _authProvider.currentAuthToken,
      );
      final statuses = items.map(_PipelineStatusOption.fromApi).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _pipelineStatuses = statuses;
        _selectedPipelineStatusKey ??= _normalizeStatus(_lead?.status ?? '');
      });
    } catch (_) {
      // Keep page usable without status-config data.
    }
  }

  Future<void> _updatePipelineStage() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final next = _selectedPipelineStatusKey;
    if (next == null || next.isEmpty) {
      _showSnackBar('Please select stage.');
      return;
    }
    setState(() {
      _isSubmittingStatus = true;
    });
    try {
      await _authProvider.updateLeadStatus(
        id: widget.leadId,
        status: next,
        note: '',
        token: _authProvider.currentAuthToken,
      );
      await _fetchLeadDetails();
      if (!mounted) return;
      _showSnackBar('Stage updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingStatus = false;
        });
      }
    }
  }

  Future<void> _openManagePipelineStatusesDialog() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final labelController = TextEditingController();
    final colorController = TextEditingController(text: '#3B82F6');
    Color selectedColor = _parseHexColor(colorController.text);
    bool isSubmitting = false;

    Future<void> refresh() async {
      await _loadPipelineStatuses();
    }

    Future<void> createStatus(StateSetter setDialogState) async {
      final label = labelController.text.trim();
      if (label.isEmpty) {
        _showSnackBar('Please enter status label.');
        return;
      }
      setDialogState(() => isSubmitting = true);
      try {
        final key = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        await _authProvider.createLeadStatus(
          key: key,
          label: label,
          color: _toHexColor(selectedColor),
          sortOrder: _pipelineStatuses.length + 1,
          token: _authProvider.currentAuthToken,
        );
        labelController.clear();
        selectedColor = _parseHexColor('#3B82F6');
        colorController.text = _toHexColor(selectedColor);
        await refresh();
        if (!mounted) return;
        _showSnackBar('Pipeline status created.');
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(e));
      } finally {
        if (mounted) {
          setDialogState(() => isSubmitting = false);
        }
      }
    }

    Future<void> pickColor(StateSetter setDialogState) async {
      final picked = await _openColorPickerDialog(selectedColor);
      if (picked == null) return;
      setDialogState(() {
        selectedColor = picked;
        colorController.text = _toHexColor(picked);
      });
    }

    Future<void> editStatus(
      StateSetter setDialogState,
      _PipelineStatusOption status,
    ) async {
      final editLabelController = TextEditingController(text: status.label);
      Color editColor = _parseHexColor(status.color);
      bool editActive = status.isActive;
      bool editSubmitting = false;

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setEditState) {
              return AlertDialog(
                title: const Text('Edit Status'),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: editLabelController,
                        decoration: _fieldDecoration('Status label'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: _toHexColor(editColor)),
                              readOnly: true,
                              decoration: _fieldDecoration('Color'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final picked =
                                  await _openColorPickerDialog(editColor);
                              if (picked == null) return;
                              setEditState(() => editColor = picked);
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: editColor,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFD5DBE8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Active'),
                          const Spacer(),
                          Switch(
                            value: editActive,
                            onChanged: (v) =>
                                setEditState(() => editActive = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: editSubmitting
                        ? null
                        : () async {
                            final label = editLabelController.text.trim();
                            if (label.isEmpty) return;
                            setEditState(() => editSubmitting = true);
                            await _authProvider.updateLeadStatusConfig(
                              id: status.id,
                              label: label,
                              color: _toHexColor(editColor),
                              isActive: editActive,
                              token: _authProvider.currentAuthToken,
                            );
                            await refresh();
                            if (mounted) setDialogState(() {});
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
      editLabelController.dispose();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 640;
                final dialogWidth = width < 520 ? width * 0.98 : 720.0;
                final dialogHeight =
                    width < 520 ? constraints.maxHeight * 0.94 : 560.0;

                return Dialog(
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: dialogHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Manage Pipeline Statuses',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ADD CUSTOM STATUS',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: labelController,
                                  decoration:
                                      _fieldDecoration('e.g. Warm Lead'),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => pickColor(setDialogState),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 70,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.palette_outlined,
                                                size: 12),
                                            const SizedBox(width: 3),
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: selectedColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFD5DBE8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isSubmitting
                                            ? null
                                            : () =>
                                                createStatus(setDialogState),
                                        icon: const Icon(Icons.add, size: 12),
                                        label: Text(
                                            isSubmitting ? 'Adding...' : 'Add'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: labelController,
                                    decoration:
                                        _fieldDecoration('e.g. Warm Lead'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => pickColor(setDialogState),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 70,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.palette_outlined,
                                            size: 12),
                                        const SizedBox(width: 3),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: selectedColor,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: const Color(0xFFD5DBE8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => createStatus(setDialogState),
                                  icon: const Icon(Icons.add, size: 12),
                                  label:
                                      Text(isSubmitting ? 'Adding...' : 'Add'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: _pipelineStatuses.isEmpty
                                ? const Center(
                                    child: Text('No statuses found.',
                                        style: TextStyle(fontSize: 11)))
                                : DataTable(
                                    columnSpacing: isCompact ? 6 : 10,
                                    horizontalMargin: 4,
                                    headingRowHeight: 24,
                                    dataRowMinHeight: 36,
                                    dataRowMaxHeight: 40,
                                    headingTextStyle: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                    dataTextStyle: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textPrimary,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('STATUS LABEL')),
                                      DataColumn(label: Text('PREVIEW')),
                                      DataColumn(label: Text('VISIBILITY')),
                                      DataColumn(label: Text('ACTIONS')),
                                    ],
                                    rows: _pipelineStatuses
                                        .map(
                                          (s) => DataRow(
                                            cells: [
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 110,
                                                    maxWidth: 130,
                                                  ),
                                                  child: Text(
                                                    s.label,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _parseHexColor(s.color),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    s.label,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Switch(
                                                  value: s.isActive,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  onChanged: (v) async {
                                                    await _authProvider
                                                        .updateLeadStatusConfig(
                                                      id: s.id,
                                                      label: s.label,
                                                      color: s.color,
                                                      isActive: v,
                                                      token: _authProvider
                                                          .currentAuthToken,
                                                    );
                                                    await refresh();
                                                    setDialogState(() {});
                                                  },
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 15,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 24,
                                                        minHeight: 24,
                                                      ),
                                                      onPressed: () =>
                                                          editStatus(
                                                              setDialogState,
                                                              s),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 15,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 24,
                                                        minHeight: 24,
                                                      ),
                                                      onPressed: () async {
                                                        await _authProvider
                                                            .deleteLeadStatusConfig(
                                                          id: s.id,
                                                          token: _authProvider
                                                              .currentAuthToken,
                                                        );
                                                        await refresh();
                                                        setDialogState(() {});
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
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
      },
    );
    labelController.dispose();
    colorController.dispose();
  }

  static const List<Color> _statusColorPalette = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF6B7280),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
  ];

  Color _parseHexColor(String input) {
    final normalized = input.trim().replaceAll('#', '');
    final value = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFF3B82F6);
    return Color(parsed);
  }

  String _toHexColor(Color color) {
    final value =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  Future<Color?> _openColorPickerDialog(Color initial) async {
    Color temp = initial;
    int red = ((temp.r * 255).round()).clamp(0, 255);
    int green = ((temp.g * 255).round()).clamp(0, 255);
    int blue = ((temp.b * 255).round()).clamp(0, 255);
    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final dialogWidth = width < 380 ? width * 0.96 : 360.0;
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              content: SizedBox(
                width: dialogWidth,
                child: StatefulBuilder(
                  builder: (context, setColorState) {
                    void applyRgb() {
                      temp = Color.fromARGB(255, red, green, blue);
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: temp,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD5DBE8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _statusColorPalette
                              .map((c) => GestureDetector(
                                    onTap: () {
                                      setColorState(() {
                                        temp = c;
                                        red =
                                            ((c.r * 255).round()).clamp(0, 255);
                                        green =
                                            ((c.g * 255).round()).clamp(0, 255);
                                        blue =
                                            ((c.b * 255).round()).clamp(0, 255);
                                      });
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: c.toARGB32() == temp.toARGB32()
                                              ? AppColors.primary
                                              : const Color(0xFFD5DBE8),
                                          width: c.toARGB32() == temp.toARGB32()
                                              ? 2
                                              : 1,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        _buildRgbSlider(
                          label: 'R',
                          value: red.toDouble(),
                          onChanged: (v) => setColorState(() {
                            red = v.round();
                            applyRgb();
                          }),
                          display: '$red',
                        ),
                        _buildRgbSlider(
                          label: 'G',
                          value: green.toDouble(),
                          onChanged: (v) => setColorState(() {
                            green = v.round();
                            applyRgb();
                          }),
                          display: '$green',
                        ),
                        _buildRgbSlider(
                          label: 'B',
                          value: blue.toDouble(),
                          onChanged: (v) => setColorState(() {
                            blue = v.round();
                            applyRgb();
                          }),
                          display: '$blue',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_toHexColor(temp)}  RGB($red, $green, $blue)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(temp),
                  child: const Text('Use Color'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRgbSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required String display,
  }) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 34, child: Text(display)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Lead Details',
        showBackButton: true,
      ),
      bottomNavigationBar: _isLoading || _lead == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openCreateSiteVisit,
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: const Text('Site Visit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openCreateFollowUp,
                        icon: const Icon(Icons.event_note_outlined, size: 18),
                        label: const Text('Follow Up'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Expanded(
                    //   child: FilledButton.icon(
                    //     onPressed:
                    //         _isSubmittingStatus ? null : _openStatusSheet,
                    //     icon: const Icon(Icons.timeline_rounded, size: 18),
                    //     label: const Text('Status'),
                    //     style: FilledButton.styleFrom(
                    //       minimumSize: const Size.fromHeight(46),
                    //       backgroundColor: AppColors.primary,
                    //       foregroundColor: Colors.white,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLeadDetails,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _lead == null
                  ? const Center(child: Text('No data found'))
                  : RefreshIndicator(
                      onRefresh: _refreshPage,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLeadTopCard(),
                            const SizedBox(height: 14),
                            _buildLeadInfoGridCard(),
                            const SizedBox(height: 14),
                            _buildPipelineStatusCard(),
                            const SizedBox(height: 14),
                            _buildAssignCard(),
                            const SizedBox(height: 14),
                            _buildLeadHistorySection(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildLeadTopCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              _lead!.name.isNotEmpty ? _lead!.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lead!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadInfoGridCard() {
    final items = <_LeadInfoItem>[
      _LeadInfoItem(
        'Phone',
        _phoneDisplayValue(),
      ),
      _LeadInfoItem('Alternate Phone', _lead!.alternatePhoneNumber),
      _LeadInfoItem('Email', _lead!.email),
      _LeadInfoItem('Project', _lead!.projectName),
      _LeadInfoItem('Source', _lead!.source),
      _LeadInfoItem('Callback', _formatDateTimeValue(_lead!.callbackTime)),
      _LeadInfoItem(
          'Next Follow-up', _formatDateTimeValue(_lead!.nextFollowupTime)),
      _LeadInfoItem('Configuration', _lead!.configurationText),
      _LeadInfoItem('Budget', _lead!.budget),
      _LeadInfoItem('Location', _lead!.locationPreference),
      _LeadInfoItem('Status', _prettyStatus(_normalizeStatus(_lead!.status))),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fontSize = width < 360 ? 12.0 : 13.0;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return SizedBox(
                width: (width - 8) / 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (item.label == 'Phone')
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.value.isEmpty ? 'N/A' : item.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (_phoneRevealAction() != null) ...[
                              const SizedBox(width: 8),
                              _phoneRevealAction()!,
                            ],
                          ],
                        )
                      else
                        Text(
                          item.value.isEmpty ? 'N/A' : item.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildAssignCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assign To',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _lead?.assignedTo?.fullName.isNotEmpty == true
                      ? _lead!.assignedTo!.fullName
                      : 'Unassigned',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isSubmittingReassign ? null : _openReassignSheet,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  _isSubmittingReassign ? 'Reassigning...' : 'Reassign',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.22),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  minimumSize: const Size(120, 40),
                ),
              ),
            ],
          ),
          if (_lead?.assignedTo?.phone.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Phone: ${_lead!.assignedTo!.phone}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTimelineTabChip(
                        tab: _LeadTimelineTab.activity,
                        label: 'Activity',
                        icon: Icons.access_time_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildTimelineTabChip(
                        tab: _LeadTimelineTab.recordings,
                        label: 'Recordings',
                        icon: Icons.mic_none_rounded,
                        count: _recordingItems.length,
                      ),
                      if (!_isAssociateRole) ...[
                        const SizedBox(width: 8),
                        _buildTimelineTabChip(
                          tab: _LeadTimelineTab.reassignHistory,
                          label: 'Reassign History',
                          icon: Icons.history_toggle_off_rounded,
                          count: _reassignmentItems.length,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_timelineError != null)
            _buildHistoryErrorState()
          else if (_isLoadingTimeline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            _buildSelectedTimelineBody(),
        ],
      ),
    );
  }

  Widget _buildTimelineTabChip({
    required _LeadTimelineTab tab,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _selectedTimelineTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTimelineTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD9E7FF) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            _timelineError ?? 'Unable to load lead history.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _loadLeadTimelineData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTimelineBody() {
    switch (_selectedTimelineTab) {
      case _LeadTimelineTab.activity:
        return _buildActivityTabBody();
      case _LeadTimelineTab.recordings:
        return _buildRecordingsTabBody();
      case _LeadTimelineTab.reassignHistory:
        if (_isAssociateRole) {
          return _buildActivityTabBody();
        }
        return _buildReassignHistoryTabBody();
    }
  }

  Widget _buildActivityTabBody() {
    return Column(
      children: [
        if (_activityItems.isEmpty)
          _buildEmptyTimelineState(
            icon: Icons.history_rounded,
            message: 'No lead activity found yet.',
          )
        else
          Column(
            children: _activityItems
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildActivityTimelineCard(item),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildActivityTimelineCard(_LeadActivityItem item) {
    final initials = _initialsFor(item.actorName);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            Container(
              width: 2,
              height: 108,
              color: const Color(0xFFE5EAF2),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    _formatTimelineDate(item.createdAt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF9AA4B2)),
                    ),
                    child: Text(
                      item.typeLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFEFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Added by ',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: item.actorName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
      ],
    );
  }

  Widget _buildRecordingsTabBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _isUploadingRecording ? null : _uploadRecording,
            icon: _isUploadingRecording
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              _isUploadingRecording ? 'Uploading...' : 'Upload Recording',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_recordingItems.isEmpty)
          _buildEmptyTimelineState(
            icon: Icons.mic_none_rounded,
            message: 'No call recordings found for this lead.',
          )
        else
          ..._recordingItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRecordingCard(item),
              )),
      ],
    );
  }

  Widget _buildRecordingCard(_LeadRecordingItem item) {
    final isUpdating = _updatingRecordingIds.contains(item.id);
    final isDeleting = _deletingRecordingIds.contains(item.id);
    final isBusy = isUpdating || isDeleting;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _playRecording(item),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                color: Colors.white,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTimelineDate(item.createdAt)}${item.createdBy.isEmpty ? '' : '  |  ${item.createdBy}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBusy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _openEditRecordingSheet(item),
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.textSecondary,
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _deleteRecording(item),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'Delete',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReassignHistoryTabBody() {
    if (_reassignmentItems.isEmpty) {
      return _buildEmptyTimelineState(
        icon: Icons.sync_alt_rounded,
        message: 'This lead has never been reassigned.',
        actionLabel: 'Reassign now',
        onAction: _openReassignSheet,
      );
    }

    return Column(
      children: _reassignmentItems
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReassignHistoryCard(item),
              ))
          .toList(),
    );
  }

  Widget _buildReassignHistoryCard(_LeadReassignmentItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.fromUser} -> ${item.toUser}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _formatTimelineDate(item.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.note,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (item.changedBy.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Changed by ${item.changedBy}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTimelineState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.45,
                ),
                disabledForegroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineStatusCard() {
    final current = _normalizeStatus(_lead?.status ?? '');
    final statuses = _pipelineStatuses.where((e) => e.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _selectedPipelineStatusKey ??= current;
    final selected = statuses
        .where((s) => s.key == (_selectedPipelineStatusKey ?? current))
        .toList();
    final selectedKey = selected.isEmpty
        ? (statuses.isNotEmpty ? statuses.first.key : current)
        : selected.first.key;
    final progress = statuses.isEmpty
        ? 0.0
        : ((statuses.indexWhere((s) => s.key == current) + 1) / statuses.length)
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pipeline Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _openManagePipelineStatusesDialog,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SearchableDropdownField<String>(
            label: 'Pipeline Status',
            sheetTitle: 'Pipeline Status',
            showFieldLabel: false,
            value: selectedKey,
            hintText: 'Select stage',
            items: statuses
                .map(
                  (s) => SearchableDropdownItem<String>(
                    value: s.key,
                    label: s.label,
                  ),
                )
                .toList(),
            enabled: true,
            onChanged: (value) =>
                setState(() => _selectedPipelineStatusKey = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmittingStatus ? null : _updatePipelineStage,
              child: Text(_isSubmittingStatus ? 'Updating...' : 'Update Stage'),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFFE5E7EB),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPremiumActionButton(
            label: 'Schedule Follow Up',
            icon: Icons.call_outlined,
            onTap: _openCreateFollowUp,
          ),
          const SizedBox(height: 10),
          _buildPremiumActionButton(
            label: 'Schedule Visit',
            icon: Icons.calendar_month_outlined,
            onTap: _openCreateSiteVisit,
          ),
          const SizedBox(height: 10),
          _buildPremiumActionButton(
            label: 'Add Status',
            icon: Icons.playlist_add_check_circle_outlined,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildIconActionButton(
                  tooltip: 'Send via WhatsApp',
                  icon: Icons.chat_outlined,
                  color: const Color(0xFF25D366),
                  onTap: () {
                    _sendDetailsViaWhatsApp();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIconActionButton(
                  tooltip: 'Send via Email',
                  icon: Icons.email_outlined,
                  color: const Color(0xFF1976D2),
                  onTap: () {
                    _sendDetailsViaEmail();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIconActionButton(
                  tooltip: 'Share Project',
                  icon: Icons.share_outlined,
                  color: const Color(0xFF7B1FA2),
                  onTap: () {
                    _shareProjectDetails();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8E1F0)),
            ),
            child: Center(child: Icon(icon, size: 19, color: color)),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              _lead!.name.isNotEmpty ? _lead!.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lead!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Text(
                //   'Lead #${widget.leadId}',
                //   style: const TextStyle(
                //     fontSize: 12,
                //     color: AppColors.textSecondary,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _prettyStatus(_normalizeStatus(_lead!.status)),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContainer({required String title, required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    List<Widget> children, {
    Widget? trailingAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.06),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _formatDateTimeValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'N/A';
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String _formatTimelineDate(DateTime? value) {
    if (value == null) {
      return 'Unknown time';
    }
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    final month = months[local.month - 1];
    final minute = local.minute.toString().padLeft(2, '0');
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final meridiem = hour24 >= 12 ? 'pm' : 'am';
    return '${local.day} $month, $hour12:$minute $meridiem';
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _buildPhoneInfoTile() {
    final canViewPhone =
        _hasPhoneAccess || RoleAccess.canViewLeadPhones(_currentRole);
    if (_isCheckingPhoneAccess && !canViewPhone) {
      return _buildInfoTile(
        Icons.phone_outlined,
        'Phone',
        'Checking access...',
      );
    }
    if (canViewPhone) {
      return _buildInfoTile(
        Icons.phone_outlined,
        'Phone',
        _phoneDisplayValue(),
        onTap: () => _makeCall(
          _phoneCallValue(),
        ),
      );
    }

    return InkWell(
      onTap: _openPhoneRequestSheet,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFC47A00),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Phone',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_phoneRevealAction() != null) _phoneRevealAction()!,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _phoneDisplayValue(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasPendingPhoneRequest
                        ? 'Request pending for this lead'
                        : 'Request approval to view full number',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC47A00),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhoneRequestSheet() async {
    if (_hasPendingPhoneRequest) {
      _showSnackBar('Request pending for this lead.');
      return;
    }
    final reasonController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildSheetContainer(
          title: 'Request Phone Access',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _lead?.name ?? 'Selected lead',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 4,
                decoration: _fieldDecoration('Reason for phone access'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      _showSnackBar('Please enter reason.');
                      return;
                    }
                    _submitPhoneRequest(reason);
                  },
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Submit Request'),
                ),
              ),
            ],
          ),
        );
      },
    );
    reasonController.dispose();
  }

  Future<void> _submitPhoneRequest(String reason) async {
    try {
      await _authProvider.requestPhoneReveal(
        leadId: widget.leadId,
        reason: reason,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Phone access request sent for review.');
      await _loadPhoneAccess();
    } catch (e) {
      final message = AppErrorHandler.friendlyMessage(e);
      if (message.toLowerCase().contains('already have a pending request')) {
        _showSnackBar('Request pending for this lead.');
        if (mounted) {
          Navigator.of(context).pop();
        }
        await _loadPhoneAccess();
      } else {
        _showSnackBar(message);
      }
    }
  }

  bool _isPendingRequest(dynamic value) {
    if (value is Map<String, dynamic>) {
      final rawStatus = _readString(value['status']);
      return rawStatus.toLowerCase() == 'pending';
    }
    return false;
  }

  String _maskedPhone(String phone) {
    final value = phone.trim();
    if (value.isEmpty) {
      return 'Not available';
    }
    final keepCount = (value.length / 2).ceil();
    final hiddenCount = value.length - keepCount;
    if (hiddenCount <= 0) {
      return value;
    }
    return '${value.substring(0, keepCount)}${'x' * hiddenCount}';
  }

  String _phoneDisplayValue() {
    final phone = _lead?.phone.trim() ?? '';
    if (phone.isEmpty) {
      return 'Not available';
    }
    if (_hasPhoneAccess) {
      return _accessiblePhone.isNotEmpty ? _accessiblePhone : phone;
    }
    if (_isPhoneVisible) {
      final accessible = _accessiblePhone.trim();
      return accessible.isNotEmpty ? accessible : phone;
    }
    return _maskedPhone(phone);
  }

  String _phoneCallValue() {
    final phone = _lead?.phone.trim() ?? '';
    if (_hasPhoneAccess || _isPhoneVisible) {
      return _accessiblePhone.trim().isNotEmpty ? _accessiblePhone : phone;
    }
    return phone;
  }

  Widget? _phoneRevealAction() {
    final phone = _lead?.phone.trim() ?? '';
    if (_hasPhoneAccess || phone.isEmpty) {
      return null;
    }
    final isVisible = _isPhoneVisible;
    return InkWell(
      onTap: () {
        setState(() {
          _isPhoneVisible = !isVisible;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          isVisible ? 'Hide' : 'View',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onTap != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  color: AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hintText) {
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

  String _normalizeStatus(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  String _prettyStatus(String value) {
    final normalized = _normalizeStatus(value);
    if (normalized.isEmpty) {
      return 'UNKNOWN';
    }
    return normalized
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _firstStatusAfter(String current) {
    final next = _allowedTransitions(current);
    if (next.isEmpty) {
      return null;
    }
    return next.first;
  }

  List<String> _allowedTransitions(String current) {
    if (current.isEmpty || !_statusFlow.contains(current)) {
      return _statusFlow;
    }
    if (current == 'booked' || current == 'lost') {
      return const <String>[];
    }
    final index = _statusFlow.indexOf(current);
    if (index < 0 || index + 1 >= _statusFlow.length) {
      return const <String>[];
    }
    final forward = _statusFlow.sublist(index + 1);
    return forward;
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

class _LeadInfoItem {
  const _LeadInfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _PipelineStatusOption {
  const _PipelineStatusOption({
    required this.id,
    required this.key,
    required this.label,
    required this.color,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String key;
  final String label;
  final String color;
  final int sortOrder;
  final bool isActive;

  factory _PipelineStatusOption.fromApi(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(read(value)) ?? 0;
    }

    bool readBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = read(value).toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return _PipelineStatusOption(
      id: read(json['id'] ?? json['status_id'] ?? json['uuid']),
      key: read(json['key']),
      label: read(json['label']),
      color: read(json['color']),
      sortOrder: readInt(json['sort_order'] ?? json['sortOrder']),
      isActive: readBool(json['is_active'] ?? json['isActive'] ?? true),
    );
  }
}

class _LeadActivityItem {
  const _LeadActivityItem({
    required this.title,
    required this.description,
    required this.typeLabel,
    required this.actorName,
    required this.createdAt,
  });

  final String title;
  final String description;
  final String typeLabel;
  final String actorName;
  final DateTime? createdAt;

  factory _LeadActivityItem.fromJson(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    Map<String, dynamic>? mapValue(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    final actor = mapValue(
      json['created_by'] ??
          json['user'] ??
          json['actor'] ??
          json['added_by'] ??
          json['assigned_to'],
    );

    final title = read(
      json['title'] ??
          json['message'] ??
          json['activity'] ??
          json['event'] ??
          json['action'],
    );
    final description = read(
      json['description'] ?? json['note'] ?? json['details'] ?? json['remarks'],
    );
    final type = read(
      json['type'] ??
          json['category'] ??
          json['action_type'] ??
          json['event_type'],
    );
    final actorName = read(
      json['added_by_name'] ??
          json['created_by_name'] ??
          json['user_name'] ??
          actor?['full_name'] ??
          actor?['name'] ??
          actor?['email'],
    );

    return _LeadActivityItem(
      title: title.isEmpty ? 'Lead update' : title,
      description: description,
      typeLabel: type.isEmpty ? 'Note' : type.replaceAll('_', ' '),
      actorName: actorName.isEmpty ? 'System' : actorName,
      createdAt: DateTime.tryParse(
        read(json['created_at'] ?? json['updated_at'] ?? json['timestamp']),
      ),
    );
  }
}

class _LeadRecordingItem {
  static const String _recordingBaseUrl = 'https://api.nextonerealty.in/';

  const _LeadRecordingItem({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.phoneNumber,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String audioUrl;
  final String phoneNumber;
  final String createdBy;
  final DateTime? createdAt;

  factory _LeadRecordingItem.fromJson(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    Map<String, dynamic>? mapValue(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    final createdByMap =
        mapValue(json['created_by'] ?? json['user'] ?? json['uploaded_by']);
    final relativeUrl = read(
      json['audio_url'] ??
          json['recording_url'] ??
          json['url'] ??
          json['file_url'] ??
          json['path'] ??
          json['file_path'],
    );

    return _LeadRecordingItem(
      id: read(json['id'] ?? json['recording_id']),
      title: read(
        json['title'] ??
            json['name'] ??
            json['file_name'] ??
            json['recording_name'],
      ).isEmpty
          ? 'Call recording'
          : read(
              json['title'] ??
                  json['name'] ??
                  json['file_name'] ??
                  json['recording_name'],
            ),
      audioUrl: _resolveRecordingUrl(relativeUrl),
      phoneNumber: read(json['phone_number'] ?? json['phone']),
      createdBy: read(
        json['created_by_name'] ??
            json['uploaded_by_name'] ??
            createdByMap?['full_name'] ??
            createdByMap?['name'] ??
            createdByMap?['email'],
      ),
      createdAt: DateTime.tryParse(
        read(json['created_at'] ?? json['updated_at'] ?? json['timestamp']),
      ),
    );
  }

  static String _resolveRecordingUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }
    final normalizedPath =
        trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$_recordingBaseUrl$normalizedPath';
  }
}

class _LeadReassignmentItem {
  const _LeadReassignmentItem({
    required this.fromUser,
    required this.toUser,
    required this.changedBy,
    required this.note,
    required this.createdAt,
  });

  final String fromUser;
  final String toUser;
  final String changedBy;
  final String note;
  final DateTime? createdAt;

  factory _LeadReassignmentItem.fromJson(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    Map<String, dynamic>? mapValue(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    final fromMap = mapValue(
        json['from_user'] ?? json['previous_assignee'] ?? json['from']);
    final toMap =
        mapValue(json['to_user'] ?? json['assigned_to'] ?? json['to']);
    final changedByMap =
        mapValue(json['changed_by'] ?? json['updated_by'] ?? json['actor']);

    final fromUser = read(
      json['from_user_name'] ??
          fromMap?['full_name'] ??
          fromMap?['name'] ??
          json['from_name'],
    );
    final toUser = read(
      json['to_user_name'] ??
          toMap?['full_name'] ??
          toMap?['name'] ??
          json['to_name'],
    );
    final changedBy = read(
      json['changed_by_name'] ??
          changedByMap?['full_name'] ??
          changedByMap?['name'] ??
          changedByMap?['email'],
    );

    return _LeadReassignmentItem(
      fromUser: fromUser.isEmpty ? 'Unassigned' : fromUser,
      toUser: toUser.isEmpty ? 'Unassigned' : toUser,
      changedBy: changedBy,
      note: read(json['note'] ?? json['remarks'] ?? json['reason']),
      createdAt: DateTime.tryParse(
        read(json['created_at'] ?? json['updated_at'] ?? json['timestamp']),
      ),
    );
  }
}
