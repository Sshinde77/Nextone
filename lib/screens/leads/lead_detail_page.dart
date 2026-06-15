import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/lead_detail_model.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailPage extends StatefulWidget {
  final String leadId;

  const LeadDetailPage({super.key, required this.leadId});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

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
  bool _isCheckingPhoneAccess = false;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_PipelineStatusOption> _pipelineStatuses =
      const <_PipelineStatusOption>[];
  String? _selectedPipelineStatusKey;

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _fetchLeadDetails();
    _loadAssigneeOptions();
    _loadPipelineStatuses();
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

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() => _currentRole = role);
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPhoneAccess = false;
        _hasPendingPhoneRequest = false;
        _accessiblePhone = _lead?.phone ?? '';
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingPhoneAccess = false);
      }
    }
  }

  Future<void> _loadAssigneeOptions() async {
    try {
      final users =
          await _authProvider.users(token: _authProvider.currentAuthToken);
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
              DropdownButtonFormField<String>(
                initialValue: _selectedNextStatus,
                isExpanded: true,
                decoration: _fieldDecoration('Select status'),
                items: nextStatuses
                    .map((status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(_prettyStatus(status)),
                        ))
                    .toList(),
                onChanged: _isSubmittingStatus
                    ? null
                    : (value) => setState(() => _selectedNextStatus = value),
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
              DropdownButtonFormField<String>(
                initialValue: _selectedAssigneeId,
                isExpanded: true,
                decoration: _fieldDecoration('Select assignee'),
                items: _assigneeOptions
                    .map((user) => DropdownMenuItem<String>(
                          value: user.id,
                          child: Text(user.name),
                        ))
                    .toList(),
                onChanged: _isSubmittingReassign
                    ? null
                    : (value) => setState(() => _selectedAssigneeId = value),
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
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
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
                      onRefresh: _fetchLeadDetails,
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
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconActionButton(
                tooltip: 'Send via WhatsApp',
                icon: Icons.chat_outlined,
                color: const Color(0xFF25D366),
                onTap: _sendDetailsViaWhatsApp,
              ),
              const SizedBox(width: 6),
              _buildIconActionButton(
                tooltip: 'Send via Email',
                icon: Icons.email_outlined,
                color: const Color(0xFF1976D2),
                onTap: _sendDetailsViaEmail,
              ),
              const SizedBox(width: 6),
              _buildIconActionButton(
                tooltip: 'Share Project',
                icon: Icons.share_outlined,
                color: const Color(0xFF7B1FA2),
                onTap: _shareProjectDetails,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadInfoGridCard() {
    final items = <_LeadInfoItem>[
      _LeadInfoItem(
        'Phone',
        _hasPhoneAccess
            ? (_accessiblePhone.isEmpty ? _lead!.phone : _accessiblePhone)
            : _maskedPhone(_lead!.phone),
      ),
      _LeadInfoItem('Email', _lead!.email),
      _LeadInfoItem('Source', _lead!.source),
      _LeadInfoItem('Callback', _formatDateTimeValue(_lead!.callbackTime)),
      _LeadInfoItem(
          'Next Follow-up', _formatDateTimeValue(_lead!.nextFollowupTime)),
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
          DropdownButtonFormField<String>(
            initialValue: selectedKey,
            isExpanded: true,
            decoration: _fieldDecoration('Select stage'),
            items: statuses
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.key,
                    child: Text(s.label),
                  ),
                )
                .toList(),
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
        side: const BorderSide(color: AppColors.border),
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
        _accessiblePhone.isNotEmpty ? _accessiblePhone : _lead!.phone,
        onTap: () => _makeCall(
          _accessiblePhone.isNotEmpty ? _accessiblePhone : _lead!.phone,
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
                  Text(
                    'Phone',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _maskedPhone(_lead?.phone ?? ''),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasPendingPhoneRequest
                        ? 'Request pending for this lead'
                        : 'Request approval to view full number',
                    style: TextStyle(
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

  String _normalizeRole(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'sales_executive') {
      return 'sale_executive';
    }
    return normalized;
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

