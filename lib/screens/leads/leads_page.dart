import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
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
  bool _isBulkOperating = false;
  bool _isSubmittingReassign = false;
  String? _lastBulkResultFilename;
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
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
    final launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
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
              'Leads export downloaded: ${outFile.path}',
            ),
          ),
        );
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

    final choice = await showDialog<_BulkLeadDialogChoice>(
      context: context,
      builder: (context) {
        final resultController = TextEditingController(
          text: _lastBulkResultFilename ?? '',
        );

        return AlertDialog(
          title: const Text('Bulk Lead Operations'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download the Excel template, fill lead details, then upload the completed file.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _BulkOperationTile(
                  icon: Icons.file_download_outlined,
                  title: 'Download template',
                  subtitle: 'Get the latest Excel format for lead import.',
                  onTap: () => Navigator.of(context).pop(
                    const _BulkLeadDialogChoice.template(),
                  ),
                ),
                const SizedBox(height: 10),
                _BulkOperationTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Upload leads file',
                  subtitle: 'Import filled Excel rows into leads.',
                  onTap: () => Navigator.of(context).pop(
                    const _BulkLeadDialogChoice.upload(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resultController,
                  decoration: const InputDecoration(
                    labelText: 'Result filename',
                    hintText: 'Example: bulk-result-123.xlsx',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final filename = resultController.text.trim();
                      if (filename.isEmpty) {
                        return;
                      }
                      Navigator.of(context).pop(
                        _BulkLeadDialogChoice.result(filename),
                      );
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Download result file'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice.action) {
      case _BulkLeadDialogAction.template:
        await _downloadLeadBulkTemplate();
        break;
      case _BulkLeadDialogAction.upload:
        await _pickAndUploadLeadBulkFile();
        break;
      case _BulkLeadDialogAction.result:
        await _downloadLeadBulkResult(choice.filename ?? '');
        break;
    }
  }

  Future<void> _downloadLeadBulkTemplate() async {
    setState(() {
      _isBulkOperating = true;
    });
    try {
      final exported = await _authProvider.downloadLeadBulkTemplate(
        token: _authProvider.currentAuthToken,
      );
      final fileName = exported.fileName.trim().isEmpty
          ? 'lead_bulk_template.xlsx'
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Template generated ($fileName), but direct file save is not supported on Web in this build.',
        );
        return;
      }
      final file = await ExportFileHelper.saveToDownloadNextone(
        fileName: fileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;
      _showSnackBar('Lead template downloaded: ${file.path}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBulkOperating = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadLeadBulkFile() async {
    if (kIsWeb) {
      _showSnackBar('Bulk upload is not supported on Web in this build.');
      return;
    }

    final hasPermission = await _requestFilePickerPermission();
    if (!hasPermission || !mounted) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['xlsx', 'xls', 'csv'],
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final filePath = picked.files.single.path;
    if (filePath == null || filePath.trim().isEmpty) {
      _showSnackBar('Could not read the selected file path.');
      return;
    }

    setState(() {
      _isBulkOperating = true;
    });
    try {
      final response = await _authProvider.uploadLeadBulkFile(
        filePath: filePath,
        token: _authProvider.currentAuthToken,
      );
      final resultFilename = _readBulkResultFilename(response);
      if (resultFilename != null && resultFilename.trim().isNotEmpty) {
        _lastBulkResultFilename = resultFilename.trim();
      }
      if (!mounted) return;
      await _loadLeads();
      if (!mounted) return;
      final message =
          _readBulkMessage(response) ?? 'Leads uploaded successfully.';
      _showSnackBar(
        _lastBulkResultFilename == null
            ? message
            : '$message Result file: $_lastBulkResultFilename',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBulkOperating = false;
        });
      }
    }
  }

  Future<bool> _requestFilePickerPermission() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Allow file selection?'),
          content: const Text(
            'NextOne needs to open your device file picker so you can select an Excel or CSV file for bulk lead upload.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    if (allowed != true && mounted) {
      _showSnackBar('File selection cancelled.');
    }
    return allowed == true;
  }

  Future<void> _downloadLeadBulkResult(String filename) async {
    final normalizedFilename = filename.trim();
    if (normalizedFilename.isEmpty) {
      _showSnackBar('Enter a result filename first.');
      return;
    }

    setState(() {
      _isBulkOperating = true;
    });
    try {
      final exported = await _authProvider.downloadLeadBulkResult(
        filename: normalizedFilename,
        token: _authProvider.currentAuthToken,
      );
      final fileName = exported.fileName.trim().isEmpty
          ? normalizedFilename
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Result generated ($fileName), but direct file save is not supported on Web in this build.',
        );
        return;
      }
      final file = await ExportFileHelper.saveToDownloadNextone(
        fileName: fileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;
      _lastBulkResultFilename = normalizedFilename;
      _showSnackBar('Lead upload result downloaded: ${file.path}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBulkOperating = false;
        });
      }
    }
  }

  String? _readBulkMessage(Map<String, dynamic> response) {
    final value = response['message'] ?? response['detail'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String? _readBulkResultFilename(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in const <String>[
      'filename',
      'file_name',
      'fileName',
      'result_filename',
      'resultFilename',
      'result_file',
      'resultFile',
      'report_filename',
      'reportFilename',
      'output_file',
      'outputFile',
    ]) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final data = source['data'];
    if (data is Map<String, dynamic>) {
      return _readBulkResultFilename(data);
    }
    return null;
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

        final exportButton = _canExportData
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportLeads,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_isExporting ? 'Exporting...' : 'Export'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

        final bulkButton = _canUseBulkLeadTools
            ? OutlinedButton.icon(
                onPressed:
                    (_isBulkOperating || _isExporting) ? null : _openLeadBulkDialog,
                icon: _isBulkOperating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(_isBulkOperating ? 'Working...' : 'Bulk'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : null;

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
                        onPressed: () {},
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
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
                        onPressed: () {},
                        icon: const Icon(Icons.flag_outlined, size: 16),
                        label: const Text('Update Status'),
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
                      onPressed: () {},
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                      label: const Text('Assign'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Update Status'),
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
            ...leads.map(
              (lead) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DataCard(
                  name: lead.name,
                  leadId: '',
                  status: lead.status,
                  priority: lead.priority,
                  priorityColor: lead.priorityColor,
                  nextFollowUpDate: lead.nextFollowUpDate,
                  budget: lead.budget,
                  phone: lead.phone,
                  profileImageUrl: lead.profileImageUrl,
                  assigneeName: lead.assignee.name,
                  assigneeImageUrl: lead.assignee.imageUrl,
                  onTap: () => _viewLeadDetail(lead.id),
                  actions: [
                    DataCardAction(
                      icon: Icons.call_outlined,
                      onTap: () => _callLead(lead.phone),
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
              ),
            ),
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
}

enum _BulkLeadDialogAction { template, upload, result }

class _BulkLeadDialogChoice {
  const _BulkLeadDialogChoice.template()
      : action = _BulkLeadDialogAction.template,
        filename = null;

  const _BulkLeadDialogChoice.upload()
      : action = _BulkLeadDialogAction.upload,
        filename = null;

  const _BulkLeadDialogChoice.result(this.filename)
      : action = _BulkLeadDialogAction.result;

  final _BulkLeadDialogAction action;
  final String? filename;
}

class _BulkOperationTile extends StatelessWidget {
  const _BulkOperationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
    final priorityRaw = _readString(
      json['priority'] ?? json['temperature'],
      fallback: 'Warm',
    );
    final nextFollowUpDate = _readDate(
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

    final priorityLabel = _readPriorityLabel(priorityRaw);
    return _LeadModel(
      id: id,
      name: resolvedName.isNotEmpty
          ? resolvedName
          : (fullName.isNotEmpty ? fullName : 'Unknown Lead'),
      status: status,
      priority: priorityLabel,
      priorityColor: _priorityColor(priorityLabel),
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

  static String _readDate(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return 'N/A';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  static String _readBudget(dynamic value) {
    if (value is num) {
      return 'INR ${value.toString()}';
    }
    final asString = _readString(value);
    return asString.isEmpty ? 'N/A' : asString;
  }

  static String _readPriorityLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'high' || normalized == 'hot') {
      return 'Hot';
    }
    if (normalized == 'low' || normalized == 'cold') {
      return 'Cold';
    }
    return 'Warm';
  }

  static Color _priorityColor(String label) {
    switch (label.toLowerCase()) {
      case 'hot':
        return const Color(0xFFE53935);
      case 'cold':
        return const Color(0xFF1E88E5);
      default:
        return const Color(0xFFFB8C00);
    }
  }
}

class _PersonModel {
  const _PersonModel({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;
}
