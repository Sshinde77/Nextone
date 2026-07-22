import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/api_constants.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/app_feedback.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/widgets/app_preloader.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class ClosureDetailPage extends StatefulWidget {
  const ClosureDetailPage({
    super.key,
    required this.lookupId,
  });

  final String lookupId;

  @override
  State<ClosureDetailPage> createState() => _ClosureDetailPageState();
}

class _ClosureDetailPageState extends State<ClosureDetailPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _documentNameController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingDocument = false;
  String? _error;
  Map<String, dynamic>? _data;
  String? _selectedDocumentType;
  final Set<String> _renamingDocumentIds = <String>{};
  final Set<String> _deletingDocumentIds = <String>{};

  static const List<MapEntry<String, String>> _documentTypeOptions =
      <MapEntry<String, String>>[
    MapEntry<String, String>('cost_sheet', 'Cost Sheet'),
    MapEntry<String, String>('payment_proof', 'Payment Proof'),
    MapEntry<String, String>('booking_form', 'Booking Form'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _documentNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _authProvider.closureLeadDetail(
        id: widget.lookupId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _data = detail;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Closure Detail',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: AppPreloader.compact(
                  message: 'Loading closure details...',
                ),
              )
            else if (_error != null)
              _errorCard()
            else if (_data == null)
              _emptyCard()
            else ...[
              _headerCard(),
              const SizedBox(height: 10),
              _statusCard(),
              const SizedBox(height: 10),
              _paymentCard(),
              const SizedBox(height: 10),
              _commissionCard(),
              const SizedBox(height: 10),
              _leadCard(),
              const SizedBox(height: 10),
              _closedByCard(),
              const SizedBox(height: 10),
              _notesCard(),
              const SizedBox(height: 10),
              _documentsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final d = _data!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _readString(d['project_name'],
                          fallback: 'Closure Project'),
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_readString(d['id'], fallback: '-')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Booking Date: ${_formatDate(_readString(d['booking_date'], fallback: ''))}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(_readString(d['status'], fallback: 'confirmed')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _miniTile(
                      'Unit', _readString(d['unit_number'], fallback: '-'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _miniTile(
                      'Tower', _readString(d['tower_block'], fallback: '-'))),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _miniTile('Floor', d['floor_number']?.toString() ?? '-')),
              const SizedBox(width: 8),
              Expanded(
                  child: _miniTile(
                      'Deal Value', _rupee(_toDouble(d['agreed_price'])))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Status',
      icon: Icons.check_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Current', _readString(d['status'], fallback: '-')),
          _row('Updated',
              _formatDateTime(_readString(d['updated_at'], fallback: ''))),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Payment Details',
      icon: Icons.credit_card_outlined,
      child: Column(
        children: [
          _row('Booking Amount', _rupee(_toDouble(d['booking_amount']))),
          _row('Payment Plan', _readString(d['payment_plan'], fallback: '-')),
          _row('Home Loan', d['loan_required'] == true ? 'Yes' : 'No'),
          _row('Loan Bank', _readString(d['loan_bank'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _commissionCard() {
    final d = _data!;
    final amount = _toDouble(d['commission_amount']);
    final percent = _toDouble(d['commission_percent']);
    return _sectionCard(
      title: 'Commission',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _row('Amount', '${_rupee(amount)} (${percent.toStringAsFixed(0)}%)'),
          _row('Payment Status',
              d['commission_paid'] == true ? 'Paid' : 'Pending'),
          _row(
            'Paid Date',
            _formatDate(_readString(d['commission_paid_date'], fallback: '')),
          ),
        ],
      ),
    );
  }

  Widget _leadCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Lead Information',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _row('Name', _readString(d['lead_name'], fallback: '-')),
          _row('Phone', _readString(d['lead_phone'], fallback: '-')),
          _row('Email', _readString(d['lead_email'], fallback: '-')),
          _row('Project', _readString(d['project_name'], fallback: '-')),
          _row('City', _readString(d['project_city'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _closedByCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Closed By',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _row('Name', _readString(d['closed_by_name'], fallback: '-')),
          _row('Manager',
              _readString(d['closed_by_manager_name'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _notesCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Closure Notes',
      icon: Icons.info_outline,
      child: Text(
        _readString(d['closure_notes'], fallback: '-'),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _documentsCard() {
    final documents = _readDocuments();
    return _sectionCard(
      title: 'Documents',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final typeField = _documentDropdownField();
              final nameField = _documentNameField();
              if (compact) {
                return Column(
                  children: [
                    typeField,
                    const SizedBox(height: 12),
                    nameField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: typeField),
                  const SizedBox(width: 12),
                  Expanded(child: nameField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isUploadingDocument ? null : _uploadClosureDocument,
            icon: _isUploadingDocument
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(
              _isUploadingDocument ? 'Uploading...' : 'Upload Document',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (documents.isEmpty)
            const Text(
              'No documents available.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: List<Widget>.generate(documents.length, (index) {
                final document = documents[index];
                final documentId = _readString(document['id'], fallback: '');
                final name =
                    _readString(document['name'], fallback: 'Document');
                final type = _documentTypeLabel(
                  _readString(document['document_type'], fallback: '-'),
                );
                final url = _readString(document['url'], fallback: '');
                final previewUrl = _closureDocumentPreviewUrl(url);
                final isRenaming = _renamingDocumentIds.contains(documentId);
                final isDeleting = _deletingDocumentIds.contains(documentId);
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == documents.length - 1 ? 0 : 10,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: previewUrl.isEmpty
                                  ? null
                                  : () => _openDocumentPreview(previewUrl),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: previewUrl.isEmpty
                                      ? AppColors.textPrimary
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: previewUrl.isEmpty
                                      ? TextDecoration.none
                                      : TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (previewUrl.isNotEmpty)
                        IconButton(
                          onPressed: () => _openDocumentPreview(previewUrl),
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'Preview document',
                        ),
                      IconButton(
                        onPressed:
                            isRenaming || isDeleting || _isUploadingDocument
                                ? null
                                : () => _editClosureDocument(document),
                        icon: isRenaming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.edit_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                        tooltip: 'Edit document name',
                      ),
                      IconButton(
                        onPressed:
                            isRenaming || isDeleting || _isUploadingDocument
                                ? null
                                : () => _deleteClosureDocument(document),
                        icon: isDeleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.delete_outline,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                        tooltip: 'Delete document',
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _errorCard() {
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
          Text(_error ?? 'Unable to load detail',
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadDetail,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No closure detail found.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  List<Map<String, dynamic>> _readDocuments() {
    final data = _data;
    if (data == null) {
      return const <Map<String, dynamic>>[];
    }
    final raw = data['documents'];
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        return item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _documentTypeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'cost_sheet':
        return 'Cost Sheet';
      case 'payment_proof':
        return 'Payment Proof';
      case 'booking_form':
        return 'Booking Form';
      default:
        return value.trim().isEmpty ? '-' : value.trim().replaceAll('_', ' ');
    }
  }

  Future<void> _uploadClosureDocument() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'closures',
      action: 'edit',
      moduleLabel: 'closures',
    );
    if (!allowed || _isUploadingDocument) {
      return;
    }

    final closureId = _closureId;
    if (closureId.isEmpty) {
      _showSnackBar('Closure id is not available.');
      return;
    }

    final documentType = (_selectedDocumentType ?? '').trim();
    final documentName = _documentNameController.text.trim();
    if (documentType.isEmpty) {
      _showSnackBar('Please select document type.');
      return;
    }
    if (documentName.isEmpty) {
      _showSnackBar('Please enter document name.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      withData: kIsWeb,
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.first;
    if (!_hasSelectedUploadFile(file)) {
      _showSnackBar('Please choose a valid document.');
      return;
    }

    setState(() {
      _isUploadingDocument = true;
    });

    try {
      await _authProvider.uploadClosureDocument(
        closureId: closureId,
        filePath: _platformFilePath(file),
        fileBytes: file.bytes,
        fileName: file.name.trim(),
        documentType: documentType,
        name: documentName,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Document uploaded successfully.');
      _documentNameController.clear();
      setState(() {
        _selectedDocumentType = null;
      });
      await _loadDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDocument = false;
        });
      }
    }
  }

  Future<void> _editClosureDocument(Map<String, dynamic> document) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'closures',
      action: 'edit',
      moduleLabel: 'closures',
    );
    if (!allowed) {
      return;
    }

    final closureId = _closureId;
    final documentId = _readString(document['id'], fallback: '');
    if (closureId.isEmpty || documentId.isEmpty) {
      _showSnackBar('Document id is not available.');
      return;
    }

    final nameController = TextEditingController(
      text: _readString(document['name'], fallback: ''),
    );
    var shouldUpdate = false;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Document Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  _showSnackBar('Please enter document name.');
                  return;
                }
                shouldUpdate = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || !shouldUpdate) {
      nameController.dispose();
      return;
    }

    setState(() {
      _renamingDocumentIds.add(documentId);
    });
    try {
      await _authProvider.updateClosureDocument(
        closureId: closureId,
        documentId: documentId,
        name: nameController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Document updated successfully.');
      await _loadDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      nameController.dispose();
      if (mounted) {
        setState(() {
          _renamingDocumentIds.remove(documentId);
        });
      }
    }
  }

  Future<void> _deleteClosureDocument(Map<String, dynamic> document) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'closures',
      action: 'edit',
      moduleLabel: 'closures',
    );
    if (!allowed) {
      return;
    }

    final closureId = _closureId;
    final documentId = _readString(document['id'], fallback: '');
    final documentName = _readString(document['name'], fallback: 'document');
    if (closureId.isEmpty || documentId.isEmpty) {
      _showSnackBar('Document id is not available.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Delete "$documentName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingDocumentIds.add(documentId);
    });
    try {
      await _authProvider.deleteClosureDocument(
        closureId: closureId,
        documentId: documentId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Document deleted successfully.');
      await _loadDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _deletingDocumentIds.remove(documentId);
        });
      }
    }
  }

  String _closureDocumentPreviewUrl(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return '';
    }
    if (normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://')) {
      return normalizedPath;
    }
    return '${ApiConstants.baseUrl.replaceFirst('/api/v1', '')}$normalizedPath';
  }

  Future<void> _openDocumentPreview(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      _showSnackBar('Unable to preview this document.');
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showSnackBar('Unable to preview this document.');
    }
  }

  String get _closureId {
    return _readString(_data?['id'] ?? widget.lookupId, fallback: '').trim();
  }

  Widget _documentDropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDocumentType,
      decoration: const InputDecoration(
        labelText: 'Document Type',
        border: OutlineInputBorder(),
      ),
      items: _documentTypeOptions
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.key,
              child: Text(option.value),
            ),
          )
          .toList(growable: false),
      onChanged: _isUploadingDocument
          ? null
          : (value) {
              setState(() {
                _selectedDocumentType = value;
              });
            },
    );
  }

  Widget _documentNameField() {
    return TextField(
      controller: _documentNameController,
      enabled: !_isUploadingDocument,
      decoration: const InputDecoration(
        labelText: 'Document Name',
        hintText: 'Cost Sheet - Tower B',
        border: OutlineInputBorder(),
      ),
    );
  }

  bool _hasSelectedUploadFile(PlatformFile? file) {
    if (file == null) {
      return false;
    }
    if (!kIsWeb) {
      return (file.path?.trim().isNotEmpty ?? false);
    }
    return file.bytes != null && file.bytes!.isNotEmpty;
  }

  String _platformFilePath(PlatformFile? file) {
    if (file == null || kIsWeb) {
      return '';
    }
    return file.path?.trim() ?? '';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    AppFeedback.showMessage(message, isError: true);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  String _rupee(double value) {
    if (value <= 0) return '-';
    return 'Rs ${value.toStringAsFixed(0)}';
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
      'Dec',
    ];
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  String _formatDateTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '-';
    final date = _formatDate(parsed.toIso8601String());
    final hh = parsed.toLocal().hour.toString().padLeft(2, '0');
    final mm = parsed.toLocal().minute.toString().padLeft(2, '0');
    return '$date, $hh:$mm';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF0A9A55);
      case 'on_hold':
      case 'on hold':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }
}
