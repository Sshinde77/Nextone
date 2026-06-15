import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/auth_models.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialData,
  });

  final String projectId;
  final Map<String, dynamic>? initialData;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  static const int _maxDocumentBytes = 20 * 1024 * 1024;
  static const int _maxDocumentCount = 10;
  static const List<String> _documentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'doc',
    'docx',
  ];

  final _authProvider = AuthProvider();
  final RegExp _emailPattern =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  final TextEditingController _leadsSearchController = TextEditingController();

  Map<String, dynamic>? _data;
  List<_ProjectDocument> _unitPlans = const <_ProjectDocument>[];
  List<_ProjectDocument> _creatives = const <_ProjectDocument>[];
  bool _isLoading = true;
  bool _isLoadingDocuments = true;
  bool _isLoadingLeads = true;
  bool _isDocumentAction = false;
  String? _error;
  String? _documentsError;
  String? _leadsError;
  List<_ProjectLead> _projectLeads = const <_ProjectLead>[];
  Timer? _leadsSearchDebounce;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _loadDetail();
    _loadProjectLeads();
  }

  @override
  void dispose() {
    _leadsSearchDebounce?.cancel();
    _leadsSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _authProvider.projectDetail(
        id: widget.projectId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _data = detail;
      });
      await _loadDocuments(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.friendlyMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDocuments({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingDocuments = true;
        _documentsError = null;
      });
    } else {
      setState(() {
        _documentsError = null;
      });
    }

    try {
      final payload = await _authProvider.projectDocuments(
        id: widget.projectId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _unitPlans = _readDocuments(payload, 'unit_plans');
        _creatives = _readDocuments(payload, 'creatives');
        _isLoadingDocuments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _documentsError = AppErrorHandler.friendlyMessage(error);
        _isLoadingDocuments = false;
      });
    }
  }

  Future<void> _loadProjectLeads({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingLeads = true;
        _leadsError = null;
      });
    } else {
      setState(() {
        _leadsError = null;
      });
    }

    try {
      final result = await _authProvider.projectLeads(
        id: widget.projectId,
        token: _authProvider.currentAuthToken,
        search: _leadsSearchController.text.trim().isEmpty
            ? null
            : _leadsSearchController.text.trim(),
        page: 1,
        perPage: 50,
      );
      if (!mounted) return;
      setState(() {
        _projectLeads = result.items
            .map(
                (item) => _ProjectLead.fromMap(Map<String, dynamic>.from(item)))
            .where((lead) => lead.name.isNotEmpty || lead.id.isNotEmpty)
            .toList();
        _isLoadingLeads = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _leadsError = AppErrorHandler.friendlyMessage(error);
        _isLoadingLeads = false;
      });
    }
  }

  void _onLeadsSearchChanged(String _) {
    _leadsSearchDebounce?.cancel();
    _leadsSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _loadProjectLeads();
    });
  }

  Future<void> _uploadDocuments() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'projects',
      action: 'edit',
      moduleLabel: 'projects',
    );
    if (!allowed) return;

    if (_isDocumentAction) {
      return;
    }
    final uploadAsUnitPlans = await _chooseDocumentUploadType();
    if (uploadAsUnitPlans == null) {
      return;
    }
    if (kIsWeb) {
      _showSnackBar('Document upload is not supported on Web in this build.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
      allowMultiple: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final acceptedPaths = <String>[];
    for (final file in picked.files.take(_maxDocumentCount)) {
      final extension = (file.extension ?? '').toLowerCase();
      if (!_documentExtensions.contains(extension)) {
        _showSnackBar('Unsupported file skipped: ${file.name}');
        continue;
      }
      if (file.path == null || file.path!.trim().isEmpty) {
        _showSnackBar('Could not read file path: ${file.name}');
        continue;
      }
      if (file.size > _maxDocumentBytes) {
        _showSnackBar('File is larger than 20MB: ${file.name}');
        continue;
      }
      acceptedPaths.add(file.path!.trim());
    }
    if (acceptedPaths.isEmpty) {
      return;
    }

    setState(() {
      _isDocumentAction = true;
    });
    try {
      await _authProvider.uploadProjectDocuments(
        id: widget.projectId,
        unitPlanFilePaths: uploadAsUnitPlans ? acceptedPaths : const <String>[],
        creativeFilePaths: uploadAsUnitPlans ? const <String>[] : acceptedPaths,
        token: _authProvider.currentAuthToken,
      );
      await _loadDocuments(showLoading: false);
      if (!mounted) return;
      _showSnackBar('Documents uploaded successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDocumentAction = false;
        });
      }
    }
  }

  Future<bool?> _chooseDocumentUploadType() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Upload Documents',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.home_work_outlined,
                      color: AppColors.primary),
                  title: const Text('Unit Plans'),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                ListTile(
                  leading: const Icon(Icons.collections_outlined,
                      color: AppColors.primary),
                  title: const Text('Creatives'),
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadAllDocuments() async {
    if (_isDocumentAction) {
      return;
    }
    setState(() {
      _isDocumentAction = true;
    });
    try {
      final exported = await _authProvider.downloadAllProjectDocuments(
        id: widget.projectId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      await _saveExportedFile(exported, 'Documents ZIP');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDocumentAction = false;
        });
      }
    }
  }

  Future<void> _downloadDocument(_ProjectDocument document) async {
    if (_isDocumentAction) {
      return;
    }
    setState(() {
      _isDocumentAction = true;
    });
    try {
      final exported = await _authProvider.downloadProjectDocument(
        projectId: widget.projectId,
        documentId: document.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final fileName = exported.fileName.trim().isEmpty
          ? document.name
          : exported.fileName.trim();
      await _saveExportedFile(
        ExportFileResult(
          fileName: fileName,
          bytes: exported.bytes,
          contentType: exported.contentType,
        ),
        'Document',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDocumentAction = false;
        });
      }
    }
  }

  Future<void> _deleteDocument(_ProjectDocument document) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'projects',
      action: 'delete',
      moduleLabel: 'projects',
    );
    if (!allowed) return;

    if (_isDocumentAction) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Delete "${document.name}"?'),
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

    setState(() {
      _isDocumentAction = true;
    });
    try {
      await _authProvider.deleteProjectDocument(
        projectId: widget.projectId,
        documentId: document.id,
        token: _authProvider.currentAuthToken,
      );
      await _loadDocuments(showLoading: false);
      if (!mounted) return;
      _showSnackBar('Document deleted successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDocumentAction = false;
        });
      }
    }
  }

  Future<void> _saveExportedFile(
    ExportFileResult exported,
    String label,
  ) async {
    final fileName = exported.fileName.trim().isEmpty
        ? "${label.toLowerCase().replaceAll(' ', '_')}.bin"
        : exported.fileName.trim();
    if (kIsWeb) {
      _showSnackBar(
        '$label generated ($fileName), but direct file save is not supported on Web in this build.',
      );
      return;
    }
    final file = await ExportFileHelper.saveToDownloadNextone(
      fileName: fileName,
      bytes: exported.bytes,
    );
    if (!mounted) return;
    _showSnackBar('$label downloaded: ${file.path}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareProjectFromDetail() async {
    final data = _data ?? const <String, dynamic>{};
    final projectName = _readString(data['name']).isEmpty
        ? 'Project'
        : _readString(data['name']);

    final emailController = TextEditingController();
    final messageController = TextEditingController(
      text: 'Hi, please find the project details as discussed.',
    );
    final emails = <String>[];
    var isSharing = false;

    bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

    void addEmails(
      String rawValue,
      void Function(void Function()) setDialogState,
    ) {
      final parsed = rawValue
          .split(RegExp(r'[,\n]'))
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isEmpty) return;
      final invalid = parsed.where((item) => !isValidEmail(item)).toList();
      if (invalid.isNotEmpty) {
        _showSnackBar('Invalid email: ${invalid.first}');
        return;
      }
      setDialogState(() {
        for (final email in parsed) {
          if (!emails.contains(email)) {
            emails.add(email);
          }
        }
      });
      emailController.clear();
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (isSharing) return;
              if (emailController.text.trim().isNotEmpty) {
                addEmails(emailController.text, setDialogState);
              }
              if (emails.isEmpty) {
                _showSnackBar('Please add at least one email.');
                return;
              }
              setDialogState(() {
                isSharing = true;
              });
              try {
                final response = await _authProvider.shareProject(
                  id: widget.projectId,
                  emails: emails,
                  message: messageController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                final responseMessage =
                    (response['message'] ?? 'Project shared successfully')
                        .toString();
                _showSnackBar(responseMessage);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (!mounted) return;
                _showSnackBar(AppErrorHandler.friendlyMessage(error));
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSharing = false;
                  });
                }
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.share_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Share Project',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                projectName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSharing
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          icon: const Icon(Icons.close),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    const Text(
                      'Send to (press Enter or comma to add multiple)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) =>
                                addEmails(emailController.text, setDialogState),
                            onChanged: (value) {
                              if (value.endsWith(',')) {
                                addEmails(value, setDialogState);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'client@example.com',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: isSharing
                                ? null
                                : () => addEmails(
                                      emailController.text,
                                      setDialogState,
                                    ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    if (emails.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: emails
                            .map(
                              (email) => Chip(
                                label: Text(email),
                                onDeleted: isSharing
                                    ? null
                                    : () => setDialogState(
                                          () => emails.remove(email),
                                        ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Personal message (optional)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Hi, please find the project details...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Email will include:\n'
                        '- Full project details (location, price, RERA, configurations)\n'
                        '- All unit plans + creatives attached as a ZIP file\n'
                        '- Your personal message (if provided)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSharing
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSharing ? null : submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.send_outlined, size: 18),
                            label: Text(
                              isSharing ? 'Sharing...' : 'Share Project',
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
        );
      },
    );
    emailController.dispose();
    messageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? const <String, dynamic>{};
    final status = _readString(data['status']).toLowerCase();
    final statusColor =
        status == 'active' ? AppColors.success : AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Project Details', showBackButton: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _shareProjectFromDetail,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.share_outlined),
        label: const Text('Share Project'),
      ),
      body: _isLoading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: _loadDetail, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildHeroCard(data, status, statusColor),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Overview',
                        children: [
                          _kv('Project ID', _readString(data['id']),
                              icon: Icons.fingerprint),
                          _kv('Developer', _readString(data['developer']),
                              icon: Icons.business_outlined),
                          _kv('City', _readString(data['city']),
                              icon: Icons.location_city_outlined),
                          _kv('Locality', _readString(data['locality']),
                              icon: Icons.map_outlined),
                          _kv('Address', _readString(data['address']),
                              icon: Icons.place_outlined),
                          _kv('Price Range', _readString(data['price_range']),
                              icon: Icons.currency_rupee_outlined),
                          _kv('Total Units', _readString(data['total_units']),
                              icon: Icons.apartment_outlined),
                          _kv('Possession Date',
                              _formatDate(_readString(data['possession_date'])),
                              icon: Icons.event_outlined),
                          _kv('RERA Number', _readString(data['rera_number']),
                              icon: Icons.verified_user_outlined),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDocumentsSection(),
                      const SizedBox(height: 14),
                      _buildProjectLeadsSection(),
                      const SizedBox(height: 14),
                      // _buildSectionCard(
                      //   title: 'Configurations',
                      //   children: [
                      //     _chipWrap(_readList(data['configurations']))
                      //   ],
                      // ),
                      // const SizedBox(height: 14),
                      // _buildSectionCard(
                      //   title: 'Amenities',
                      //   children: [_chipWrap(_readList(data['amenities']))],
                      // ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Meta',
                        children: [
                          _kv('Total Leads', _readString(data['total_leads']),
                              icon: Icons.groups_outlined),
                          _kv('Created By', _readString(data['created_by']),
                              icon: Icons.person_outline),
                          _kv(
                            'Brochure URL',
                            _readString(data['brochure_url']).isEmpty
                                ? 'Not available'
                                : _readString(data['brochure_url']),
                            icon: Icons.picture_as_pdf_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Description',
                        children: [
                          Text(
                            _readString(data['description']).isEmpty
                                ? 'No description provided.'
                                : _readString(data['description']),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDocumentsSection() {
    final totalDocuments = _unitPlans.length + _creatives.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFDF9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.folder_open_outlined,
                  color: Color(0xFF00A88F),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Documents',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalDocuments documents - Unit Plans & Creatives',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final downloadButton = OutlinedButton.icon(
                onPressed: totalDocuments == 0 || _isDocumentAction
                    ? null
                    : _downloadAllDocuments,
                icon: const Icon(Icons.folder_zip_outlined, size: 16),
                label: const Text('Download All ZIP'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              final uploadButton = FilledButton.icon(
                onPressed: _isDocumentAction ? null : _uploadDocuments,
                icon: _isDocumentAction
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Upload'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: downloadButton),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: uploadButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: downloadButton),
                  const SizedBox(width: 10),
                  Expanded(child: uploadButton),
                ],
              );
            },
          ),
          if (_isLoadingDocuments) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (_documentsError != null) ...[
            const SizedBox(height: 16),
            Text(
              _documentsError!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadDocuments,
              child: const Text('Retry'),
            ),
          ] else ...[
            const SizedBox(height: 18),
            _buildDocumentGroup(
              title: 'UNIT PLANS',
              documents: _unitPlans,
              accentColor: AppColors.primary,
            ),
            const SizedBox(height: 18),
            _buildDocumentGroup(
              title: 'CREATIVES',
              documents: _creatives,
              accentColor: const Color(0xFF7C3AED),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectLeadsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Leads',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'All leads interested in this project',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _leadsSearchController,
                    onChanged: _onLeadsSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search leads...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoadingLeads ? null : () => _loadProjectLeads(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon:
                    const Icon(Icons.refresh_rounded, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingLeads)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_leadsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _leadsError!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadProjectLeads,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_projectLeads.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No leads found for this project.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ..._projectLeads.map(
              (lead) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildProjectLeadCard(lead),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectLeadCard(_ProjectLead lead) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  _initials(lead.name),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lead.name.isEmpty ? 'Unnamed Lead' : lead.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: lead.id.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LeadDetailPage(leadId: lead.id),
                          ),
                        ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(68, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(
                icon: Icons.flag_outlined,
                label: lead.statusLabel,
                color: const Color(0xFF00A88F),
              ),
              _metaPill(
                icon: Icons.person_outline,
                label: lead.assignedTo.isEmpty ? 'Unassigned' : lead.assignedTo,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildDocumentGroup({
    required String title,
    required List<_ProjectDocument> documents,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                documents.length.toString(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: documents.isEmpty || _isDocumentAction
                  ? null
                  : _downloadAllDocuments,
              icon: Icon(Icons.download_outlined, size: 15, color: accentColor),
              label: Text(
                'Download all',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (documents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No documents uploaded.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...documents.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDocumentTile(document),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentTile(_ProjectDocument document) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EEF6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFFE53935),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  document.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Download',
            onPressed:
                _isDocumentAction ? null : () => _downloadDocument(document),
            icon: const Icon(Icons.download_outlined, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed:
                _isDocumentAction ? null : () => _deleteDocument(document),
            icon: const Icon(Icons.delete_outline, color: Color(0xFF98A4B4)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
      Map<String, dynamic> data, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _readString(data['name']).isEmpty
                      ? 'Project'
                      : _readString(data['name']),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.isEmpty ? 'N/A' : status.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_readString(data['locality'])}, ${_readString(data['city'])}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('Leads', _readString(data['total_leads'])),
              const SizedBox(width: 10),
              _heroStat('Units', _readString(data['total_units'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  List<_ProjectDocument> _readDocuments(
    Map<String, dynamic> payload,
    String category,
  ) {
    final source = _documentSource(payload, category);
    if (source is! List) {
      return const <_ProjectDocument>[];
    }
    return source
        .whereType<Map>()
        .map((item) => _ProjectDocument.fromMap(
              Map<String, dynamic>.from(item),
              fallbackCategory: category,
            ))
        .where((document) => document.id.isNotEmpty)
        .toList();
  }

  dynamic _documentSource(Map<String, dynamic> payload, String category) {
    final data = payload['data'];
    if (payload[category] is List) {
      return payload[category];
    }
    if (data is Map<String, dynamic> && data[category] is List) {
      return data[category];
    }
    final documents = payload['documents'] ??
        (data is Map ? data['documents'] : null) ??
        (data is List ? data : null);
    if (documents is Map<String, dynamic> && documents[category] is List) {
      return documents[category];
    }
    if (documents is List) {
      return documents.where((item) {
        if (item is! Map) {
          return false;
        }
        final type = _readString(
          item['category'] ?? item['type'] ?? item['document_type'],
        ).toLowerCase();
        if (category == 'unit_plans') {
          return type.contains('unit') || type.contains('plan');
        }
        return type.contains('creative');
      }).toList();
    }
    return const <dynamic>[];
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }
}

class _ProjectDocument {
  const _ProjectDocument({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.category,
  });

  final String id;
  final String name;
  final String sizeLabel;
  final String uploadedBy;
  final String uploadedAt;
  final String category;

  String get meta {
    final parts = <String>[
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (uploadedBy.isNotEmpty) uploadedBy,
      if (uploadedAt.isNotEmpty) uploadedAt,
    ];
    return parts.isEmpty ? 'Document' : parts.join(' - ');
  }

  factory _ProjectDocument.fromMap(
    Map<String, dynamic> json, {
    required String fallbackCategory,
  }) {
    final id = _readValue(
      json['id'] ?? json['_id'] ?? json['doc_id'] ?? json['document_id'],
    );
    final name = _readValue(
      json['name'] ??
          json['file_name'] ??
          json['filename'] ??
          json['original_name'] ??
          json['originalName'] ??
          json['title'],
    );
    final uploadedByRaw =
        json['uploaded_by'] ?? json['uploadedBy'] ?? json['created_by'];
    final uploadedBy = uploadedByRaw is Map<String, dynamic>
        ? _readValue(
            uploadedByRaw['name'] ??
                uploadedByRaw['full_name'] ??
                uploadedByRaw['fullName'] ??
                uploadedByRaw['email'],
          )
        : _readValue(uploadedByRaw);
    final uploadedAt = _formatDocDate(
      _readValue(
        json['created_at'] ??
            json['createdAt'] ??
            json['uploaded_at'] ??
            json['uploadedAt'],
      ),
    );
    final sizeLabel = _readSizeLabel(
      json['size'] ?? json['file_size'] ?? json['fileSize'] ?? json['bytes'],
    );

    return _ProjectDocument(
      id: id,
      name: name.isEmpty ? 'Project document' : name,
      sizeLabel: sizeLabel,
      uploadedBy: uploadedBy,
      uploadedAt: uploadedAt,
      category: fallbackCategory,
    );
  }

  static String _readValue(dynamic value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString().trim();
    return '';
  }

  static String _readSizeLabel(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      final bytes = value.toDouble();
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      if (bytes >= 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${bytes.toStringAsFixed(0)} B';
    }
    return '';
  }

  static String _formatDocDate(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }
}

class _ProjectLead {
  const _ProjectLead({
    required this.id,
    required this.name,
    required this.status,
    required this.assignedTo,
  });

  final String id;
  final String name;
  final String status;
  final String assignedTo;

  String get statusLabel {
    final normalized = status.trim();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  factory _ProjectLead.fromMap(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString();
      return '';
    }

    final assignedToObj =
        json['assigned_to'] ?? json['assignedTo'] ?? json['owner'];
    final assignedTo = assignedToObj is Map<String, dynamic>
        ? read(
            assignedToObj['name'] ??
                assignedToObj['full_name'] ??
                assignedToObj['fullName'] ??
                assignedToObj['email'],
          )
        : read(assignedToObj);

    return _ProjectLead(
      id: read(json['id'] ?? json['_id'] ?? json['lead_id']),
      name: read(json['name'] ?? json['lead_name'] ?? json['full_name']),
      status: read(json['status'] ?? json['lead_status']),
      assignedTo: assignedTo,
    );
  }
}
