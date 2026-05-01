import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class SiteVisitFormPage extends StatefulWidget {
  final String? visitId;
  final Map<String, dynamic>? visitData;

  const SiteVisitFormPage({
    super.key,
    this.visitId,
    this.visitData,
  });

  bool get isEditMode => visitId != null && visitId!.trim().isNotEmpty;

  @override
  State<SiteVisitFormPage> createState() => _SiteVisitFormPageState();
}

class _SiteVisitFormPageState extends State<SiteVisitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _authProvider = AuthProvider();

  bool _isSubmitting = false;
  bool _isLoadingDropdowns = true;
  bool _transportArranged = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Dropdown data
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _teamMembers = [];

  String? _selectedLeadId;
  String? _selectedProjectId;
  String? _selectedAssigneeId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final token = _authProvider.currentAuthToken;
      final leadsResult = await _authProvider.leads(token: token, perPage: 100);
      final projectsResult =
          await _authProvider.projects(token: token, perPage: 100);
      final usersList = await _authProvider.users(token: token);

      setState(() {
        _leads = leadsResult.items;
        _projects = projectsResult.items;
        _teamMembers = usersList;
        _isLoadingDropdowns = false;
      });

      if (widget.isEditMode && widget.visitData != null) {
        _prefillData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form data: $e')),
        );
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  void _prefillData() {
    final data = widget.visitData!;
    _notesController.text = data['notes'] ?? '';
    _transportArranged = data['transport_arranged'] ?? false;
    _selectedLeadId = data['lead_id']?.toString();
    _selectedProjectId = data['project_id']?.toString();
    _selectedAssigneeId = data['assigned_to']?.toString();

    // If the incoming values are names (not IDs), resolve them against loaded options.
    _selectedLeadId = _resolveLeadValue(
      _selectedLeadId,
      fallbackName: data['lead_name']?.toString(),
    );
    _selectedProjectId = _resolveProjectValue(
      _selectedProjectId,
      fallbackName: data['project_name']?.toString(),
    );
    _selectedAssigneeId = _resolveAssigneeValue(
      _selectedAssigneeId,
      fallbackName: data['assignee_name']?.toString(),
    );

    if (data['visit_date'] != null) {
      _selectedDate = DateTime.tryParse(data['visit_date']);
    }
    if (data['visit_time'] != null) {
      final parts = data['visit_time'].toString().split(':');
      if (parts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  String? _resolveLeadValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final lead in _leads) {
        if (lead['id']?.toString() == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final lead in _leads) {
      final name = (lead['name'] ?? '').toString().trim().toLowerCase();
      if (name == candidateName) {
        return lead['id']?.toString();
      }
    }
    return null;
  }

  String? _resolveProjectValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final project in _projects) {
        if (project['id']?.toString() == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final project in _projects) {
      final name = (project['name'] ?? '').toString().trim().toLowerCase();
      if (name == candidateName) {
        return project['id']?.toString();
      }
    }
    return null;
  }

  String? _resolveAssigneeValue(String? raw, {String? fallbackName}) {
    final normalizedRaw = (raw ?? '').trim();
    if (normalizedRaw.isNotEmpty) {
      for (final member in _teamMembers) {
        if (member['id']?.toString() == normalizedRaw) {
          return normalizedRaw;
        }
      }
    }
    final candidateName = (fallbackName ?? normalizedRaw).trim().toLowerCase();
    if (candidateName.isEmpty) {
      return null;
    }
    for (final member in _teamMembers) {
      final first = (member['first_name'] ?? '').toString().trim();
      final last = (member['last_name'] ?? '').toString().trim();
      final fullName = '$first $last'.trim().toLowerCase();
      if (fullName == candidateName) {
        return member['id']?.toString();
      }
    }
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formattedDate =
          '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final formattedTime =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      if ((_selectedAssigneeId ?? '').trim().isEmpty) {
        throw Exception('Please select a team member.');
      }

      Map<String, dynamic> responseData;
      if (widget.isEditMode) {
        responseData = await _authProvider.editSiteVisit(
          id: widget.visitId!.trim(),
          visitDate: formattedDate,
          visitTime: formattedTime,
          rescheduleReason: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      } else {
        responseData = await _authProvider.createSiteVisit(
          leadId: (_selectedLeadId ?? '').trim(),
          projectId: (_selectedProjectId ?? '').trim(),
          visitDate: formattedDate,
          visitTime: formattedTime,
          assignedTo: (_selectedAssigneeId ?? '').trim(),
          notes: _notesController.text.trim(),
          transportArranged: _transportArranged,
          token: _authProvider.currentAuthToken,
        );
      }

      if (mounted) {
        Navigator.pop(context, responseData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
                content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? 'Edit Site Visit' : 'Schedule Site Visit';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(title: title, showBackButton: true),
      body: _isLoadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEditMode
                              ? 'Update Details'
                              : 'Visit Details',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildLabel('LEAD *'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _selectedLeadId,
                          hint: 'Select lead...',
                          items: _leads
                              .map(
                                (e) => _DropdownOption(
                                  value: e['id'].toString(),
                                  label: (e['name'] ?? 'Unknown').toString(),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedLeadId = val),
                          validator: (val) =>
                              val == null ? 'Lead is required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('PROJECT *'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _selectedProjectId,
                          hint: 'Select project...',
                          items: _projects
                              .map(
                                (e) => _DropdownOption(
                                  value: e['id'].toString(),
                                  label: (e['name'] ?? 'Unknown').toString(),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProjectId = val),
                          validator: (val) =>
                              val == null ? 'Project is required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('VISIT DATE *'),
                                  const SizedBox(height: 8),
                                  _buildPickerField(
                                    text: _selectedDate == null
                                        ? 'dd-mm-yyyy'
                                        : '${_selectedDate!.day.toString().padLeft(2, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.year}',
                                    icon: Icons.calendar_today_outlined,
                                    onTap: _selectDate,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('VISIT TIME *'),
                                  const SizedBox(height: 8),
                                  _buildPickerField(
                                    text: _selectedTime == null
                                        ? '-- : --'
                                        : _selectedTime!.format(context),
                                    icon: Icons.access_time,
                                    onTap: _selectTime,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('ASSIGN TO'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _selectedAssigneeId,
                          hint: 'Select team member...',
                          items: _teamMembers
                              .map(
                                (e) => _DropdownOption(
                                  value: e['id'].toString(),
                                  label:
                                      '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'
                                          .trim(),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedAssigneeId = val),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: CheckboxListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text(
                              'Transport arranged for client',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary),
                            ),
                            value: _transportArranged,
                            onChanged: (val) => setState(
                                () => _transportArranged = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('NOTES'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Add any specific requirements or notes...',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text(widget.isEditMode
                                        ? 'Update Visit'
                                        : 'Schedule Visit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<_DropdownOption> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    _DropdownOption? selectedOption;
    if (value != null) {
      for (final item in items) {
        if (item.value == value) {
          selectedOption = item;
          break;
        }
      }
    }

    return FormField<String>(
      initialValue: value,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (fieldState) {
        final displayText = selectedOption?.label.isNotEmpty == true
            ? selectedOption!.label
            : hint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (fieldContext) {
                return GestureDetector(
                  onTap: (_isSubmitting || _isLoadingDropdowns || items.isEmpty)
                      ? null
                      : () async {
                          final renderBox =
                              fieldContext.findRenderObject() as RenderBox?;
                          if (renderBox == null) {
                            return;
                          }

                          final overlay = Overlay.of(fieldContext)
                              .context
                              .findRenderObject() as RenderBox;
                          final topLeft = renderBox.localToGlobal(
                            Offset.zero,
                            ancestor: overlay,
                          );
                          final bottomLeft = renderBox.localToGlobal(
                            Offset(0, renderBox.size.height),
                            ancestor: overlay,
                          );

                          final selected = await showMenu<String>(
                            context: fieldContext,
                            color: Colors.white,
                            elevation: 4,
                            constraints: BoxConstraints.tightFor(
                                width: renderBox.size.width),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            position: RelativeRect.fromLTRB(
                              topLeft.dx,
                              bottomLeft.dy + 6,
                              overlay.size.width -
                                  topLeft.dx -
                                  renderBox.size.width,
                              overlay.size.height - bottomLeft.dy,
                            ),
                            items: items
                                .map(
                                  (item) => PopupMenuItem<String>(
                                    value: item.value,
                                    child: Text(item.label.isEmpty
                                        ? 'Unknown'
                                        : item.label),
                                  ),
                                )
                                .toList(),
                          );

                          if (!mounted || selected == null) {
                            return;
                          }
                          fieldState.didChange(selected);
                          onChanged(selected);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: fieldState.hasError
                            ? AppColors.error
                            : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayText,
                            style: TextStyle(
                              color: selectedOption == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (fieldState.hasError) ...[
              const SizedBox(height: 6),
              Text(
                fieldState.errorText ?? '',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPickerField({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: (text.contains('-') ||
                          text.contains(':') ||
                          text.contains('AM') ||
                          text.contains('PM'))
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DropdownOption {
  final String value;
  final String label;

  const _DropdownOption({
    required this.value,
    required this.label,
  });
}
