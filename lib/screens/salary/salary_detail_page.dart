import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';

class SalaryDetailPage extends StatefulWidget {
  const SalaryDetailPage({
    super.key,
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
    required this.monthlySalary,
    required this.perDaySalary,
    required this.effectiveFrom,
    required this.setBy,
  });

  final String userId;
  final String name;
  final String role;
  final String email;
  final double monthlySalary;
  final double perDaySalary;
  final DateTime? effectiveFrom;
  final String setBy;

  @override
  State<SalaryDetailPage> createState() => _SalaryDetailPageState();
}

class _SalaryDetailPageState extends State<SalaryDetailPage> {
  final AuthProvider _authProvider = AuthProvider();
  late DateTime _selectedMonth;
  bool _isLoading = true;
  String? _error;
  List<_AttendanceDayRow> _rows = <_AttendanceDayRow>[];
  int _presentDays = 0;
  int _absentDays = 0;
  int _onLeaveDays = 0;
  double _earnedTotal = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadAttendanceForSelectedMonth();
  }

  Future<void> _loadAttendanceForSelectedMonth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allRows = <Map<String, dynamic>>[];
      var page = 1;
      var totalPages = 1;

      do {
        final response = await _authProvider.attendanceUser(
          userId: widget.userId,
          page: page,
          perPage: 30,
          token: _authProvider.currentAuthToken,
        );

        final dataRaw = response['data'];
        if (dataRaw is List) {
          allRows.addAll(
            dataRaw
                .whereType<Map>()
                .map((item) => item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    )),
          );
        }

        final paginationRaw = response['pagination'];
        if (paginationRaw is Map) {
          final pagination = paginationRaw.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          totalPages = _readInt(pagination['total_pages'], fallback: 1);
        } else {
          totalPages = 1;
        }
        page += 1;
      } while (page <= totalPages);

      final monthRows = allRows
          .map(_mapAttendanceRow)
          .where(
            (row) =>
                row.date.year == _selectedMonth.year &&
                row.date.month == _selectedMonth.month,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      var present = 0;
      var absent = 0;
      var onLeave = 0;
      var earned = 0.0;
      for (final row in monthRows) {
        if (row.status == _AttendanceStatus.present ||
            row.status == _AttendanceStatus.halfDay) {
          present += 1;
        } else if (row.status == _AttendanceStatus.absent) {
          absent += 1;
        } else {
          onLeave += 1;
        }
        earned += row.earned;
      }

      if (!mounted) return;
      setState(() {
        _rows = monthRows;
        _presentDays = present;
        _absentDays = absent;
        _onLeaveDays = onLeave;
        _earnedTotal = earned;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.friendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return DateTime(1970, 1, 1);
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  _AttendanceDayRow _mapAttendanceRow(Map<String, dynamic> json) {
    final date = _parseDate(json['date']);
    final statusRaw = (json['status']?.toString() ?? '').trim().toLowerCase();
    final checkIn = _parseDateTime(json['check_in_time']);
    final checkOut = _parseDateTime(json['check_out_time']);
    final workingHours = _readDouble(json['working_hours']);
    late final _AttendanceStatus status;
    if (statusRaw == 'present' || statusRaw == 'full_day') {
      status = _AttendanceStatus.present;
    } else if (statusRaw == 'half_day') {
      status = _AttendanceStatus.halfDay;
    } else if (statusRaw == 'absent') {
      status = _AttendanceStatus.absent;
    } else if (statusRaw == 'leave' || statusRaw == 'on_leave') {
      status = _AttendanceStatus.onLeave;
    } else {
      status = _AttendanceStatus.onLeave;
    }

    late final double earned;
    if (status == _AttendanceStatus.present) {
      earned = widget.perDaySalary;
    } else if (status == _AttendanceStatus.halfDay) {
      earned = widget.perDaySalary / 2;
    } else {
      earned = 0;
    }

    final checkInLabel = checkIn == null ? '-' : DateFormat('hh:mm a').format(checkIn);
    final checkOutLabel = checkOut == null ? '-' : DateFormat('hh:mm a').format(checkOut);
    final timeLabel = '$checkInLabel - $checkOutLabel';

    return _AttendanceDayRow(
      date: date,
      status: status,
      statusLabel: _statusText(status),
      timeLabel: timeLabel,
      hoursLabel: workingHours > 0 ? '${workingHours.toStringAsFixed(2)}h' : '-',
      earned: earned,
    );
  }

  String _statusText(_AttendanceStatus status) {
    switch (status) {
      case _AttendanceStatus.present:
        return 'Present';
      case _AttendanceStatus.halfDay:
        return 'Half Day';
      case _AttendanceStatus.absent:
        return 'Absent';
      case _AttendanceStatus.onLeave:
        return 'On Leave';
    }
  }

  Color _statusColor(_AttendanceStatus status) {
    switch (status) {
      case _AttendanceStatus.present:
        return const Color(0xFF10B981);
      case _AttendanceStatus.halfDay:
        return const Color(0xFFF59E0B);
      case _AttendanceStatus.absent:
        return const Color(0xFFEF4444);
      case _AttendanceStatus.onLeave:
        return const Color(0xFF6366F1);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadAttendanceForSelectedMonth();
  }

  static String _currency(double value) {
    return 'Rs. ${NumberFormat('#,##,##0.00').format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 380;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final effectiveLabel = widget.effectiveFrom == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(widget.effectiveFrom!.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F7FC),
        foregroundColor: AppColors.textPrimary,
        titleSpacing: 0,
        title: const Text(
          'Back to Salary',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
        children: [
          _employeeHeaderCard(
            isCompact: isCompact,
            name: widget.name,
            role: widget.role,
            email: widget.email,
            monthlySalary: widget.monthlySalary,
            perDaySalary: widget.perDaySalary,
            effectiveFrom: effectiveLabel,
            setBy: widget.setBy,
          ),
          const SizedBox(height: 10),
          _monthRow(monthLabel),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: isCompact ? 1.9 : 2.05,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard('Present Days', '$_presentDays', 'Month total', const Color(0xFF10B981)),
              _statCard('Absent Days', '$_absentDays', 'No pay', const Color(0xFFEF4444)),
              _statCard('On Leave', '$_onLeaveDays', 'Leave days', const Color(0xFFF59E0B)),
              _statCard(
                'Earned (Est.)',
                _currency(_earnedTotal),
                monthLabel,
                const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _daywiseCard(monthLabel: monthLabel, perDaySalary: widget.perDaySalary),
        ],
      ),
    );
  }

  Widget _employeeHeaderCard({
    required bool isCompact,
    required String name,
    required String role,
    required String email,
    required double monthlySalary,
    required double perDaySalary,
    required String effectiveFrom,
    required String setBy,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 11 : 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: const LinearGradient(
                colors: [Color(0xFF0A7CFF), Color(0xFF2F5FE3)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isCompact ? 15 : 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _meta('Monthly Salary', _currency(monthlySalary))),
                    Expanded(child: _meta('Per Day Salary', _currency(perDaySalary))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _meta('Effective From', effectiveFrom)),
                    Expanded(child: _meta('Set By', setBy)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthRow(String monthLabel) {
    return Row(
      children: [
        GestureDetector(onTap: () => _changeMonth(-1), child: _navCircle(Icons.chevron_left)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            monthLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ),
        GestureDetector(onTap: () => _changeMonth(1), child: _navCircle(Icons.chevron_right)),
      ],
    );
  }

  Widget _navCircle(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 16),
    );
  }

  Widget _statCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _daywiseCard({
    required String monthLabel,
    required double perDaySalary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Day-wise Attendance & Salary',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$monthLabel - ${_rows.length} records',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadAttendanceForSelectedMonth,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No attendance records for selected month.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _rows[index];
                final statusColor = _statusColor(row.status);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(row.date),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${row.statusLabel} | ${row.timeLabel}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hours: ${row.hoursLabel}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              row.statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+${_currency(row.earned)}',
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Per Day: ${_currency(perDaySalary)}',
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

enum _AttendanceStatus { present, halfDay, absent, onLeave }

class _AttendanceDayRow {
  const _AttendanceDayRow({
    required this.date,
    required this.status,
    required this.statusLabel,
    required this.timeLabel,
    required this.hoursLabel,
    required this.earned,
  });

  final DateTime date;
  final _AttendanceStatus status;
  final String statusLabel;
  final String timeLabel;
  final String hoursLabel;
  final double earned;
}
