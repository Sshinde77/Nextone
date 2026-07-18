import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';

class ProjectFormPage extends StatefulWidget {
  const ProjectFormPage({
    super.key,
    this.projectData,
  });

  final Map<String, dynamic>? projectData;

  bool get isEditMode => projectData != null;

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
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
  static const List<String> _imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'm4v',
    'webm',
    'avi',
  ];

  static const List<_SelectOption> _statuses = <_SelectOption>[
    _SelectOption(value: 'pre_launch', label: 'Pre Launch'),
    _SelectOption(value: 'active', label: 'Active'),
    _SelectOption(value: 'inactive', label: 'Inactive'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _developerController = TextEditingController();
  final _cityController = TextEditingController();
  final _localityController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _possessionDateController = TextEditingController();
  final _reraNumberController = TextEditingController();
  final _homeLoanInfoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amenityInputController = TextEditingController();

  final List<_ConfigurationInput> _configurations = <_ConfigurationInput>[];
  final List<String> _amenities = <String>[];

  String _status = 'active';

  List<Map<String, dynamic>> _existingPhotoDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingDeveloperLogoDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingUnitPlanDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingCreativeDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingPaymentPlanDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingVideoDocs =
      const <Map<String, dynamic>>[];

  List<PlatformFile> _photoFiles = const <PlatformFile>[];
  List<PlatformFile> _developerLogoFiles = const <PlatformFile>[];
  List<PlatformFile> _unitPlanFiles = const <PlatformFile>[];
  List<PlatformFile> _creativeFiles = const <PlatformFile>[];
  List<PlatformFile> _paymentPlanFiles = const <PlatformFile>[];
  List<PlatformFile> _videoFiles = const <PlatformFile>[];

  final Set<String> _deletingDocumentIds = <String>{};
  bool _isSubmitting = false;
  bool _isLoadingExistingData = false;

  @override
  void initState() {
    super.initState();
    _ensureConfigurationRow();
    _prefillData();
    _loadExistingProjectData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _developerController.dispose();
    _cityController.dispose();
    _localityController.dispose();
    _addressController.dispose();
    _priceRangeController.dispose();
    _totalUnitsController.dispose();
    _possessionDateController.dispose();
    _reraNumberController.dispose();
    _homeLoanInfoController.dispose();
    _descriptionController.dispose();
    _amenityInputController.dispose();
    for (final row in _configurations) {
      row.dispose();
    }
    super.dispose();
  }

  void _prefillData() {
    final data = widget.projectData;
    if (data == null) {
      return;
    }
    _applyProjectData(data);
  }

  Future<void> _loadExistingProjectData() async {
    if (!widget.isEditMode) {
      return;
    }

    final id = _readString(widget.projectData?['id']);
    if (id.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingExistingData = true;
    });

    try {
      final detail = await _authProvider.projectDetail(
        id: id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }

      final merged = <String, dynamic>{};
      final baseData = widget.projectData;
      if (baseData != null) {
        merged.addAll(baseData);
      }
      merged.addAll(detail);

      setState(() {
        _applyProjectData(merged);
      });
    } catch (_) {
      // Keep fallback payload values if detail loading fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExistingData = false;
        });
      }
    }
  }

  void _applyProjectData(Map<String, dynamic> data) {
    _nameController.text = _readString(data['name']);
    _developerController.text = _readString(data['developer']);
    _cityController.text = _readString(data['city']);
    _localityController.text = _readString(data['locality']);
    _addressController.text = _readString(data['address']);
    _priceRangeController.text = _readString(data['price_range']);
    _totalUnitsController.text = _readString(data['total_units']);
    _possessionDateController.text = _readDateText(data['possession_date']);
    _reraNumberController.text = _readString(data['rera_number']);
    _homeLoanInfoController.text = _readString(data['home_loan_info']);
    _descriptionController.text = _readString(data['description']);

    _replaceConfigurations(_parseConfigurations(data['configurations']));
    _replaceAmenities(_readStringList(data['amenities']));

    _existingPhotoDocs = _readDocumentPayloads(data, 'photos');
    _existingDeveloperLogoDocs = _readDocumentPayloads(data, 'developer_logo');
    _existingUnitPlanDocs = _readDocumentPayloads(data, 'unit_plans');
    _existingCreativeDocs = _readDocumentPayloads(data, 'creatives');
    _existingPaymentPlanDocs = _readDocumentPayloads(data, 'payment_plans');
    _existingVideoDocs = _readDocumentPayloads(data, 'videos');

    final status = _readString(data['status']).toLowerCase();
    if (_statuses.any((option) => option.value == status)) {
      _status = status;
    }
  }

  void _replaceConfigurations(List<_ConfigurationInput> items) {
    for (final row in _configurations) {
      row.dispose();
    }
    _configurations
      ..clear()
      ..addAll(items);
    _ensureConfigurationRow();
  }

  void _replaceAmenities(List<String> values) {
    _amenities
      ..clear()
      ..addAll(values);
  }

  void _ensureConfigurationRow() {
    if (_configurations.isEmpty) {
      _configurations.add(_ConfigurationInput());
    }
  }

  List<_ConfigurationInput> _parseConfigurations(dynamic value) {
    final rows = <_ConfigurationInput>[];
    if (value is List) {
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          rows.add(
            _ConfigurationInput(
              configuration: _readString(item['configuration']),
              carpetArea: _readString(item['carpet_area']),
              price: _readString(item['price']),
            ),
          );
          continue;
        }
        if (item is Map) {
          final casted = Map<String, dynamic>.from(item);
          rows.add(
            _ConfigurationInput(
              configuration: _readString(casted['configuration']),
              carpetArea: _readString(casted['carpet_area']),
              price: _readString(casted['price']),
            ),
          );
          continue;
        }
        final text = _readString(item);
        if (text.isNotEmpty) {
          rows.add(_ConfigurationInput(configuration: text));
        }
      }
    } else {
      final text = _readString(value);
      if (text.isNotEmpty) {
        final entries = text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty);
        for (final entry in entries) {
          rows.add(_ConfigurationInput(configuration: entry));
        }
      }
    }
    return rows;
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map(_readString)
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = _readString(value);
    if (text.isEmpty) {
      return const <String>[];
    }
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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

  String _readDateText(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return '';
    }
    final parts = raw.split('T');
    return parts.isNotEmpty ? parts.first : raw;
  }

  Future<void> _pickPossessionDate() async {
    if (_isSubmitting) {
      return;
    }

    final initialDate =
        _tryParseDate(_possessionDateController.text) ?? DateTime.now();
    final firstDate = DateTime(2000, 1, 1);
    final lastDate = DateTime(2100, 12, 31);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : initialDate.isAfter(lastDate)
              ? lastDate
              : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (!mounted || pickedDate == null) {
      return;
    }

    setState(() {
      _possessionDateController.text = _formatDate(pickedDate);
    });
  }

  DateTime? _tryParseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _readDocumentId(Map<String, dynamic> source) {
    return _readString(
      source['id'] ??
          source['document_id'] ??
          source['documentId'] ??
          source['uuid'],
    );
  }

  String _readDocumentName(Map<String, dynamic> source) {
    final name = _readString(
      source['file_name'] ??
          source['filename'] ??
          source['original_name'] ??
          source['originalName'] ??
          source['name'] ??
          source['document_name'] ??
          source['documentName'] ??
          source['title'] ??
          source['label'],
    );
    if (name.isNotEmpty) {
      return name;
    }
    return _fileNameFromPath(_readDocumentPath(source));
  }

  String _readDocumentPath(Map<String, dynamic> source) {
    return _readString(
      source['file_path'] ??
          source['filePath'] ??
          source['path'] ??
          source['url'] ??
          source['file_url'] ??
          source['fileUrl'] ??
          source['document_url'] ??
          source['documentUrl'],
    );
  }

  String _fileNameFromPath(String path) {
    if (path.isEmpty) {
      return '';
    }
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path.trim() : segments.last.trim();
  }

  List<Map<String, dynamic>> _readDocumentPayloads(
    Map<String, dynamic> data,
    String key,
  ) {
    final raw = data[key];
    final documents = <Map<String, dynamic>>[];

    void addDocument(Map<String, dynamic> source) {
      final document = Map<String, dynamic>.from(source);
      final fileName = _readDocumentName(source);
      final filePath = _readDocumentPath(source);
      final fileSize =
          source['file_size'] ?? source['fileSize'] ?? source['size'];
      final mimeType = _readString(source['mime_type'] ?? source['mimeType']);

      if (fileName.isEmpty && filePath.isEmpty) {
        return;
      }

      document['file_name'] =
          fileName.isNotEmpty ? fileName : _fileNameFromPath(filePath);
      if (filePath.isNotEmpty) {
        document['file_path'] = filePath;
      }
      if (fileSize != null) {
        document['file_size'] = fileSize is num
            ? fileSize.toInt()
            : int.tryParse(_readString(fileSize)) ?? fileSize;
      }
      if (mimeType.isNotEmpty) {
        document['mime_type'] = mimeType;
      }

      documents.add(document);
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          addDocument(item);
        } else if (item is Map) {
          addDocument(Map<String, dynamic>.from(item));
        }
      }
    } else if (raw is Map<String, dynamic>) {
      addDocument(raw);
    } else if (raw is Map) {
      addDocument(Map<String, dynamic>.from(raw));
    }

    final nested = data['documents'];
    if (nested is Map<String, dynamic>) {
      final nestedItems = nested[key];
      if (nestedItems is List) {
        for (final item in nestedItems) {
          if (item is Map<String, dynamic>) {
            addDocument(item);
          } else if (item is Map) {
            addDocument(Map<String, dynamic>.from(item));
          }
        }
      }
    }

    return documents;
  }

  List<Map<String, dynamic>> _buildDocumentPayloads(List<PlatformFile> files) {
    return files
        .where((file) => file.path != null && file.path!.trim().isNotEmpty)
        .map(
          (file) => <String, dynamic>{
            'file_name': file.name.trim(),
            'file_path': '/uploads/projects/${file.name.trim()}',
            'file_size': file.size,
            'mime_type': _mimeTypeForFile(file),
          },
        )
        .toList();
  }

  String _mimeTypeForFile(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isDocumentDeleting(Map<String, dynamic> document) {
    final id = _readDocumentId(document);
    return id.isNotEmpty && _deletingDocumentIds.contains(id);
  }

  Future<void> _deleteExistingDocument({
    required List<Map<String, dynamic>> documents,
    required ValueChanged<List<Map<String, dynamic>>> onChanged,
    required Map<String, dynamic> document,
  }) async {
    if (_isSubmitting || _isLoadingExistingData) {
      return;
    }

    final projectId = _readString(widget.projectData?['id']);
    final documentId = _readDocumentId(document);
    if (projectId.isEmpty ||
        documentId.isEmpty ||
        _isDocumentDeleting(document)) {
      return;
    }

    final documentName = _readDocumentName(document);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete file?'),
          content: Text(
            documentName.isEmpty
                ? 'Do you want to delete this file?'
                : 'Do you want to delete "$documentName"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      await _authProvider.deleteProjectDocument(
        projectId: projectId,
        documentId: documentId,
        token: _authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        onChanged(
          documents
              .where((item) => _readDocumentId(item) != documentId)
              .toList(),
        );
      });
      _showSnackBar('File deleted successfully.');
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

  Future<void> _pickDocuments({
    required List<PlatformFile> currentFiles,
    required ValueChanged<List<PlatformFile>> onChanged,
    required List<String> allowedExtensions,
    int maxCount = _maxDocumentCount,
  }) async {
    if (_isSubmitting) {
      return;
    }
    if (kIsWeb) {
      _showSnackBar('Document upload is not supported on Web in this build.');
      return;
    }

    final remainingSlots = maxCount - currentFiles.length;
    if (remainingSlots <= 0) {
      _showSnackBar(
        maxCount == 1
            ? 'You can attach only 1 file here.'
            : 'You can attach up to $maxCount files.',
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: remainingSlots > 1,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final accepted = <PlatformFile>[];
    for (final file in picked.files) {
      if (accepted.length >= remainingSlots) {
        break;
      }
      final extension = (file.extension ?? '').toLowerCase();
      if (!allowedExtensions.contains(extension)) {
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
      accepted.add(file);
    }

    if (accepted.isEmpty) {
      return;
    }

    setState(() {
      onChanged(<PlatformFile>[...currentFiles, ...accepted]);
    });
  }

  void _removeDocument({
    required List<PlatformFile> currentFiles,
    required ValueChanged<List<PlatformFile>> onChanged,
    required PlatformFile file,
  }) {
    setState(() {
      onChanged(currentFiles.where((item) => !identical(item, file)).toList());
    });
  }

  void _addConfigurationRow() {
    setState(() {
      _configurations.add(_ConfigurationInput());
    });
  }

  void _addAmenity() {
    final value = _amenityInputController.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (_amenities.any((item) => item.toLowerCase() == value.toLowerCase())) {
      _amenityInputController.clear();
      return;
    }
    setState(() {
      _amenities.add(value);
      _amenityInputController.clear();
    });
  }

  void _removeAmenity(String amenity) {
    setState(() {
      _amenities.remove(amenity);
    });
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _numberValidator(String? value, String label) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (int.tryParse(trimmed) == null) {
      return '$label must be a number.';
    }
    return null;
  }

  Future<void> _submit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'projects',
      action: widget.isEditMode ? 'edit' : 'create',
      moduleLabel: 'projects',
    );
    if (!allowed) {
      return;
    }

    _addAmenity();

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final configurations = _configurations
          .map((row) => row.toPayload())
          .where((item) => item.isNotEmpty)
          .toList();
      final photos = <Map<String, dynamic>>[
        ..._existingPhotoDocs,
        ..._buildDocumentPayloads(_photoFiles),
      ];
      final developerLogoPayload = _developerLogoFiles.isNotEmpty
          ? _buildDocumentPayloads(_developerLogoFiles).first
          : (_existingDeveloperLogoDocs.isNotEmpty
              ? _existingDeveloperLogoDocs.first
              : null);
      final unitPlans = <Map<String, dynamic>>[
        ..._existingUnitPlanDocs,
        ..._buildDocumentPayloads(_unitPlanFiles),
      ];
      final creatives = <Map<String, dynamic>>[
        ..._existingCreativeDocs,
        ..._buildDocumentPayloads(_creativeFiles),
      ];
      final paymentPlans = <Map<String, dynamic>>[
        ..._existingPaymentPlanDocs,
        ..._buildDocumentPayloads(_paymentPlanFiles),
      ];
      final videos = <Map<String, dynamic>>[
        ..._existingVideoDocs,
        ..._buildDocumentPayloads(_videoFiles),
      ];

      final name = _nameController.text.trim();
      final developer = _developerController.text.trim();
      final city = _cityController.text.trim();
      final locality = _localityController.text.trim();
      final address = _addressController.text.trim();
      final priceRange = _priceRangeController.text.trim();
      final totalUnits = int.tryParse(_totalUnitsController.text.trim()) ?? 0;
      final possessionDate = _possessionDateController.text.trim();
      final reraNumber = _reraNumberController.text.trim();
      final homeLoanInfo = _homeLoanInfoController.text.trim();
      final description = _descriptionController.text.trim();
      final resolvedAddress = address.isNotEmpty
          ? address
          : [locality, city].where((item) => item.isNotEmpty).join(', ');

      if (widget.isEditMode) {
        final id = _readString(widget.projectData?['id']);
        if (id.isEmpty) {
          _showSnackBar('Unable to update project: missing project id.');
          return;
        }

        await _authProvider.editProject(
          id: id,
          name: name,
          developer: developer,
          city: city,
          locality: locality,
          address: resolvedAddress,
          configurations: configurations,
          priceRange: priceRange,
          totalUnits: totalUnits,
          possessionDate: possessionDate,
          reraNumber: reraNumber,
          amenities: _amenities,
          status: _status,
          description: description,
          photos: photos,
          developerLogo: developerLogoPayload,
          unitPlans: unitPlans,
          creatives: creatives,
          paymentPlans: paymentPlans,
          videos: videos,
          homeLoanInfo: homeLoanInfo,
          token: _authProvider.currentAuthToken,
        );
      } else {
        await _authProvider.createProject(
          name: name,
          developer: developer,
          city: city,
          locality: locality,
          address: resolvedAddress,
          configurations: configurations,
          priceRange: priceRange,
          totalUnits: totalUnits,
          possessionDate: possessionDate,
          reraNumber: reraNumber,
          amenities: _amenities,
          status: _status,
          description: description,
          photos: photos,
          developerLogo: developerLogoPayload,
          unitPlans: unitPlans,
          creatives: creatives,
          paymentPlans: paymentPlans,
          videos: videos,
          homeLoanInfo: homeLoanInfo,
          token: _authProvider.currentAuthToken,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSelectMenu({
    required BuildContext fieldContext,
    required List<_SelectOption> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final renderBox = fieldContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final overlay =
        Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomLeft = renderBox.localToGlobal(
      Offset(0, renderBox.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<String>(
      context: fieldContext,
      color: Colors.white,
      elevation: 10,
      constraints: BoxConstraints.tightFor(width: renderBox.size.width),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3EAF3)),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomLeft.dy + 6,
        overlay.size.width - topLeft.dx - renderBox.size.width,
        overlay.size.height - bottomLeft.dy,
      ),
      items: options.map((option) {
        final selected = option.value == currentValue;
        return PopupMenuItem<String>(
          value: option.value,
          height: 46,
          child: Text(
            option.label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );

    if (!mounted || selected == null) {
      return;
    }
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? 'Edit Project' : 'Add New Project';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 860),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(title),
                  if (_isLoadingExistingData)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 640;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResponsiveRow(
                                isNarrow: isNarrow,
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Project Name *',
                                    hintText: 'Skyline Heights',
                                    validator: (value) => _requiredValidator(
                                        value, 'Project Name'),
                                  ),
                                  _buildTextField(
                                    controller: _developerController,
                                    label: 'Developer',
                                    hintText: 'Lodha Group',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildUploadField(
                                label: 'Developer Logo',
                                title: 'Upload Logo',
                                files: _developerLogoFiles,
                                existingDocuments: _existingDeveloperLogoDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _developerLogoFiles,
                                  onChanged: (files) =>
                                      _developerLogoFiles = files,
                                  allowedExtensions: _imageExtensions,
                                  maxCount: 1,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _developerLogoFiles,
                                  onChanged: (files) =>
                                      _developerLogoFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingDeveloperLogoDocs = files;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isNarrow: isNarrow,
                                children: [
                                  _buildTextField(
                                    controller: _cityController,
                                    label: 'City *',
                                    hintText: 'Mumbai',
                                    validator: (value) =>
                                        _requiredValidator(value, 'City'),
                                  ),
                                  _buildTextField(
                                    controller: _localityController,
                                    label: 'Locality',
                                    hintText: 'Andheri West',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isNarrow: isNarrow,
                                children: [
                                  _buildTextField(
                                    controller: _addressController,
                                    label: 'Address',
                                    hintText: 'Plot 14, Veera Desai Road',
                                  ),
                                  _buildTextField(
                                    controller: _possessionDateController,
                                    label: 'Possession Date',
                                    hintText: 'Select date',
                                    readOnly: true,
                                    onTap: _pickPossessionDate,
                                    suffixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: Color(0xFF98A4B4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildSelectField(
                                label: 'Status',
                                value: _status,
                                options: _statuses,
                                onChanged: (value) {
                                  setState(() {
                                    _status = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _priceRangeController,
                                label: 'Price Range (e.g. 90L - 2.2Cr)',
                                hintText: '90L - 2.2Cr',
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isNarrow: isNarrow,
                                children: [
                                  _buildTextField(
                                    controller: _totalUnitsController,
                                    label: 'Total Units',
                                    hintText: '240',
                                    keyboardType: TextInputType.number,
                                    validator: (value) =>
                                        _numberValidator(value, 'Total Units'),
                                  ),
                                  _buildTextField(
                                    controller: _reraNumberController,
                                    label: 'RERA Number',
                                    hintText: 'P51800045678',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildConfigurationSection(isNarrow),
                              const SizedBox(height: 14),
                              _buildAmenitiesSection(isNarrow),
                              const SizedBox(height: 14),
                              _buildUploadField(
                                label: 'Project Photos',
                                title: 'Upload Photos',
                                files: _photoFiles,
                                existingDocuments: _existingPhotoDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _photoFiles,
                                  onChanged: (files) => _photoFiles = files,
                                  allowedExtensions: _imageExtensions,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _photoFiles,
                                  onChanged: (files) => _photoFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingPhotoDocs = files;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _homeLoanInfoController,
                                label: 'Home Loan Info',
                                hintText: 'Available through HDFC, SBI, ICICI',
                                minLines: 3,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _descriptionController,
                                label: 'Description',
                                hintText:
                                    'Premium residential project in the heart of Andheri West',
                                minLines: 4,
                                maxLines: 4,
                              ),
                              const SizedBox(height: 14),
                              _buildUploadField(
                                label: 'Unit Plans',
                                title: 'Upload Unit Plans',
                                files: _unitPlanFiles,
                                existingDocuments: _existingUnitPlanDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _unitPlanFiles,
                                  onChanged: (files) => _unitPlanFiles = files,
                                  allowedExtensions: _documentExtensions,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _unitPlanFiles,
                                  onChanged: (files) => _unitPlanFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingUnitPlanDocs = files;
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildUploadField(
                                label: 'Creatives',
                                title: 'Upload Creatives',
                                files: _creativeFiles,
                                existingDocuments: _existingCreativeDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _creativeFiles,
                                  onChanged: (files) => _creativeFiles = files,
                                  allowedExtensions: _documentExtensions,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _creativeFiles,
                                  onChanged: (files) => _creativeFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingCreativeDocs = files;
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildUploadField(
                                label: 'Payment Plan Files',
                                title: 'Upload Payment Plan Files',
                                files: _paymentPlanFiles,
                                existingDocuments: _existingPaymentPlanDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _paymentPlanFiles,
                                  onChanged: (files) =>
                                      _paymentPlanFiles = files,
                                  allowedExtensions: _documentExtensions,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _paymentPlanFiles,
                                  onChanged: (files) =>
                                      _paymentPlanFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingPaymentPlanDocs = files;
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildUploadField(
                                label: 'Video Files',
                                title: 'Upload Video Files',
                                files: _videoFiles,
                                existingDocuments: _existingVideoDocs,
                                onTap: () => _pickDocuments(
                                  currentFiles: _videoFiles,
                                  onChanged: (files) => _videoFiles = files,
                                  allowedExtensions: _videoExtensions,
                                ),
                                onRemove: (file) => _removeDocument(
                                  currentFiles: _videoFiles,
                                  onChanged: (files) => _videoFiles = files,
                                  file: file,
                                ),
                                onExistingChanged: (files) {
                                  _existingVideoDocs = files;
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildFooter(isNarrow),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6EBF2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1D2939),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            color: const Color(0xFF667085),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Configurations'),
        const SizedBox(height: 8),
        Column(
          children: [
            for (var i = 0; i < _configurations.length; i++) ...[
              _buildResponsiveRow(
                isNarrow: isNarrow,
                children: [
                  _buildTextField(
                    controller: _configurations[i].configurationController,
                    label: i == 0 ? '' : '',
                    hintText: '1BHK',
                    showLabel: false,
                  ),
                  _buildTextField(
                    controller: _configurations[i].carpetAreaController,
                    label: '',
                    hintText: '450 sqft',
                    showLabel: false,
                  ),
                  _buildTextField(
                    controller: _configurations[i].priceController,
                    label: '',
                    hintText: '65L',
                    showLabel: false,
                  ),
                ],
              ),
              if (i != _configurations.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _addConfigurationRow,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 38),
            foregroundColor: const Color(0xFF84BEFF),
            side: const BorderSide(color: Color(0xFFD9E7FB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Add Configuration',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Amenities'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _amenityInputController,
                enabled: !_isSubmitting,
                onFieldSubmitted: (_) => _addAmenity(),
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDecoration(
                  hintText: 'Enter amenity (e.g. Swimming Pool, Gym)',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: isNarrow ? 84 : 86,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _addAmenity,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: const Color(0xFF84BEFF),
                  side: const BorderSide(color: Color(0xFFD9E7FB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        if (_amenities.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenities
                .map(
                  (amenity) => _AmenityChip(
                    label: amenity,
                    onRemove:
                        _isSubmitting ? null : () => _removeAmenity(amenity),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadField({
    required String label,
    required String title,
    required List<PlatformFile> files,
    required List<Map<String, dynamic>> existingDocuments,
    required VoidCallback onTap,
    required ValueChanged<PlatformFile> onRemove,
    required ValueChanged<List<Map<String, dynamic>>> onExistingChanged,
  }) {
    final hasSelection = files.isNotEmpty;
    final borderColor =
        hasSelection ? AppColors.primary : const Color(0xFFD6DCE5);
    final background =
        hasSelection ? const Color(0xFFF0F7FF) : const Color(0xFFFCFCFD);
    final textColor =
        hasSelection ? AppColors.primary : const Color(0xFF667085);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isSubmitting ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: borderColor,
              radius: 16,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: files
                .map(
                  (file) => _DocumentChip(
                    file: file,
                    onRemove: _isSubmitting ? null : () => onRemove(file),
                  ),
                )
                .toList(),
          ),
        ],
        if (existingDocuments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: existingDocuments
                .map(
                  (document) => _StoredDocumentChip(
                    name: _readDocumentName(document),
                    isDeleting: _isDocumentDeleting(document),
                    onDelete: _isDocumentDeleting(document)
                        ? null
                        : () => _deleteExistingDocument(
                              documents: existingDocuments,
                              onChanged: onExistingChanged,
                              document: document,
                            ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(bool isNarrow) {
    final cancelButton = OutlinedButton(
      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: const Color(0xFF344054),
        side: const BorderSide(color: Color(0xFFDCE3ED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    final submitButton = FilledButton(
      onPressed: _isSubmitting ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              widget.isEditMode ? 'Update Project' : 'Add Project',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    );

    if (isNarrow) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: cancelButton),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: submitButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cancelButton),
        const SizedBox(width: 14),
        Expanded(child: submitButton),
      ],
    );
  }

  Widget _buildResponsiveRow({
    required bool isNarrow,
    required List<Widget> children,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildSelectField({
    required String label,
    required String value,
    required List<_SelectOption> options,
    required ValueChanged<String> onChanged,
  }) {
    final selected = options.firstWhere(
      (option) => option.value == value,
      orElse: () => options.first,
    );

    return Builder(
      builder: (fieldContext) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(label),
            const SizedBox(height: 6),
            InkWell(
              onTap: _isSubmitting
                  ? null
                  : () => _openSelectMenu(
                        fieldContext: fieldContext,
                        options: options,
                        currentValue: value,
                        onSelected: onChanged,
                      ),
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _fieldDecoration(hintText: ''),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.label,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF95A1B2),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    bool readOnly = false,
    bool showLabel = true,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          _FieldLabel(label),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          enabled: !_isSubmitting,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF98A4B4),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
    );
  }
}

class _ConfigurationInput {
  _ConfigurationInput({
    String configuration = '',
    String carpetArea = '',
    String price = '',
  })  : configurationController = TextEditingController(text: configuration),
        carpetAreaController = TextEditingController(text: carpetArea),
        priceController = TextEditingController(text: price);

  final TextEditingController configurationController;
  final TextEditingController carpetAreaController;
  final TextEditingController priceController;

  Map<String, dynamic> toPayload() {
    final configuration = configurationController.text.trim();
    final carpetArea = carpetAreaController.text.trim();
    final price = priceController.text.trim();
    if (configuration.isEmpty && carpetArea.isEmpty && price.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'configuration': configuration,
      'carpet_area': carpetArea,
      'price': price,
    };
  }

  void dispose() {
    configurationController.dispose();
    carpetAreaController.dispose();
    priceController.dispose();
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF667085),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  const _DocumentChip({
    required this.file,
    required this.onRemove,
  });

  final PlatformFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _formatFileSize(file.size),
                  style: const TextStyle(
                    color: Color(0xFF98A4B4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.close,
                size: 14,
                color: Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _StoredDocumentChip extends StatelessWidget {
  const _StoredDocumentChip({
    required this.name,
    required this.isDeleting,
    required this.onDelete,
  });

  final String name;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 16,
            color: Color(0xFF667085),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name.isEmpty ? 'Project document' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: isDeleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
            ),
          ),
        ],
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
      ..strokeWidth = 1.2
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

class _SelectOption {
  const _SelectOption({required this.value, required this.label});

  final String value;
  final String label;
}
