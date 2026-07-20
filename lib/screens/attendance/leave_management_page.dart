import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:nextone/widgets/pagination_widget.dart';

class LeaveManagementPage extends StatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  State<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends State<LeaveManagementPage> {
  static const int _todayTab = 0;
  static const int _allTab = 1;
  static const int _adminPageSize = 10;
  static const int _userPageSize = 30;
  static const List<_LeaveTypeOption> _adminFilterLeaveTypes =
      <_LeaveTypeOption>[
    _LeaveTypeOption(value: '', label: 'All Types'),
    _LeaveTypeOption(value: 'full_day', label: 'Full Day'),
    _LeaveTypeOption(value: 'half_day', label: 'Half Day'),
    _LeaveTypeOption(value: 'sick_leave', label: 'Sick Leave'),
    _LeaveTypeOption(value: 'casual_leave', label: 'Casual Leave'),
    _LeaveTypeOption(value: 'unpaid_leave', label: 'Unpaid Leave'),
  ];
  static const List<_LeaveTypeOption> _applyLeaveTypes = <_LeaveTypeOption>[
    _LeaveTypeOption(value: 'full_day', label: 'Full Day'),
    _LeaveTypeOption(value: 'half_day', label: 'Half Day'),
    _LeaveTypeOption(value: 'sick_leave', label: 'Sick Leave'),
    _LeaveTypeOption(value: 'casual_leave', label: 'Casual Leave'),
    _LeaveTypeOption(value: 'unpaid_leave', label: 'Unpaid Leave'),
  ];

  final AuthProvider _authProvider = AuthProvider();

  String _currentRole = '';
  bool _isLoadingScreen = true;

  String _currentUserId = '';

  bool _isLoadingUsers = false;
  List<_UserOption> _users = const <_UserOption>[];

  int _selectedTab = _todayTab;
  bool _isLoadingToday = false;
  String? _todayError;
  List<_LeaveRecord> _todayLeaves = const <_LeaveRecord>[];

  bool _isLoadingAll = false;
  String? _allError;
  List<_LeaveRecord> _allLeaves = const <_LeaveRecord>[];
  int _allCurrentPage = 1;
  int _allTotalPages = 1;
  int _allTotalItems = 0;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedUserId = '';
  String _selectedLeaveType = '';

  bool _isLoadingMyLeaves = false;
  String? _myLeavesError;
  List<_LeaveRecord> _myLeaves = const <_LeaveRecord>[];
  int _myCurrentPage = 1;
  int _myTotalPages = 1;
  int _myTotalItems = 0;

  bool get _isAdminView => RoleAccess.isAdminOrSuperAdmin(_currentRole);

  @override
  void initState() {
    super.initState();
    _loadScreen();
  }

  Future<void> _loadScreen() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      final profile = await _authProvider.profile(
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }

      final data = profile.data;
      setState(() {
        _currentRole = role;
        _currentUserId = _readString(
          data,
          const ['id', 'user_id', 'userId', 'uuid'],
        );
        _isLoadingScreen = false;
      });

      if (_isAdminView) {
        await _loadUsers();
        await Future.wait(<Future<void>>[
          _loadTodayLeaves(),
          _loadAllLeaves(),
        ]);
      } else {
        await _loadMyLeaves();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingScreen = false;
        _myLeavesError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      final rows =
          await _authProvider.users(token: _authProvider.currentAuthToken);
      final users = rows
          .map(_userOptionFromMap)
          .whereType<_UserOption>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _loadTodayLeaves() async {
    setState(() {
      _isLoadingToday = true;
      _todayError = null;
    });
    try {
      final data = await _authProvider.attendanceLeavesToday(
        token: _authProvider.currentAuthToken,
      );
      final rows = _extractLeaveRows(data).map(_LeaveRecord.fromMap).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _todayLeaves = rows;
        _isLoadingToday = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _todayLeaves = const <_LeaveRecord>[];
        _todayError = AppErrorHandler.friendlyMessage(error);
        _isLoadingToday = false;
      });
    }
  }

  Future<void> _loadAllLeaves({int? page}) async {
    final nextPage = page ?? _allCurrentPage;
    setState(() {
      _isLoadingAll = true;
      _allError = null;
    });
    try {
      final data = await _authProvider.attendanceLeaves(
        token: _authProvider.currentAuthToken,
        page: nextPage,
        perPage: _adminPageSize,
        from: _fromDate == null ? null : _formatApiDate(_fromDate!),
        to: _toDate == null ? null : _formatApiDate(_toDate!),
        userId: _selectedUserId.isEmpty ? null : _selectedUserId,
        leaveType: _selectedLeaveType.isEmpty ? null : _selectedLeaveType,
      );
      final rows = _extractLeaveRows(data).map(_LeaveRecord.fromMap).toList();
      final pagination = _extractPaginationMap(data);
      if (!mounted) {
        return;
      }
      setState(() {
        _allLeaves = rows;
        _allCurrentPage = _resolveCurrentPage(
          pagination,
          fallback: nextPage,
        );
        _allTotalItems = _resolveTotalItems(pagination, fallback: rows.length);
        _allTotalPages = _resolveTotalPages(
          pagination,
          totalItems: _allTotalItems,
          perPage: _resolvePerPage(pagination, fallback: _adminPageSize),
        );
        _isLoadingAll = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allLeaves = const <_LeaveRecord>[];
        _allError = AppErrorHandler.friendlyMessage(error);
        _isLoadingAll = false;
      });
    }
  }

  Future<void> _loadMyLeaves({int? page}) async {
    final nextPage = page ?? _myCurrentPage;
    if (_currentUserId.trim().isEmpty) {
      setState(() {
        _myLeaves = const <_LeaveRecord>[];
        _myLeavesError = 'Unable to resolve current user.';
      });
      return;
    }

    setState(() {
      _isLoadingMyLeaves = true;
      _myLeavesError = null;
    });
    try {
      final data = await _authProvider.attendanceLeaves(
        token: _authProvider.currentAuthToken,
        userId: _currentUserId,
        page: nextPage,
        perPage: _userPageSize,
      );
      final rows = _extractLeaveRows(data).map(_LeaveRecord.fromMap).toList();
      final pagination = _extractPaginationMap(data);
      if (!mounted) {
        return;
      }
      setState(() {
        _myLeaves = rows;
        _myCurrentPage = _resolveCurrentPage(
          pagination,
          fallback: nextPage,
        );
        _myTotalItems = _resolveTotalItems(pagination, fallback: rows.length);
        _myTotalPages = _resolveTotalPages(
          pagination,
          totalItems: _myTotalItems,
          perPage: _resolvePerPage(pagination, fallback: _userPageSize),
        );
        _isLoadingMyLeaves = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _myLeaves = const <_LeaveRecord>[];
        _myLeavesError = AppErrorHandler.friendlyMessage(error);
        _isLoadingMyLeaves = false;
      });
    }
  }

  _UserOption? _userOptionFromMap(Map<String, dynamic> raw) {
    final id = _readString(raw, const ['id', 'user_id', 'userId', 'uuid']);
    if (id.isEmpty) {
      return null;
    }
    final firstName = _readString(raw, const ['first_name', 'firstName']);
    final lastName = _readString(raw, const ['last_name', 'lastName']);
    final combined = [firstName, lastName]
        .where((item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
    final name = combined.isNotEmpty
        ? combined
        : _readString(raw, const ['name', 'full_name', 'fullName', 'email']);
    return _UserOption(
      id: id,
      name: name.isEmpty ? 'User $id' : name,
      email: _readString(raw, const ['email']),
    );
  }

  List<Map<String, dynamic>> _extractLeaveRows(Map<String, dynamic> source) {
    final candidates = <dynamic>[
      source['data'],
      source['items'],
      source['rows'],
      source['leaves'],
      source['results'],
      source['records'],
      source,
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (candidate is Map<String, dynamic>) {
        final nested = candidate['data'] ??
            candidate['items'] ??
            candidate['rows'] ??
            candidate['leaves'];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractPaginationMap(Map<String, dynamic> source) {
    final raw =
        source['pagination'] ?? source['meta'] ?? source['page'] ?? source;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return source;
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  int _resolveCurrentPage(Map<String, dynamic> source,
      {required int fallback}) {
    final value =
        _readInt(source, const ['page', 'current_page', 'currentPage']);
    if (value == null || value <= 0) {
      return fallback <= 0 ? 1 : fallback;
    }
    return value;
  }

  int _resolvePerPage(Map<String, dynamic> source, {required int fallback}) {
    final value = _readInt(source, const ['per_page', 'perPage', 'limit']);
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }

  int _resolveTotalItems(Map<String, dynamic> source, {required int fallback}) {
    final value =
        _readInt(source, const ['total', 'total_items', 'totalItems', 'count']);
    return value == null || value < 0 ? fallback : value;
  }

  int _resolveTotalPages(
    Map<String, dynamic> source, {
    required int totalItems,
    required int perPage,
  }) {
    final direct = _readInt(
      source,
      const ['total_pages', 'totalPages', 'last_page', 'lastPage'],
    );
    if (direct != null && direct > 0) {
      return direct;
    }
    if (perPage <= 0) {
      return 1;
    }
    final pages = ((totalItems + perPage - 1) / perPage).floor();
    return pages <= 0 ? 1 : pages;
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _formatApiDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatDisplayDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      return normalized;
    }
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatDatePlaceholder(DateTime? value) {
    if (value == null) {
      return 'Select date';
    }
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _formatLeaveType(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'full_day':
        return 'Full Day';
      case 'half_day':
        return 'Half Day';
      case 'sick_leave':
        return 'Sick Leave';
      case 'casual_leave':
        return 'Casual Leave';
      case 'unpaid_leave':
        return 'Unpaid Leave';
      default:
        if (normalized.isEmpty) {
          return 'Unknown';
        }
        return normalized
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  Future<void> _pickFilterDate({
    required DateTime? initialValue,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialValue ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    });
    await _loadAllLeaves(page: 1);
  }

  Future<void> _openApplyLeaveDialog() async {
    final didApply = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApplyLeaveDialog(
        leaveTypes: _applyLeaveTypes,
        onSubmit: ({
          required DateTime date,
          required String leaveType,
          required String reason,
        }) async {
          await _authProvider.applyAttendanceLeave(
            date: _formatApiDate(date),
            leaveType: leaveType,
            reason: reason,
            token: _authProvider.currentAuthToken,
          );
        },
      ),
    );
    if (didApply == true) {
      await _loadMyLeaves(page: 1);
      if (!mounted) {
        return;
      }
      _showSnackBar('Leave applied successfully.');
    }
  }

  Future<void> _openMarkLeaveDialog() async {
    if (_isLoadingUsers || _users.isEmpty) {
      _showSnackBar('Users are still loading. Please try again.');
      return;
    }
    final didCreate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MarkLeaveDialog(
        users: _users,
        leaveTypes: _applyLeaveTypes,
        onSubmit: ({
          required String userId,
          required DateTime date,
          required String leaveType,
          required String reason,
        }) async {
          await _authProvider.markAttendanceLeave(
            userId: userId,
            date: _formatApiDate(date),
            leaveType: leaveType,
            reason: reason,
            token: _authProvider.currentAuthToken,
          );
        },
      ),
    );
    if (didCreate == true) {
      await Future.wait(<Future<void>>[
        _loadTodayLeaves(),
        _loadAllLeaves(page: _allCurrentPage),
      ]);
      if (!mounted) {
        return;
      }
      _showSnackBar('Leave marked successfully.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingScreen) {
      return const Scaffold(
        appBar: CrmAppBar(title: 'Leave Management'),
        backgroundColor: Color(0xFFF4F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CrmAppBar(title: 'Leave Management'),
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_isAdminView) {
              await Future.wait(<Future<void>>[
                _loadTodayLeaves(),
                _loadAllLeaves(page: _allCurrentPage),
              ]);
            } else {
              await _loadMyLeaves(page: _myCurrentPage);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                if (_isAdminView) ...[
                  _buildAdminTabs(),
                  const SizedBox(height: 18),
                  if (_selectedTab == _allTab) ...[
                    _buildAdminFilters(),
                    const SizedBox(height: 18),
                  ],
                  _buildAdminLeaveSection(),
                ] else
                  _buildUserLeaveSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final button = FilledButton.icon(
          onPressed:
              _isAdminView ? _openMarkLeaveDialog : _openApplyLeaveDialog,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            _isAdminView ? 'Mark Leave' : 'Apply Leave',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );

        final titleBlock = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Management',
              style: TextStyle(
                color: Color(0xFF071A3A),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Apply and track leaves',
              style: TextStyle(
                color: Color(0xFF5D6B82),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: button),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            button,
          ],
        );
      },
    );
  }

  Widget _buildAdminTabs() {
    return Row(
      children: [
        _LeaveTabChip(
          label: "Today's Leaves",
          isActive: _selectedTab == _todayTab,
          onTap: () {
            setState(() {
              _selectedTab = _todayTab;
            });
          },
        ),
        const SizedBox(width: 10),
        _LeaveTabChip(
          label: 'All Leaves',
          isActive: _selectedTab == _allTab,
          onTap: () {
            setState(() {
              _selectedTab = _allTab;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdminFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final fields = <Widget>[
          _buildDateFilterField(
            label: 'From',
            value: _fromDate,
            onTap: () => _pickFilterDate(
              initialValue: _fromDate,
              onChanged: (value) => _fromDate = value,
            ),
          ),
          _buildDateFilterField(
            label: 'To',
            value: _toDate,
            onTap: () => _pickFilterDate(
              initialValue: _toDate,
              onChanged: (value) => _toDate = value,
            ),
          ),
          _buildDropdownFilterField<String>(
            label: 'User',
            value: _selectedUserId,
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All Users'),
              ),
              ..._users.map(
                (user) => DropdownMenuItem<String>(
                  value: user.id,
                  child: Text(user.name),
                ),
              ),
            ],
            onChanged: (value) async {
              setState(() {
                _selectedUserId = value ?? '';
              });
              await _loadAllLeaves(page: 1);
            },
          ),
          _buildDropdownFilterField<String>(
            label: 'Leave Type',
            value: _selectedLeaveType,
            items: _adminFilterLeaveTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type.value,
                    child: Text(type.label),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              setState(() {
                _selectedLeaveType = value ?? '';
              });
              await _loadAllLeaves(page: 1);
            },
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDateFilterField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: _fieldDecoration(),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF98A4B4),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDatePlaceholder(value),
                  style: TextStyle(
                    color: value == null
                        ? const Color(0xFF98A4B4)
                        : const Color(0xFF344054),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilterField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: _fieldDecoration(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildAdminLeaveSection() {
    final title = _selectedTab == _todayTab ? "Today's Leaves" : 'All Leaves';
    final isLoading =
        _selectedTab == _todayTab ? _isLoadingToday : _isLoadingAll;
    final error = _selectedTab == _todayTab ? _todayError : _allError;
    final leaves = _selectedTab == _todayTab ? _todayLeaves : _allLeaves;

    return _buildLeaveCard(
      title: title,
      isLoading: isLoading,
      error: error,
      leaves: leaves,
      emptyTitle: _selectedTab == _todayTab
          ? 'No leaves found for Saturday, July 18, 2026.'
          : 'No leave records matched the current filters.',
      onRetry: _selectedTab == _todayTab
          ? _loadTodayLeaves
          : () => _loadAllLeaves(page: _allCurrentPage),
      pagination: _selectedTab == _allTab && _allTotalPages > 1
          ? PaginationWidget(
              currentPage: _allCurrentPage,
              totalPages: _allTotalPages,
              totalItems: _allTotalItems,
              itemLabel: 'leaves',
              onPageChanged: (page) => _loadAllLeaves(page: page),
            )
          : null,
    );
  }

  Widget _buildUserLeaveSection() {
    return _buildLeaveCard(
      title: 'My Leaves',
      isLoading: _isLoadingMyLeaves,
      error: _myLeavesError,
      leaves: _myLeaves,
      emptyTitle: 'No leave records found yet.',
      onRetry: () => _loadMyLeaves(page: _myCurrentPage),
      pagination: _myTotalPages > 1
          ? PaginationWidget(
              currentPage: _myCurrentPage,
              totalPages: _myTotalPages,
              totalItems: _myTotalItems,
              itemLabel: 'leaves',
              onPageChanged: (page) => _loadMyLeaves(page: page),
            )
          : null,
    );
  }

  Widget _buildLeaveCard({
    required String title,
    required bool isLoading,
    required String? error,
    required List<_LeaveRecord> leaves,
    required String emptyTitle,
    required VoidCallback onRetry,
    Widget? pagination,
  }) {
    return DataCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF071A3A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE6EBF2)),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (leaves.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.event_busy_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              itemCount: leaves.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE6EBF2)),
              itemBuilder: (context, index) => _LeaveRecordTile(
                record: leaves[index],
                formatDate: _formatDisplayDate,
                formatLeaveType: _formatLeaveType,
              ),
            ),
            if (pagination != null) ...[
              const Divider(height: 1, color: Color(0xFFE6EBF2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: pagination,
              ),
            ],
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: true,
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
    );
  }
}

class _LeaveRecordTile extends StatelessWidget {
  const _LeaveRecordTile({
    required this.record,
    required this.formatDate,
    required this.formatLeaveType,
  });

  final _LeaveRecord record;
  final String Function(String raw) formatDate;
  final String Function(String raw) formatLeaveType;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF0E9F6E);
      case 'rejected':
      case 'declined':
        return const Color(0xFFDC2626);
      case 'pending':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF475467);
    }
  }

  Color _statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFDFF8E8);
      case 'rejected':
      case 'declined':
        return const Color(0xFFFEE2E2);
      case 'pending':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      record.name,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _MetaChip(
                      text: formatLeaveType(record.leaveType),
                      backgroundColor: const Color(0xFFDDE4FF),
                      textColor: const Color(0xFF4F46E5),
                    ),
                    _MetaChip(
                      text: record.statusLabel,
                      backgroundColor: _statusBackground(record.statusLabel),
                      textColor: _statusColor(record.statusLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatDate(record.date),
                style: const TextStyle(
                  color: Color(0xFF071A3A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InlineInfo(
                icon: Icons.email_outlined,
                color: const Color(0xFF7C3AED),
                text: record.email.isEmpty ? '-' : record.email,
              ),
              _InlineInfo(
                icon: Icons.call_outlined,
                color: const Color(0xFFE11D48),
                text: record.phone.isEmpty ? '-' : record.phone,
              ),
              _InlineInfo(
                icon: Icons.person_outline,
                color: const Color(0xFF5B3F99),
                text: record.role.isEmpty ? '-' : record.role,
              ),
            ],
          ),
          if (record.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFC7D2FE), width: 2),
                ),
              ),
              child: Text(
                record.reason,
                style: const TextStyle(
                  color: Color(0xFF344054),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF5D6B82),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LeaveTabChip extends StatelessWidget {
  const _LeaveTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFFE2E8F0) : Colors.transparent,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primary : const Color(0xFF5D6B82),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MarkLeaveDialog extends StatefulWidget {
  const _MarkLeaveDialog({
    required this.users,
    required this.leaveTypes,
    required this.onSubmit,
  });

  final List<_UserOption> users;
  final List<_LeaveTypeOption> leaveTypes;
  final Future<void> Function({
    required String userId,
    required DateTime date,
    required String leaveType,
    required String reason,
  }) onSubmit;

  @override
  State<_MarkLeaveDialog> createState() => _MarkLeaveDialogState();
}

class _MarkLeaveDialogState extends State<_MarkLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late DateTime _selectedDate;
  String? _selectedUserId;
  String _selectedLeaveType = 'full_day';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if ((_selectedUserId ?? '').trim().isEmpty) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.onSubmit(
        userId: _selectedUserId!.trim(),
        date: _selectedDate,
        leaveType: _selectedLeaveType,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppErrorHandler.friendlyMessage(error))),
        );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LeaveDialogShell(
      title: 'Mark Leave for User',
      isSubmitting: _isSubmitting,
      onClose: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DialogLabel('User'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserId,
              items: widget.users
                  .map(
                    (user) => DropdownMenuItem<String>(
                      value: user.id,
                      child: Text(user.name),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedUserId = value),
              decoration: _dialogDecoration(hintText: 'Select user'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'User is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Date'),
            const SizedBox(height: 8),
            _DialogDateField(
              date: _selectedDate,
              onTap: _isSubmitting ? null : _pickDate,
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Leave Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedLeaveType,
              items: widget.leaveTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type.value,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) =>
                      setState(() => _selectedLeaveType = value ?? 'full_day'),
              decoration: _dialogDecoration(),
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Reason'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              enabled: !_isSubmitting,
              maxLines: 4,
              decoration: _dialogDecoration(hintText: 'Reason for leave'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Reason is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            _DialogActions(
              isSubmitting: _isSubmitting,
              primaryLabel: 'Mark Leave',
              onCancel: () => Navigator.of(context).pop(),
              onPrimary: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyLeaveDialog extends StatefulWidget {
  const _ApplyLeaveDialog({
    required this.leaveTypes,
    required this.onSubmit,
  });

  final List<_LeaveTypeOption> leaveTypes;
  final Future<void> Function({
    required DateTime date,
    required String leaveType,
    required String reason,
  }) onSubmit;

  @override
  State<_ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<_ApplyLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late DateTime _selectedDate;
  String _selectedLeaveType = 'full_day';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.onSubmit(
        date: _selectedDate,
        leaveType: _selectedLeaveType,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppErrorHandler.friendlyMessage(error))),
        );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LeaveDialogShell(
      title: 'Apply for Leave',
      isSubmitting: _isSubmitting,
      onClose: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DialogLabel('Date'),
            const SizedBox(height: 8),
            _DialogDateField(
              date: _selectedDate,
              onTap: _isSubmitting ? null : _pickDate,
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Leave Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedLeaveType,
              items: widget.leaveTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type.value,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) =>
                      setState(() => _selectedLeaveType = value ?? 'full_day'),
              decoration: _dialogDecoration(),
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Reason'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              enabled: !_isSubmitting,
              maxLines: 4,
              decoration: _dialogDecoration(hintText: 'Reason for leave'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Reason is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            _DialogActions(
              isSubmitting: _isSubmitting,
              primaryLabel: 'Apply',
              onCancel: () => Navigator.of(context).pop(),
              onPrimary: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveDialogShell extends StatelessWidget {
  const _LeaveDialogShell({
    required this.title,
    required this.isSubmitting,
    required this.onClose,
    required this.child,
  });

  final String title;
  final bool isSubmitting;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                    onPressed: isSubmitting ? null : onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE6EBF2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogDateField extends StatelessWidget {
  const _DialogDateField({
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _dialogDecoration(),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF98A4B4),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('dd MMM yyyy').format(date),
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.isSubmitting,
    required this.primaryLabel,
    required this.onCancel,
    required this.onPrimary,
  });

  final bool isSubmitting;
  final String primaryLabel;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting ? null : onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: Color(0xFFDCE3ED)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              foregroundColor: const Color(0xFF344054),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: isSubmitting ? null : onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF667085),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

InputDecoration _dialogDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF98A4B4),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    isDense: true,
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

class _LeaveRecord {
  const _LeaveRecord({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.reason,
    required this.date,
    required this.leaveType,
    required this.statusLabel,
  });

  final String name;
  final String email;
  final String phone;
  final String role;
  final String reason;
  final String date;
  final String leaveType;
  final String statusLabel;

  factory _LeaveRecord.fromMap(Map<String, dynamic> raw) {
    String readValue(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value is num || value is bool) {
          return value.toString().trim();
        }
      }
      return '';
    }

    Map<String, dynamic> nestedUser() {
      final dynamic value = raw['user'] ?? raw['employee'] ?? raw['member'];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return const <String, dynamic>{};
    }

    final user = nestedUser();
    final firstName = readValue(user, const ['first_name', 'firstName']);
    final lastName = readValue(user, const ['last_name', 'lastName']);
    final combinedName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
    final rawStatus = readValue(
      raw,
      const ['status', 'approval_status', 'approvalStatus'],
    );

    return _LeaveRecord(
      name: readValue(raw, const ['name', 'user_name', 'userName']).isNotEmpty
          ? readValue(raw, const ['name', 'user_name', 'userName'])
          : (combinedName.isNotEmpty
              ? combinedName
              : readValue(
                  user,
                  const ['name', 'full_name', 'fullName', 'email'],
                )),
      email: readValue(raw, const ['email']).isNotEmpty
          ? readValue(raw, const ['email'])
          : readValue(user, const ['email']),
      phone:
          readValue(raw, const ['phone', 'mobile', 'phone_number']).isNotEmpty
              ? readValue(raw, const ['phone', 'mobile', 'phone_number'])
              : readValue(user, const ['phone', 'mobile', 'phone_number']),
      role: readValue(raw, const ['role', 'designation']).isNotEmpty
          ? readValue(raw, const ['role', 'designation'])
          : RoleAccess.label(readValue(user, const ['role', 'designation'])),
      reason: readValue(raw, const ['reason', 'remarks', 'comment']),
      date: readValue(
          raw, const ['date', 'leave_date', 'leaveDate', 'created_at']),
      leaveType: readValue(raw, const ['leave_type', 'leaveType']),
      statusLabel: rawStatus.isEmpty
          ? 'Pending'
          : rawStatus
              .split('_')
              .where((part) => part.isNotEmpty)
              .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
              .join(' '),
    );
  }
}

class _UserOption {
  const _UserOption({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

class _LeaveTypeOption {
  const _LeaveTypeOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}
