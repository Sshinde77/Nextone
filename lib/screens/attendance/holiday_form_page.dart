// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';

class HolidayFormPage extends StatefulWidget {
  const HolidayFormPage({super.key, this.holidayData});

  final Map<String, dynamic>? holidayData;

  bool get isEditMode {
    final data = holidayData;
    if (data == null) return false;
    final id = _readStringFromMap(
      data,
      const ['id', 'holiday_id', 'holidayId', 'uuid'],
      fallback: '',
    );
    return id.trim().isNotEmpty;
  }

  @override
  State<HolidayFormPage> createState() => _HolidayFormPageState();
}

class _HolidayFormPageState extends State<HolidayFormPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingRoles = true;
  bool _isLoadingUsers = true;
  String? _rolesError;
  String? _usersError;
  String? _holidayId;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedRoleIds = <String>[];
  List<String> _selectedUserIds = <String>[];
  List<_SelectionOption> _roleOptions = const <_SelectionOption>[];
  List<_SelectionOption> _userOptions = const <_SelectionOption>[];

  @override
  void initState() {
    super.initState();
    _applyHolidayData(widget.holidayData);
    _loadRoleOptions();
    _loadUserOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _applyHolidayData(Map<String, dynamic>? data) {
    if (data == null) {
      return;
    }

    _holidayId = _readStringFromMap(
      data,
      const ['id', 'holiday_id', 'holidayId', 'uuid'],
      fallback: '',
    ).trim();
    final parsedDate = _parseDate(
      data['date'] ??
          data['holiday_date'] ??
          data['holidayDate'] ??
          data['start_date'] ??
          data['startDate'],
    );
    if (parsedDate != null) {
      _selectedDate = parsedDate;
    }
    _nameController.text = _readStringFromMap(
      data,
      const ['name', 'holiday_name', 'holidayName'],
      fallback: '',
    );
    _descriptionController.text = _readStringFromMap(
      data,
      const ['description', 'notes', 'remark'],
      fallback: '',
    );
    _selectedRoleIds = _extractHolidaySelectionList(
      data,
      const ['roles', 'role_ids', 'roleIds', 'apply_to_roles'],
    )
        .map(_normalizeRoleId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    _selectedUserIds = _extractHolidaySelectionList(
      data,
      const ['user_ids', 'userIds', 'users', 'specific_users'],
    );
  }

  Future<void> _loadRoleOptions() async {
    setState(() {
      _isLoadingRoles = true;
      _rolesError = null;
    });

    try {
      final rawRoles =
          await _authProvider.usersRoles(token: _authProvider.currentAuthToken);
      final mapped = rawRoles
          .map(_roleFromApi)
          .whereType<_SelectionOption>()
          .toList(growable: false);
      final unique = <String, _SelectionOption>{
        'all': const _SelectionOption(id: 'all', label: 'All Roles'),
        for (final option in mapped) option.id: option,
      };
      final options = unique.values.toList(growable: false)
        ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _roleOptions = options;
        _isLoadingRoles = false;
        _selectedRoleIds = _selectedRoleIds
            .where((id) => options.any((option) => option.id == id))
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoles = false;
        _rolesError = AppErrorHandler.friendlyMessage(error);
        _roleOptions = const <_SelectionOption>[
          _SelectionOption(id: 'all', label: 'All Roles'),
          _SelectionOption(id: RoleAccess.superAdmin, label: 'Super Admin'),
          _SelectionOption(id: RoleAccess.admin, label: 'Admin'),
          _SelectionOption(id: RoleAccess.salesManager, label: 'Sales Manager'),
          _SelectionOption(
            id: RoleAccess.salesExecutive,
            label: 'Sales Executive',
          ),
          _SelectionOption(
            id: RoleAccess.externalCaller,
            label: 'External Caller',
          ),
        ];
      });
    }
  }

  Future<void> _loadUserOptions() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final users = await _authProvider.assignmentUsers(
        token: _authProvider.currentAuthToken,
      );
      final options = users
          .map(_userFromApi)
          .whereType<_SelectionOption>()
          .toList(growable: false)
        ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _userOptions = options;
        _isLoadingUsers = false;
        _selectedUserIds = _selectedUserIds
            .where((id) => options.any((option) => option.id == id))
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingUsers = false;
        _usersError = AppErrorHandler.friendlyMessage(error);
        _userOptions = const <_SelectionOption>[];
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final dateText = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final selectedRoles = List<String>.from(_selectedRoleIds);
    final selectedUsers = List<String>.from(_selectedUserIds);

    if (name.isEmpty) {
      _showSnackBar('Holiday name is required.');
      return;
    }
    if (selectedRoles.isEmpty && selectedUsers.isEmpty) {
      _showSnackBar('Select at least one role or user.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = widget.isEditMode
          ? await _authProvider.updateHoliday(
              id: _holidayId ?? '',
              date: dateText,
              name: name,
              description: description,
              roles: selectedRoles,
              userIds: selectedUsers,
              token: _authProvider.currentAuthToken,
            )
          : await _authProvider.createHoliday(
              date: dateText,
              name: name,
              description: description,
              roles: selectedRoles,
              userIds: selectedUsers,
              token: _authProvider.currentAuthToken,
            );
      if (!mounted) return;
      Navigator.of(context).pop(payload);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSelectionSheet({
    required String title,
    required String subtitle,
    required List<_SelectionOption> options,
    required List<String> selectedIds,
    required bool allowSearch,
    required bool isRoleSelection,
    String? exclusiveValue,
  }) async {
    final searchController = TextEditingController();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var query = '';
        final currentSelection = List<String>.from(selectedIds);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredOptions = _filterOptions(options, query);
            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD0D5DD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (allowSearch) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD0D5DD)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD0D5DD)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredOptions.isEmpty
                            ? const Center(
                                child: Text(
                                  'No options available.',
                                  style: TextStyle(
                                    color: Color(0xFF667085),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredOptions.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final option = filteredOptions[index];
                                  final isSelected =
                                      currentSelection.contains(option.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: AppColors.primary,
                                    title: Text(
                                      option.label,
                                      style: const TextStyle(
                                        color: Color(0xFF101828),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          if (exclusiveValue != null &&
                                              option.id == exclusiveValue) {
                                            currentSelection
                                              ..clear()
                                              ..add(option.id);
                                          } else {
                                            currentSelection
                                                .remove(exclusiveValue);
                                            if (!currentSelection
                                                .contains(option.id)) {
                                              currentSelection.add(option.id);
                                            }
                                          }
                                        } else {
                                          currentSelection.remove(option.id);
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
                                foregroundColor: const Color(0xFF344054),
                                side:
                                    const BorderSide(color: Color(0xFFD0D5DD)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(sheetContext)
                                  .pop(currentSelection),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
    searchController.dispose();

    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (exclusiveValue != null && result.contains(exclusiveValue)) {
        _selectedRoleIds = <String>[exclusiveValue];
      } else {
        if (exclusiveValue != null) {
          result.remove(exclusiveValue);
        }
        if (isRoleSelection) {
          _selectedRoleIds = result;
        } else {
          _selectedUserIds = result;
        }
      }
    });
  }

  List<_SelectionOption> _filterOptions(
    List<_SelectionOption> options,
    String query,
  ) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return options;
    return options
        .where((option) => option.label.toLowerCase().contains(lower))
        .toList(growable: false);
  }

  Future<void> _openRolePicker() async {
    await _openSelectionSheet(
      title: 'Apply to Roles',
      subtitle: 'Choose one or more roles, or All Roles for company-wide.',
      options: _roleOptions,
      selectedIds: _selectedRoleIds,
      allowSearch: true,
      isRoleSelection: true,
      exclusiveValue: 'all',
    );
  }

  Future<void> _openUserPicker() async {
    await _openSelectionSheet(
      title: 'Specific Users',
      subtitle: 'Choose individual employees that should receive this holiday.',
      options: _userOptions,
      selectedIds: _selectedUserIds,
      allowSearch: true,
      isRoleSelection: false,
    );
  }

  String _selectionSummary(
    List<String> selectedIds,
    List<_SelectionOption> options, {
    String emptyLabel = 'Select options',
  }) {
    if (selectedIds.isEmpty) return emptyLabel;
    final labels = <String>[
      for (final id in selectedIds)
        options
            .firstWhere(
              (option) => option.id == id,
              orElse: () => _SelectionOption(id: id, label: id),
            )
            .label,
    ];
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return labels.join(', ');
    return '${labels.take(2).join(', ')} +${labels.length - 2} more';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? 'Edit Holiday' : 'Create Holiday';
    final wideLayout = MediaQuery.of(context).size.width >= 760;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF101828),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF667085),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.isEditMode)
                        const Text(
                          'Update the holiday name, date, roles, or specific users.',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        const Text(
                          'Create a company or team holiday and target roles or users.',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (wideLayout)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDateField()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildNameField()),
                          ],
                        )
                      else ...[
                        _buildDateField(),
                        const SizedBox(height: 12),
                        _buildNameField(),
                      ],
                      const SizedBox(height: 12),
                      _buildDescriptionField(),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(
                        label: 'Apply to Roles',
                        helperText: _rolesError ??
                            (_isLoadingRoles
                                ? 'Loading roles...'
                                : 'Select one or more roles, or choose All Roles.'),
                        value: _selectionSummary(
                          _selectedRoleIds,
                          _roleOptions,
                          emptyLabel: 'Select roles, or All Roles',
                        ),
                        onTap: _isLoadingRoles ? null : _openRolePicker,
                      ),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(
                        label: 'Also apply to specific users',
                        helperText: _usersError ??
                            (_isLoadingUsers
                                ? 'Loading users...'
                                : 'Search and select individual employees.'),
                        value: _selectionSummary(
                          _selectedUserIds,
                          _userOptions,
                          emptyLabel: 'Search and select users',
                        ),
                        onTap: _isLoadingUsers ? null : _openUserPicker,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'At least one role or one specific user is required. If All Roles is selected, the holiday applies company-wide.',
                          style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF344054),
                                side:
                                    const BorderSide(color: Color(0xFFD0D5DD)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _isSubmitting
                                    ? 'Saving...'
                                    : (widget.isEditMode
                                        ? 'Update Holiday'
                                        : 'Create Holiday'),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return _HolidayInputShell(
      label: 'Date *',
      child: InkWell(
        onTap: _isSubmitting ? null : _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8E0EA)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd-MM-yyyy').format(_selectedDate),
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF667085), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return _HolidayInputShell(
      label: 'Name *',
      child: TextField(
        controller: _nameController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: 'e.g. Diwali',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _HolidayInputShell(
      label: 'Description (optional)',
      child: TextField(
        controller: _descriptionController,
        minLines: 3,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'e.g. Festival of Lights - company holiday',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required String value,
    required String helperText,
    required VoidCallback? onTap,
  }) {
    return _HolidayInputShell(
      label: label,
      helperText: helperText,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8E0EA)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value.toLowerCase().contains('select')
                        ? const Color(0xFF98A2B3)
                        : const Color(0xFF101828),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF667085)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HolidayInputShell extends StatelessWidget {
  const _HolidayInputShell({
    required this.label,
    required this.child,
    this.helperText,
  });

  final String label;
  final Widget child;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475467),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (helperText != null && helperText!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionOption {
  const _SelectionOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

_SelectionOption? _roleFromApi(Map<String, dynamic> role) {
  final id = _readStringFromMap(
    role,
    const ['role', 'value', 'slug', 'name'],
    fallback: '',
  ).trim();
  if (id.isEmpty) return null;
  final label = _readStringFromMap(
    role,
    const ['label', 'display_name', 'displayName', 'name', 'role', 'value'],
    fallback: '',
  );
  return _SelectionOption(
    id: RoleAccess.normalize(id),
    label: label.isEmpty ? RoleAccess.label(id) : _formatRoleLabel(label),
  );
}

_SelectionOption? _userFromApi(Map<String, dynamic> user) {
  final id = _readStringFromMap(
    user,
    const ['id', 'user_id', 'userId', 'uuid'],
    fallback: '',
  ).trim();
  if (id.isEmpty) return null;
  final firstName = _readStringFromMap(
    user,
    const ['first_name', 'firstName'],
    fallback: '',
  );
  final lastName = _readStringFromMap(
    user,
    const ['last_name', 'lastName'],
    fallback: '',
  );
  final fullName = _readStringFromMap(
    user,
    const ['full_name', 'fullName', 'name'],
    fallback: '',
  );
  final role = _readStringFromMap(
    user,
    const ['role', 'designation', 'title'],
    fallback: '',
  );
  final name = fullName.isNotEmpty
      ? fullName
      : '${firstName.trim()} ${lastName.trim()}'.trim();
  if (name.isEmpty) return null;
  return _SelectionOption(
    id: id,
    label: role.isEmpty ? name : '$name (${_formatRoleLabel(role)})',
  );
}

List<String> _extractHolidaySelectionList(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty && entry.toLowerCase() != 'null')
          .toList(growable: false);
    }
  }
  return const <String>[];
}

String _normalizeRoleId(String value) {
  final normalized = RoleAccess.normalize(value);
  if (normalized == 'all_roles' ||
      normalized == 'allrole' ||
      normalized == 'all' ||
      normalized == 'all_roles_') {
    return 'all';
  }
  return normalized;
}

String _readStringFromMap(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num || value is bool) return value.toString();
    if (value is Map<String, dynamic>) {
      final nested = _readStringFromMap(
        value,
        const ['name', 'label', 'title', 'value', 'id'],
        fallback: '',
      );
      if (nested.isNotEmpty) return nested;
    }
  }
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is! String || value.trim().isEmpty) return null;
  final normalized = value.trim();
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed.toLocal();
  final formats = <DateFormat>[
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd MMM yyyy'),
  ];
  for (final format in formats) {
    try {
      return format.parseStrict(normalized).toLocal();
    } catch (_) {
      // continue
    }
  }
  return null;
}

String _formatRoleLabel(String value) {
  final normalized = RoleAccess.normalize(value);
  if (normalized.isEmpty) return '';
  return normalized
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
