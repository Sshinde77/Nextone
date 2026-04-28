import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

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
  final _addressController = TextEditingController();
  final _configurationsController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _reraNumberController = TextEditingController();
  final _amenitiesController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedPossessionDate;
  String _status = 'active';
  bool _isSubmitting = false;

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
    _addressController.dispose();
    _configurationsController.dispose();
    _priceRangeController.dispose();
    _totalUnitsController.dispose();
    _reraNumberController.dispose();
    _amenitiesController.dispose();
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
    _addressController.text = _readString(data['address']);
    _configurationsController.text = _listToCsv(data['configurations']);
    _priceRangeController.text = _readString(data['price_range']);
    _totalUnitsController.text = _readString(data['total_units']);
    _reraNumberController.text = _readString(data['rera_number']);
    _amenitiesController.text = _listToCsv(data['amenities']);
    _descriptionController.text = _readString(data['description']);

    final parsedDate = DateTime.tryParse(_readString(data['possession_date']));
    if (parsedDate != null) {
      _selectedPossessionDate = parsedDate;
    }

    final status = _readString(data['status']).toLowerCase();
    if (status == 'active' || status == 'inactive') {
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

  String _listToCsv(dynamic value) {
    if (value is List) {
      return value.map((e) => _readString(e)).where((e) => e.isNotEmpty).join(', ');
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

  Future<void> _pickPossessionDate() async {
    final now = DateTime.now();
    final initialDate = _selectedPossessionDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPossessionDate = picked;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_selectedPossessionDate == null) {
      _showSnackBar('Please select possession date.');
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
      final configurations = _csvToList(_configurationsController.text);
      final priceRange = _priceRangeController.text.trim();
      final totalUnits = int.parse(_totalUnitsController.text.trim());
      final possessionDate = DateFormat('yyyy-MM-dd').format(_selectedPossessionDate!);
      final reraNumber = _reraNumberController.text.trim();
      final amenities = _csvToList(_amenitiesController.text);
      final description = _descriptionController.text.trim();

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
          possessionDate: possessionDate,
          reraNumber: reraNumber,
          amenities: amenities,
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
          possessionDate: possessionDate,
          reraNumber: reraNumber,
          amenities: amenities,
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

  @override
  Widget build(BuildContext context) {
    final possessionDateLabel = _selectedPossessionDate == null
        ? 'Select possession date'
        : DateFormat('dd MMM yyyy').format(_selectedPossessionDate!);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: widget.isEditMode ? 'Edit Project' : 'Create Project',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Project Name',
                    hintText: 'Skyline Heights',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _developerController,
                    label: 'Developer',
                    hintText: 'Lodha Group',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    hintText: 'Mumbai',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _localityController,
                    label: 'Locality',
                    hintText: 'Andheri West',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    hintText: 'Plot 14, Veera Desai Road, Andheri West',
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _configurationsController,
                    label: 'Configurations',
                    hintText: '1BHK, 2BHK, 3BHK',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _priceRangeController,
                    label: 'Price Range',
                    hintText: '80L - 2Cr',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _totalUnitsController,
                    label: 'Total Units',
                    hintText: '240',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Total Units is required.';
                      }
                      final parsed = int.tryParse(text);
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid positive number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPossessionDateField(possessionDateLabel),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _reraNumberController,
                    label: 'RERA Number',
                    hintText: 'P51800045678',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _amenitiesController,
                    label: 'Amenities',
                    hintText: 'Swimming Pool, Gym, Clubhouse',
                  ),
                  const SizedBox(height: 12),
                  _buildStatusDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hintText: 'Premium residential project in the heart of Andheri West',
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(widget.isEditMode ? 'Update Project' : 'Create Project'),
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

  Widget _buildPossessionDateField(String valueText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Possession Date',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isSubmitting ? null : _pickPossessionDate,
          child: InputDecorator(
            decoration: _fieldDecoration(hintText: 'Select possession date'),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    valueText,
                    style: TextStyle(
                      color: _selectedPossessionDate == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    const statuses = <String>['active', 'inactive'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: _fieldDecoration(hintText: 'Select status'),
          items: statuses
              .map(
                (status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status[0].toUpperCase() + status.substring(1)),
                ),
              )
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _status = value;
                  });
                },
        ),
      ],
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
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          enabled: !_isSubmitting,
          validator: validator ??
              (value) {
                if ((value?.trim().isEmpty ?? true)) {
                  return '$label is required.';
                }
                return null;
              },
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
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
}
