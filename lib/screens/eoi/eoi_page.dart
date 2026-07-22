import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/leads/lead_bulk_upload_page.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/screens/leads/lead_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:nextone/widgets/pagination_widget.dart';

class EoiPage extends StatefulWidget {
  const EoiPage({super.key});

  @override
  State<EoiPage> createState() => _EoiPageState();
}

class _EoiPageState extends State<EoiPage> {
  static const int _myEoiTabIndex = 0;
  static const int _teamEoiTabIndex = 1;
  static const List<String> _defaultSourceOptions = <String>[
    'Facebook',
    'Walk-in',
    'Referral',
  ];

  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();

  Timer? _searchDebounce;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _loadError;
  String _currentRole = '';
  int _activeTabIndex = _myEoiTabIndex;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  String? _selectedSource;
  String? _selectedTeamId;
  List<_LeadModel> _currentPageLeads = <_LeadModel>[];
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  List<_LeadSourceOption> _leadSources = const <_LeadSourceOption>[];
  List<_PipelineStatusOption> _pipelineStatuses =
      const <_PipelineStatusOption>[];

  bool get _isMyTab => _activeTabIndex == _myEoiTabIndex;
  bool get _canDeleteLeads => RoleAccess.canDeleteModule('leads');
  bool get _canExportData => RoleAccess.canExportModule('leads');
  bool get _showExportButton =>
      _canExportData && RoleAccess.isAdminOrSuperAdmin(_currentRole);
  bool get _canUseBulkLeadTools => RoleAccess.canCreateModule('leads');
  bool get _showLeadTabs =>
      _currentRole.isNotEmpty &&
      !RoleAccess.isAdmin(_currentRole) &&
      !RoleAccess.isSuperAdmin(_currentRole);

  List<String> get _sourceOptions {
    final values = <String>{
      ..._defaultSourceOptions,
      ..._leadSources
          .where((source) => source.isActive)
          .map((source) => source.name)
          .where((source) => source.trim().isNotEmpty),
      ..._currentPageLeads
          .map((lead) => lead.source)
          .where((source) => source.trim().isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<_LeadModel> get _visibleLeads {
    final query = _projectController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _currentPageLeads;
    }
    return _currentPageLeads.where((lead) {
      return lead.project.toLowerCase().contains(query) ||
          lead.locationPreference.toLowerCase().contains(query) ||
          lead.notes.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadAssigneeOptions();
    _loadLeadSources();
    _loadPipelineStatuses();
    _loadEoiLeads();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      final isAdminRole =
          RoleAccess.isAdmin(role) || RoleAccess.isSuperAdmin(role);
      setState(() {
        _currentRole = role;
        if (isAdminRole) {
          _activeTabIndex = _teamEoiTabIndex;
          _selectedTeamId = null;
        }
      });
      if (isAdminRole) {
        _loadEoiLeads();
      }
    } catch (_) {
      // Keep screen usable with fallback role state.
    }
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
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _assigneeOptions = options;
      });
    } catch (_) {
      // Team filter remains optional.
    }
  }

  Future<void> _loadLeadSources() async {
    try {
      final items = await _authProvider.leadSourcesConfig(
        token: _authProvider.currentAuthToken,
      );
      final sources = items.map(_LeadSourceOption.fromApi).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _leadSources = sources;
        if (_selectedSource != null &&
            !sources.any((source) => source.name == _selectedSource)) {
          _selectedSource = null;
        }
      });
    } catch (_) {
      // Keep screen usable without source config data.
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
      });
    } catch (_) {
      // Keep screen usable without status config data.
    }
  }

  Future<void> _loadEoiLeads() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final result = _isMyTab
          ? await _authProvider.myLeads(
              token: _authProvider.currentAuthToken,
              status: 'eoi',
              source: _selectedSource,
              search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
              page: _currentPage,
              perPage: _pageSize,
            )
          : await _authProvider.leads(
              token: _authProvider.currentAuthToken,
              status: 'eoi',
              source: _selectedSource,
              assignedTo: _selectedTeamId,
              search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
              page: _currentPage,
              perPage: _pageSize,
            );

      if (!mounted) return;

      setState(() {
        _currentPageLeads = result.items.map(_LeadModel.fromApi).toList();
        _currentPage = result.currentPage <= 0 ? 1 : result.currentPage;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _totalItems = result.totalItems;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _currentPageLeads = <_LeadModel>[];
        _totalItems = 0;
        _totalPages = 1;
        _isLoading = false;
        _loadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _currentPage = 1;
      });
      _loadEoiLeads();
    });
  }

  void _switchTab(int tabIndex) {
    if (_activeTabIndex == tabIndex) return;
    setState(() {
      _activeTabIndex = tabIndex;
      _currentPage = 1;
      _selectedTeamId = null;
    });
    _loadEoiLeads();
  }

  void _changePage(int page) {
    if (page == _currentPage) return;
    setState(() {
      _currentPage = page;
    });
    _loadEoiLeads();
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
    if (!mounted) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );

    if (created == true && mounted) {
      _loadEoiLeads();
    }
  }

  Future<void> _openBulkUpload() async {
    if (!_canUseBulkLeadTools) {
      _showSnackBar('You do not have permission to use bulk lead tools.');
      return;
    }

    final result = await Navigator.of(context).push<LeadBulkUploadResult>(
      MaterialPageRoute(builder: (_) => const LeadBulkUploadPage()),
    );

    if (!mounted || result == null) return;
    await _loadEoiLeads();
    if (!mounted) return;
    final resultFilename = result.resultFilename;
    _showSnackBar(
      resultFilename == null || resultFilename.trim().isEmpty
          ? result.message
          : '${result.message} Result file: $resultFilename',
    );
  }

  Future<void> _openFiltersSheet() async {
    String? tempSource = _selectedSource;
    String? tempTeamId = _isMyTab ? null : _selectedTeamId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetContainer(
              title: 'EOI Filters',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: tempSource,
                    decoration: _sheetFieldDecoration('Select source'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Sources'),
                      ),
                      ..._sourceOptions.map(
                        (source) => DropdownMenuItem<String?>(
                          value: source,
                          child: Text(source),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        tempSource = value;
                      });
                    },
                  ),
                  if (!_isMyTab) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: tempTeamId,
                      decoration: _sheetFieldDecoration('Select team member'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Team'),
                        ),
                        ..._assigneeOptions.map(
                          (assignee) => DropdownMenuItem<String?>(
                            value: assignee.id,
                            child: Text(assignee.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          tempTeamId = value;
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
                              _selectedSource = null;
                              _selectedTeamId = null;
                              _currentPage = 1;
                            });
                            Navigator.of(context).pop();
                            _loadEoiLeads();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedSource = tempSource;
                              _selectedTeamId = _isMyTab ? null : tempTeamId;
                              _currentPage = 1;
                            });
                            Navigator.of(context).pop();
                            _loadEoiLeads();
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
  }

  Future<void> _openManageLeadSourcesDialog() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'edit',
      moduleLabel: 'leads',
    );
    if (!allowed) return;
    if (!mounted) return;

    final createController = TextEditingController();
    bool isSubmitting = false;

    Future<void> refreshSources(
        void Function(void Function()) setDialogState) async {
      await _loadLeadSources();
      if (mounted) {
        setDialogState(() {});
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createSource() async {
              final name = createController.text.trim();
              if (name.isEmpty) {
                _showSnackBar('Please enter source name.');
                return;
              }
              setDialogState(() => isSubmitting = true);
              try {
                await _authProvider.createLeadSource(
                  name: name,
                  token: _authProvider.currentAuthToken,
                );
                createController.clear();
                await refreshSources(setDialogState);
                _showSnackBar('Lead source created successfully.');
              } catch (error) {
                _showSnackBar(AppErrorHandler.friendlyMessage(error));
              } finally {
                if (context.mounted) {
                  setDialogState(() => isSubmitting = false);
                }
              }
            }

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
                      padding: const EdgeInsets.all(16),
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
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: createController,
                                  decoration:
                                      _sheetFieldDecoration('New source name'),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: isSubmitting ? null : createSource,
                                  child:
                                      Text(isSubmitting ? 'Adding...' : 'Add'),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: createController,
                                    decoration: _sheetFieldDecoration(
                                      'New source name',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: isSubmitting ? null : createSource,
                                  child:
                                      Text(isSubmitting ? 'Adding...' : 'Add'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _leadSources.isEmpty
                                ? const Center(
                                    child: Text('No lead sources found.'),
                                  )
                                : ListView.separated(
                                    itemCount: _leadSources.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final source = _leadSources[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(source.name),
                                        subtitle: Text(
                                          source.isActive
                                              ? 'Active'
                                              : 'Inactive',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              onPressed: () async {
                                                await _editLeadSource(source);
                                                if (dialogContext.mounted) {
                                                  await refreshSources(
                                                    setDialogState,
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                await _deleteLeadSource(source);
                                                if (dialogContext.mounted) {
                                                  await refreshSources(
                                                    setDialogState,
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
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
                );
              },
            );
          },
        );
      },
    );

    createController.dispose();
  }

  Future<void> _editLeadSource(_LeadSourceOption source) async {
    final nameController = TextEditingController(text: source.name);
    bool isActive = source.isActive;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Lead Source'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: _sheetFieldDecoration('Source name'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                          setDialogState(() => isSaving = true);
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
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (error) {
                            _showSnackBar(
                                AppErrorHandler.friendlyMessage(error));
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
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

  Future<void> _deleteLeadSource(_LeadSourceOption source) async {
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

    if (confirmed != true) return;
    try {
      await _authProvider.deleteLeadSource(
        id: source.id,
        token: _authProvider.currentAuthToken,
      );
      _showSnackBar('Lead source deleted successfully.');
    } catch (error) {
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
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
    if (!mounted) return;

    final labelController = TextEditingController();
    final colorController = TextEditingController(text: '#3B82F6');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> refreshStatuses() async {
              await _loadPipelineStatuses();
              if (context.mounted) {
                setDialogState(() {});
              }
            }

            Future<void> createStatus() async {
              final label = labelController.text.trim();
              if (label.isEmpty) {
                _showSnackBar('Please enter status label.');
                return;
              }
              setDialogState(() => isSubmitting = true);
              try {
                final key =
                    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                await _authProvider.createLeadStatus(
                  key: key,
                  label: label,
                  color: colorController.text.trim().isEmpty
                      ? '#3B82F6'
                      : colorController.text.trim(),
                  sortOrder: _pipelineStatuses.length + 1,
                  token: _authProvider.currentAuthToken,
                );
                labelController.clear();
                colorController.text = '#3B82F6';
                await refreshStatuses();
                _showSnackBar('Pipeline status created.');
              } catch (error) {
                _showSnackBar(AppErrorHandler.friendlyMessage(error));
              } finally {
                if (context.mounted) {
                  setDialogState(() => isSubmitting = false);
                }
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 640;
                final dialogWidth = width < 520 ? width * 0.98 : 680.0;
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Manage Pipeline Statuses',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: labelController,
                                  decoration:
                                      _sheetFieldDecoration('Status label'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: colorController,
                                  decoration: _sheetFieldDecoration('Color'),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: isSubmitting ? null : createStatus,
                                  child: Text(
                                    isSubmitting ? 'Adding...' : 'Add',
                                  ),
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
                                      'Status label',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: colorController,
                                    decoration: _sheetFieldDecoration('Color'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: isSubmitting ? null : createStatus,
                                  child: Text(
                                    isSubmitting ? 'Adding...' : 'Add',
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _pipelineStatuses.isEmpty
                                ? const Center(
                                    child: Text('No statuses found.'),
                                  )
                                : ListView.separated(
                                    itemCount: _pipelineStatuses.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final status = _pipelineStatuses[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(status.label),
                                        subtitle: Text(
                                          status.isActive
                                              ? 'Active'
                                              : 'Inactive',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              onPressed: () async {
                                                await _editPipelineStatus(
                                                  status,
                                                );
                                                if (dialogContext.mounted) {
                                                  await refreshStatuses();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                await _deletePipelineStatus(
                                                  status,
                                                );
                                                if (dialogContext.mounted) {
                                                  await refreshStatuses();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
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

  Future<void> _editPipelineStatus(_PipelineStatusOption status) async {
    final labelController = TextEditingController(text: status.label);
    final colorController = TextEditingController(text: status.color);
    bool isActive = status.isActive;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: _sheetFieldDecoration('Status label'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: colorController,
                    decoration: _sheetFieldDecoration('Color'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final label = labelController.text.trim();
                          if (label.isEmpty) return;
                          setDialogState(() => isSaving = true);
                          try {
                            await _authProvider.updateLeadStatusConfig(
                              id: status.id,
                              label: label,
                              color: colorController.text.trim(),
                              isActive: isActive,
                              token: _authProvider.currentAuthToken,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (error) {
                            _showSnackBar(
                                AppErrorHandler.friendlyMessage(error));
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
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

    labelController.dispose();
    colorController.dispose();
  }

  Future<void> _deletePipelineStatus(_PipelineStatusOption status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Status'),
          content: Text('Delete "${status.label}"?'),
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

    if (confirmed != true) return;
    try {
      await _authProvider.deleteLeadStatusConfig(
        id: status.id,
        token: _authProvider.currentAuthToken,
      );
      _showSnackBar('Pipeline status deleted.');
    } catch (error) {
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Future<void> _exportLeads() async {
    if (!_canExportData) {
      _showSnackBar('You do not have permission to export leads.');
      return;
    }
    final range = await _showExportDateRangeDialog();
    if (!mounted || range == null) return;

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
      if (!mounted) return;
      final safeFileName = exported.fileName.trim().isEmpty
          ? 'leads_${from}_to_$to.xlsx'
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Export generated ($safeFileName), but direct file save is not supported on Web in this build.',
        );
        return;
      }
      final outFile = await ExportFileHelper.saveToDownloadNextone(
        fileName: safeFileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;
      _showSnackBar('Leads export downloaded and saved to: ${outFile.path}');
    } catch (error) {
      final message = error is UnsupportedError
          ? 'This platform does not support local file save for export yet.'
          : AppErrorHandler.friendlyMessage(error);
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
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

  Future<void> _viewLeadDetail(String leadId) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LeadDetailPage(leadId: leadId)),
      );
      if (mounted) {
        _loadEoiLeads();
      }
    } catch (error) {
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
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
    if (!mounted) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadFormPage(
          leadId: lead.id,
          leadData: lead.rawData,
        ),
      ),
    );

    if (updated == true && mounted) {
      _loadEoiLeads();
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
          content: Text('Are you sure you want to delete "${lead.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _authProvider.deleteLead(
        id: lead.id,
        token: _authProvider.currentAuthToken,
      );
      _showSnackBar('Lead deleted successfully.');
      _loadEoiLeads();
    } catch (error) {
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleLeads = _visibleLeads;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'EOI Management'),
      body: RefreshIndicator(
        onRefresh: _loadEoiLeads,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showLeadTabs) ...[
                _buildTabs(),
                const SizedBox(height: 16),
              ],
              _buildToolbar(),
              const SizedBox(height: 16),
              _buildLeadsSection(visibleLeads),
              const SizedBox(height: 16),
              _buildPagination(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
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
            child: _buildTabButton(
              label: 'My EOI',
              tabIndex: _myEoiTabIndex,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Team EOI',
              tabIndex: _teamEoiTabIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int tabIndex,
  }) {
    final isActive = _activeTabIndex == tabIndex;
    return GestureDetector(
      onTap: () => _switchTab(tabIndex),
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
        final canManageLeadMetadata =
            RoleAccess.isAdminOrSuperAdmin(_currentRole);

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
          label: const Text('Filters'),
          style: _actionButtonStyle(backgroundColor: AppColors.card),
        );

        final bulkButton = _canUseBulkLeadTools
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _openBulkUpload,
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text('Bulk'),
                style: _actionButtonStyle(backgroundColor: AppColors.card),
              )
            : null;

        final addButton = FilledButton.icon(
          onPressed: _openCreateLead,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Lead'),
          style: FilledButton.styleFrom(
            fixedSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final addSourceButton = canManageLeadMetadata
            ? OutlinedButton.icon(
                onPressed: _openManageLeadSourcesDialog,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Manage Source'),
                style: _actionButtonStyle(backgroundColor: AppColors.card),
              )
            : null;

        final manageStatusButton = canManageLeadMetadata
            ? OutlinedButton.icon(
                onPressed: _openManagePipelineStatusesDialog,
                icon: const Icon(Icons.tune_outlined, size: 16),
                label: const Text('Manage Status'),
                style: _actionButtonStyle(backgroundColor: AppColors.card),
              )
            : null;

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
                style: _actionButtonStyle(backgroundColor: AppColors.card),
              )
            : null;

        if (isCompact) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              Row(
                children: [
                  if (bulkButton != null) ...[
                    Expanded(child: bulkButton),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: filterButton),
                  const SizedBox(width: 8),
                  Expanded(child: addButton),
                ],
              ),
              if (canManageLeadMetadata || exportButton != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (addSourceButton != null)
                      Expanded(child: addSourceButton),
                    if (manageStatusButton != null) ...[
                      if (addSourceButton != null) const SizedBox(width: 8),
                      Expanded(child: manageStatusButton),
                    ],
                    if (exportButton != null) ...[
                      if (addSourceButton != null || manageStatusButton != null)
                        const SizedBox(width: 8),
                      Expanded(child: exportButton),
                    ],
                  ],
                ),
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
                    child: Row(
                      children: [
                        if (bulkButton != null) ...[
                          Expanded(child: bulkButton),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: filterButton),
                        const SizedBox(width: 8),
                        Expanded(child: addButton),
                      ],
                    ),
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
                      child: Row(
                        children: [
                          if (addSourceButton != null)
                            Expanded(child: addSourceButton),
                          if (manageStatusButton != null) ...[
                            if (addSourceButton != null)
                              const SizedBox(width: 8),
                            Expanded(child: manageStatusButton),
                          ],
                          if (exportButton != null) ...[
                            if (addSourceButton != null ||
                                manageStatusButton != null)
                              const SizedBox(width: 8),
                            Expanded(child: exportButton),
                          ],
                        ],
                      ),
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

  ButtonStyle _actionButtonStyle({required Color backgroundColor}) {
    return OutlinedButton.styleFrom(
      fixedSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildLeadsSection(List<_LeadModel> leads) {
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
          _buildListHeader(),
          const SizedBox(height: 8),
          if (_isLoading)
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
                    onPressed: _loadEoiLeads,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (leads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'No EOI leads found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...leads.map(
              (lead) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DataCard(
                  name: lead.name,
                  leadId: lead.project.isEmpty ? '' : lead.project,
                  status: lead.status,
                  priority: lead.priority,
                  priorityColor: lead.priorityColor,
                  nextFollowUpDate: lead.nextFollowUpDate,
                  leftMetaLabel: 'Callback Time',
                  rightMetaLabel: 'Next Follow-up',
                  budget: lead.budget,
                  phone: lead.phone,
                  profileImageUrl: lead.profileImageUrl,
                  assigneeName: lead.assignee.name,
                  assigneeImageUrl: lead.assignee.imageUrl,
                  onTap: () => _viewLeadDetail(lead.id),
                  actions: [
                    DataCardAction(
                      icon: Icons.visibility_outlined,
                      color: AppColors.primary,
                      onTap: () => _viewLeadDetail(lead.id),
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
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    final label = _isMyTab ? 'my EOI leads' : 'team EOI leads';
    final visibleCount = _visibleLeads.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            '$visibleCount shown',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$_totalItems total $label',
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
                itemLabel: 'eoi leads',
                onPageChanged: _isLoading ? (_) {} : _changePage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final id = _readString(
      user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid'],
    );
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final fullName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();
    final displayName = fullName.isNotEmpty
        ? fullName
        : _readString(user['name'] ?? user['full_name'] ?? user['email']);

    return _AssigneeOption(
      id: id,
      name: displayName.isEmpty ? 'User $id' : displayName,
    );
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _sheetFieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
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
    required this.source,
    required this.project,
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
  final String source;
  final String project;
  final String locationPreference;
  final String notes;
  final Map<String, dynamic> rawData;

  factory _LeadModel.fromApi(Map<String, dynamic> json) {
    final firstName = _readString(json['first_name'] ?? json['firstName']);
    final lastName = _readString(json['last_name'] ?? json['lastName']);
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

    final assigned = json['assigned_to'] ?? json['assignee'];
    final assigneeName = assigned is Map<String, dynamic>
        ? _readString(
            assigned['name'] ??
                assigned['full_name'] ??
                assigned['fullName'] ??
                assigned['first_name'],
            fallback: 'Unassigned',
          )
        : _readString(
            json['assigned_name'] ??
                json['assignedName'] ??
                json['assignee_name'] ??
                json['assigneeName'],
            fallback: 'Unassigned',
          );
    final assigneeImage = assigned is Map<String, dynamic>
        ? _readString(
            assigned['image'] ??
                assigned['avatar'] ??
                assigned['profile_image'] ??
                assigned['image_url'],
          )
        : '';

    return _LeadModel(
      id: _readString(
        json['id'] ?? json['lead_id'] ?? json['leadId'],
        fallback: 'N/A',
      ),
      name: resolvedName.isNotEmpty
          ? resolvedName
          : (fullName.isNotEmpty ? fullName : 'Unknown Lead'),
      status: _readString(
        json['status'] ?? json['stage'] ?? json['current_status'],
        fallback: 'EOI',
      ),
      priority: _readDateTime(
        json['callback_time'] ?? json['callbackTime'],
      ),
      priorityColor: const Color(0xFF1E88E5),
      nextFollowUpDate: _readDateTime(
        json['next_followup_time'] ??
            json['next_follow_up_time'] ??
            json['next_follow_up_date'] ??
            json['nextFollowUpDate'] ??
            json['follow_up_date'],
      ),
      budget: _readBudget(
        json['budget'] ?? json['budget_value'] ?? json['budget_range'],
      ),
      phone: _readString(
        json['phone_number'] ?? json['phone'] ?? json['mobile'],
        fallback: 'N/A',
      ),
      profileImageUrl: _readString(
        json['profile_image'] ??
            json['profileImage'] ??
            json['avatar'] ??
            json['image_url'],
      ),
      assignee: _PersonModel(name: assigneeName, imageUrl: assigneeImage),
      source: _readString(json['source']),
      project: _readString(
        json['project_name'] ??
            json['project'] ??
            json['project_title'] ??
            json['property_name'],
      ),
      locationPreference: _readString(
        json['location_preference'] ?? json['locationPreference'],
      ),
      notes: _readString(json['notes']),
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
    return _LeadSourceOption(
      id: _LeadModel._readString(
        json['id'] ?? json['source_id'] ?? json['sourceId'],
      ),
      name: _LeadModel._readString(
        json['name'] ?? json['label'] ?? json['source_name'],
      ),
      isActive: json['is_active'] == true ||
          json['isActive'] == true ||
          json['status'] == true ||
          json['status']?.toString().toLowerCase() == 'active',
    );
  }
}

class _PipelineStatusOption {
  const _PipelineStatusOption({
    required this.id,
    required this.label,
    required this.color,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String color;
  final bool isActive;
  final int sortOrder;

  factory _PipelineStatusOption.fromApi(Map<String, dynamic> json) {
    return _PipelineStatusOption(
      id: _LeadModel._readString(
        json['id'] ?? json['status_id'] ?? json['statusId'],
      ),
      label: _LeadModel._readString(
        json['label'] ?? json['name'] ?? json['status_label'],
      ),
      color: _LeadModel._readString(json['color'], fallback: '#3B82F6'),
      isActive: json['is_active'] == true ||
          json['isActive'] == true ||
          json['status'] == true ||
          json['status']?.toString().toLowerCase() == 'active',
      sortOrder: int.tryParse(
            (json['sort_order'] ?? json['sortOrder'] ?? 0).toString(),
          ) ??
          0,
    );
  }
}
