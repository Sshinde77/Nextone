import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/closures/closure_detail_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/closure_data_card.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';

class _SelectionOption {
  const _SelectionOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _ClosureDocumentDraft {
  const _ClosureDocumentDraft({
    required this.documentType,
    required this.documentTypeLabel,
    required this.name,
    required this.url,
    this.localPath,
    this.fileBytes,
    this.sourceFileName,
  });

  final String documentType;
  final String documentTypeLabel;
  final String name;
  final String url;
  final String? localPath;
  final List<int>? fileBytes;
  final String? sourceFileName;

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'url': url,
        'document_type': documentType,
        'name': name,
      };
}

class ClosuresPage extends StatefulWidget {
  const ClosuresPage({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<ClosuresPage> createState() => _ClosuresPageState();
}

class _ClosuresPageState extends State<ClosuresPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  String _currentRole = '';
  String _statusFilter = 'all';
  bool _isExporting = false;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _perPage = 10;
  static const List<String> _paymentPlans = <String>[
    'Construction Linked Plan',
    'Down Payment Plan',
    'Time Linked Plan',
    'Flexi Pay Plan',
    'Subvention Scheme',
    'Custom',
  ];
  static const List<MapEntry<String, String>> _documentTypeOptions =
      <MapEntry<String, String>>[
    MapEntry<String, String>('cost_sheet', 'Cost Sheet'),
    MapEntry<String, String>('payment_proof', 'Payment Proof'),
    MapEntry<String, String>('booking_form', 'Booking Form'),
  ];

  String _normalizePaymentPlan(String value) {
    switch (value.trim()) {
      case 'Flexi Payment Plan':
        return 'Flexi Pay Plan';
      case 'Subvention Plan':
        return 'Subvention Scheme';
      default:
        return value.trim();
    }
  }

  String _documentTypeLabel(String value) {
    for (final option in _documentTypeOptions) {
      if (option.key == value.trim()) {
        return option.value;
      }
    }
    return value.trim();
  }

  String _documentTypeValue(String labelOrValue) {
    final normalized = labelOrValue.trim().toLowerCase();
    for (final option in _documentTypeOptions) {
      if (option.key == normalized ||
          option.value.toLowerCase() == normalized) {
        return option.key;
      }
    }
    return normalized.replaceAll(' ', '_');
  }

  List<_ClosureDocumentDraft> _readClosureDocuments(Map<String, dynamic> item) {
    final raw = item['documents'];
    final documents = <_ClosureDocumentDraft>[];

    void addDraft(Map<String, dynamic> source) {
      final documentType = _documentTypeValue(
        _readString(
          source['document_type'] ?? source['documentType'],
          fallback: '',
        ),
      );
      final name = _readString(
        source['name'] ?? source['document_name'] ?? source['documentName'],
        fallback: '',
      );
      final url = _readString(
        source['url'] ?? source['file_path'] ?? source['filePath'],
        fallback: '',
      );
      if (documentType.isEmpty || name.isEmpty || url.isEmpty) {
        return;
      }
      documents.add(
        _ClosureDocumentDraft(
          documentType: documentType,
          documentTypeLabel: _documentTypeLabel(documentType),
          name: name,
          url: url,
        ),
      );
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          addDraft(item);
        } else if (item is Map) {
          addDraft(Map<String, dynamic>.from(item));
        }
      }
    }

    return documents;
  }

  List<Map<String, dynamic>> _buildClosureDocumentPayloads(
    List<_ClosureDocumentDraft> documents,
  ) {
    return documents.map((document) => document.toPayload()).where((document) {
      final url = _readString(document['url'], fallback: '').trim();
      final documentType =
          _readString(document['document_type'], fallback: '').trim();
      final name = _readString(document['name'], fallback: '').trim();
      return url.isNotEmpty && documentType.isNotEmpty && name.isNotEmpty;
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadClosures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canExportData => RoleAccess.canExportModule('closures');
  bool get _showExportButton =>
      _canExportData && RoleAccess.isAdminOrSuperAdmin(_currentRole);

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Keep export action hidden if role lookup fails.
    }
  }

  Future<void> _loadClosures({int? page}) async {
    final nextPage = page ?? _currentPage;
    final apiStatus =
        _statusFilter == 'all' ? null : _statusFilter.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _authProvider.closures(
        token: _authProvider.currentAuthToken,
        status: apiStatus,
        page: nextPage,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _currentPage = result.currentPage;
        _totalPages = result.totalPages;
        _totalItems = result.totalItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppErrorHandler.friendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items.where(_matchesSearch).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          CrmAppBar(title: 'Closures', showBackButton: widget.showBackButton),
      body: RefreshIndicator(
        onRefresh: () => _loadClosures(page: _currentPage),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildKpiRow(visibleItems),
            const SizedBox(height: 10),
            _buildSearchAndFilter(),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (visibleItems.isEmpty)
              _buildEmpty()
            else ...[
              ...visibleItems.map(_buildCard),
              const SizedBox(height: 12),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final exportButton = _showExportButton
            ? OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportClosures,
                icon: _isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(_isExporting ? 'Exporting...' : 'Export'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            : null;
        final bookLeadButton = FilledButton.icon(
          onPressed: _openCreateClosureDialog,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Book Lead'),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking records when leads are converted',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (exportButton != null) ...[
                    Expanded(child: exportButton),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: bookLeadButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            const Expanded(
              child: Text(
                'Booking records when leads are converted',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (exportButton != null) exportButton,
                bookLeadButton,
              ],
            ),
          ],
        );
      },
    );
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

            Widget dateField({
              required String label,
              required String value,
              required String placeholder,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(value.isEmpty ? placeholder : value),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Export Closures'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dateField(
                    label: 'Start date',
                    value: formatDate(fromDate),
                    placeholder: 'Select start date',
                    onTap: pickFromDate,
                  ),
                  const SizedBox(height: 12),
                  dateField(
                    label: 'End date',
                    value: formatDate(toDate),
                    placeholder: 'Select end date',
                    onTap: pickToDate,
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

  String _formatDateForApi(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _exportClosures() async {
    if (!_canExportData) {
      _showSnackBar('You do not have permission to export closures.');
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
      final exported = await _authProvider.exportClosures(
        from: from,
        to: to,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final safeFileName = exported.fileName.trim().isEmpty
          ? 'closures_${from}_to_$to.xlsx'
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
      _showSnackBar(
        'Closures export downloaded and saved to: ${outFile.path}',
      );
    } catch (error) {
      if (!mounted) return;
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

  Future<void> _openCreateClosureDialog() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'closures',
      action: 'create',
      moduleLabel: 'closures',
    );
    if (!allowed) return;

    final leadResult = await _authProvider.leads(
      token: _authProvider.currentAuthToken,
      perPage: 100,
    );
    final projectResult = await _authProvider.projects(
      token: _authProvider.currentAuthToken,
      perPage: 100,
    );
    final users = await _authProvider.assignmentUsers(
      token: _authProvider.currentAuthToken,
    );

    if (!mounted) return;
    final leads = leadResult.items;
    final projects = projectResult.items;
    if (leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No leads available for closure booking.')),
      );
      return;
    }

    String step = 'booking';
    bool isSubmitting = false;

    String? selectedLeadId;
    String? selectedProjectId;
    DateTime bookingDate = DateTime.now();

    final unitNumberController = TextEditingController();
    final towerController = TextEditingController();
    final floorController = TextEditingController();
    final unitTypeController = TextEditingController();
    final carpetAreaController = TextEditingController();
    final superAreaController = TextEditingController();
    final agreedPriceController = TextEditingController();
    final bookingAmountController = TextEditingController();
    final paymentPlanController = TextEditingController();
    String? selectedPaymentPlan;
    String? selectedDocumentType;
    final documentNameController = TextEditingController();
    List<_ClosureDocumentDraft> documents = <_ClosureDocumentDraft>[];
    bool loanRequired = false;
    final loanBankController = TextEditingController();
    final commissionPercentController = TextEditingController();
    commissionPercentController.text = '2';
    bool commissionPaid = false;
    List<String> selectedManagerIds = <String>[];
    final managerOptions = users
        .map(_teamTreeSelectionOption)
        .whereType<_SelectionOption>()
        .toList(growable: false);
    final notesController = TextEditingController();

    String? resolveLeadLinkedProjectId(String? leadId) {
      final normalizedLeadId = (leadId ?? '').trim();
      if (normalizedLeadId.isEmpty) {
        return null;
      }

      Map<String, dynamic>? selectedLead;
      for (final lead in leads) {
        final currentLeadId = _readString(
          lead['id'] ?? lead['lead_id'] ?? lead['leadId'],
          fallback: '',
        );
        if (currentLeadId == normalizedLeadId) {
          selectedLead = lead;
          break;
        }
      }

      if (selectedLead == null) {
        return null;
      }

      final nestedProject = selectedLead['project'] is Map<String, dynamic>
          ? selectedLead['project'] as Map<String, dynamic>
          : null;

      final projectName = _readString(
        selectedLead['project_name'] ??
            selectedLead['projectName'] ??
            nestedProject?['name'] ??
            selectedLead['project_name_text'],
        fallback: '',
      );
      if (projectName.isNotEmpty) {
        final normalizedProjectName = projectName.trim().toLowerCase();
        for (final project in projects) {
          final currentProjectName =
              _readString(project['name'], fallback: '').trim().toLowerCase();
          if (currentProjectName == normalizedProjectName) {
            final matchedProjectId = _readString(project['id'], fallback: '');
            if (matchedProjectId.isNotEmpty) {
              return matchedProjectId;
            }
          }
        }
      }

      final directProjectId = _readString(
        selectedLead['project_id'] ??
            selectedLead['projectId'] ??
            nestedProject?['id'] ??
            nestedProject?['project_id'] ??
            nestedProject?['projectId'],
        fallback: '',
      );
      if (directProjectId.isNotEmpty &&
          projects.any(
            (project) =>
                _readString(project['id'], fallback: '') == directProjectId,
          )) {
        return directProjectId;
      }

      return null;
    }

    String? resolveLeadSiteVisitId(String? leadId) {
      final normalizedLeadId = (leadId ?? '').trim();
      if (normalizedLeadId.isEmpty) {
        return null;
      }

      Map<String, dynamic>? selectedLead;
      for (final lead in leads) {
        final currentLeadId = _readString(
          lead['id'] ?? lead['lead_id'] ?? lead['leadId'],
          fallback: '',
        );
        if (currentLeadId == normalizedLeadId) {
          selectedLead = lead;
          break;
        }
      }

      if (selectedLead == null) {
        return null;
      }

      final nestedSiteVisit = selectedLead['site_visit'] is Map<String, dynamic>
          ? selectedLead['site_visit'] as Map<String, dynamic>
          : selectedLead['siteVisit'] is Map<String, dynamic>
              ? selectedLead['siteVisit'] as Map<String, dynamic>
              : null;

      final siteVisitId = _readString(
        selectedLead['site_visit_id'] ??
            selectedLead['siteVisitId'] ??
            selectedLead['latest_site_visit_id'] ??
            selectedLead['latestSiteVisitId'] ??
            nestedSiteVisit?['id'] ??
            nestedSiteVisit?['site_visit_id'] ??
            nestedSiteVisit?['siteVisitId'],
        fallback: '',
      );
      return siteVisitId.isEmpty ? null : siteVisitId;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> addDocument() async {
              final documentType =
                  _documentTypeValue(selectedDocumentType ?? '');
              final documentName = documentNameController.text.trim();
              if (documentType.isEmpty || documentName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Select document type and enter document name.'),
                  ),
                );
                return;
              }

              final picked = await FilePicker.platform.pickFiles(
                withData: kIsWeb,
              );
              if (picked == null || picked.files.isEmpty) return;

              final file = picked.files.first;
              final safeFileName = file.name.trim();
              if (safeFileName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected file is not valid.')),
                );
                return;
              }

              setLocalState(() {
                documents = <_ClosureDocumentDraft>[
                  ...documents,
                  _ClosureDocumentDraft(
                    documentType: documentType,
                    documentTypeLabel: _documentTypeLabel(documentType),
                    name: documentName,
                    url: '/uploads/closures/documents/$safeFileName',
                    localPath: kIsWeb ? null : file.path,
                    fileBytes: file.bytes,
                    sourceFileName: safeFileName,
                  ),
                ];
                selectedDocumentType = null;
                documentNameController.clear();
              });
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: bookingDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) return;
              setLocalState(() => bookingDate = picked);
            }

            Future<void> submit() async {
              final documentPayloads = _buildClosureDocumentPayloads(documents);
              if (selectedDocumentType != null ||
                  documentNameController.text.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upload the document before submitting.'),
                  ),
                );
                return;
              }
              if ((selectedLeadId ?? '').isEmpty ||
                  (selectedProjectId ?? '').isEmpty ||
                  unitNumberController.text.trim().isEmpty ||
                  floorController.text.trim().isEmpty ||
                  unitTypeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all required fields.')),
                );
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.createClosure(
                  leadId: selectedLeadId!,
                  projectId: selectedProjectId!,
                  siteVisitId: resolveLeadSiteVisitId(selectedLeadId),
                  bookingDate: _toYmd(bookingDate),
                  unitNumber: unitNumberController.text.trim(),
                  towerBlock: towerController.text.trim(),
                  floorNumber: int.tryParse(floorController.text.trim()) ?? 0,
                  unitType: unitTypeController.text.trim(),
                  carpetAreaSqft:
                      double.tryParse(carpetAreaController.text.trim()) ?? 0,
                  superAreaSqft:
                      double.tryParse(superAreaController.text.trim()) ?? 0,
                  agreedPrice:
                      double.tryParse(agreedPriceController.text.trim()) ?? 0,
                  bookingAmount:
                      double.tryParse(bookingAmountController.text.trim()) ?? 0,
                  paymentPlan:
                      (selectedPaymentPlan ?? paymentPlanController.text)
                          .trim(),
                  loanRequired: loanRequired,
                  loanBank: loanBankController.text.trim(),
                  commissionPercent: double.tryParse(
                          commissionPercentController.text.trim()) ??
                      0,
                  commissionPaid: commissionPaid,
                  closedByManagerIds: selectedManagerIds,
                  closureNotes: notesController.text.trim(),
                  documents: documentPayloads,
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() => isSubmitting = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 560 ? 12 : 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Builder(
                builder: (dialogContext) {
                  final screenWidth = MediaQuery.of(dialogContext).size.width;
                  final compactDialog = screenWidth < 720;
                  final narrowDialog = screenWidth < 560;
                  return SizedBox(
                    width: narrowDialog ? screenWidth - 24 : 650,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(narrowDialog ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Create Closure - Book Lead',
                                  style: TextStyle(
                                      fontSize: narrowDialog
                                          ? 16
                                          : (compactDialog ? 20 : 26),
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: narrowDialog ? 32 : 40,
                                  minHeight: narrowDialog ? 32 : 40,
                                ),
                                icon: Icon(Icons.close,
                                    size: narrowDialog ? 20 : 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _stepTabs(
                            step,
                            (v) => setLocalState(() => step = v),
                            compact: compactDialog,
                            narrow: narrowDialog,
                          ),
                          const SizedBox(height: 14),
                          if (step == 'booking') ...[
                            _dropdownField(
                              label: 'Lead *',
                              value: selectedLeadId,
                              hint: 'Select lead to book...',
                              items: const <DropdownMenuItem<String>>[],
                              searchable: true,
                              searchableItems: leads
                                  .map(
                                    (e) => SearchableDropdownItem<String>(
                                      value: _readString(e['id'], fallback: ''),
                                      label: _readString(e['name'],
                                          fallback: 'Lead'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setLocalState(() {
                                  selectedLeadId = v;
                                  final linkedProjectId =
                                      resolveLeadLinkedProjectId(v);
                                  selectedProjectId =
                                      (linkedProjectId != null &&
                                              linkedProjectId.isNotEmpty)
                                          ? linkedProjectId
                                          : null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            _dropdownField(
                              label: 'Project *',
                              value: selectedProjectId,
                              hint: 'Select project...',
                              items: const <DropdownMenuItem<String>>[],
                              searchable: true,
                              searchableItems: projects
                                  .map(
                                    (e) => SearchableDropdownItem<String>(
                                      value: _readString(e['id'], fallback: ''),
                                      label: _readString(e['name'],
                                          fallback: 'Project'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setLocalState(() => selectedProjectId = v),
                            ),
                            const SizedBox(height: 10),
                            _dateField('Booking Date *', bookingDate, pickDate),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                    child: _textField(
                                        'Unit Number *', unitNumberController)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _textField(
                                        'Tower / Block', towerController)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Floor *',
                                    floorController,
                                    keyboardType: TextInputType.number,
                                    hintText: 'Floor',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _textField(
                                    'Unit Type *',
                                    unitTypeController,
                                    hintText: 'Unit Type',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _textField(
                                    'Carpet Area (sqft)',
                                    carpetAreaController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: 'Carpet',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _textField(
                              'Super Area (sqft)',
                              superAreaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 10),
                            _textField('Closure Notes', notesController,
                                maxLines: 3),
                          ] else if (step == 'financials') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Agreed Price (Rs) *',
                                    agreedPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '9500000',
                                    prefixText: 'Rs ',
                                    onChanged: (_) => setLocalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _textField(
                                    'Booking Amount (Rs)',
                                    bookingAmountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '500000',
                                    prefixText: 'Rs ',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _dropdownField(
                              label: 'Payment Plan',
                              value: selectedPaymentPlan,
                              hint: 'Select payment plan...',
                              items: _paymentPlans
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setLocalState(() {
                                  selectedPaymentPlan = v;
                                  paymentPlanController.text = v ?? '';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: loanRequired,
                              onChanged: (v) => setLocalState(
                                  () => loanRequired = v ?? false),
                              title: const Text(
                                'Home loan required',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _textField('Loan Bank', loanBankController),
                          ] else if (step == 'commission') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Commission % (auto-calcs amount)',
                                    commissionPercentController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '2',
                                    prefixText: '% ',
                                    onChanged: (_) => setLocalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _readOnlyField(
                                    'Commission Amount (Rs)',
                                    _rupee(
                                      (double.tryParse(agreedPriceController
                                                  .text
                                                  .trim()) ??
                                              0) *
                                          (double.tryParse(
                                                commissionPercentController.text
                                                    .trim(),
                                              ) ??
                                              0) /
                                          100,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _selectionField(
                              label: 'Reporting Manager',
                              hint: 'Select one or more managers...',
                              value: _formatSelectionSummary(
                                managerOptions,
                                selectedManagerIds,
                              ),
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      final selected =
                                          await _openMultiSelectSheet(
                                        title: 'Reporting Manager',
                                        options: managerOptions,
                                        initialSelectedIds: selectedManagerIds,
                                      );
                                      if (selected == null) return;
                                      setLocalState(
                                        () => selectedManagerIds = selected,
                                      );
                                    },
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: commissionPaid,
                              onChanged: (v) => setLocalState(
                                  () => commissionPaid = v ?? false),
                              title: const Text(
                                'Commission already paid',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ] else ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stackFields = constraints.maxWidth < 520;
                                final documentTypeField = _dropdownField(
                                  label: 'Document Type',
                                  value: selectedDocumentType,
                                  hint: 'Select document type...',
                                  items: _documentTypeOptions
                                      .map(
                                        (option) => DropdownMenuItem<String>(
                                          value: option.value,
                                          child: Text(
                                            option.value,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: narrowDialog ? 13 : 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setLocalState(
                                    () => selectedDocumentType = value,
                                  ),
                                );
                                final documentNameField = _textField(
                                  'Document Name',
                                  documentNameController,
                                  hintText: 'Cost Sheet - Tower B',
                                );
                                if (stackFields) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      documentTypeField,
                                      const SizedBox(height: 10),
                                      documentNameField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: documentTypeField),
                                    const SizedBox(width: 10),
                                    Expanded(child: documentNameField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: isSubmitting ? null : addDocument,
                                icon: Icon(
                                  Icons.upload_file_outlined,
                                  size: narrowDialog ? 16 : 18,
                                ),
                                label: Text(
                                  'Upload Document',
                                  style: TextStyle(
                                      fontSize: narrowDialog ? 13 : 15),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (documents.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: narrowDialog ? 20 : 28,
                                ),
                                child: Center(
                                  child: Text(
                                    'No documents yet',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: narrowDialog ? 13 : 15,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: List<Widget>.generate(
                                    documents.length, (index) {
                                  final document = documents[index];
                                  return Container(
                                    margin: EdgeInsets.only(
                                      bottom: index == documents.length - 1
                                          ? 0
                                          : 10,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                document.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize:
                                                      narrowDialog ? 13 : 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                document.documentTypeLabel,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize:
                                                      narrowDialog ? 12 : 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: isSubmitting
                                              ? null
                                              : () => setLocalState(
                                                    () => documents = documents
                                                        .where((item) =>
                                                            !identical(
                                                                item, document))
                                                        .toList(
                                                            growable: false),
                                                  ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: isSubmitting ? null : submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Book Lead',
                                          style: TextStyle(
                                            fontSize: narrowDialog ? 14 : 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    unitNumberController.dispose();
    towerController.dispose();
    floorController.dispose();
    unitTypeController.dispose();
    carpetAreaController.dispose();
    superAreaController.dispose();
    agreedPriceController.dispose();
    bookingAmountController.dispose();
    paymentPlanController.dispose();
    documentNameController.dispose();
    loanBankController.dispose();
    commissionPercentController.dispose();
    notesController.dispose();

    if (created == true && mounted) {
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Closure created successfully.')),
      );
    }
  }

  Widget _stepTabs(
    String step,
    ValueChanged<String> onChanged, {
    bool compact = false,
    bool narrow = false,
  }) {
    Widget tab(String value, String label) {
      final selected = value == step;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: narrow ? 6 : 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: narrow ? 11 : (compact ? 12 : 14),
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tab('booking', 'Booking Details'),
          const SizedBox(width: 4),
          tab('financials', 'Financials'),
          const SizedBox(width: 4),
          tab('commission', 'Commission'),
          const SizedBox(width: 4),
          tab('documents', 'Documents'),
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool searchable = false,
    List<SearchableDropdownItem<String>>? searchableItems,
  }) {
    if (searchable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          SearchableDropdownField<String>(
            key: ValueKey<String>('${label}_${value ?? ''}'),
            label: label,
            sheetTitle: label,
            showFieldLabel: false,
            value: (value ?? '').isEmpty ? null : value,
            hintText: hint,
            items: searchableItems ?? const <SearchableDropdownItem<String>>[],
            enabled:
                (searchableItems ?? const <SearchableDropdownItem<String>>[])
                    .isNotEmpty,
            onChanged: onChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (value ?? '').isEmpty ? null : value,
          decoration: _fieldDecoration(hint: hint),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _selectionField({
    required String label,
    required String hint,
    required String value,
    required VoidCallback? onTap,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(hint: hint),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value : hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<String>?> _openMultiSelectSheet({
    required String title,
    required List<_SelectionOption> options,
    required List<String> initialSelectedIds,
  }) async {
    final initial = List<String>.from(initialSelectedIds);
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final selectedIds = List<String>.from(initial);
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        options.isEmpty
                            ? 'No managers available.'
                            : 'Select one or more managers.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: options.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nothing available to select.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final option = options[index];
                                  final selected =
                                      selectedIds.contains(option.id);
                                  return CheckboxListTile(
                                    value: selected,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: AppColors.primary,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      option.label,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          if (!selectedIds
                                              .contains(option.id)) {
                                            selectedIds.add(option.id);
                                          }
                                        } else {
                                          selectedIds.remove(option.id);
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
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(sheetContext)
                                  .pop(List<String>.from(selectedIds)),
                              style: ElevatedButton.styleFrom(
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
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: _fieldDecoration(hint: ''),
            child: Text(_toYmd(date)),
          ),
        ),
      ],
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? prefixText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration:
              _fieldDecoration(hint: hintText ?? label, prefixText: prefixText),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InputDecorator(
          decoration:
              _fieldDecoration(hint: 'Auto-calculated', prefixText: 'Rs '),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint, String? prefixText}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefixText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildKpiRow(List<Map<String, dynamic>> items) {
    final totalClosures = items.length;
    final totalDealValue =
        items.fold<double>(0, (sum, e) => sum + _toDouble(e['agreed_price']));
    final commissionPaidValue = items.fold<double>(
      0,
      (sum, e) =>
          sum +
          (_readBool(e['commission_paid'])
              ? _toDouble(e['commission_amount'])
              : 0),
    );
    final commissionPendingValue = items.fold<double>(
      0,
      (sum, e) =>
          sum +
          (_readBool(e['commission_paid'])
              ? 0
              : _toDouble(e['commission_amount'])),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final spacing = isCompact ? 10.0 : 12.0;
        final cardWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _kpiTile(
              label: 'Total Closures',
              value: '$totalClosures',
              subtitle: '$totalClosures records',
              color: const Color(0xFF2F80ED),
              icon: Icons.verified_outlined,
              width: cardWidth,
            ),
            _kpiTile(
              label: 'Total Deal Value',
              value: _formatCurrency(totalDealValue),
              subtitle: _formatCompactCurrency(totalDealValue),
              color: const Color(0xFF1BA97F),
              icon: Icons.currency_rupee,
              width: cardWidth,
            ),
            _kpiTile(
              label: 'Commission Paid',
              value: commissionPaidValue <= 0
                  ? '—'
                  : _formatCurrency(commissionPaidValue),
              subtitle: commissionPaidValue <= 0
                  ? 'No paid commission'
                  : _formatCompactCurrency(commissionPaidValue),
              color: const Color(0xFF25B05B),
              icon: Icons.payments_outlined,
              width: cardWidth,
            ),
            _kpiTile(
              label: 'Comm. Pending',
              value: commissionPendingValue <= 0
                  ? '—'
                  : _formatCurrency(commissionPendingValue),
              subtitle: commissionPendingValue <= 0
                  ? 'No pending commission'
                  : _formatCompactCurrency(commissionPendingValue),
              color: const Color(0xFFC48A12),
              icon: Icons.access_time,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search lead, project, unit...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        final refreshButton = IconButton(
          onPressed: _refreshClosures,
          icon: const Icon(Icons.refresh),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildStatusDropdown()),
                  const SizedBox(width: 8),
                  refreshButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 8),
            SizedBox(width: 180, child: _buildStatusDropdown()),
            refreshButton,
          ],
        );
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All')),
        DropdownMenuItem(value: 'confirmed', child: Text('confirmed')),
        DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
        DropdownMenuItem(value: 'on_hold', child: Text('on_hold')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _statusFilter = value;
          _currentPage = 1;
        });
        _loadClosures(page: 1);
      },
    );
  }

  void _refreshClosures() {
    _loadClosures(page: _currentPage);
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = _readString(item['status'], fallback: 'pending');
    return ClosureDataCard(
      leadName: _readString(item['lead_name'], fallback: 'N/A'),
      leadPhone: _readString(item['lead_phone'], fallback: 'N/A'),
      projectName: _readString(item['project_name'], fallback: 'N/A'),
      projectCity: _readString(item['project_city'], fallback: 'N/A'),
      unitNumber: _readString(item['unit_number'], fallback: '-'),
      unitType: _readString(item['unit_type'], fallback: '-'),
      towerBlock: _readString(item['tower_block'], fallback: '-').toUpperCase(),
      floorNumber: item['floor_number']?.toString() ?? '-',
      bookingDate: _formatDate(_readString(item['booking_date'], fallback: '')),
      dealValueLabel: _rupee(_toDouble(item['agreed_price'])),
      commissionLabel: _rupee(_toDouble(item['commission_amount'])),
      commissionPaidLabel: item['commission_paid'] == true ? 'Yes' : 'No',
      closedByName: _readString(item['closed_by_name'], fallback: '-'),
      statusLabel: status,
      statusColor: _statusColor(status),
      onView: () => _openClosureDetail(item),
      onEdit: () => _openEditClosureDialog(item),
      onStatus: () => _openStatusUpdateDialog(item),
    );
  }

  Future<void> _openClosureDetail(Map<String, dynamic> item) async {
    final leadId = _readString(item['lead_id'], fallback: '');
    final closureId = _readString(item['id'], fallback: '');
    final lookupId = leadId.isNotEmpty ? leadId : closureId;
    if (lookupId.isEmpty) {
      _showInfo('Unable to open detail. Missing id.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClosureDetailPage(lookupId: lookupId),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditClosureDialog(Map<String, dynamic> item) async {
    final id = _readString(item['id'], fallback: '');
    if (id.isEmpty) return;
    final users = await _authProvider.assignmentUsers(
      token: _authProvider.currentAuthToken,
    );
    if (!mounted) return;

    String step = 'booking';
    bool isSubmitting = false;
    DateTime bookingDate =
        DateTime.tryParse(_readString(item['booking_date'], fallback: '')) ??
            DateTime.now();

    final unitNumberController = TextEditingController(
        text: _readString(item['unit_number'], fallback: ''));
    final towerController = TextEditingController(
        text: _readString(item['tower_block'], fallback: ''));
    final floorController = TextEditingController(
      text: item['floor_number']?.toString() ?? '',
    );
    final unitTypeController = TextEditingController(
        text: _readString(item['unit_type'], fallback: ''));
    final carpetAreaController = TextEditingController(
      text: _readString(item['carpet_area_sqft'], fallback: ''),
    );
    final superAreaController = TextEditingController(
      text: _readString(item['super_area_sqft'], fallback: ''),
    );
    final agreedPriceController = TextEditingController(
      text: _readString(item['agreed_price'], fallback: ''),
    );
    final bookingAmountController = TextEditingController(
      text: _readString(item['booking_amount'], fallback: ''),
    );
    String? selectedPaymentPlan =
        _normalizePaymentPlan(_readString(item['payment_plan'], fallback: ''));
    String? selectedDocumentType;
    final documentNameController = TextEditingController();
    List<_ClosureDocumentDraft> documents = _readClosureDocuments(item);
    bool loanRequired = item['loan_required'] == true;
    final loanBankController = TextEditingController(
        text: _readString(item['loan_bank'], fallback: ''));
    final commissionPercentController = TextEditingController(
      text: _readString(item['commission_percent'], fallback: '2'),
    );
    bool commissionPaid = item['commission_paid'] == true;
    DateTime? commissionPaidDate = DateTime.tryParse(
        _readString(item['commission_paid_date'], fallback: ''));
    List<String> selectedManagerIds =
        _extractStringList(item['closed_by_manager']);
    final managerOptions = users
        .map(_teamTreeSelectionOption)
        .whereType<_SelectionOption>()
        .toList(growable: false);
    final notesController = TextEditingController(
      text: _readString(item['closure_notes'], fallback: ''),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> addDocument() async {
              final documentType =
                  _documentTypeValue(selectedDocumentType ?? '');
              final documentName = documentNameController.text.trim();
              if (documentType.isEmpty || documentName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Select document type and enter document name.'),
                  ),
                );
                return;
              }

              final picked = await FilePicker.platform.pickFiles(
                withData: kIsWeb,
              );
              if (picked == null || picked.files.isEmpty) return;

              final file = picked.files.first;
              final safeFileName = file.name.trim();
              if (safeFileName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected file is not valid.')),
                );
                return;
              }

              setLocalState(() {
                documents = <_ClosureDocumentDraft>[
                  ...documents,
                  _ClosureDocumentDraft(
                    documentType: documentType,
                    documentTypeLabel: _documentTypeLabel(documentType),
                    name: documentName,
                    url: '/uploads/closures/documents/$safeFileName',
                    localPath: kIsWeb ? null : file.path,
                    fileBytes: file.bytes,
                    sourceFileName: safeFileName,
                  ),
                ];
                selectedDocumentType = null;
                documentNameController.clear();
              });
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: bookingDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) return;
              setLocalState(() => bookingDate = picked);
            }

            Future<void> submit() async {
              final documentPayloads = _buildClosureDocumentPayloads(documents);
              if (selectedDocumentType != null ||
                  documentNameController.text.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upload the document before submitting.'),
                  ),
                );
                return;
              }
              if (unitNumberController.text.trim().isEmpty ||
                  floorController.text.trim().isEmpty ||
                  unitTypeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all required fields.')),
                );
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.editClosure(
                  id: id,
                  bookingDate: _toYmd(bookingDate),
                  unitNumber: unitNumberController.text.trim(),
                  towerBlock: towerController.text.trim(),
                  floorNumber: int.tryParse(floorController.text.trim()) ?? 0,
                  unitType: unitTypeController.text.trim(),
                  carpetAreaSqft:
                      double.tryParse(carpetAreaController.text.trim()) ?? 0,
                  superAreaSqft:
                      double.tryParse(superAreaController.text.trim()) ?? 0,
                  agreedPrice:
                      double.tryParse(agreedPriceController.text.trim()) ?? 0,
                  bookingAmount:
                      double.tryParse(bookingAmountController.text.trim()) ?? 0,
                  paymentPlan: selectedPaymentPlan ?? '',
                  loanRequired: loanRequired,
                  loanBank: loanBankController.text.trim(),
                  commissionPercent: double.tryParse(
                          commissionPercentController.text.trim()) ??
                      0,
                  commissionPaid: commissionPaid,
                  commissionPaidDate:
                      commissionPaid && commissionPaidDate != null
                          ? _toYmd(commissionPaidDate!)
                          : null,
                  closedByManagerIds: selectedManagerIds,
                  closureNotes: notesController.text.trim(),
                  documents: documentPayloads,
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() => isSubmitting = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 560 ? 12 : 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Builder(
                builder: (dialogContext) {
                  final screenWidth = MediaQuery.of(dialogContext).size.width;
                  final compactDialog = screenWidth < 720;
                  final narrowDialog = screenWidth < 560;
                  return SizedBox(
                    width: narrowDialog ? screenWidth - 24 : 650,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(narrowDialog ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Edit Closure',
                                  style: TextStyle(
                                      fontSize: narrowDialog
                                          ? 16
                                          : (compactDialog ? 20 : 26),
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: narrowDialog ? 32 : 40,
                                  minHeight: narrowDialog ? 32 : 40,
                                ),
                                icon: Icon(Icons.close,
                                    size: narrowDialog ? 20 : 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _stepTabs(
                            step,
                            (v) => setLocalState(() => step = v),
                            compact: compactDialog,
                            narrow: narrowDialog,
                          ),
                          const SizedBox(height: 14),
                          if (step == 'booking') ...[
                            _dateField('Booking Date *', bookingDate, pickDate),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                    child: _textField(
                                        'Unit Number', unitNumberController)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _textField(
                                        'Tower / Block', towerController)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Floor',
                                    floorController,
                                    keyboardType: TextInputType.number,
                                    hintText: 'Floor',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _textField(
                                    'Unit Type',
                                    unitTypeController,
                                    hintText: 'Unit Type',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _textField(
                                    'Carpet Area (sqft)',
                                    carpetAreaController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: 'Carpet',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _textField(
                              'Super Area (sqft)',
                              superAreaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 10),
                            _textField('Closure Notes', notesController,
                                maxLines: 3),
                          ] else if (step == 'financials') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Agreed Price (Rs) *',
                                    agreedPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '9500000',
                                    prefixText: 'Rs ',
                                    onChanged: (_) => setLocalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _textField(
                                    'Booking Amount (Rs)',
                                    bookingAmountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '500000',
                                    prefixText: 'Rs ',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _dropdownField(
                              label: 'Payment Plan',
                              value: (selectedPaymentPlan ?? '').isEmpty
                                  ? null
                                  : selectedPaymentPlan,
                              hint: 'Select payment plan...',
                              items: _paymentPlans
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setLocalState(() => selectedPaymentPlan = v),
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: loanRequired,
                              onChanged: (v) => setLocalState(
                                  () => loanRequired = v ?? false),
                              title: const Text(
                                'Home loan required',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ] else if (step == 'commission') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    'Commission % (auto-calcs amount)',
                                    commissionPercentController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    hintText: '2',
                                    prefixText: '% ',
                                    onChanged: (_) => setLocalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _readOnlyField(
                                    'Commission Amount (Rs)',
                                    _rupee(
                                      (double.tryParse(agreedPriceController
                                                  .text
                                                  .trim()) ??
                                              0) *
                                          (double.tryParse(
                                                commissionPercentController.text
                                                    .trim(),
                                              ) ??
                                              0) /
                                          100,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _selectionField(
                              label: 'Reporting Manager',
                              hint: 'Select one or more managers...',
                              value: _formatSelectionSummary(
                                managerOptions,
                                selectedManagerIds,
                              ),
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      final selected =
                                          await _openMultiSelectSheet(
                                        title: 'Reporting Manager',
                                        options: managerOptions,
                                        initialSelectedIds: selectedManagerIds,
                                      );
                                      if (selected == null) return;
                                      setLocalState(
                                        () => selectedManagerIds = selected,
                                      );
                                    },
                            ),
                            const SizedBox(height: 10),
                            if (commissionPaid) ...[
                              _dateField(
                                'Commission Paid Date',
                                commissionPaidDate ?? DateTime.now(),
                                () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        commissionPaidDate ?? DateTime.now(),
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 3650)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 3650)),
                                  );
                                  if (picked == null) return;
                                  setLocalState(
                                      () => commissionPaidDate = picked);
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                            CheckboxListTile(
                              value: commissionPaid,
                              onChanged: (v) => setLocalState(() {
                                commissionPaid = v ?? false;
                                if (commissionPaid &&
                                    commissionPaidDate == null) {
                                  commissionPaidDate = DateTime.now();
                                }
                              }),
                              title: const Text(
                                'Commission already paid',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ] else ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stackFields = constraints.maxWidth < 520;
                                final documentTypeField = _dropdownField(
                                  label: 'Document Type',
                                  value: selectedDocumentType,
                                  hint: 'Select document type...',
                                  items: _documentTypeOptions
                                      .map(
                                        (option) => DropdownMenuItem<String>(
                                          value: option.value,
                                          child: Text(
                                            option.value,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: narrowDialog ? 13 : 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setLocalState(
                                    () => selectedDocumentType = value,
                                  ),
                                );
                                final documentNameField = _textField(
                                  'Document Name',
                                  documentNameController,
                                  hintText: 'Cost Sheet - Tower B',
                                );
                                if (stackFields) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      documentTypeField,
                                      const SizedBox(height: 10),
                                      documentNameField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: documentTypeField),
                                    const SizedBox(width: 10),
                                    Expanded(child: documentNameField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: isSubmitting ? null : addDocument,
                                icon: Icon(
                                  Icons.upload_file_outlined,
                                  size: narrowDialog ? 16 : 18,
                                ),
                                label: Text(
                                  'Upload Document',
                                  style: TextStyle(
                                      fontSize: narrowDialog ? 13 : 15),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (documents.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: narrowDialog ? 20 : 28,
                                ),
                                child: Center(
                                  child: Text(
                                    'No documents yet',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: narrowDialog ? 13 : 15,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: List<Widget>.generate(
                                    documents.length, (index) {
                                  final document = documents[index];
                                  return Container(
                                    margin: EdgeInsets.only(
                                      bottom: index == documents.length - 1
                                          ? 0
                                          : 10,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                document.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize:
                                                      narrowDialog ? 13 : 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                document.documentTypeLabel,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize:
                                                      narrowDialog ? 12 : 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: isSubmitting
                                              ? null
                                              : () => setLocalState(
                                                    () => documents = documents
                                                        .where((item) =>
                                                            !identical(
                                                                item, document))
                                                        .toList(
                                                            growable: false),
                                                  ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: isSubmitting ? null : submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Update Closure',
                                          style: TextStyle(
                                            fontSize: narrowDialog ? 14 : 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    unitNumberController.dispose();
    towerController.dispose();
    floorController.dispose();
    unitTypeController.dispose();
    carpetAreaController.dispose();
    superAreaController.dispose();
    documentNameController.dispose();
    agreedPriceController.dispose();
    bookingAmountController.dispose();
    loanBankController.dispose();
    commissionPercentController.dispose();
    notesController.dispose();

    if (updated == true && mounted) {
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Closure updated successfully.')));
    }
  }

  Future<void> _openStatusUpdateDialog(Map<String, dynamic> item) async {
    final closureId = _readString(item['id'], fallback: '');
    if (closureId.isEmpty) return;

    final noteController = TextEditingController();
    bool isSubmitting = false;
    final currentStatus =
        _readString(item['status'], fallback: 'confirmed').toLowerCase();
    String selectedStatus = _statusToUi(currentStatus);

    final leadName = _readString(item['lead_name'], fallback: 'N/A');
    final projectName = _readString(item['project_name'], fallback: 'N/A');
    final bookingDate =
        _formatDate(_readString(item['booking_date'], fallback: ''));

    List<String> allowedStatuses;
    if (currentStatus == 'confirmed') {
      allowedStatuses = <String>['Confirmed', 'On Hold', 'Cancelled'];
    } else {
      allowedStatuses = <String>[selectedStatus];
    }
    if (!allowedStatuses.contains(selectedStatus)) {
      selectedStatus = allowedStatuses.first;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.updateClosureStatus(
                  id: closureId,
                  status: _uiToApiStatus(selectedStatus),
                  note: noteController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 560,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Change Closure Status',
                              style: TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                _initials(leadName),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leadName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                    ),
                                  ),
                                  Text(
                                    '$projectName · $bookingDate',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('New Status'),
                      const SizedBox(height: 6),
                      SearchableDropdownField<String>(
                        label: 'New Status',
                        sheetTitle: 'Change Closure Status',
                        showFieldLabel: false,
                        value: selectedStatus,
                        hintText: 'Select status',
                        items: allowedStatuses
                            .map(
                              (s) => SearchableDropdownItem<String>(
                                value: s,
                                label: s,
                              ),
                            )
                            .toList(),
                        enabled: !isSubmitting,
                        onChanged: (value) => setLocalState(
                          () => selectedStatus = value ?? selectedStatus,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Note (optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        enabled: !isSubmitting,
                        maxLines: 3,
                        decoration: _fieldDecoration(
                            hint: 'Reason for status change...'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSubmitting ? null : submit,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Update Status'),
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

    noteController.dispose();
    if (updated == true && mounted) {
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Closure status updated')));
    }
  }

  String _uiToApiStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'on hold':
        return 'on_hold';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return 'confirmed';
    }
  }

  String _statusToUi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'on_hold':
      case 'on hold':
        return 'On Hold';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return 'Confirmed';
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error ?? 'Unable to load closures.',
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadClosures,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text('No closures found.',
          style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildPagination() {
    return PaginationWidget(
      currentPage: _currentPage,
      totalPages: _totalPages,
      totalItems: _totalItems,
      itemLabel: 'records',
      onPageChanged: (page) => _loadClosures(page: page),
    );
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final query = _searchController.text.trim().toLowerCase();
    final lead = _readString(item['lead_name'], fallback: '').toLowerCase();
    final project =
        _readString(item['project_name'], fallback: '').toLowerCase();
    final unit = _readString(item['unit_number'], fallback: '').toLowerCase();
    return query.isEmpty ||
        lead.contains(query) ||
        project.contains(query) ||
        unit.contains(query);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = _readString(value, fallback: '').toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  String _readRoleLabel(Map<String, dynamic> user) {
    final rawRole = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
      fallback: '',
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

  _SelectionOption? _teamTreeSelectionOption(Map<String, dynamic> user) {
    if (!_readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    )) {
      return null;
    }
    final id = _readString(
      user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid'],
      fallback: '',
    );
    if (id.isEmpty) {
      return null;
    }
    final name = _readString(
      user['full_name'] ??
          user['fullName'] ??
          user['name'] ??
          '${_readString(user['first_name'], fallback: '')} ${_readString(user['last_name'], fallback: '')}',
      fallback: '',
    );
    if (name.isEmpty) {
      return null;
    }
    final roleLabel = _readRoleLabel(user);
    return _SelectionOption(
      id: id,
      label: roleLabel.isEmpty ? name : '$name ($roleLabel)',
    );
  }

  List<String> _extractStringList(dynamic value) {
    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty && entry.toLowerCase() != 'null')
          .toList(growable: false);
    }
    final text = _readString(value, fallback: '');
    if (text.isEmpty) return <String>[];
    if (text.startsWith('[') && text.endsWith(']')) {
      final stripped = text.substring(1, text.length - 1).trim();
      if (stripped.isEmpty) return <String>[];
      return stripped
          .split(',')
          .map((entry) => entry.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return <String>[text];
  }

  String _formatSelectionSummary(
    List<_SelectionOption> options,
    List<String> selectedIds,
  ) {
    if (selectedIds.isEmpty) {
      return '';
    }

    final labelsById = {
      for (final option in options) option.id: option.label,
    };
    final selectedLabels = selectedIds
        .map((id) => labelsById[id] ?? id)
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);
    if (selectedLabels.isEmpty) {
      return '';
    }
    if (selectedLabels.length <= 2) {
      return selectedLabels.join(', ');
    }
    return '${selectedLabels.take(2).join(', ')} +${selectedLabels.length - 2} more';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  String _rupee(double value) {
    if (value <= 0) return 'Rs 0';
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  String _formatCurrency(double value) {
    if (value <= 0) return '₹0';
    return '₹${NumberFormat('#,##,##0').format(value)}';
  }

  String _formatCompactCurrency(double value) {
    if (value <= 0) return '₹0';
    if (value >= 10000000) {
      return '₹${_trimDecimal(value / 10000000)} Cr';
    }
    if (value >= 100000) {
      return '₹${_trimDecimal(value / 100000)} L';
    }
    if (value >= 1000) {
      return '₹${_trimDecimal(value / 1000)} K';
    }
    return _formatCurrency(value);
  }

  String _trimDecimal(double value) {
    final formatted = value.toStringAsFixed(value >= 100 ? 0 : 2);
    return formatted.contains('.')
        ? formatted.replaceFirst(RegExp(r'\.?0+$'), '')
        : formatted;
  }

  String _toYmd(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '-';
    final local = parsed.toLocal();
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
      'Dec'
    ];
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'done':
        return const Color(0xFF0A9A55);
      case 'pending':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }
}
