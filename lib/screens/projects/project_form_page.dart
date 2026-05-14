import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _authProvider = AuthProvider();

  final _nameController = TextEditingController();
  final _developerController = TextEditingController();
  final _cityController = TextEditingController();
  final _localityController = TextEditingController();
  final _configurationsController = TextEditingController();
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _reraNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _projectType = 'residential';
  String _status = 'active';
  bool _isSubmitting = false;

  static const _projectTypes = <_SelectOption>[
    _SelectOption(value: 'residential', label: 'Residential'),
    _SelectOption(value: 'commercial', label: 'Commercial'),
    _SelectOption(value: 'mixed_use', label: 'Mixed Use'),
    _SelectOption(value: 'plots_land', label: 'Plots / Land'),
  ];

  static const _statuses = <_SelectOption>[
    _SelectOption(value: 'active', label: 'Active'),
    _SelectOption(value: 'inactive', label: 'Inactive'),
  ];

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _developerController.dispose();
    _cityController.dispose();
    _localityController.dispose();
    _configurationsController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _totalUnitsController.dispose();
    _reraNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillData() {
    final data = widget.projectData;
    if (data == null) {
      return;
    }

    _nameController.text = _readString(data['name']);
    _developerController.text = _readString(data['developer']);
    _cityController.text = _readString(data['city']);
    _localityController.text = _readString(data['locality']);
    _configurationsController.text = _listToCsv(data['configurations']);
    _totalUnitsController.text = _readString(data['total_units']);
    _reraNumberController.text = _readString(data['rera_number']);
    _descriptionController.text = _readString(data['description']);

    final status = _readString(data['status']).toLowerCase();
    if (_statuses.any((option) => option.value == status)) {
      _status = status;
    }

    final type = _readString(data['type'] ?? data['project_type'])
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('/', '_');
    if (_projectTypes.any((option) => option.value == type)) {
      _projectType = type;
    }

    final priceParts = _splitPriceRange(_readString(data['price_range']));
    _priceMinController.text = priceParts.$1;
    _priceMaxController.text = priceParts.$2;
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

  String _listToCsv(dynamic value) {
    if (value is List) {
      return value
          .map((e) => _readString(e))
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return _readString(value);
  }

  List<String> _csvToList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  (String, String) _splitPriceRange(String value) {
    final numbers = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(value)
        .map((match) => match.group(0) ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
    if (numbers.length >= 2) {
      return (numbers.first, numbers[1]);
    }
    if (numbers.length == 1) {
      return (numbers.first, '');
    }
    return ('', '');
  }

  String _priceRangeForApi() {
    final min = _priceMinController.text.trim();
    final max = _priceMaxController.text.trim();
    if (min.isNotEmpty && max.isNotEmpty) {
      return '$min - $max';
    }
    return min.isNotEmpty ? min : max;
  }

  Future<void> _submit() async {
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
      final configurations = _csvToList(_configurationsController.text);
      final priceRange = _priceRangeForApi();
      final totalUnits = int.tryParse(_totalUnitsController.text.trim()) ?? 0;
      final reraNumber = _reraNumberController.text.trim();
      final description = _descriptionController.text.trim();
      final existingAddress = _readString(widget.projectData?['address']);
      final derivedAddress =
          [locality, city].where((item) => item.isNotEmpty).join(', ');
      final address =
          existingAddress.isNotEmpty ? existingAddress : derivedAddress;

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
          address: address,
          configurations: configurations,
          priceRange: priceRange,
          totalUnits: totalUnits,
          possessionDate: _readString(widget.projectData?['possession_date']),
          reraNumber: reraNumber,
          amenities: _csvToList(_listToCsv(widget.projectData?['amenities'])),
          status: _status,
          description: description,
          token: _authProvider.currentAuthToken,
        );
      } else {
        await _authProvider.createProject(
          name: name,
          developer: developer,
          city: city,
          locality: locality,
          address: address,
          configurations: configurations,
          priceRange: priceRange,
          totalUnits: totalUnits,
          possessionDate: '',
          reraNumber: reraNumber,
          amenities: const <String>[],
          status: _status,
          description: description,
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
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
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
                                label: 'Project Name *',
                                hintText: 'Skyline Heights',
                                validator: _requiredValidator(
                                  'Project Name is required.',
                                ),
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
                                label: 'City *',
                                hintText: 'Mumbai',
                                validator: _requiredValidator(
                                  'City is required.',
                                ),
                              ),
                              _buildTextField(
                                controller: _localityController,
                                label: 'Locality',
                                hintText: 'Andheri West',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildSelectField(
                                label: 'Type',
                                value: _projectType,
                                options: _projectTypes,
                                onChanged: (value) {
                                  setState(() {
                                    _projectType = value;
                                  });
                                },
                              ),
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
                            controller: _configurationsController,
                            label: 'Configurations',
                            hintText: '2BHK, 3BHK, 4BHK',
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveRow(
                            isNarrow: isNarrow,
                            children: [
                              _buildTextField(
                                controller: _priceMinController,
                                label: 'Price Min (₹)',
                                hintText: '8500000',
                                keyboardType: TextInputType.number,
                              ),
                              _buildTextField(
                                controller: _priceMaxController,
                                label: 'Price Max (₹)',
                                hintText: '24000000',
                                keyboardType: TextInputType.number,
                              ),
                            ],
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
      padding: const EdgeInsets.only(left: 20, right: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE3EAF3)),
        ),
      ),
      child: Row(
        children: [
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
    String? Function(String?)? validator,
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
          validator: validator,
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

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
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

class _SelectOption {
  const _SelectOption({required this.value, required this.label});

  final String value;
  final String label;
}
