import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/widgets/pagination_widget.dart';

class AttendanceUserHistoryPage extends StatefulWidget {
  const AttendanceUserHistoryPage({
    super.key,
    required this.userId,
    required this.initialName,
    required this.initialRole,
    required this.initialFrom,
    required this.initialTo,
  });

  final String userId;
  final String initialName;
  final String initialRole;
  final DateTime initialFrom;
  final DateTime initialTo;

  @override
  State<AttendanceUserHistoryPage> createState() =>
      _AttendanceUserHistoryPageState();
}

class _AttendanceUserHistoryPageState extends State<AttendanceUserHistoryPage> {
  final AuthProvider _authProvider = AuthProvider();

  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _response = <String, dynamic>{};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(
      widget.initialFrom.year,
      widget.initialFrom.month,
      widget.initialFrom.day,
    );
    _toDate = DateTime(
      widget.initialTo.year,
      widget.initialTo.month,
      widget.initialTo.day,
    );
    _loadHistory();
  }

  Future<void> _loadHistory({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _authProvider.attendanceUserHistory(
        userId: widget.userId,
        from: _formatDateForApi(_fromDate),
        to: _formatDateForApi(_toDate),
        page: page,
        perPage: 20,
        token: _authProvider.currentAuthToken,
      );

      final pagination = _paginationMap(data);
      if (!mounted) return;
      setState(() {
        _response = data;
        _currentPage = _readInt(
          pagination['page'] ?? pagination['current_page'],
          fallback: page,
        );
        _totalPages = _readInt(
          pagination['total_pages'] ?? pagination['last_page'],
          fallback: 1,
        );
        _totalItems = _readInt(
          pagination['total'] ?? pagination['total_items'],
          fallback: _historyEntries().length,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.friendlyMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = DateTime(picked.year, picked.month, picked.day);
      if (_toDate.isBefore(_fromDate)) {
        _toDate = _fromDate;
      }
    });
    _loadHistory();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _toDate = DateTime(picked.year, picked.month, picked.day);
      if (_toDate.isBefore(_fromDate)) {
        _fromDate = _toDate;
      }
    });
    _loadHistory();
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _displayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }

  Map<String, dynamic> _userMap() {
    final direct = _response['user'];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) {
      return Map<String, dynamic>.from(
        direct.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    final data = _response['data'];
    if (data is Map) {
      final nested = data['user'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) {
        return Map<String, dynamic>.from(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _summaryMap() {
    final direct = _response['summary'];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) {
      return Map<String, dynamic>.from(
        direct.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    final data = _response['data'];
    if (data is Map) {
      final nested = data['summary'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) {
        return Map<String, dynamic>.from(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _paginationMap(Map<String, dynamic> source) {
    final direct = source['pagination'];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) {
      return Map<String, dynamic>.from(
        direct.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    final meta = source['meta'];
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) {
      return Map<String, dynamic>.from(
        meta.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    final data = source['data'];
    if (data is Map) {
      final nested = data['pagination'] ?? data['meta'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) {
        return Map<String, dynamic>.from(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _historyRows() {
    dynamic rowsRaw = _response['data'];
    if (rowsRaw is Map) {
      rowsRaw = rowsRaw['data'] ??
          rowsRaw['items'] ??
          rowsRaw['records'] ??
          rowsRaw['attendance'] ??
          rowsRaw['attendances'];
    }
    rowsRaw ??= _response['items'] ??
        _response['records'] ??
        _response['attendance'] ??
        _response['attendances'];

    if (rowsRaw is! List) return const <Map<String, dynamic>>[];
    return rowsRaw
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  List<_AttendanceHistoryEntry> _historyEntries() {
    final rows = _historyRows();
    final entries = rows
        .map(_mapHistoryEntry)
        .whereType<_AttendanceHistoryEntry>()
        .toList(growable: false);
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<_AttendanceHistoryEntry> _filteredHistoryEntries() {
    final entries = _historyEntries();
    final selected = _selectedStatusFilter;
    if (selected == null || selected.isEmpty) {
      return entries;
    }
    return entries
        .where((entry) => entry.status.toLowerCase() == selected)
        .toList(growable: false);
  }

  _AttendanceHistoryEntry? _mapHistoryEntry(Map<String, dynamic> row) {
    final date = _parseApiDate(
      _readString(
        row,
        const [
          'date',
          'attendance_date',
          'attendanceDate',
          'created_at',
          'createdAt',
        ],
      ),
    );
    if (date == null) return null;

    final status = _normalizeStatus(
      _readString(
          row, const ['status', 'attendance_status', 'attendanceStatus']),
    );

    return _AttendanceHistoryEntry(
      date: DateTime(date.year, date.month, date.day),
      status: status,
      checkIn: _formatTime(
        _readString(
          row,
          const [
            'check_in_time',
            'checkInTime',
            'check_in',
            'checkIn',
            'check_in_at',
          ],
          fallback: '--:--',
        ),
      ),
      checkOut: _formatTime(
        _readString(
          row,
          const [
            'check_out_time',
            'checkOutTime',
            'check_out',
            'checkOut',
            'check_out_at',
          ],
          fallback: '--:--',
        ),
      ),
      workingHours: _readString(
        row,
        const [
          'working_hours',
          'workingHours',
          'hours_worked',
          'hoursWorked',
          'total_working_hours',
        ],
      ),
      lateByMinutes: _readInt(
        row['late_by_minutes'] ?? row['lateByMinutes'],
        fallback: 0,
      ),
      leaveType: _readString(row, const ['leave_type', 'leaveType']),
      checkInPhoto: _readString(
        row,
        const ['checkin_photo', 'checkInPhoto', 'check_in_photo'],
      ),
      checkOutPhoto: _readString(
        row,
        const ['checkout_photo', 'checkOutPhoto', 'check_out_photo'],
      ),
      checkInLocation: _locationMap(
        row['checkin_location'] ?? row['checkInLocation'],
      ),
      checkOutLocation: _locationMap(
        row['checkout_location'] ?? row['checkOutLocation'],
      ),
      checkInDevice: _readString(
        row,
        const ['checkin_device', 'checkInDevice', 'check_in_device'],
      ),
      checkOutDevice: _readString(
        row,
        const ['checkout_device', 'checkOutDevice', 'check_out_device'],
      ),
      checkInIp: _readString(
        row,
        const ['checkin_ip', 'checkInIp', 'check_in_ip'],
      ),
      checkOutIp: _readString(
        row,
        const ['checkout_ip', 'checkOutIp', 'check_out_ip'],
      ),
      isManualEntry: _readBool(
        row,
        const ['is_manual_entry', 'isManualEntry'],
      ),
      manualByName: _readString(
        row,
        const ['manual_by_name', 'manualByName'],
      ),
      manualReason: _readString(
        row,
        const ['manual_reason', 'manualReason'],
      ),
    );
  }

  Map<String, dynamic> _locationMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  String _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num || value is bool) return value.toString();
    }
    return fallback;
  }

  bool _readBool(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
      }
    }
    return false;
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  DateTime? _parseApiDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  String _formatTime(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == '--:--') return '--:--';
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return normalized;
    final local = parsed.toLocal();
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = h24 >= 12 ? 'pm' : 'am';
    return '$h12:$minute $suffix';
  }

  String _formatLongDate(DateTime date) {
    const week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${week[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'on leave') return 'leave';
    if (normalized == 'on_leave') return 'leave';
    if (normalized == 'checked_in' || normalized == 'checked in') {
      return 'present';
    }
    if (normalized.isEmpty) return 'absent';
    return normalized;
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'present':
        return const _StatusStyle(
          fg: Color(0xFF008A63),
          bg: Color(0xFFDDF7E9),
          accent: Color(0xFF10B981),
        );
      case 'late':
        return const _StatusStyle(
          fg: Color(0xFFC56B00),
          bg: Color(0xFFFFF0C6),
          accent: Color(0xFFF59E0B),
        );
      case 'leave':
        return const _StatusStyle(
          fg: Color(0xFF4F46E5),
          bg: Color(0xFFE8EAFE),
          accent: Color(0xFF4F46E5),
        );
      default:
        return const _StatusStyle(
          fg: Color(0xFFDC2626),
          bg: Color(0xFFFFE7E7),
          accent: Color(0xFFF04452),
        );
    }
  }

  int _summaryValue(List<String> keys) {
    final summary = _summaryMap();
    for (final key in keys) {
      if (summary.containsKey(key)) {
        return _readInt(summary[key], fallback: 0);
      }
    }
    return 0;
  }

  String _summaryHours(List<String> keys) {
    final summary = _summaryMap();
    for (final key in keys) {
      final value = summary[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return '0';
  }

  String _displayHours(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '0h';
    return normalized.toLowerCase().endsWith('h')
        ? normalized
        : '${normalized}h';
  }

  String _summaryName() {
    final user = _userMap();
    return _readString(
      user,
      const ['name', 'full_name', 'fullName'],
      fallback: widget.initialName,
    );
  }

  String _summaryRole() {
    final user = _userMap();
    return _readString(
      user,
      const ['role', 'designation'],
      fallback: widget.initialRole,
    ).replaceAll('_', ' ');
  }

  int _statusCountFromEntries(String status) {
    return _historyEntries()
        .where((entry) => entry.status.toLowerCase() == status)
        .length;
  }

  List<_StatusFilterChipData> _statusFilterTiles() {
    final presentCount =
        _summaryValue(const ['present', 'present_count', 'presentCount']);
    final absentCount =
        _summaryValue(const ['absent', 'absent_count', 'absentCount']);
    final lateCount = _summaryValue(const ['late', 'late_count', 'lateCount']);
    final leaveCount = _summaryValue(
      const ['leave', 'on_leave', 'onLeave', 'leave_count', 'leaveCount'],
    );

    final primaryTiles = <_StatusFilterChipData>[
      _StatusFilterChipData(
        statusKey: 'present',
        label: 'Present',
        value: presentCount > 0
            ? presentCount
            : _statusCountFromEntries('present'),
        color: const Color(0xFF0F9D71),
      ),
      _StatusFilterChipData(
        statusKey: 'absent',
        label: 'Absent',
        value:
            absentCount > 0 ? absentCount : _statusCountFromEntries('absent'),
        color: const Color(0xFFF04452),
      ),
      _StatusFilterChipData(
        statusKey: 'late',
        label: 'Late',
        value: lateCount > 0 ? lateCount : _statusCountFromEntries('late'),
        color: const Color(0xFFE07900),
      ),
      _StatusFilterChipData(
        statusKey: 'leave',
        label: 'Leave',
        value: leaveCount > 0 ? leaveCount : _statusCountFromEntries('leave'),
        color: const Color(0xFF4F46E5),
      ),
    ];

    const known = <String>{'present', 'absent', 'late', 'leave'};
    final extraStatusCounts = <String, int>{};
    for (final entry in _historyEntries()) {
      final status = entry.status.toLowerCase();
      if (known.contains(status)) {
        continue;
      }
      extraStatusCounts.update(status, (value) => value + 1, ifAbsent: () => 1);
    }

    final extraTiles = extraStatusCounts.entries.map((entry) {
      final style = _statusStyle(entry.key);
      return _StatusFilterChipData(
        statusKey: entry.key,
        label: _statusLabel(entry.key),
        value: entry.value,
        color: style.accent,
      );
    });

    return <_StatusFilterChipData>[
      ...primaryTiles,
      ...extraTiles,
    ].where((tile) => tile.value > 0).toList(growable: false);
  }

  String _summaryEmail() {
    return _readString(_userMap(), const ['email']);
  }

  String _summaryPhone() {
    return _readString(
      _userMap(),
      const ['phone', 'phone_number', 'phoneNumber', 'mobile'],
    );
  }

  String _summaryJoinDate() {
    final raw = _readString(
      _userMap(),
      const ['join_date', 'joinDate', 'joining_date', 'joiningDate'],
    );
    final parsed = _parseApiDate(raw);
    return parsed == null ? '' : _displayDate(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredHistoryEntries();
    final summary = _summaryMap();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? _buildErrorState()
                              : RefreshIndicator(
                                  onRefresh: () =>
                                      _loadHistory(page: _currentPage),
                                  child: ListView(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 0, 0, 18),
                                    children: [
                                      _buildFilters(),
                                      _buildSummaryStrip(),
                                      _buildHoursBar(summary),
                                      if (entries.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Text(
                                            _selectedStatusFilter == null
                                                ? 'No attendance history available for the selected period.'
                                                : 'No ${_statusLabel(_selectedStatusFilter!)} records found for the selected period.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF71809A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        ...entries.map(_buildEntryCard),
                                      if (_totalPages > 1)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            0,
                                          ),
                                          child: PaginationWidget(
                                            currentPage: _currentPage,
                                            totalPages: _totalPages,
                                            totalItems: _totalItems,
                                            itemLabel: 'records',
                                            onPageChanged: (page) {
                                              if (_isLoading) return;
                                              _loadHistory(page: page);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
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
    final email = _summaryEmail();
    final phone = _summaryPhone();
    final joinDate = _summaryJoinDate();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF0A84FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _summaryName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172B4D),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _summaryRole().isEmpty ? 'N/A' : _summaryRole(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8D99AE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty ||
                    phone.isNotEmpty ||
                    joinDate.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (email.isNotEmpty)
                        _InfoPill(icon: Icons.mail_outline, text: email),
                      if (phone.isNotEmpty)
                        _InfoPill(icon: Icons.call_outlined, text: phone),
                      if (joinDate.isNotEmpty)
                        _InfoPill(
                            icon: Icons.event_outlined,
                            text: 'Joined $joinDate'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF8B97AB)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateField(
                  label: 'From',
                  value: _displayDate(_fromDate),
                  onTap: _pickFromDate,
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'To',
                  value: _displayDate(_toDate),
                  onTap: _pickToDate,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'From',
                  value: _displayDate(_fromDate),
                  onTap: _pickFromDate,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DateField(
                  label: 'To',
                  value: _displayDate(_toDate),
                  onTap: _pickToDate,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final tiles = _statusFilterTiles();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8EDF5)),
          bottom: BorderSide(color: Color(0xFFE8EDF5)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              children: tiles
                  .map(
                    (tile) => _SummaryTile(
                      value: tile.value,
                      label: tile.label,
                      color: tile.color,
                      isSelected: _selectedStatusFilter == tile.statusKey,
                      onTap: () => _toggleStatusFilter(tile.statusKey),
                    ),
                  )
                  .toList(growable: false),
            );
          }
          return Row(
            children: tiles
                .map(
                  (tile) => Expanded(
                    child: _SummaryTile(
                      value: tile.value,
                      label: tile.label,
                      color: tile.color,
                      isSelected: _selectedStatusFilter == tile.statusKey,
                      onTap: () => _toggleStatusFilter(tile.statusKey),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  void _toggleStatusFilter(String statusKey) {
    setState(() {
      _selectedStatusFilter =
          _selectedStatusFilter == statusKey ? null : statusKey;
    });
  }

  Widget _buildHoursBar(Map<String, dynamic> summary) {
    final totalHours = _summaryHours(
      const ['total_working_hours', 'totalWorkingHours'],
    );
    final averageHours = _summaryHours(
      const ['avg_working_hours', 'avgWorkingHours', 'average_working_hours'],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(
        children: [
          const Icon(Icons.av_timer_rounded,
              size: 18, color: Color(0xFF0A84FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  'Total:',
                  style: const TextStyle(
                    color: Color(0xFF68778F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _displayHours(totalHours),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Avg: ${_displayHours(averageHours)}/day',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(_AttendanceHistoryEntry entry) {
    final style = _statusStyle(entry.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE8EDF5).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatLongDate(entry.date),
                  style: const TextStyle(
                    color: Color(0xFF1E2D44),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _statusLabel(entry.status).toUpperCase(),
                  style: TextStyle(
                    color: style.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final checkInCard = _CheckPointCard(
                title: 'Check In',
                icon: Icons.login_rounded,
                iconColor: const Color(0xFF12A150),
                time: entry.checkIn,
                locationText: _locationText(entry.checkInLocation),
                extraText: _metaLine(
                  device: entry.checkInDevice,
                  ip: entry.checkInIp,
                ),
                footer: entry.lateByMinutes > 0
                    ? '${entry.lateByMinutes} min late'
                    : '',
                footerColor: const Color(0xFFE07900),
              );
              final checkOutCard = _CheckPointCard(
                title: 'Check Out',
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFF04452),
                time: entry.checkOut,
                locationText: _locationText(entry.checkOutLocation),
                extraText: _metaLine(
                  device: entry.checkOutDevice,
                  ip: entry.checkOutIp,
                ),
                footer: entry.workingHours.isNotEmpty
                    ? '${entry.workingHours} worked'
                    : '',
                footerColor: const Color(0xFF0A84FF),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    checkInCard,
                    const SizedBox(height: 12),
                    checkOutCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: checkInCard),
                  const SizedBox(width: 12),
                  Expanded(child: checkOutCard),
                ],
              );
            },
          ),
          if (entry.leaveType.isNotEmpty || entry.isManualEntry) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.leaveType.isNotEmpty)
                  _InfoPill(
                    icon: Icons.event_available_outlined,
                    text: 'Leave: ${entry.leaveType}',
                  ),
                if (entry.isManualEntry)
                  _InfoPill(
                    icon: Icons.edit_note_rounded,
                    text: entry.manualByName.isNotEmpty
                        ? 'Manual by ${entry.manualByName}'
                        : 'Manual entry',
                  ),
              ],
            ),
          ],
          if (entry.manualReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCE3A2)),
              ),
              child: Text(
                entry.manualReason,
                style: const TextStyle(
                  color: Color(0xFF6D5800),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (entry.checkInPhoto.isNotEmpty ||
              entry.checkOutPhoto.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Photos',
              style: TextStyle(
                color: Color(0xFF7C8DA6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (entry.checkInPhoto.isNotEmpty)
                  _PhotoTile(label: 'Check-in', url: entry.checkInPhoto),
                if (entry.checkOutPhoto.isNotEmpty)
                  _PhotoTile(label: 'Check-out', url: entry.checkOutPhoto),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _locationText(Map<String, dynamic> location) {
    if (location.isEmpty) return '';
    final address = _readString(location, const ['address']);
    if (address.isNotEmpty) return address;
    final lat = _readString(location, const ['latitude', 'lat']);
    final lng = _readString(location, const ['longitude', 'lng', 'lon']);
    if (lat.isEmpty && lng.isEmpty) return '';
    return [lat, lng].where((value) => value.isNotEmpty).join(', ');
  }

  String _metaLine({required String device, required String ip}) {
    return [device, ip].where((value) => value.trim().isNotEmpty).join(' . ');
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Unable to load attendance history.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceHistoryEntry {
  const _AttendanceHistoryEntry({
    required this.date,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.workingHours,
    required this.lateByMinutes,
    required this.leaveType,
    required this.checkInPhoto,
    required this.checkOutPhoto,
    required this.checkInLocation,
    required this.checkOutLocation,
    required this.checkInDevice,
    required this.checkOutDevice,
    required this.checkInIp,
    required this.checkOutIp,
    required this.isManualEntry,
    required this.manualByName,
    required this.manualReason,
  });

  final DateTime date;
  final String status;
  final String checkIn;
  final String checkOut;
  final String workingHours;
  final int lateByMinutes;
  final String leaveType;
  final String checkInPhoto;
  final String checkOutPhoto;
  final Map<String, dynamic> checkInLocation;
  final Map<String, dynamic> checkOutLocation;
  final String checkInDevice;
  final String checkOutDevice;
  final String checkInIp;
  final String checkOutIp;
  final bool isManualEntry;
  final String manualByName;
  final String manualReason;
}

class _StatusStyle {
  const _StatusStyle({
    required this.fg,
    required this.bg,
    required this.accent,
  });

  final Color fg;
  final Color bg;
  final Color accent;
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7C8DA6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9E2F0)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF23324A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF23324A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final int value;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : null,
          border: Border(
            right: const BorderSide(color: Color(0xFFE8EDF5)),
            bottom: isSelected
                ? BorderSide(color: color, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF7C8DA6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterChipData {
  const _StatusFilterChipData({
    required this.statusKey,
    required this.label,
    required this.value,
    required this.color,
  });

  final String statusKey;
  final String label;
  final int value;
  final Color color;
}

class _CheckPointCard extends StatelessWidget {
  const _CheckPointCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.locationText,
    required this.extraText,
    required this.footer,
    required this.footerColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final String time;
  final String locationText;
  final String extraText;
  final String footer;
  final Color footerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF95A1B6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF172B4D),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              footer,
              style: TextStyle(
                color: footerColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              locationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8E9AAF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (extraText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              extraText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFA0AABC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7C8DA6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF3F5F8),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF9AA6BA),
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF3F5F8),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7C8DA6)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF51627C),
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
