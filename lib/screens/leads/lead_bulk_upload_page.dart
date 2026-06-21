import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';

class LeadBulkUploadResult {
  const LeadBulkUploadResult({
    required this.message,
    this.resultFilename,
  });

  final String message;
  final String? resultFilename;
}

class LeadBulkUploadPage extends StatefulWidget {
  const LeadBulkUploadPage({super.key});

  @override
  State<LeadBulkUploadPage> createState() => _LeadBulkUploadPageState();
}

class _LeadBulkUploadPageState extends State<LeadBulkUploadPage> {
  static const int _maxUploadBytes = 10 * 1024 * 1024;

  final AuthProvider _authProvider = AuthProvider();

  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];
  String? _selectedAssigneeId;
  PlatformFile? _selectedFile;
  bool _isLoadingAssignees = true;
  bool _isDownloadingTemplate = false;
  bool _isPickingFile = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAssigneeOptions();
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
        _isLoadingAssignees = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAssignees = false;
      });
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
    final group = _roleGroup(_normalizeRole(roleRaw));

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
    final roleLabel = roleRaw
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
    final baseName = displayName.isEmpty ? 'User $id' : displayName;

    return _AssigneeOption(
      id: id,
      name: roleLabel.isEmpty ? baseName : '$baseName ($roleLabel)',
      group: group,
    );
  }

  Future<void> _downloadTemplate() async {
    setState(() {
      _isDownloadingTemplate = true;
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
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingTemplate = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    if (kIsWeb) {
      _showSnackBar('Bulk upload is not supported on Web in this build.');
      return;
    }

    setState(() {
      _isPickingFile = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['xlsx', 'xls'],
        allowMultiple: false,
      );
      if (!mounted || picked == null || picked.files.isEmpty) {
        return;
      }

      final file = picked.files.single;
      if (file.path == null || file.path!.trim().isEmpty) {
        _showSnackBar('Could not read the selected file path.');
        return;
      }
      if (file.size > _maxUploadBytes) {
        _showSnackBar('Select a file smaller than 10 MB.');
        return;
      }

      setState(() {
        _selectedFile = file;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _uploadAndImport() async {
    final file = _selectedFile;
    final filePath = file?.path?.trim();
    if (file == null || filePath == null || filePath.isEmpty) {
      _showSnackBar('Select your filled Excel file first.');
      return;
    }

    setState(() {
      _isUploading = true;
    });
    try {
      final response = await _authProvider.uploadLeadBulkFile(
        filePath: filePath,
        assignedTo: _selectedAssigneeId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }

      final message =
          _readBulkMessage(response) ?? 'Leads uploaded successfully.';
      Navigator.of(context).pop(
        LeadBulkUploadResult(
          message: message,
          resultFilename: _readBulkResultFilename(response),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selectedFile != null && !_isUploading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                      child: Column(
                        children: [
                          _buildTemplateStep(),
                          const SizedBox(height: 18),
                          _buildFileStep(),
                          const SizedBox(height: 18),
                          _buildAssigneeStep(),
                          const SizedBox(height: 22),
                          _buildActions(canSubmit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 24, 18),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bulk Upload Leads',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateStep() {
    return _StepRow(
      number: '1',
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download the template',
            style: _titleStyle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Template has real project names & team members from your system.\nYou can also fill the Assign To column per-row in Excel.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
            icon: _isDownloadingTemplate
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined, size: 18),
            label: Text(
              _isDownloadingTemplate
                  ? 'Downloading...'
                  : 'Download Template (.xlsx)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileStep() {
    final file = _selectedFile;
    final fileText = file == null
        ? 'or click to browse - .xlsx / .xls - max 10 MB'
        : '${file.name} - ${_formatFileSize(file.size)}';

    return _StepRow(
      number: '2',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select your filled Excel', style: _titleStyle),
          const SizedBox(height: 12),
          InkWell(
            onTap: _isPickingFile || _isUploading ? null : _pickFile,
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: const Color(0xFFD7DEE8),
                radius: 20,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _isPickingFile
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.upload_file_outlined,
                              color: Color(0xFF94A3B8),
                              size: 24,
                            ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Drag & drop your Excel file here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeStep() {
    return _StepRow(
      number: '3',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
            TextSpan(
              text: 'Assign all leads to ',
              children: [
                TextSpan(
                  text: '(optional)',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            style: _titleStyle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Overrides the Assign To column in Excel - all leads go to this person. Leave empty to use per-row assignment from Excel or keep unassigned.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _AssigneeDropdown(
            options: _assigneeOptions,
            selectedId: _selectedAssigneeId,
            hintText: _isLoadingAssignees
                ? 'Loading team members...'
                : 'Select team member (optional)',
            enabled: !_isLoadingAssignees && !_isUploading,
            onSelected: (value) {
              setState(() {
                _selectedAssigneeId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canSubmit) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final cancel = OutlinedButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancel'),
        );
        final upload = FilledButton.icon(
          onPressed: canSubmit ? _uploadAndImport : null,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined, size: 18),
          label: Text(_isUploading ? 'Uploading...' : 'Upload & Import'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            backgroundColor: const Color(0xFF72B9F4),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFBBDDF9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: cancel),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: upload),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: 14),
            Expanded(child: upload),
          ],
        );
      },
    );
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  String _normalizeRole(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'sales_executive') {
      return 'sale_executive';
    }
    return normalized;
  }

  String _roleGroup(String normalizedRole) {
    switch (normalizedRole) {
      case 'sales_manager':
        return 'Sales Managers';
      case 'super_admin':
      case 'admin':
        return 'Admins';
      case 'associate':
      case 'associate_partner':
        return 'Associates';
      case 'external_caller':
        return 'External Callers';
      case 'sale_executive':
      case 'sales_executive':
        return 'Sales Executives';
      default:
        return 'Team Members';
    }
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

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.child,
    this.highlight = false,
  });

  final String number;
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepNumber(number: number, highlight: highlight),
        const SizedBox(width: 14),
        Expanded(child: child),
      ],
    );

    if (!highlight) {
      return row;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2E5FF)),
      ),
      child: row,
    );
  }
}

class _AssigneeDropdown extends StatefulWidget {
  const _AssigneeDropdown({
    required this.options,
    required this.selectedId,
    required this.hintText,
    required this.enabled,
    required this.onSelected,
  });

  final List<_AssigneeOption> options;
  final String? selectedId;
  final String hintText;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  @override
  State<_AssigneeDropdown> createState() => _AssigneeDropdownState();
}

class _AssigneeDropdownState extends State<_AssigneeDropdown> {
  bool _isOpen = false;

  static const List<String> _groupOrder = <String>[
    'Sales Managers',
    'Sales Executives',
    'External Callers',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedName = _selectedName;
    final hasOptions = widget.options.isNotEmpty;
    final isEnabled = widget.enabled && hasOptions;

    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<String>(
          enabled: isEnabled,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          elevation: 8,
          onOpened: () => setState(() => _isOpen = true),
          onCanceled: () => setState(() => _isOpen = false),
          onSelected: (value) {
            setState(() => _isOpen = false);
            widget.onSelected(value);
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            for (final group in _groupOrder) {
              final groupOptions = widget.options
                  .where((option) => option.group == group)
                  .toList();
              if (groupOptions.isEmpty) {
                continue;
              }
              items.add(_groupHeader(group));
              for (final option in groupOptions) {
                items.add(
                  PopupMenuItem<String>(
                    value: option.id,
                    height: 40,
                    child: Text(
                      option.name,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }
            }
            return items;
          },
          child: _buildField(
            text: hasOptions
                ? (selectedName ?? widget.hintText)
                : 'No active team members',
            showHint: selectedName == null,
            enabled: isEnabled,
          ),
        );
      },
    );
  }

  PopupMenuEntry<String> _groupHeader(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 38,
      child: Text(
        '-- $title --',
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildField({
    required String text,
    required bool showHint,
    required bool enabled,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOpen ? AppColors.primary : const Color(0xFFDCE3ED),
          width: _isOpen ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: showHint
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: const Color(0xFF94A3B8),
            size: 22,
          ),
        ],
      ),
    );
  }

  String? get _selectedName {
    final selectedId = widget.selectedId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    for (final option in widget.options) {
      if (option.id == selectedId) {
        return option.name;
      }
    }
    return null;
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({
    required this.number,
    required this.highlight,
  });

  final String number;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFDCEBFF) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        number,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 7;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _AssigneeOption {
  const _AssigneeOption({
    required this.id,
    required this.name,
    required this.group,
  });

  final String id;
  final String name;
  final String group;
}

const TextStyle _titleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 15,
  fontWeight: FontWeight.w800,
);

const TextStyle _bodyStyle = TextStyle(
  color: Color(0xFF64748B),
  fontSize: 13,
  height: 1.35,
  fontWeight: FontWeight.w500,
);
