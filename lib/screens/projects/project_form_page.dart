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
  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'm4v',
    'webm',
    'avi',
  ];

  final _formKey = GlobalKey<FormState>();
  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _developerController = TextEditingController();
  final _cityController = TextEditingController();
  final _localityController = TextEditingController();
  final _addressController = TextEditingController();
  final _configurationsController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _possessionDateController = TextEditingController();
  final _reraNumberController = TextEditingController();
  final _amenitiesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _homeLoanInfoController = TextEditingController();

  String _status = 'active';
  List<Map<String, dynamic>> _existingUnitPlanDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingCreativeDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingPaymentPlanDocs =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _existingVideoDocs =
      const <Map<String, dynamic>>[];
  List<PlatformFile> _unitPlanFiles = const <PlatformFile>[];
  List<PlatformFile> _creativeFiles = const <PlatformFile>[];
  List<PlatformFile> _paymentPlanFiles = const <PlatformFile>[];
  List<PlatformFile> _videoFiles = const <PlatformFile>[];
  bool _isSubmitting = false;
  bool _isLoadingExistingData = false;

  static const _statuses = <_SelectOption>[
    _SelectOption(value: 'active', label: 'Active'),
    _SelectOption(value: 'inactive', label: 'Inactive'),
  ];

  @override
  void initState() {
    super.initState();
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
    _configurationsController.dispose();
    _priceRangeController.dispose();
    _totalUnitsController.dispose();
    _possessionDateController.dispose();
    _reraNumberController.dispose();
    _amenitiesController.dispose();
    _descriptionController.dispose();
    _homeLoanInfoController.dispose();
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
      final mergedData = <String, dynamic>{};
      final baseData = widget.projectData;
      if (baseData != null) {
        mergedData.addAll(baseData);
      }
      mergedData.addAll(detail);
      setState(() {
        _applyProjectData(mergedData);
      });
    } catch (_) {
      // Keep the prefilled values from the list payload if detail lookup fails.
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
    _configurationsController.text = _readListText(data['configurations']);
    _priceRangeController.text = _readString(data['price_range']);
    _totalUnitsController.text = _readString(data['total_units']);
    _possessionDateController.text = _readDateText(data['possession_date']);
    _reraNumberController.text = _readString(data['rera_number']);
    _amenitiesController.text = _readListText(data['amenities']);
    _descriptionController.text = _readString(data['description']);
    _homeLoanInfoController.text = _readString(data['home_loan_info']);
    _existingUnitPlanDocs = _readDocumentPayloads(data, 'unit_plans');
    _existingCreativeDocs = _readDocumentPayloads(data, 'creatives');
    _existingPaymentPlanDocs = _readDocumentPayloads(data, 'payment_plans');
    _existingVideoDocs = _readDocumentPayloads(data, 'videos');

    final status = _readString(data['status']).toLowerCase();
    if (_statuses.any((option) => option.value == status)) {
      _status = status;
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

  String _readListText(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map(_readString)
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return _readString(value);
  }

  String _readDateText(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return '';
    }
    final parts = raw.split('T');
    return parts.isNotEmpty ? parts.first : raw;
  }

  List<String> _splitCsv(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _buildDocumentPayloads(
    List<PlatformFile> files,
  ) {
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
    } else if (nested is List) {
      for (final item in nested) {
        if (item is! Map) {
          continue;
        }
        final candidate = Map<String, dynamic>.from(item);
        final category = _readString(
          candidate['category'] ??
              candidate['type'] ??
              candidate['document_type'],
        ).toLowerCase();
        if (key == 'unit_plans' &&
            !(category.contains('unit') || category.contains('plan'))) {
          continue;
        }
        if (key == 'creatives' && !category.contains('creative')) {
          continue;
        }
        if (key == 'payment_plans' && !category.contains('payment')) {
          continue;
        }
        if (key == 'videos' && !category.contains('video')) {
          continue;
        }
        addDocument(candidate);
      }
    }

    return documents;
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

  Future<void> _submit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'projects',
      action: widget.isEditMode ? 'edit' : 'create',
      moduleLabel: 'projects',
    );
    if (!allowed) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final name = _nameController.text.trim();
      final developer = _developerController.text.trim();
      final city = _cityController.text.trim();
      final locality = _localityController.text.trim();
      final address = _addressController.text.trim();
      final configurations = _splitCsv(_configurationsController.text);
      final priceRange = _priceRangeController.text.trim();
      final totalUnits = int.tryParse(_totalUnitsController.text.trim()) ?? 0;
      final possessionDate = _possessionDateController.text.trim();
      final reraNumber = _reraNumberController.text.trim();
      final amenities = _splitCsv(_amenitiesController.text);
      final description = _descriptionController.text.trim();
      final homeLoanInfo = _homeLoanInfoController.text.trim();
      final resolvedAddress = address.isNotEmpty
          ? address
          : [locality, city].where((item) => item.isNotEmpty).join(', ');
      final unitPlans = [
        ..._existingUnitPlanDocs,
        ..._buildDocumentPayloads(_unitPlanFiles),
      ];
      final creatives = [
        ..._existingCreativeDocs,
        ..._buildDocumentPayloads(_creativeFiles),
      ];
      final paymentPlans = [
        ..._existingPaymentPlanDocs,
        ..._buildDocumentPayloads(_paymentPlanFiles),
      ];
      final videos = [
        ..._existingVideoDocs,
        ..._buildDocumentPayloads(_videoFiles),
      ];

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
          amenities: amenities,
          status: _status,
          description: description,
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
          amenities: amenities,
          status: _status,
          description: description,
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

  Future<void> _pickDocuments({
    required List<PlatformFile> currentFiles,
    required ValueChanged<List<PlatformFile>> onChanged,
    required List<String> allowedExtensions,
  }) async {
    if (_isSubmitting) {
      return;
    }
    if (kIsWeb) {
      _showSnackBar('Document upload is not supported on Web in this build.');
      return;
    }

    final remainingSlots = _maxDocumentCount - currentFiles.length;
    if (remainingSlots <= 0) {
      _showSnackBar('You can attach up to 10 files.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
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

    final skipped = picked.files.length - accepted.length;
    if (skipped > 0) {
      _showSnackBar('$skipped file(s) skipped. Max 10 files, 20MB each.');
    }
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
        borderRadius: BorderRadius.circular(9),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(title),
              if (_isLoadingExistingData)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      return Column(
                        children: [
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'Project Name',
                                hintText: 'Skyline Heights',
                              ),
                              _buildTextField(
                                controller: _developerController,
                                label: 'Developer',
                                hintText: 'Lodha Group',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildTextField(
                                controller: _cityController,
                                label: 'City',
                                hintText: 'Mumbai',
                              ),
                              _buildTextField(
                                controller: _localityController,
                                label: 'Locality',
                                hintText: 'Andheri West',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Address',
                            hintText: 'Plot 14, Veera Desai Road',
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildTextField(
                                controller: _configurationsController,
                                label: 'Configurations',
                                hintText: '1BHK, 2BHK, 3BHK',
                              ),
                              _buildTextField(
                                controller: _possessionDateController,
                                label: 'Possession Date',
                                hintText: '2027-12-01',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _priceRangeController,
                            label: 'Price Range',
                            hintText: '80L - 1.2Cr',
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _amenitiesController,
                            label: 'Amenities',
                            hintText: 'Swimming Pool, Gym, Clubhouse',
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildTextField(
                                controller: _totalUnitsController,
                                label: 'Total Units',
                                hintText: '240',
                                keyboardType: TextInputType.number,
                              ),
                              _buildTextField(
                                controller: _reraNumberController,
                                label: 'RERA Number',
                                hintText: 'P519OOO12345',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hintText:
                                'Brief overview of project features, amenities...',
                            minLines: 3,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _homeLoanInfoController,
                            label: 'Home Loan Info',
                            hintText: 'Available through HDFC, SBI, ICICI',
                            minLines: 3,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          _buildDocumentSection(),
                          const SizedBox(height: 26),
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
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 8, right: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE3EAF3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: const Color(0xFF667085),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            color: const Color(0xFF7B8794),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFE3EAF3)),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.attach_file, size: 17, color: Color(0xFF667085)),
            SizedBox(width: 6),
            Text(
              'Attach Documents',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '(optional - unit plans & creatives)',
                style: TextStyle(
                  color: Color(0xFF98A4B4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildDocumentPicker(
          label: 'Unit Plans',
          title: 'Click to upload unit plans',
          files: _unitPlanFiles,
          highlighted: _unitPlanFiles.isNotEmpty,
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
        ),
        if (_existingUnitPlanDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildExistingDocuments('Previously uploaded', _existingUnitPlanDocs),
        ],
        const SizedBox(height: 16),
        _buildDocumentPicker(
          label: 'Creatives',
          title: 'Click to upload creatives',
          files: _creativeFiles,
          highlighted: _creativeFiles.isNotEmpty,
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
        ),
        if (_existingCreativeDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildExistingDocuments('Previously uploaded', _existingCreativeDocs),
        ],
        const SizedBox(height: 16),
        _buildDocumentPicker(
          label: 'Payment Plan Files',
          title: 'Click to upload payment plans',
          files: _paymentPlanFiles,
          highlighted: _paymentPlanFiles.isNotEmpty,
          onTap: () => _pickDocuments(
            currentFiles: _paymentPlanFiles,
            onChanged: (files) => _paymentPlanFiles = files,
            allowedExtensions: _documentExtensions,
          ),
          onRemove: (file) => _removeDocument(
            currentFiles: _paymentPlanFiles,
            onChanged: (files) => _paymentPlanFiles = files,
            file: file,
          ),
        ),
        if (_existingPaymentPlanDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildExistingDocuments(
              'Previously uploaded', _existingPaymentPlanDocs),
        ],
        const SizedBox(height: 16),
        _buildDocumentPicker(
          label: 'Video Files',
          title: 'Click to upload videos',
          files: _videoFiles,
          highlighted: _videoFiles.isNotEmpty,
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
        ),
        if (_existingVideoDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildExistingDocuments('Previously uploaded', _existingVideoDocs),
        ],
      ],
    );
  }

  Widget _buildExistingDocuments(
    String label,
    List<Map<String, dynamic>> documents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF98A4B4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: documents
              .map(
                (document) => _StoredDocumentChip(
                  name: _readDocumentName(document),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDocumentPicker({
    required String label,
    required String title,
    required List<PlatformFile> files,
    required bool highlighted,
    required VoidCallback onTap,
    required ValueChanged<PlatformFile> onRemove,
  }) {
    final borderColor =
        highlighted ? AppColors.primary : const Color(0xFFDCE3ED);
    final background =
        highlighted ? const Color(0xFFEFF8FF) : const Color(0xFFFCFCFD);
    final iconColor = highlighted ? AppColors.primary : const Color(0xFF98A4B4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isSubmitting ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: borderColor,
              radius: 18,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? const Color(0xFFDDF0FF)
                          : const Color(0xFFF4F6F9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.upload_outlined,
                      size: 24,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PDF, JPEG, PNG, WEBP, Word - max 20MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF98A4B4),
                      fontSize: 12,
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
      ],
    );
  }

  Widget _buildFooter(bool isNarrow) {
    final cancelButton = OutlinedButton(
      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        foregroundColor: const Color(0xFF374151),
        side: const BorderSide(color: Color(0xFFDCE3ED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Cancel'),
    );

    final submitButton = FilledButton(
      onPressed: _isSubmitting ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          : Text(widget.isEditMode ? 'Update Project' : 'Add Project'),
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
        const SizedBox(width: 10),
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
            const SizedBox(height: 5),
            InkWell(
              onTap: _isSubmitting
                  ? null
                  : () => _openSelectMenu(
                        fieldContext: fieldContext,
                        options: options,
                        currentValue: value,
                        onSelected: onChanged,
                      ),
              borderRadius: BorderRadius.circular(10),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          enabled: !_isSubmitting,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF98A4B4),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
    );
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
        borderRadius: BorderRadius.circular(10),
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
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(10),
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
      ..strokeWidth = 1.4
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
