import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/leads/lead_bulk_upload_page.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/screens/leads/lead_form_page.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reassignNoteController =
      TextEditingController();
  final Set<String> _selectedLeadIds = <String>{};
  final AuthProvider _authProvider = AuthProvider();
  bool _isBulkSelectionMode = false;
  bool _isExporting = false;
  bool _isSubmittingReassign = false;
  String? _activeShareLeadId;
  String? _selectedAssigneeId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];

  Timer? _searchDebounce;
  bool _isLoadingLeads = true;
  String? _loadError;
  String _currentRole = '';

  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  List<_LeadModel> _currentPageLeads = <_LeadModel>[];
  final Map<String, _LeadPhoneAccess> _leadPhoneAccessById =
      <String, _LeadPhoneAccess>{};

  bool get _isAllCurrentPageSelected {
    final leads = _currentPageLeads;
    if (leads.isEmpty) {
      return false;
    }
    return leads.every((lead) => _selectedLeadIds.contains(lead.id));
  }

  void _syncBulkSelectionMode() {
    if (_selectedLeadIds.isEmpty && _isBulkSelectionMode) {
      _isBulkSelectionMode = false;
    } else if (_selectedLeadIds.isNotEmpty && !_isBulkSelectionMode) {
      _isBulkSelectionMode = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadAssigneeOptions();
    _loadLeads();
  }

  bool get _canExportData => RoleAccess.canExportData(_currentRole);
  bool get _canUseBulkLeadTools => RoleAccess.canExportData(_currentRole);

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Export actions stay hidden if access cannot be resolved.
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _reassignNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadAssigneeOptions() async {
    try {
      final users =
          await _authProvider.users(token: _authProvider.currentAuthToken);
      final options = users
          .map(_assigneeFromApi)
          .where((user) => user != null)
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
      // Keep the leads list usable even if users cannot be loaded.
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
        : _readString(
            user['name'] ??
                user['full_name'] ??
                user['fullName'] ??
                user['email'],
          );

    return _AssigneeOption(
      id: id,
      name: displayName.isEmpty ? 'User $id' : displayName,
    );
  }

  Future<void> _loadLeads() async {
    setState(() {
      _isLoadingLeads = true;
      _loadError = null;
    });

    try {
      final result = await _authProvider.leads(
        token: _authProvider.currentAuthToken,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: _currentPage,
        perPage: _pageSize,
      );

      if (!mounted) {
        return;
      }

      final pageLeads = result.items.map(_LeadModel.fromApi).toList();
      final pageLeadIds = pageLeads.map((lead) => lead.id).toSet();

      setState(() {
        _currentPageLeads = pageLeads;
        _currentPage = result.currentPage <= 0 ? 1 : result.currentPage;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _totalItems = result.totalItems;
        _selectedLeadIds.removeWhere((id) => !pageLeadIds.contains(id));
        _isLoadingLeads = false;
      });
      await _loadPhoneAccessForCurrentPage(pageLeads);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPageLeads = <_LeadModel>[];
        _totalItems = 0;
        _totalPages = 1;
        _isLoadingLeads = false;
        _selectedLeadIds.clear();
        _leadPhoneAccessById.clear();
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadPhoneAccessForCurrentPage(List<_LeadModel> leads) async {
    if (RoleAccess.hasFullAccess(_currentRole)) {
      if (!mounted) return;
      setState(() {
        _leadPhoneAccessById.clear();
        for (final lead in leads) {
          _leadPhoneAccessById[lead.id] = _LeadPhoneAccess(
            hasAccess: true,
            phone: lead.phone,
            hasPendingRequest: false,
          );
        }
      });
      return;
    }

    final results = <String, _LeadPhoneAccess>{};
    for (final lead in leads) {
      try {
        final access = await _authProvider.phoneRevealCheck(
          leadId: lead.id,
          token: _authProvider.currentAuthToken,
        );
        final hasAccessRaw = access['has_access'];
        final hasAccess = hasAccessRaw is bool
            ? hasAccessRaw
            : (hasAccessRaw is num
                ? hasAccessRaw != 0
                : (hasAccessRaw is String &&
                    hasAccessRaw.trim().toLowerCase() == 'true'));
        final apiPhone = _readString(
          access['phone'] ??
              access['lead_phone'] ??
              access['phone_number'] ??
              access['mobile'],
        );
        results[lead.id] = _LeadPhoneAccess(
          hasAccess: hasAccess,
          phone: apiPhone.isNotEmpty ? apiPhone : lead.phone,
          hasPendingRequest: _isPendingRequest(access['request']),
        );
      } catch (_) {
        results[lead.id] = _LeadPhoneAccess(
          hasAccess: false,
          phone: lead.phone,
          hasPendingRequest: false,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _leadPhoneAccessById
        ..clear()
        ..addAll(results);
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = value;
        _currentPage = 1;
        _selectedLeadIds.clear();
        _isBulkSelectionMode = false;
      });
      _loadLeads();
    });
  }

  Future<void> _openCreateLead() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );

    if (created == true && mounted) {
      _loadLeads();
    }
  }

  Future<void> _openEditLead(_LeadModel lead) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadFormPage(
          leadId: lead.id,
          leadData: lead.rawData,
        ),
      ),
    );

    if (updated == true && mounted) {
      _loadLeads();
    }
  }

  Future<void> _callLead(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty || phoneNumber.trim().toUpperCase() == 'N/A') {
      _showSnackBar('Phone number is not available.');
      return;
    }
    final launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendLeadDetailsViaWhatsApp(_LeadModel lead) async {
    final phoneNumber = _callPhoneForLead(lead).trim();
    if (phoneNumber.isEmpty || phoneNumber.toUpperCase() == 'N/A') {
      _showSnackBar('Phone number is not available.');
      return;
    }
    final message = Uri.encodeComponent(
      'Lead Details\n'
      'Name: ${lead.name}\n'
      'Phone: ${_displayPhoneForLead(lead)}\n'
      'Budget: ${lead.budget}\n'
      'Location: ${lead.locationPreference}\n'
      'Callback Time: ${lead.priority}\n'
      'Next Follow-up: ${lead.nextFollowUpDate}\n',
    );
    final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$sanitizedPhone?text=$message');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendLeadDetailsViaEmail(_LeadModel lead) async {
    final email = lead.email.trim();
    if (email.isEmpty) {
      _showSnackBar('Email is not available.');
      return;
    }
    final subject = Uri.encodeComponent('Lead Details - ${lead.name}');
    final body = Uri.encodeComponent(
      'Lead Details\n\n'
      'Name: ${lead.name}\n'
      'Phone: ${_displayPhoneForLead(lead)}\n'
      'Budget: ${lead.budget}\n'
      'Location: ${lead.locationPreference}\n'
      'Callback Time: ${lead.priority}\n'
      'Next Follow-up: ${lead.nextFollowUpDate}\n'
      'Source: ${lead.source}\n'
      'Status: ${lead.status}\n',
    );
    final mailto = Uri.parse('mailto:$email?subject=$subject&body=$body');
    await launchUrl(mailto, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareProjectDetails(_LeadModel lead) async {
    final details = 'Lead Details\n'
        'Name: ${lead.name}\n'
        'Phone: ${_displayPhoneForLead(lead)}\n'
        'Budget: ${lead.budget}\n'
        'Location: ${lead.locationPreference}\n'
        'Callback Time: ${lead.priority}\n'
        'Next Follow-up: ${lead.nextFollowUpDate}\n'
        'Source: ${lead.source}\n'
        'Status: ${lead.status}';
    await Clipboard.setData(ClipboardData(text: details));
    _showSnackBar('Project details copied to clipboard.');
  }

  Future<void> _handleCallAction(_LeadModel lead) async {
    if (RoleAccess.hasFullAccess(_currentRole)) {
      await _callLead(_callPhoneForLead(lead));
      return;
    }
    final access = _leadPhoneAccessById[lead.id];
    if (access?.hasAccess == true) {
      await _callLead(_callPhoneForLead(lead));
      return;
    }
    if (access?.hasPendingRequest == true) {
      _showSnackBar('Request pending for this lead.');
      return;
    }
    await _openPhoneRequestSheet(lead);
  }

  Future<void> _openPhoneRequestSheet(_LeadModel lead) async {
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      lead.name,
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
                    decoration: _sheetFieldDecoration('Reason for phone access'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final reason = reasonController.text.trim();
                              if (reason.isEmpty) {
                                _showSnackBar('Please enter reason.');
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _authProvider.requestPhoneReveal(
                                  leadId: lead.id,
                                  reason: reason,
                                  token: _authProvider.currentAuthToken,
                                );
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _showSnackBar(
                                  'Phone access request submitted successfully.',
                                );
                                await _loadPhoneAccessForCurrentPage(
                                  _currentPageLeads,
                                );
                              } catch (e) {
                                final message = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                                if (message.toLowerCase().contains(
                                  'already have a pending request',
                                )) {
                                  _showSnackBar('Request pending for this lead.');
                                } else {
                                  _showSnackBar(message);
                                }
                              } finally {
                                if (mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(
                        isSubmitting ? 'Submitting...' : 'Submit Request',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
  }

  Future<void> _openBulkPhoneRequestSheet() async {
    final selectedIds = _selectedLeadIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      _showSnackBar('Select at least one lead.');
      return;
    }
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: 'Bulk Phone Access Request',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedIds.length} leads selected',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: _sheetFieldDecoration(
                      'Reason for bulk phone access',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final reason = reasonController.text.trim();
                              if (reason.isEmpty) {
                                _showSnackBar('Please enter reason.');
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _authProvider.bulkRequestPhoneReveal(
                                  leadIds: selectedIds,
                                  reason: reason,
                                  token: _authProvider.currentAuthToken,
                                );
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _showSnackBar(
                                  'Bulk phone access request submitted.',
                                );
                                await _loadPhoneAccessForCurrentPage(
                                  _currentPageLeads,
                                );
                              } catch (e) {
                                _showSnackBar(
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              } finally {
                                if (mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.group_add_outlined, size: 18),
                      label: Text(
                        isSubmitting ? 'Submitting...' : 'Submit Bulk Request',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
  }

  Future<void> _openReassignSheet(_LeadModel lead) async {
    if (_assigneeOptions.isEmpty) {
      _showSnackBar('No active assignee available.');
      return;
    }

    _reassignNoteController.clear();
    _selectedAssigneeId = lead.assignedToId.isNotEmpty
        ? lead.assignedToId
        : _assigneeOptions.first.id;
    if (!_assigneeOptions.any((option) => option.id == _selectedAssigneeId)) {
      _selectedAssigneeId = _assigneeOptions.first.id;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: lead.assignedToId.isEmpty ? 'Assign Lead' : 'Reassign Lead',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedAssigneeId,
                    isExpanded: true,
                    decoration: _sheetFieldDecoration('Select assignee'),
                    items: _assigneeOptions
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(user.name),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmittingReassign
                        ? null
                        : (value) {
                            setSheetState(() {
                              _selectedAssigneeId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reassignNoteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: _sheetFieldDecoration('Add note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmittingReassign
                          ? null
                          : () async {
                              setSheetState(() {
                                _isSubmittingReassign = true;
                              });
                              final reassigned = await _submitReassignment(lead);
                              if (!mounted) {
                                return;
                              }
                              setSheetState(() {
                                _isSubmittingReassign = false;
                              });
                              if (reassigned) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(
                        _isSubmittingReassign
                            ? 'Reassigning...'
                            : (lead.assignedToId.isEmpty
                                ? 'Assign Lead'
                                : 'Reassign Lead'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitReassignment(_LeadModel lead) async {
    if (_selectedAssigneeId == null || _selectedAssigneeId!.isEmpty) {
      _showSnackBar('Please select an assignee.');
      return false;
    }

    try {
      await _authProvider.reassignLead(
        id: lead.id,
        assignedTo: _selectedAssigneeId!,
        note: _reassignNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _loadLeads();
      if (!mounted) {
        return false;
      }
      _showSnackBar('Lead reassigned successfully.');
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> _openBulkAssignSheet() async {
    if (_selectedLeadIds.isEmpty) {
      _showSnackBar('Select at least one lead to assign.');
      return;
    }
    if (_assigneeOptions.isEmpty) {
      _showSnackBar('No active assignee available.');
      return;
    }

    final selectedIds = _selectedLeadIds.toList(growable: false);
    _reassignNoteController.clear();
    _selectedAssigneeId ??= _assigneeOptions.first.id;
    if (!_assigneeOptions.any((option) => option.id == _selectedAssigneeId)) {
      _selectedAssigneeId = _assigneeOptions.first.id;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: 'Assign Selected Leads',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedIds.length} leads selected',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedAssigneeId,
                    isExpanded: true,
                    decoration: _sheetFieldDecoration('Select assignee'),
                    items: _assigneeOptions
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(user.name),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmittingReassign
                        ? null
                        : (value) {
                            setSheetState(() {
                              _selectedAssigneeId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reassignNoteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: _sheetFieldDecoration('Add note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmittingReassign
                          ? null
                          : () async {
                              setSheetState(() {
                                _isSubmittingReassign = true;
                              });
                              final reassigned = await _submitBulkReassignment(
                                selectedIds,
                              );
                              if (!mounted) {
                                return;
                              }
                              setSheetState(() {
                                _isSubmittingReassign = false;
                              });
                              if (reassigned) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(
                        _isSubmittingReassign
                            ? 'Assigning...'
                            : 'Assign ${selectedIds.length} Leads',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitBulkReassignment(List<String> leadIds) async {
    if (_selectedAssigneeId == null || _selectedAssigneeId!.isEmpty) {
      _showSnackBar('Please select an assignee.');
      return false;
    }

    try {
      for (final leadId in leadIds) {
        await _authProvider.reassignLead(
          id: leadId,
          assignedTo: _selectedAssigneeId!,
          note: _reassignNoteController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      }
      await _loadLeads();
      if (!mounted) {
        return false;
      }
      setState(() {
        _selectedLeadIds.clear();
        _isBulkSelectionMode = false;
      });
      _showSnackBar('${leadIds.length} leads assigned successfully.');
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> _viewLeadDetail(String leadId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailPage(leadId: leadId),
      ),
    );
  }

  Future<void> _exportLeads() async {
    if (!_canExportData) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to export leads.'),
          ),
        );
      return;
    }
    final range = await _showExportDateRangeDialog();
    if (!mounted || range == null) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    final from = _formatDateForApi(range.start);
    final to = _formatDateForApi(range.end);
    try {
      final exported = await _authProvider.exportLeads(
        from: from,
        to: to,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      final safeFileName = exported.fileName.trim().isEmpty
          ? 'leads_${from}_to_$to.xlsx'
          : exported.fileName.trim();
      if (kIsWeb) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Export generated ($safeFileName), but direct file save is not supported on Web in this build.',
              ),
            ),
          );
        return;
      }
      final outFile = await ExportFileHelper.saveToDownloadNextone(
        fileName: safeFileName,
        bytes: exported.bytes,
      );
      if (!mounted) {
        return;
      }
      // ScaffoldMessenger.of(context)
      //   ..hideCurrentSnackBar()
      //   ..showSnackBar(
      //     SnackBar(
      //       content: Text(
      //         'Leads export downloaded: ${outFile.path}',
      //       ),
      //     ),
      //   );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is UnsupportedError
          ? 'This platform does not support local file save for export yet.'
          : error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _openLeadBulkDialog() async {
    if (!_canUseBulkLeadTools) {
      _showSnackBar('You do not have permission to use bulk lead tools.');
      return;
    }

    final result = await Navigator.of(context).push<LeadBulkUploadResult>(
      MaterialPageRoute(builder: (_) => const LeadBulkUploadPage()),
    );

    if (!mounted || result == null) {
      return;
    }

    await _loadLeads();
    if (!mounted) {
      return;
    }
    final resultFilename = result.resultFilename;
    _showSnackBar(
      resultFilename == null || resultFilename.trim().isEmpty
          ? result.message
          : '${result.message} Result file: $resultFilename',
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<DateTimeRange?> _showExportDateRangeDialog() async {
    final now = DateTime.now();
    DateTime? fromDate;
    DateTime? toDate;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formatDate(DateTime? date) =>
                date == null ? '' : _formatDateForApi(date);

            Future<void> pickFromDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fromDate ?? now,
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                fromDate = DateTime(picked.year, picked.month, picked.day);
                if (toDate != null && toDate!.isBefore(fromDate!)) {
                  toDate = fromDate;
                }
              });
            }

            Future<void> pickToDate() async {
              final baseDate = toDate ?? fromDate ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: baseDate,
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                toDate = DateTime(picked.year, picked.month, picked.day);
              });
            }

            final isValidRange =
                fromDate != null && toDate != null && !toDate!.isBefore(fromDate!);

            return AlertDialog(
              title: const Text('Export Leads'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: pickFromDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Text(
                        formatDate(fromDate).isEmpty
                            ? 'Select start date'
                            : formatDate(fromDate),
                        style: TextStyle(
                          color: formatDate(fromDate).isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: pickToDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Text(
                        formatDate(toDate).isEmpty
                            ? 'Select end date'
                            : formatDate(toDate),
                        style: TextStyle(
                          color: formatDate(toDate).isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isValidRange
                      ? () => Navigator.of(context).pop(
                            DateTimeRange(start: fromDate!, end: toDate!),
                          )
                      : null,
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSheetContainer({
    required String title,
    required Widget child,
  }) {
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

  InputDecoration _sheetFieldDecoration(String hintText) {
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

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedLeadIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Lead Management'),
      body: RefreshIndicator(
        onRefresh: _loadLeads,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(),
              const SizedBox(height: 16),
              if (selectedCount > 0) ...[
                _buildBulkActionBar(selectedCount),
                const SizedBox(height: 16),
              ],
              _buildLeadsSection(),
              const SizedBox(height: 16),
              _buildPagination(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        final searchField = Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by name, status, assignee',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final exportButton = null;
        // final exportButton = _canExportData
        //     ? OutlinedButton.icon(
        //         onPressed: _isExporting ? null : _exportLeads,
        //         icon: _isExporting
        //             ? const SizedBox(
        //                 width: 16,
        //                 height: 16,
        //                 child: CircularProgressIndicator(strokeWidth: 2),
        //               )
        //             : const Icon(Icons.download_rounded, size: 18),
        //         label: Text(_isExporting ? 'Exporting...' : 'Export'),
        //         style: OutlinedButton.styleFrom(
        //           minimumSize: const Size(0, 48),
        //           padding: const EdgeInsets.symmetric(horizontal: 14),
        //           shape: RoundedRectangleBorder(
        //             borderRadius: BorderRadius.circular(12),
        //           ),
        //         ),
        //       )
        //     : null;

        final bulkButton = _canUseBulkLeadTools
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _openLeadBulkDialog,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Bulk'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final addSourceButton = OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Source'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: _openCreateLead,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Lead'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (isCompact) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              Row(
                children: [
                  if (exportButton != null) ...[
                    Expanded(child: exportButton),
                    const SizedBox(width: 8),
                  ],
                  if (bulkButton != null) ...[
                    Expanded(child: bulkButton),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: addSourceButton),
                  const SizedBox(width: 8),
                  Expanded(child: addButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            if (exportButton != null) ...[
              exportButton,
              const SizedBox(width: 8),
            ],
            if (bulkButton != null) ...[
              bulkButton,
              const SizedBox(width: 8),
            ],
            addSourceButton,
            const SizedBox(width: 8),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildBulkActionBar(int selectedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4E2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              if (isNarrow) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSubmittingReassign ? null : _openBulkAssignSheet,
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 16,
                        ),
                        label: const Text('Assign'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openBulkPhoneRequestSheet,
                        icon: const Icon(Icons.phone_outlined, size: 16),
                        label: const Text('Request Phone Access'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isSubmittingReassign ? null : _openBulkAssignSheet,
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 16,
                      ),
                      label: const Text('Assign'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openBulkPhoneRequestSheet,
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Request Phone Access'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedLeadIds.clear();
                  _isBulkSelectionMode = false;
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsSection() {
    final leads = _currentPageLeads;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListHeader(leads),
          const SizedBox(height: 8),
          if (_isLoadingLeads)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadLeads,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (leads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'No leads found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...leads.map((lead) {
              final isShareOpen = _activeShareLeadId == lead.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    DataCard(
                  name: lead.name,
                  leadId: '',
                  status: lead.status,
                  priority: lead.priority,
                  priorityColor: lead.priorityColor,
                  nextFollowUpDate: lead.nextFollowUpDate,
                  leftMetaLabel: 'Callback Time',
                  rightMetaLabel: 'Next Follow-up',
                  budget: lead.budget,
                  phone: _displayPhoneForLead(lead),
                  profileImageUrl: lead.profileImageUrl,
                  assigneeName: lead.assignee.name,
                  assigneeImageUrl: lead.assignee.imageUrl,
                  onTap: () => _viewLeadDetail(lead.id),
                  actions: [
                    DataCardAction(
                      icon: Icons.call_outlined,
                      onTap: () => _handleCallAction(lead),
                    ),
                    DataCardAction(
                      icon: Icons.share_outlined,
                      color: const Color(0xFF7B1FA2),
                      onTap: () {
                        setState(() {
                          _activeShareLeadId = isShareOpen ? null : lead.id;
                        });
                      },
                    ),
                    DataCardAction(
                      icon: Icons.person_add_alt_1_outlined,
                      color: AppColors.primary,
                      onTap: () => _openReassignSheet(lead),
                    ),
                    DataCardAction(
                      icon: Icons.edit_outlined,
                      onTap: () => _openEditLead(lead),
                    ),
                    DataCardAction(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFD32F2F),
                      onTap: () {},
                    ),
                  ],
                  bulkSelectionMode: _isBulkSelectionMode,
                  isSelected: _selectedLeadIds.contains(lead.id),
                  onLongPress: () {
                    setState(() {
                      _isBulkSelectionMode = true;
                      _selectedLeadIds.add(lead.id);
                    });
                  },
                    onSelectionChanged: (selected) {
                      setState(() {
                      if (selected) {
                        _selectedLeadIds.add(lead.id);
                      } else {
                        _selectedLeadIds.remove(lead.id);
                      }
                      _syncBulkSelectionMode();
                      });
                    },
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: !isShareOpen
                          ? const SizedBox.shrink()
                          : Container(
                              key: ValueKey<String>('share-${lead.id}'),
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF9FAFF),
                                    Color(0xFFF3F6FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFDCE3F7)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildInlineShareOption(
                                      label: 'WhatsApp',
                                      icon: Icons.chat_outlined,
                                      color: const Color(0xFF25D366),
                                      onTap: () => _sendLeadDetailsViaWhatsApp(lead),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildInlineShareOption(
                                      label: 'Email',
                                      icon: Icons.email_outlined,
                                      color: const Color(0xFF1976D2),
                                      onTap: () => _sendLeadDetailsViaEmail(lead),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildInlineShareOption(
                                      label: 'Share',
                                      icon: Icons.share_outlined,
                                      color: const Color(0xFF7B1FA2),
                                      onTap: () => _shareProjectDetails(lead),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildListHeader(List<_LeadModel> currentPageLeads) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          if (_isBulkSelectionMode) ...[
            Checkbox(
              value: _isAllCurrentPageSelected,
              onChanged: (value) {
                final shouldSelect = value ?? false;
                setState(() {
                  for (final lead in currentPageLeads) {
                    if (shouldSelect) {
                      _selectedLeadIds.add(lead.id);
                    } else {
                      _selectedLeadIds.remove(lead.id);
                    }
                  }
                  _syncBulkSelectionMode();
                });
              },
            ),
            const Text(
              'Select all on this page',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$_totalItems total leads',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineShareOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1E6F5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalItems = _totalItems;
    final totalPages = _totalPages <= 0 ? 1 : _totalPages;
    final currentPage = _currentPage.clamp(1, totalPages);

    final start = totalItems == 0 ? 0 : ((currentPage - 1) * _pageSize) + 1;
    final end =
        totalItems == 0 ? 0 : math.min(currentPage * _pageSize, totalItems);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Showing $start-$end of $totalItems',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              IconButton(
                onPressed: !_isLoadingLeads && currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage -= 1;
                          _selectedLeadIds.clear();
                          _isBulkSelectionMode = false;
                        });
                        _loadLeads();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: !_isLoadingLeads && currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage += 1;
                          _selectedLeadIds.clear();
                          _isBulkSelectionMode = false;
                        });
                        _loadLeads();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayPhoneForLead(_LeadModel lead) {
    final access = _leadPhoneAccessById[lead.id];
    final rawPhone = lead.phone;
    if (RoleAccess.hasFullAccess(_currentRole)) {
      return rawPhone;
    }
    if (access?.hasAccess == true) {
      final grantedPhone = _readString(access?.phone);
      return grantedPhone.isNotEmpty ? grantedPhone : rawPhone;
    }
    return _maskPhone(rawPhone);
  }

  String _callPhoneForLead(_LeadModel lead) {
    final access = _leadPhoneAccessById[lead.id];
    if (RoleAccess.hasFullAccess(_currentRole)) {
      return lead.phone;
    }
    final grantedPhone = _readString(access?.phone);
    if (grantedPhone.isNotEmpty) {
      return grantedPhone;
    }
    return lead.phone;
  }

  String _maskPhone(String phone) {
    final value = phone.trim();
    if (value.isEmpty || value.toUpperCase() == 'N/A') {
      return 'N/A';
    }
    final keepCount = (value.length / 2).ceil();
    final hiddenCount = value.length - keepCount;
    if (hiddenCount <= 0) {
      return value;
    }
    return '${value.substring(0, keepCount)}${'x' * hiddenCount}';
  }

  bool _isPendingRequest(dynamic value) {
    if (value is Map<String, dynamic>) {
      final rawStatus = _readString(value['status']);
      return rawStatus.toLowerCase() == 'pending';
    }
    return false;
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

class _LeadModel {
  const _LeadModel({
    required this.id,
    required this.name,
    required this.status,
    required this.priority,
    required this.priorityColor,
    required this.nextFollowUpDate,
    required this.budget,
    required this.phone,
    required this.profileImageUrl,
    required this.assignee,
    required this.email,
    required this.source,
    required this.assignedToId,
    required this.locationPreference,
    required this.notes,
    required this.rawData,
  });

  final String id;
  final String name;
  final String status;
  final String priority;
  final Color priorityColor;
  final String nextFollowUpDate;
  final String budget;
  final String phone;
  final String profileImageUrl;
  final _PersonModel assignee;
  final String email;
  final String source;
  final String assignedToId;
  final String locationPreference;
  final String notes;
  final Map<String, dynamic> rawData;

  factory _LeadModel.fromApi(Map<String, dynamic> json) {
    final id = _readString(
      json['id'] ?? json['lead_id'] ?? json['leadId'],
      fallback: 'N/A',
    );
    final firstName = _readString(
      json['first_name'] ?? json['firstName'],
    );
    final lastName = _readString(
      json['last_name'] ?? json['lastName'],
    );
    final fullName = _readString(
      json['name'] ??
          json['full_name'] ??
          json['fullName'] ??
          json['contact_name'] ??
          json['customer_name'],
    );
    final resolvedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    final status = _readString(
      json['status'] ?? json['stage'] ?? json['current_status'],
      fallback: 'Unknown',
    );
    final callbackTime = _readDateTime(
      json['callback_time'] ?? json['callbackTime'],
    );
    final nextFollowUpDate = _readDateTime(
      json['next_followup_time'] ??
          json['next_follow_up_time'] ??
          json['next_follow_up_date'] ??
          json['nextFollowUpDate'] ??
          json['follow_up_date'],
    );
    final budget = _readBudget(
      json['budget'] ?? json['budget_value'] ?? json['budget_range'],
    );
    final phone = _readString(
      json['phone_number'] ?? json['phone'] ?? json['mobile'],
      fallback: 'N/A',
    );
    final profileImageUrl = _readString(
      json['profile_image'] ??
          json['profileImage'] ??
          json['avatar'] ??
          json['image_url'],
    );

    final assigned = json['assigned_to'] ?? json['assignee'];
    final assignedToId = assigned is Map<String, dynamic>
        ? _readString(
            assigned['id'] ??
                assigned['user_id'] ??
                assigned['userId'] ??
                assigned['uuid'],
          )
        : _readString(assigned);
    final assignedNameFromRoot = _readString(
      json['assigned_name'] ??
          json['assignedName'] ??
          json['assignee_name'] ??
          json['assigneeName'],
    );
    final assigneeName = assigned is Map<String, dynamic>
        ? _readString(
            assigned['name'] ??
                assigned['full_name'] ??
                assigned['fullName'] ??
                assigned['first_name'],
            fallback: 'Unassigned',
          )
        : (assignedNameFromRoot.isNotEmpty
            ? assignedNameFromRoot
            : 'Unassigned');
    final assigneeImage = assigned is Map<String, dynamic>
        ? _readString(
            assigned['image'] ??
                assigned['avatar'] ??
                assigned['profile_image'] ??
                assigned['image_url'],
          )
        : '';

    final email = _readString(json['email']);
    final source = _readString(json['source']);
    final locationPreference = _readString(
      json['location_preference'] ?? json['locationPreference'],
    );
    final notes = _readString(json['notes']);

    return _LeadModel(
      id: id,
      name: resolvedName.isNotEmpty
          ? resolvedName
          : (fullName.isNotEmpty ? fullName : 'Unknown Lead'),
      status: status,
      priority: callbackTime,
      priorityColor: const Color(0xFF1E88E5),
      nextFollowUpDate: nextFollowUpDate,
      budget: budget,
      phone: phone,
      profileImageUrl: profileImageUrl,
      assignee: _PersonModel(name: assigneeName, imageUrl: assigneeImage),
      email: email,
      source: source,
      assignedToId: assignedToId,
      locationPreference: locationPreference,
      notes: notes,
      rawData: Map<String, dynamic>.from(json),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String _readDateTime(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return 'N/A';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  static String _readBudget(dynamic value) {
    if (value is num) {
      return 'INR ${value.toString()}';
    }
    final asString = _readString(value);
    return asString.isEmpty ? 'N/A' : asString;
  }

}

class _PersonModel {
  const _PersonModel({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;
}

class _LeadPhoneAccess {
  const _LeadPhoneAccess({
    required this.hasAccess,
    required this.phone,
    required this.hasPendingRequest,
  });

  final bool hasAccess;
  final String phone;
  final bool hasPendingRequest;
}
