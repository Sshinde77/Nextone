import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class FollowUpFormPage extends StatefulWidget {
  const FollowUpFormPage({
    super.key,
    this.followUpId,
    this.followUpData,
  });

  final String? followUpId;
  final Map<String, dynamic>? followUpData;

  bool get isEditMode => followUpId != null && followUpId!.trim().isNotEmpty;

  @override
  State<FollowUpFormPage> createState() => _FollowUpFormPageState();
}

class _FollowUpFormPageState extends State<FollowUpFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _authProvider = AuthProvider();

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingLeads = true;
  String? _leadLoadError;
  String? _selectedLeadId;
  String _selectedPriority = 'high';
  DateTime? _selectedDueDate;

  List<_LeadOption> _leadOptions = const <_LeadOption>[];

  @override
  void initState() {
    super.initState();
    _prefillData();
    _loadLeadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillData() {
    final data = widget.followUpData;
    if (data == null) {
      return;
    }

    _titleController.text = _readString(data['title']);
    _notesController.text = _readString(data['notes']);
    _selectedLeadId = _readString(data['lead_id'] ?? data['leadId']);

    final priority = _readString(data['priority']).toLowerCase();
    if (priority == 'high' || priority == 'medium' || priority == 'low') {
      _selectedPriority = priority;
    }

    final dueRaw = _readString(data['due_date'] ?? data['dueDate']);
    final parsedDue = DateTime.tryParse(dueRaw);
    if (parsedDue != null) {
      _selectedDueDate = parsedDue.toLocal();
    }
  }

  Future<void> _loadLeadOptions() async {
    setState(() {
      _isLoadingLeads = true;
      _leadLoadError = null;
    });

    try {
      final result = await _authProvider.leads(
        token: _authProvider.currentAuthToken,
        page: 1,
        perPage: 200,
      );

      final mapped =
          result.items.map(_leadFromApi).whereType<_LeadOption>().toList();
      final uniqueById = <String, _LeadOption>{};
      for (final item in mapped) {
        uniqueById[item.id] = item;
      }
      final leads = uniqueById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final validSelection =
          _selectedLeadId != null && leads.any((l) => l.id == _selectedLeadId)
              ? _selectedLeadId
              : null;

      if (!mounted) {
        return;
      }
      setState(() {
        _leadOptions = leads;
        _selectedLeadId = validSelection;
        _isLoadingLeads = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _leadOptions = const <_LeadOption>[];
        _isLoadingLeads = false;
        _leadLoadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  _LeadOption? _leadFromApi(Map<String, dynamic> json) {
    final id = _readString(json['id'] ?? json['lead_id'] ?? json['leadId']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(json['first_name'] ?? json['firstName']);
    final lastName = _readString(json['last_name'] ?? json['lastName']);
    final fullName = _readString(
      json['name'] ??
          json['full_name'] ??
          json['fullName'] ??
          json['contact_name'] ??
          json['customer_name'],
    );
    final resolvedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName
    ].join(' ').trim();

    return _LeadOption(
      id: id,
      name: resolvedName.isNotEmpty
          ? resolvedName
          : (fullName.isNotEmpty ? fullName : id),
    );
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final initial = _selectedDueDate ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_selectedLeadId == null || _selectedLeadId!.isEmpty) {
      _showSnackBar('Please select a lead.');
      return;
    }
    if (_selectedDueDate == null) {
      _showSnackBar('Please select due date and time.');
      return;
    }
    if (_isLoadingLeads) {
      _showSnackBar('Please wait while leads are loading.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dueDateUtc = _selectedDueDate!.toUtc().toIso8601String();
      Map<String, dynamic> responseData;

      if (widget.isEditMode) {
        responseData = await _authProvider.editFollowUp(
          id: widget.followUpId!.trim(),
          title: _titleController.text.trim(),
          leadId: _selectedLeadId!,
          dueDate: dueDateUtc,
          priority: _selectedPriority,
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      } else {
        responseData = await _authProvider.createFollowUp(
          title: _titleController.text.trim(),
          leadId: _selectedLeadId!,
          dueDate: dueDateUtc,
          priority: _selectedPriority,
          notes: _notesController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(responseData);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLeadMenu(BuildContext context) async {
    if (_isSubmitting || _isLoadingLeads || _leadOptions.isEmpty) {
      return;
    }

    final fieldContext = context;
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
      elevation: 4,
      constraints: BoxConstraints.tightFor(width: renderBox.size.width),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomLeft.dy + 6,
        overlay.size.width - topLeft.dx - renderBox.size.width,
        overlay.size.height - bottomLeft.dy,
      ),
      items: _leadOptions
          .map(
            (lead) => PopupMenuItem<String>(
              value: lead.id,
              child: Text(lead.name),
            ),
          )
          .toList(),
    );

    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedLeadId = selected;
    });
  }

  Future<void> _openPriorityMenu(BuildContext context) async {
    if (_isSubmitting) {
      return;
    }

    const priorities = <String>['high', 'medium', 'low'];
    final fieldContext = context;
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
      elevation: 4,
      constraints: BoxConstraints.tightFor(width: renderBox.size.width),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomLeft.dy + 6,
        overlay.size.width - topLeft.dx - renderBox.size.width,
        overlay.size.height - bottomLeft.dy,
      ),
      items: priorities
          .map(
            (priority) => PopupMenuItem<String>(
              value: priority,
              child: Text(priority[0].toUpperCase() + priority.substring(1)),
            ),
          )
          .toList(),
    );

    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedPriority = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dueDateText = _selectedDueDate == null
        ? 'Select due date and time'
        : DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDueDate!);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: widget.isEditMode ? 'Edit Follow Up' : 'Create Follow Up',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Title',
                    hintText: 'Follow up call with Suresh Patel',
                  ),
                  const SizedBox(height: 12),
                  _buildLeadDropdown(),
                  const SizedBox(height: 12),
                  _buildDueDateField(dueDateText),
                  const SizedBox(height: 12),
                  _buildPriorityDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hintText:
                        'Client asked to call after 10am. Discuss pricing.',
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
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEditMode
                              ? 'Update Follow Up'
                              : 'Create Follow Up'),
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

  Widget _buildLeadDropdown() {
    String? selectedLeadLabel;
    for (final lead in _leadOptions) {
      if (lead.id == _selectedLeadId) {
        selectedLeadLabel = lead.name;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lead',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (fieldContext) {
            return GestureDetector(
              onTap: (_isSubmitting || _isLoadingLeads)
                  ? null
                  : () => _openLeadMenu(fieldContext),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedLeadLabel ?? 'Select lead',
                      style: TextStyle(
                        color: selectedLeadLabel == null
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isLoadingLeads) ...[
          const SizedBox(height: 8),
          const Text(
            'Loading leads...',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        if (_leadLoadError != null) ...[
          const SizedBox(height: 8),
          Text(
            _leadLoadError!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loadLeadOptions,
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  Widget _buildDueDateField(String valueText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due Date',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isSubmitting ? null : _pickDueDateTime,
          child: InputDecorator(
            decoration: _fieldDecoration(hintText: 'Select due date and time'),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    valueText,
                    style: TextStyle(
                      color: _selectedDueDate == null
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

  Widget _buildPriorityDropdown() {
    final selectedPriorityLabel =
        _selectedPriority[0].toUpperCase() + _selectedPriority.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (fieldContext) {
            return GestureDetector(
              onTap:
                  _isSubmitting ? null : () => _openPriorityMenu(fieldContext),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedPriorityLabel,
                      style: const TextStyle(color: Colors.black),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int minLines = 1,
    int maxLines = 1,
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
          minLines: minLines,
          maxLines: maxLines,
          enabled: !_isSubmitting,
          validator: (value) {
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

class _LeadOption {
  const _LeadOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
