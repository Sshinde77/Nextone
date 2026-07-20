// ignore_for_file: use_build_context_synchronously, unused_element, unused_local_variable

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/screens/leads/lead_bulk_upload_page.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/screens/leads/lead_form_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({
    super.key,
    this.title = 'Lead Management',
    this.fixedStatus,
    this.lockStatusFilter = false,
  });

  final String title;
  final String? fixedStatus;
  final bool lockStatusFilter;

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  static const List<String> _defaultSourceOptions = <String>[
    'Facebook',
    'Walk-in',
    'Referral',
  ];

  static const List<Color> _statusColorPalette = <Color>[
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

  static const int _myLeadsTabIndex = 0;
  static const int _teamLeadsTabIndex = 1;
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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reassignNoteController = TextEditingController();
  final TextEditingController _statusNoteController = TextEditingController();
  final Set<String> _selectedLeadIds = <String>{};
  final AuthProvider _authProvider = AuthProvider();
  bool _isBulkSelectionMode = false;
  bool _isExporting = false;
  bool _isSubmittingReassign = false;
  bool _isSubmittingStatus = false;
  bool _isLoadingLeadSources = false;
  String? _visiblePhoneLeadId;
  String? _expandedQuickActionLeadId;
  String? _selectedAssigneeId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_LeadSourceOption> _leadSources = const <_LeadSourceOption>[];
  List<_PipelineStatusOption> _pipelineStatuses =
      const <_PipelineStatusOption>[];

  Timer? _searchDebounce;
  bool _isLoadingLeads = true;
  String? _loadError;
  String _currentRole = '';
  int _activeLeadsTabIndex = _myLeadsTabIndex;

  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedSource;
  String? _selectedTeamId;
  String? _projectSearchQuery;
  String? _selectedNextStatus;
  List<_LeadModel> _currentPageLeads = <_LeadModel>[];
  final Map<String, _LeadPhoneAccess> _leadPhoneAccessById =
      <String, _LeadPhoneAccess>{};

  String? get _resolvedStatus {
    final fixedStatus = widget.fixedStatus?.trim();
    if (fixedStatus != null && fixedStatus.isNotEmpty) {
      return fixedStatus;
    }
    return _selectedStatus;
  }

  bool get _isStatusFilterLocked =>
      widget.lockStatusFilter &&
      widget.fixedStatus != null &&
      widget.fixedStatus!.trim().isNotEmpty;

  List<String> get _sourceOptions {
    final values = <String>{
      ..._defaultSourceOptions,
      ..._leadSources
          .where((source) => source.isActive)
          .map((source) => source.name)
          .where((name) => name.trim().isNotEmpty),
      ..._currentPageLeads
          .map((lead) => lead.source)
          .where((s) => s.trim().isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

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
    if (_isStatusFilterLocked) {
      _selectedStatus = widget.fixedStatus!.trim();
    }
    _loadAccess();
    _loadAssigneeOptions();
    _loadLeadSources();
    _loadPipelineStatuses();
    _loadLeads();
  }

  bool get _canExportData => RoleAccess.canExportModule('leads');
  bool get _showExportButton =>
      _canExportData && RoleAccess.isAdminOrSuperAdmin(_currentRole);
  bool get _canUseBulkLeadTools => RoleAccess.canCreateModule('leads');
  bool get _canDeleteLeads => RoleAccess.canDeleteModule('leads');
  bool get _showLeadTabs =>
      _currentRole.isNotEmpty &&
      !RoleAccess.isAdmin(_currentRole) &&
      !RoleAccess.isSuperAdmin(_currentRole);

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      final isAdminRole =
          RoleAccess.isAdmin(role) || RoleAccess.isSuperAdmin(role);
      setState(() {
        _currentRole = role;
        if (isAdminRole) {
          _activeLeadsTabIndex = _teamLeadsTabIndex;
          _selectedTeamId = null;
        }
      });
      if (isAdminRole) {
        _loadLeads();
      }
    } catch (_) {
      // Export actions stay hidden if access cannot be resolved.
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _reassignNoteController.dispose();
    _statusNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadAssigneeOptions() async {
    try {
      final users = await _authProvider.assignmentUsers(
        token: _authProvider.currentAuthToken,
      );
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

  Future<void> _loadLeadSources() async {
    setState(() {
      _isLoadingLeadSources = true;
    });

    try {
      final items = await _authProvider.leadSourcesConfig(
        token: _authProvider.currentAuthToken,
      );
      final sources = items.map(_LeadSourceOption.fromApi).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }

      setState(() {
        _leadSources = sources;
        _isLoadingLeadSources = false;
        if (_selectedSource != null &&
            !sources.any((source) => source.name == _selectedSource)) {
          _selectedSource = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLeadSources = false;
      });
    }
  }

  Future<void> _loadPipelineStatuses() async {
    try {
      final items = await _authProvider.leadStatusesConfig(
        token: _authProvider.currentAuthToken,
      );
      final statuses = items.map(_PipelineStatusOption.fromApi).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) {
        return;
      }

      setState(() {
        _pipelineStatuses = statuses;
      });
    } catch (_) {
      // Keep page usable without status-config data.
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
        : _readString(
            user['name'] ??
                user['full_name'] ??
                user['fullName'] ??
                user['email'],
          );
    final roleLabel = _readRoleLabel(user);

    return _AssigneeOption(
      id: id,
      name: roleLabel.isEmpty
          ? (displayName.isEmpty ? 'User $id' : displayName)
          : '${displayName.isEmpty ? 'User $id' : displayName} ($roleLabel)',
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

  Future<void> _loadLeads() async {
    setState(() {
      _isLoadingLeads = true;
      _loadError = null;
    });

    try {
      final result = _isMyLeadsTab
          ? await _authProvider.myLeads(
              token: _authProvider.currentAuthToken,
              status: _resolvedStatus,
              source: _selectedSource,
              search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
              project: _projectSearchQuery,
              page: _currentPage,
              perPage: _pageSize,
            )
          : await _authProvider.leads(
              token: _authProvider.currentAuthToken,
              status: _resolvedStatus,
              source: _selectedSource,
              assignedTo: _selectedTeamId,
              search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
              project: _projectSearchQuery,
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
        _visiblePhoneLeadId = null;
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
        _visiblePhoneLeadId = null;
        _leadPhoneAccessById.clear();
        _loadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  bool get _isMyLeadsTab => _activeLeadsTabIndex == _myLeadsTabIndex;

  void _switchLeadsTab(int tabIndex) {
    if (_activeLeadsTabIndex == tabIndex) {
      return;
    }
    setState(() {
      _activeLeadsTabIndex = tabIndex;
      _currentPage = 1;
      _selectedLeadIds.clear();
      _isBulkSelectionMode = false;
      _selectedTeamId = null;
      _visiblePhoneLeadId = null;
    });
    _loadLeads();
  }

  Future<void> _loadPhoneAccessForCurrentPage(List<_LeadModel> leads) async {
    if (RoleAccess.canViewLeadPhones(_currentRole)) {
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

  Future<void> _openFiltersSheet() async {
    String? tempStatus = _resolvedStatus;
    String? tempSource = _selectedSource;
    String? tempTeamId = _isMyLeadsTab ? null : _selectedTeamId;
    String tempProject = _projectSearchQuery ?? '';
    final projectController = TextEditingController(text: tempProject);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: 'Lead Filters',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isStatusFilterLocked) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: tempStatus,
                      decoration: _sheetFieldDecoration('Select status'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ..._pipelineStatuses
                            .where((status) => status.isActive)
                            .map(
                              (status) => DropdownMenuItem<String?>(
                                value: status.key,
                                child: Text(status.label),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          tempStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  SearchableDropdownField<String>(
                    label: 'Source',
                    sheetTitle: 'Select source',
                    value: tempSource ?? '',
                    hintText: 'All',
                    items: <SearchableDropdownItem<String>>[
                      const SearchableDropdownItem<String>(
                        value: '',
                        label: 'All',
                      ),
                      ..._sourceOptions.map(
                        (source) => SearchableDropdownItem<String>(
                          value: source,
                          label: source,
                        ),
                      ),
                    ],
                    enabled: true,
                    onChanged: (value) {
                      setSheetState(() {
                        tempSource =
                            value == null || value.isEmpty ? null : value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: projectController,
                    decoration: _sheetFieldDecoration('Search by project'),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      tempProject = value;
                    },
                    onSubmitted: (value) {
                      tempProject = value;
                    },
                  ),
                  if (!_isMyLeadsTab) ...[
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      label: 'Team Member',
                      sheetTitle: 'Select team member',
                      value: tempTeamId ?? '',
                      hintText: 'All',
                      items: <SearchableDropdownItem<String>>[
                        const SearchableDropdownItem<String>(
                          value: '',
                          label: 'All',
                        ),
                        ..._assigneeOptions.map(
                          (assignee) => SearchableDropdownItem<String>(
                            value: assignee.id,
                            label: assignee.name,
                          ),
                        ),
                      ],
                      enabled: true,
                      onChanged: (value) {
                        setSheetState(() {
                          tempTeamId =
                              value == null || value.isEmpty ? null : value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = _isStatusFilterLocked
                                  ? _resolvedStatus
                                  : null;
                              _selectedSource = null;
                              _projectSearchQuery = null;
                              _selectedTeamId = null;
                              _currentPage = 1;
                              _selectedLeadIds.clear();
                              _isBulkSelectionMode = false;
                            });
                            Navigator.of(context).pop();
                            _loadLeads();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = _isStatusFilterLocked
                                  ? _resolvedStatus
                                  : tempStatus;
                              _selectedSource = tempSource;
                              _projectSearchQuery = tempProject.trim().isEmpty
                                  ? null
                                  : tempProject.trim();
                              _selectedTeamId =
                                  _isMyLeadsTab ? null : tempTeamId;
                              _currentPage = 1;
                              _selectedLeadIds.clear();
                              _isBulkSelectionMode = false;
                            });
                            Navigator.of(context).pop();
                            _loadLeads();
                          },
                          child: const Text('Apply'),
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
    projectController.dispose();
  }

  Future<void> _openManageLeadSourcesDialog() async {
    final createController = TextEditingController();
    bool isSubmitting = false;
    bool isRefreshing = false;

    Future<void> refreshSources(
        void Function(void Function()) setDialogState) async {
      final previousSelectedSource = _selectedSource;
      setDialogState(() {
        isRefreshing = true;
      });
      try {
        final items = await _authProvider.leadSourcesConfig(
          token: _authProvider.currentAuthToken,
        );
        final sources = items.map(_LeadSourceOption.fromApi).toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (!mounted) return;
        setState(() {
          _leadSources = sources;
          if (_selectedSource != null &&
              !sources.any((source) => source.name == _selectedSource)) {
            _selectedSource = null;
          }
        });
        if (previousSelectedSource != _selectedSource) {
          await _loadLeads();
        }
      } catch (error) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(error));
      } finally {
        if (mounted) {
          setDialogState(() {
            isRefreshing = false;
          });
        }
      }
    }

    Future<void> createSource(
      void Function(void Function()) setDialogState,
    ) async {
      final name = createController.text.trim();
      if (name.isEmpty) {
        _showSnackBar('Please enter source name.');
        return;
      }

      setDialogState(() {
        isSubmitting = true;
      });
      try {
        await _authProvider.createLeadSource(
          name: name,
          token: _authProvider.currentAuthToken,
        );
        createController.clear();
        await refreshSources(setDialogState);
        if (!mounted) return;
        _showSnackBar('Lead source created successfully.');
      } catch (error) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(error));
      } finally {
        if (mounted) {
          setDialogState(() {
            isSubmitting = false;
          });
        }
      }
    }

    Future<void> editSource(
      _LeadSourceOption source,
      void Function(void Function()) setDialogState,
    ) async {
      final nameController = TextEditingController(text: source.name);
      bool isActive = source.isActive;
      bool isSaving = false;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setEditState) {
              return AlertDialog(
                title: const Text('Edit Lead Source'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Source name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (value) {
                        setEditState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              _showSnackBar('Please enter source name.');
                              return;
                            }
                            setEditState(() {
                              isSaving = true;
                            });
                            try {
                              await _authProvider.updateLeadSource(
                                id: source.id,
                                name: name,
                                isActive: isActive,
                                token: _authProvider.currentAuthToken,
                              );
                              if (mounted && _selectedSource == source.name) {
                                setState(() {
                                  _selectedSource = name;
                                });
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              await refreshSources(setDialogState);
                              if (!mounted) return;
                              _showSnackBar(
                                  'Lead source updated successfully.');
                            } catch (error) {
                              if (!mounted) return;
                              _showSnackBar(
                                AppErrorHandler.friendlyMessage(error),
                              );
                              if (context.mounted) {
                                setEditState(() {
                                  isSaving = false;
                                });
                              }
                            }
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );
      nameController.dispose();
    }

    Future<void> deleteSource(
      _LeadSourceOption source,
      void Function(void Function()) setDialogState,
    ) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Lead Source'),
            content: Text('Delete "${source.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      try {
        await _authProvider.deleteLeadSource(
          id: source.id,
          token: _authProvider.currentAuthToken,
        );
        await refreshSources(setDialogState);
        if (!mounted) return;
        _showSnackBar('Lead source deleted successfully.');
      } catch (error) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(error));
      }
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
                final dialogWidth = width < 520 ? width * 0.98 : 620.0;
                final dialogHeight =
                    width < 520 ? constraints.maxHeight * 0.9 : 560.0;

                return Dialog(
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: dialogHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Manage Lead Sources',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                visualDensity: VisualDensity.compact,
                                splashRadius: 18,
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: createController,
                                  decoration: InputDecoration(
                                    hintText: 'New source name (e.g. LinkedIn)',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) =>
                                      createSource(setDialogState),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 42,
                                  child: FilledButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : () => createSource(setDialogState),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text(
                                        isSubmitting ? 'Adding...' : 'Add'),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: createController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'New source name (e.g. LinkedIn)',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) =>
                                        createSource(setDialogState),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 40,
                                  child: FilledButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : () => createSource(setDialogState),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text(
                                        isSubmitting ? 'Adding...' : 'Add'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  if (!isCompact)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: AppColors.border),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'Source Name',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'Actions',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Expanded(
                                    child: isRefreshing || _isLoadingLeadSources
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _leadSources.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No lead sources found.',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              )
                                            : ListView.separated(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                                itemCount: _leadSources.length,
                                                separatorBuilder: (_, __) =>
                                                    const Divider(height: 1),
                                                itemBuilder: (context, index) {
                                                  final source =
                                                      _leadSources[index];
                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                    child: isCompact
                                                        ? Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                source.name,
                                                                style:
                                                                    const TextStyle(
                                                                  color: AppColors
                                                                      .textPrimary,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 8),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          5,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: source
                                                                              .isActive
                                                                          ? const Color(
                                                                              0xFFDDF7E7,
                                                                            )
                                                                          : const Color(
                                                                              0xFFF1F5F9,
                                                                            ),
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                        999,
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      source.isActive
                                                                          ? 'ACTIVE'
                                                                          : 'INACTIVE',
                                                                      style:
                                                                          TextStyle(
                                                                        color: source.isActive
                                                                            ? const Color(
                                                                                0xFF1E8E4A,
                                                                              )
                                                                            : AppColors.textSecondary,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                        fontSize:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const Spacer(),
                                                                  IconButton(
                                                                    visualDensity:
                                                                        VisualDensity
                                                                            .compact,
                                                                    splashRadius:
                                                                        16,
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      minWidth:
                                                                          32,
                                                                      minHeight:
                                                                          32,
                                                                    ),
                                                                    onPressed: () =>
                                                                        editSource(
                                                                      source,
                                                                      setDialogState,
                                                                    ),
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .edit_outlined,
                                                                      color: AppColors
                                                                          .textSecondary,
                                                                      size: 18,
                                                                    ),
                                                                  ),
                                                                  if (_canDeleteLeads)
                                                                    IconButton(
                                                                      visualDensity:
                                                                          VisualDensity
                                                                              .compact,
                                                                      splashRadius:
                                                                          16,
                                                                      constraints:
                                                                          const BoxConstraints(
                                                                        minWidth:
                                                                            32,
                                                                        minHeight:
                                                                            32,
                                                                      ),
                                                                      onPressed:
                                                                          () =>
                                                                              deleteSource(
                                                                        source,
                                                                        setDialogState,
                                                                      ),
                                                                      icon:
                                                                          const Icon(
                                                                        Icons
                                                                            .delete_outline,
                                                                        color: AppColors
                                                                            .textSecondary,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ],
                                                          )
                                                        : Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 4,
                                                                child: Text(
                                                                  source.name,
                                                                  style:
                                                                      const TextStyle(
                                                                    color: AppColors
                                                                        .textPrimary,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerLeft,
                                                                  child:
                                                                      Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          5,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: source
                                                                              .isActive
                                                                          ? const Color(
                                                                              0xFFDDF7E7,
                                                                            )
                                                                          : const Color(
                                                                              0xFFF1F5F9,
                                                                            ),
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                        999,
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      source.isActive
                                                                          ? 'ACTIVE'
                                                                          : 'INACTIVE',
                                                                      style:
                                                                          TextStyle(
                                                                        color: source.isActive
                                                                            ? const Color(
                                                                                0xFF1E8E4A,
                                                                              )
                                                                            : AppColors.textSecondary,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                        fontSize:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      IconButton(
                                                                        visualDensity:
                                                                            VisualDensity.compact,
                                                                        splashRadius:
                                                                            16,
                                                                        constraints:
                                                                            const BoxConstraints(
                                                                          minWidth:
                                                                              32,
                                                                          minHeight:
                                                                              32,
                                                                        ),
                                                                        onPressed:
                                                                            () =>
                                                                                editSource(
                                                                          source,
                                                                          setDialogState,
                                                                        ),
                                                                        icon:
                                                                            const Icon(
                                                                          Icons
                                                                              .edit_outlined,
                                                                          color:
                                                                              AppColors.textSecondary,
                                                                          size:
                                                                              18,
                                                                        ),
                                                                      ),
                                                                      if (_canDeleteLeads)
                                                                        IconButton(
                                                                          visualDensity:
                                                                              VisualDensity.compact,
                                                                          splashRadius:
                                                                              16,
                                                                          constraints:
                                                                              const BoxConstraints(
                                                                            minWidth:
                                                                                32,
                                                                            minHeight:
                                                                                32,
                                                                          ),
                                                                          onPressed: () =>
                                                                              deleteSource(
                                                                            source,
                                                                            setDialogState,
                                                                          ),
                                                                          icon:
                                                                              const Icon(
                                                                            Icons.delete_outline,
                                                                            color:
                                                                                AppColors.textSecondary,
                                                                            size:
                                                                                18,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                  );
                                                },
                                              ),
                                  ),
                                ],
                              ),
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

    createController.dispose();
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
      } catch (error) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(error));
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
                        decoration: _sheetFieldDecoration('Status label'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: _toHexColor(editColor),
                              ),
                              readOnly: true,
                              decoration: _sheetFieldDecoration('Color'),
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
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: editSubmitting
                        ? null
                        : () async {
                            final label = editLabelController.text.trim();
                            if (label.isEmpty) return;
                            setEditState(() => editSubmitting = true);
                            try {
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
                            } catch (error) {
                              if (!mounted) return;
                              _showSnackBar(
                                AppErrorHandler.friendlyMessage(error),
                              );
                              if (context.mounted) {
                                setEditState(() => editSubmitting = false);
                              }
                            }
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
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                                    fontWeight: FontWeight.w800,
                                  ),
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
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: labelController,
                                  decoration:
                                      _sheetFieldDecoration('e.g. Warm Lead'),
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
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.palette_outlined,
                                              size: 12,
                                            ),
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
                                          isSubmitting ? 'Adding...' : 'Add',
                                        ),
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
                                    decoration: _sheetFieldDecoration(
                                      'e.g. Warm Lead',
                                    ),
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
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.palette_outlined,
                                          size: 12,
                                        ),
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
                                    child: Text(
                                      'No statuses found.',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  )
                                : Scrollbar(
                                    thumbVisibility:
                                        _pipelineStatuses.length > 6,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: isCompact ? 560 : 0,
                                        ),
                                        child: SingleChildScrollView(
                                          child: DataTable(
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
                                              DataColumn(
                                                label: Text('STATUS LABEL'),
                                              ),
                                              DataColumn(
                                                label: Text('PREVIEW'),
                                              ),
                                              DataColumn(
                                                label: Text('VISIBILITY'),
                                              ),
                                              DataColumn(
                                                label: Text('ACTIONS'),
                                              ),
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
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                _parseHexColor(
                                                              s.color,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              12,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            s.label,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
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
                                                            setDialogState(
                                                                () {});
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
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 15,
                                                              ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 24,
                                                                minHeight: 24,
                                                              ),
                                                              onPressed: () =>
                                                                  editStatus(
                                                                setDialogState,
                                                                s,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                size: 15,
                                                              ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 24,
                                                                minHeight: 24,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                await _authProvider
                                                                    .deleteLeadStatusConfig(
                                                                  id: s.id,
                                                                  token: _authProvider
                                                                      .currentAuthToken,
                                                                );
                                                                await refresh();
                                                                setDialogState(
                                                                    () {});
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
                                      ),
                                    ),
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
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
      _selectedLeadIds.clear();
      _isBulkSelectionMode = false;
    });
    _loadLeads();
  }

  String _formatLeadStatusLabel(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _openCreateLead() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'create',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );

    if (created == true && mounted) {
      _loadLeads();
    }
  }

  Future<void> _openEditLead(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

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

  Future<void> _deleteLead(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'delete',
      moduleLabel: 'leads',
    );
    if (!allowed || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Lead'),
          content: Text(
            'Are you sure you want to delete "${lead.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _authProvider.deleteLead(
        id: lead.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;

      setState(() {
        _currentPageLeads.removeWhere((item) => item.id == lead.id);
        _selectedLeadIds.remove(lead.id);
        _leadPhoneAccessById.remove(lead.id);
        _visiblePhoneLeadId =
            _visiblePhoneLeadId == lead.id ? null : _visiblePhoneLeadId;
        if (_totalItems > 0) {
          _totalItems -= 1;
        }
        _syncBulkSelectionMode();
      });

      _showSnackBar('Lead deleted successfully.');
      await _loadLeads();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Future<void> _callLead(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty ||
        phoneNumber.trim().toUpperCase() == 'N/A') {
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
    if (RoleAccess.canViewLeadPhones(_currentRole)) {
      await _callLead(_callPhoneForLead(lead));
      return;
    }
    await _callLead(lead.phone);
  }

  Widget _buildLeadQuickActionsTray(_LeadModel lead) {
    return Container(
      key: ValueKey<String>('quick-actions-${lead.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuickActionIcon(
            tooltip: 'WhatsApp',
            icon: Icons.chat_outlined,
            color: const Color(0xFF25D366),
            onTap: () => _sendLeadDetailsViaWhatsApp(lead),
          ),
          const SizedBox(width: 10),
          _buildQuickActionIcon(
            tooltip: 'Email',
            icon: Icons.email_outlined,
            color: const Color(0xFF1976D2),
            onTap: () => _sendLeadDetailsViaEmail(lead),
          ),
          const SizedBox(width: 10),
          _buildQuickActionIcon(
            tooltip: 'Call',
            icon: Icons.call_outlined,
            color: const Color(0xFF2E7D32),
            onTap: () => _handleCallAction(lead),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
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
                    decoration:
                        _sheetFieldDecoration('Reason for phone access'),
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
                                final message =
                                    AppErrorHandler.friendlyMessage(e);
                                if (message.toLowerCase().contains(
                                      'already have a pending request',
                                    )) {
                                  _showSnackBar(
                                      'Request pending for this lead.');
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
                                  AppErrorHandler.friendlyMessage(e),
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

  Future<void> _openBulkFollowUpForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'create',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    final selectedIds = _selectedLeadIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      _showSnackBar('Select at least one lead.');
      return;
    }
    if (selectedIds.length != 1) {
      _showSnackBar(
        'Schedule follow-up uses the existing single-lead form. Select one lead.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowUpFormPage(initialLeadId: selectedIds.first),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadLeads();
  }

  Future<void> _openBulkSiteVisitForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    final selectedIds = _selectedLeadIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      _showSnackBar('Select at least one lead.');
      return;
    }
    if (selectedIds.length != 1) {
      _showSnackBar(
        'Schedule site visit uses the existing single-lead form. Select one lead.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteVisitFormPage(initialLeadId: selectedIds.first),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadLeads();
  }

  Future<void> _openSingleFollowUpForm(_LeadModel lead) async {
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
        builder: (_) => FollowUpFormPage(initialLeadId: lead.id),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadLeads();
  }

  Future<void> _openSingleSiteVisitForm(_LeadModel lead) async {
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
        builder: (_) => SiteVisitFormPage(initialLeadId: lead.id),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadLeads();
  }

  Future<void> _openStatusSheet(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final statusOptions = _allStatusOptions();
    if (statusOptions.isEmpty) {
      _showSnackBar('No statuses available.');
      return;
    }

    final current = _normalizeStatus(lead.status);
    _selectedNextStatus =
        statusOptions.contains(current) ? current : statusOptions.first;
    _statusNoteController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    items: statusOptions
                        .map(
                          (status) => SearchableDropdownItem<String>(
                            value: status,
                            label: _prettyStatus(status),
                          ),
                        )
                        .toList(),
                    enabled: !_isSubmittingStatus,
                    onChanged: (value) {
                      setSheetState(() {
                        _selectedNextStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _statusNoteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: _sheetFieldDecoration('Add note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmittingStatus
                          ? null
                          : () async {
                              setSheetState(() {
                                _isSubmittingStatus = true;
                              });
                              final updatedStatus =
                                  await _submitStatusChange(lead);
                              if (!mounted) {
                                return;
                              }
                              setSheetState(() {
                                _isSubmittingStatus = false;
                              });
                              if (updatedStatus != null) {
                                Navigator.of(context).pop();
                                if (_isFollowUpConversionStatus(
                                  updatedStatus,
                                )) {
                                  await _openSingleFollowUpForm(lead);
                                } else if (_isSiteVisitScheduleStatus(
                                  updatedStatus,
                                )) {
                                  await _openSingleSiteVisitForm(lead);
                                } else if (_isEoiStatus(updatedStatus) &&
                                    !(await _leadHasEoiDocuments(lead))) {
                                  await _openLeadEoiDocumentsModal(lead);
                                } else if (_isEoiStatus(updatedStatus)) {
                                  await _openLeadEoiDocumentsModal(lead);
                                }
                              }
                            },
                      child: Text(
                        _isSubmittingStatus ? 'Updating...' : 'Update Status',
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

  Future<String?> _submitStatusChange(_LeadModel lead) async {
    if (_selectedNextStatus == null || _selectedNextStatus!.isEmpty) {
      _showSnackBar('Please select the next status.');
      return null;
    }

    try {
      final updatedStatus = _selectedNextStatus!;
      await _authProvider.updateLeadStatus(
        id: lead.id,
        status: updatedStatus,
        note: _statusNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _loadLeads();
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
    }
  }

  Future<bool> _leadHasEoiDocuments(_LeadModel lead) async {
    if (_rawLeadHasEoiDocuments(lead.rawData)) {
      return true;
    }
    try {
      final proofs = await _authProvider.leadPaymentProofs(
        id: lead.id,
        token: _authProvider.currentAuthToken,
      );
      return proofs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _rawLeadHasEoiDocuments(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['payment_proofs'],
      data['paymentProofs'],
      data['payment_proof'],
      data['paymentProof'],
      data['eoi_documents'],
      data['eoiDocuments'],
    ];
    for (final candidate in candidates) {
      if (candidate is List && candidate.isNotEmpty) {
        return true;
      }
      if (candidate is Map && candidate.isNotEmpty) {
        return true;
      }
      if (_readString(candidate).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _uploadLeadEoiDocument(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final amountController = TextEditingController();
    PlatformFile? selectedFile;
    var shouldUpload = false;
    var isUploading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sheetContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
          actionsPadding: const EdgeInsets.fromLTRB(30, 0, 30, 26),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 20, 22, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Upload Payment Proof',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isUploading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: _sheetFieldDecoration('e.g. 50000').copyWith(
                      labelText: 'Amount',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'File *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final picked =
                                      await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowMultiple: false,
                                    allowedExtensions: const <String>[
                                      'jpg',
                                      'jpeg',
                                      'png',
                                      'webp',
                                      'pdf',
                                    ],
                                  );
                                  if (picked == null ||
                                      picked.files.isEmpty ||
                                      !dialogContext.mounted) {
                                    return;
                                  }
                                  selectedFile = picked.files.first;
                                  setDialogState(() {});
                                },
                          child: const Text('Choose File'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedFile?.name ?? 'No file chosen',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isUploading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isUploading
                        ? null
                        : () {
                            if (!_hasSelectedUploadFile(selectedFile)) {
                              _showSnackBar('Please choose a file.');
                              return;
                            }
                            shouldUpload = true;
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!mounted || !shouldUpload || !_hasSelectedUploadFile(selectedFile)) {
      amountController.dispose();
      return;
    }

    setState(() {
      isUploading = true;
    });
    try {
      await _authProvider.uploadLeadPaymentProof(
        id: lead.id,
        filePath: _platformFilePath(selectedFile),
        fileBytes: selectedFile?.bytes,
        fileName: selectedFile?.name.trim() ?? '',
        name: selectedFile?.name.trim() ?? '',
        amount: amountController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('EOI document uploaded successfully.');
      await _loadLeads();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      amountController.dispose();
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> _openLeadEoiDocumentsModal(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    var paymentProofs = <Map<String, dynamic>>[];
    var bookingPhotos = <Map<String, dynamic>>[];
    try {
      paymentProofs = await _authProvider.leadPaymentProofs(
        id: lead.id,
        token: _authProvider.currentAuthToken,
      );
    } catch (_) {
      paymentProofs = const <Map<String, dynamic>>[];
    }
    try {
      bookingPhotos = await _authProvider.leadPhotos(
        id: lead.id,
        token: _authProvider.currentAuthToken,
      );
    } catch (_) {
      bookingPhotos = const <Map<String, dynamic>>[];
    }
    if (!mounted) return;

    var isUploadingProof = false;
    var isUploadingPhoto = false;

    Future<void> uploadPaymentProof(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      setDialogState(() => isUploadingProof = true);
      try {
        await _uploadLeadEoiDocument(lead);
        paymentProofs = await _authProvider.leadPaymentProofs(
          id: lead.id,
          token: _authProvider.currentAuthToken,
        );
        if (!mounted || !dialogContext.mounted) return;
        await _loadLeads();
      } catch (error) {
        if (mounted) {
          _showSnackBar(AppErrorHandler.friendlyMessage(error));
        }
      } finally {
        if (mounted && dialogContext.mounted) {
          setDialogState(() => isUploadingProof = false);
        }
      }
    }

    Future<void> uploadBookingPhoto(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.first;
      if (!_hasSelectedUploadFile(file)) {
        _showSnackBar('Please choose a photo.');
        return;
      }

      setDialogState(() => isUploadingPhoto = true);
      try {
        await _authProvider.uploadLeadPhoto(
          id: lead.id,
          filePath: _platformFilePath(file),
          fileBytes: file.bytes,
          fileName: file.name.trim(),
          name: file.name.trim(),
          token: _authProvider.currentAuthToken,
        );
        bookingPhotos = await _authProvider.leadPhotos(
          id: lead.id,
          token: _authProvider.currentAuthToken,
        );
        if (!mounted || !dialogContext.mounted) return;
        _showSnackBar('Booking form photo uploaded successfully.');
        await _loadLeads();
      } catch (error) {
        if (mounted) {
          _showSnackBar(AppErrorHandler.friendlyMessage(error));
        }
      } finally {
        if (mounted && dialogContext.mounted) {
          setDialogState(() => isUploadingPhoto = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isUploadingProof && !isUploadingPhoto,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final proof = paymentProofs.isNotEmpty ? paymentProofs.first : null;
            final photo = bookingPhotos.isNotEmpty ? bookingPhotos.first : null;
            final isBusy = isUploadingProof || isUploadingPhoto;
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              title: Row(
                children: [
                  const Expanded(child: Text('EOI Documents')),
                  IconButton(
                    onPressed:
                        isBusy ? null : () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7DF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EOI Documents',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Payment proof and booking form photo for this EOI',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 560;
                          final proofColumn = _buildEoiDocumentColumn(
                            title: 'PAYMENT PROOF',
                            primaryLabel: 'Document',
                            primaryValue: _docName(proof, '--'),
                            secondaryLabel: 'Amount',
                            secondaryValue: _docAmount(proof),
                            buttonLabel: isUploadingProof
                                ? 'Uploading...'
                                : 'Upload Payment Proof',
                            onUpload: isBusy
                                ? null
                                : () => uploadPaymentProof(
                                      setDialogState,
                                      dialogContext,
                                    ),
                            onPreview: proof == null
                                ? null
                                : () => _openEoiDocumentPreview(proof),
                          );
                          final photoColumn = _buildEoiDocumentColumn(
                            title: 'BOOKING FORM PHOTO',
                            primaryLabel: '',
                            primaryValue: _docName(photo, '--'),
                            secondaryLabel: '',
                            secondaryValue: '',
                            buttonLabel: isUploadingPhoto
                                ? 'Uploading...'
                                : 'Upload Photo',
                            onUpload: isBusy
                                ? null
                                : () => uploadBookingPhoto(
                                      setDialogState,
                                      dialogContext,
                                    ),
                            onPreview: photo == null
                                ? null
                                : () => _openEoiDocumentPreview(photo),
                          );
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                proofColumn,
                                const SizedBox(height: 22),
                                photoColumn,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: proofColumn),
                              const SizedBox(width: 36),
                              Expanded(child: photoColumn),
                            ],
                          );
                        },
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
  }

  Widget _buildEoiDocumentColumn({
    required String title,
    required String primaryLabel,
    required String primaryValue,
    required String secondaryLabel,
    required String secondaryValue,
    required String buttonLabel,
    required VoidCallback? onUpload,
    VoidCallback? onPreview,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),
        if (primaryLabel.isNotEmpty) ...[
          Text(
            primaryLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          primaryValue.isEmpty ? '--' : primaryValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (secondaryLabel.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            secondaryLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            secondaryValue.isEmpty ? '--' : secondaryValue,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (onPreview != null)
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(buttonLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _docName(Map<String, dynamic>? doc, String fallback) {
    if (doc == null) return fallback;
    final value = _readString(
      doc['name'] ?? doc['title'] ?? doc['file_name'] ?? doc['filename'],
    );
    return value.isEmpty ? fallback : value;
  }

  String _docAmount(Map<String, dynamic>? doc) {
    if (doc == null) return '--';
    final value = _readString(doc['amount'] ?? doc['payment_proof_amount']);
    return value.isEmpty ? '--' : value;
  }

  String _fileNameFromUrl(String url, {required String fallback}) {
    final value = url.trim();
    if (value.isEmpty) {
      return fallback;
    }
    final uri = Uri.tryParse(value);
    final path = uri?.path.trim().isNotEmpty == true ? uri!.path : value;
    final fileName = path.replaceAll('\\', '/').split('/').last.trim();
    if (fileName.isEmpty) {
      return fallback;
    }
    return Uri.decodeComponent(fileName);
  }

  String _docUrl(Map<String, dynamic>? doc) {
    if (doc == null) return '';
    final raw = _readString(
      doc['public_url'] ??
          doc['url'] ??
          doc['payment_proof_url'] ??
          doc['file_url'] ??
          doc['file_path'] ??
          doc['path'],
    );
    if (raw.startsWith('/')) {
      return 'https://api.nextonerealty.in$raw';
    }
    return raw;
  }

  bool _isPreviewImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Future<void> _openEoiDocumentPreview(Map<String, dynamic> doc) async {
    final url = _docUrl(doc);
    if (url.isEmpty) {
      _showSnackBar('File is not available.');
      return;
    }
    if (_isPreviewImageUrl(url)) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _docName(doc, 'Document'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('File link is not valid.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _hasSelectedUploadFile(PlatformFile? file) {
    if (file == null) {
      return false;
    }
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return true;
    }
    try {
      final path = file.path;
      return path != null && path.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _platformFilePath(PlatformFile? file) {
    if (file == null) {
      return '';
    }
    try {
      return file.path?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openReassignSheet(_LeadModel lead) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

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
              title:
                  lead.assignedToId.isEmpty ? 'Assign Lead' : 'Reassign Lead',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    label: 'Assignee',
                    sheetTitle: lead.assignedToId.isEmpty
                        ? 'Assign Lead'
                        : 'Reassign Lead',
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
                    onChanged: (value) {
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
                              final reassigned =
                                  await _submitReassignment(lead);
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
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
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
                  SearchableDropdownField<String>(
                    label: 'Assignee',
                    sheetTitle: 'Assign Selected Leads',
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
                    onChanged: (value) {
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
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Leads export downloaded and saved to: ${outFile.path}',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is UnsupportedError
          ? 'This platform does not support local file save for export yet.'
          : AppErrorHandler.friendlyMessage(error);
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

            final isValidRange = fromDate != null &&
                toDate != null &&
                !toDate!.isBefore(fromDate!);

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

  String _normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  bool _isFollowUpConversionStatus(String status) {
    final normalized = _normalizeStatus(status);
    return normalized == 'follow_up' || normalized == 'followup';
  }

  bool _isSiteVisitScheduleStatus(String status) {
    final normalized = _normalizeStatus(status);
    return normalized == 'site_visit_scheduled' ||
        normalized == 'site_visit_schedule' ||
        normalized == 'schedule_visit' ||
        normalized == 'scheduled_visit';
  }

  bool _isEoiStatus(String status) {
    return _normalizeStatus(status) == 'eoi';
  }

  List<String> _allStatusOptions() {
    final apiStatuses = _pipelineStatuses
        .where((status) => status.isActive && status.key.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final apiFlow = apiStatuses
        .map((status) => _normalizeStatus(status.key))
        .where((status) => status.isNotEmpty)
        .toList(growable: false);
    return apiFlow.isNotEmpty ? apiFlow : _statusFlow;
  }

  String _prettyStatus(String status) {
    final normalized = _normalizeStatus(status);
    final configured = _pipelineStatuses.where((item) {
      return _normalizeStatus(item.key) == normalized;
    }).toList();
    if (configured.isNotEmpty && configured.first.label.trim().isNotEmpty) {
      return configured.first.label;
    }
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<String> _allowedTransitions(String current) {
    final flow = _allStatusOptions();

    if (current.isEmpty || !flow.contains(current)) {
      return flow;
    }
    if (current == 'booked' || current == 'lost') {
      return const <String>[];
    }
    final index = flow.indexOf(current);
    if (index < 0 || index + 1 >= flow.length) {
      return const <String>[];
    }
    return flow.sublist(index + 1);
  }

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
                              .map(
                                (c) => GestureDetector(
                                  onTap: () {
                                    setColorState(() {
                                      temp = c;
                                      red = ((c.r * 255).round()).clamp(0, 255);
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
                                ),
                              )
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
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
      appBar: CrmAppBar(title: widget.title),
      body: RefreshIndicator(
        onRefresh: _loadLeads,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showLeadTabs) ...[
                _buildLeadTabs(),
                const SizedBox(height: 16),
              ],
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

  Widget _buildLeadTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
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
      child: Row(
        children: [
          Expanded(
            child: _buildLeadTabButton(
              label: 'My Leads',
              tabIndex: _myLeadsTabIndex,
            ),
          ),
          Expanded(
            child: _buildLeadTabButton(
              label: 'Team Leads',
              tabIndex: _teamLeadsTabIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadTabButton({
    required String label,
    required int tabIndex,
  }) {
    final isActive = _activeLeadsTabIndex == tabIndex;
    return GestureDetector(
      onTap: () => _switchLeadsTab(tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.textSecondary,
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
              hintText: 'Search by lead name, email, or phone',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final filterButton = OutlinedButton.icon(
          onPressed: _openFiltersSheet,
          icon: const Icon(Icons.filter_alt_outlined, size: 16),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Filters',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          style: OutlinedButton.styleFrom(
            fixedSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final exportButton = _showExportButton
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportLeads,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(_isExporting ? 'Exporting...' : 'Export'),
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final bulkButton = _canUseBulkLeadTools
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _openLeadBulkDialog,
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bulk',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final canManageLeadMetadata =
            RoleAccess.isAdminOrSuperAdmin(_currentRole);

        final addSourceButton = canManageLeadMetadata
            ? OutlinedButton.icon(
                onPressed: _openManageLeadSourcesDialog,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Manage Source',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final manageStatusButton = canManageLeadMetadata
            ? OutlinedButton.icon(
                onPressed: _openManagePipelineStatusesDialog,
                icon: const Icon(Icons.tune_outlined, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Manage Status',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final addButton = FilledButton.icon(
          onPressed: _openCreateLead,
          icon: const Icon(Icons.add, size: 16),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Add Lead',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          style: FilledButton.styleFrom(
            fixedSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Widget firstActionRow() {
          return Row(
            children: [
              if (bulkButton != null) ...[
                Expanded(child: bulkButton),
                const SizedBox(width: 8),
              ],
              Expanded(child: filterButton),
              const SizedBox(width: 8),
              Expanded(child: addButton),
            ],
          );
        }

        Widget secondActionRow() {
          final widgets = <Widget>[
            if (addSourceButton != null) Expanded(child: addSourceButton),
            if (manageStatusButton != null) ...[
              if (addSourceButton != null) const SizedBox(width: 8),
              Expanded(child: manageStatusButton),
            ],
            if (exportButton != null) ...[
              if (addSourceButton != null || manageStatusButton != null)
                const SizedBox(width: 8),
              Expanded(child: exportButton),
            ],
          ];

          if (widgets.isEmpty) {
            return const SizedBox.shrink();
          }

          return Row(
            children: widgets,
          );
        }

        if (isCompact) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              firstActionRow(),
              if (canManageLeadMetadata || exportButton != null) ...[
                const SizedBox(height: 8),
                secondActionRow(),
              ],
            ],
          );
        }

        return Column(
          children: [
            searchField,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: firstActionRow(),
                  ),
                ),
              ],
            ),
            if (canManageLeadMetadata || exportButton != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: secondActionRow(),
                    ),
                  ),
                ],
              ),
            ],
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
                        label: const Text('Reassign'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openBulkFollowUpForm,
                        icon: const Icon(Icons.event_note_outlined, size: 16),
                        label: const Text('Schedule Follow-up'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openBulkSiteVisitForm,
                        icon: const Icon(Icons.location_on_outlined, size: 16),
                        label: const Text('Schedule Site Visit'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ),
                  ],
                );
              }

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
                      label: const Text('Reassign'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openBulkFollowUpForm,
                          icon: const Icon(Icons.event_note_outlined, size: 16),
                          label: const Text('Schedule Follow-up'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openBulkSiteVisitForm,
                          icon:
                              const Icon(Icons.location_on_outlined, size: 16),
                          label: const Text('Schedule Site Visit'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        ),
                      ),
                    ],
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
              final isQuickActionsOpen = _expandedQuickActionLeadId == lead.id;
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
                      phoneAction: _phoneRevealAction(lead),
                      profileImageUrl: lead.profileImageUrl,
                      assigneeName: lead.assignee.name,
                      assigneeImageUrl: lead.assignee.imageUrl,
                      onTap: () => _viewLeadDetail(lead.id),
                      actions: [
                        DataCardAction(
                          icon: isQuickActionsOpen
                              ? Icons.close_rounded
                              : Icons.phone_outlined,
                          color: const Color(0xFF2E7D32),
                          onTap: () {
                            setState(() {
                              _expandedQuickActionLeadId =
                                  isQuickActionsOpen ? null : lead.id;
                            });
                          },
                        ),
                        DataCardAction(
                          icon: Icons.person_add_alt_1_outlined,
                          color: AppColors.primary,
                          onTap: () => _openReassignSheet(lead),
                        ),
                        DataCardAction(
                          icon: Icons.autorenew_rounded,
                          color: const Color(0xFF14B8A6),
                          onTap: () => _openStatusSheet(lead),
                        ),
                        DataCardAction(
                          icon: Icons.edit_outlined,
                          onTap: () => _openEditLead(lead),
                        ),
                        if (_canDeleteLeads)
                          DataCardAction(
                            icon: Icons.delete_outline,
                            color: const Color(0xFFD32F2F),
                            onTap: () => _deleteLead(lead),
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
                      duration: const Duration(milliseconds: 180),
                      child: isQuickActionsOpen
                          ? _buildLeadQuickActionsTray(lead)
                          : const SizedBox.shrink(),
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
            '$_totalItems total ${_isMyLeadsTab ? 'my leads' : 'team leads'}',
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
    final end = totalItems == 0
        ? 0
        : (currentPage * _pageSize > totalItems
            ? totalItems
            : currentPage * _pageSize);

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
            spacing: 8,
            children: [
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              PaginationWidget(
                currentPage: currentPage,
                totalPages: totalPages,
                totalItems: totalItems,
                itemLabel: 'leads',
                onPageChanged: _isLoadingLeads ? (_) {} : _changePage,
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
    if (_canSeeFullLeadPhone) {
      return rawPhone;
    }
    if (_visiblePhoneLeadId == lead.id) {
      final grantedPhone = _readString(access?.phone);
      return grantedPhone.isNotEmpty ? grantedPhone : rawPhone;
    }
    return _maskPhone(rawPhone);
  }

  String _callPhoneForLead(_LeadModel lead) {
    final access = _leadPhoneAccessById[lead.id];
    if (_canSeeFullLeadPhone || _visiblePhoneLeadId == lead.id) {
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
    final keepCount = value.length < 5 ? value.length : 5;
    final hiddenCount = value.length - keepCount;
    if (hiddenCount <= 0) {
      return value;
    }
    return '${'*' * hiddenCount}${value.substring(value.length - keepCount)}';
  }

  bool get _canSeeFullLeadPhone {
    return RoleAccess.canViewLeadPhones(_currentRole);
  }

  Widget? _phoneRevealAction(_LeadModel lead) {
    if (_canSeeFullLeadPhone || lead.phone.trim().isEmpty) {
      return null;
    }
    final isVisible = _visiblePhoneLeadId == lead.id;
    return InkWell(
      onTap: () {
        setState(() {
          _visiblePhoneLeadId = isVisible ? null : lead.id;
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
      id: readString(json['id'] ?? json['source_id'] ?? json['uuid']),
      name: readString(json['name'] ?? json['source']),
      isActive: readBool(
        json['is_active'] ?? json['isActive'] ?? json['active'] ?? true,
      ),
    );
  }
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
