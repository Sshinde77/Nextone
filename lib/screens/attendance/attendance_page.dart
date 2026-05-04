import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/utils/csv_export_helper.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  int _selectedTabIndex = 0;

  static const List<_TabData> _tabs = [
    _TabData('Overview', Icons.bar_chart_rounded),
    _TabData('Calendar', Icons.calendar_month_outlined),
    _TabData('My History', Icons.watch_later_outlined),
    _TabData('Month Grid', Icons.group_outlined),
    _TabData('Daily View', Icons.person_search_outlined),
    _TabData('Summary', Icons.trending_up_rounded),
    _TabData('Approvals', Icons.how_to_reg_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildTopTabs(),
              const SizedBox(height: 10),
              _buildMainPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: TextStyle(
                  color: Color(0xFF071A3A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sunday, 3 May 2026',
                style: TextStyle(
                  color: Color(0xFF5D6B82),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _RoundActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {},
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _exportAttendance,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1C3159),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFD4DBEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text(
            'Export Excel',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportAttendance() async {
    await CsvExportHelper.exportRowsToClipboard(
      context: context,
      fileLabel: 'Attendance',
      headers: const <String>['Section', 'Value'],
      rows: const <List<String>>[
        <String>['View', 'Overview'],
        <String>['Status', 'Attendance summary snapshot'],
      ],
    );
  }

  Widget _buildTopTabs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final selected = index == _selectedTabIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedTabIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFD5DEF0)
                            : Colors.transparent,
                      ),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x1A0D234F),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 16,
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFF637086),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF4F5F7C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_selectedTabIndex == 1) {
          return _buildCalendarTabContent(constraints.maxWidth);
        }

        final stacked = constraints.maxWidth < 980;
        if (stacked) {
          return Column(
            children: [
              _buildTodayCard(width: constraints.maxWidth),
              const SizedBox(height: 12),
              _buildRightMetrics(width: constraints.maxWidth),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.325,
              child: _buildTodayCard(width: constraints.maxWidth * 0.325),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRightMetrics(width: constraints.maxWidth * 0.675 - 12),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarTabContent(double maxWidth) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const totalDays = 31;
    const leadingSlots = 5; // May 2026 starts on Friday in Sun-first layout.
    const selectedDay = 3;

    final items = <_CalendarCell>[];
    for (var i = 0; i < leadingSlots; i++) {
      items.add(const _CalendarCell.empty());
    }
    for (var day = 1; day <= totalDays; day++) {
      final isWeekend = ((leadingSlots + day - 1) % 7 == 0) ||
          ((leadingSlots + day - 1) % 7 == 6);
      _CalendarCellState state = _CalendarCellState.absent;
      if (day == 1) {
        state = _CalendarCellState.present;
      } else if (isWeekend) {
        state = _CalendarCellState.off;
      }
      items.add(
        _CalendarCell(
          day: day,
          state: state,
          isSelected: day == selectedDay,
        ),
      );
    }

    while (items.length % 7 != 0) {
      items.add(const _CalendarCell.empty());
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2548),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Attendance Calendar',
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1 present · 20 absent · 0 late',
                        style: TextStyle(
                          color: Color(0xFF95A1B6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundActionButton(icon: Icons.chevron_left_rounded, onTap: () {}),
                const SizedBox(width: 8),
                const Text(
                  'May 2026',
                  style: TextStyle(
                    color: Color(0xFF2C3E5D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _RoundActionButton(icon: Icons.chevron_right_rounded, onTap: () {}),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _LegendChip(
                    label: '1 Present',
                    textColor: Color(0xFF0F9D71),
                    bgColor: Color(0xFFDDF7E9),
                  ),
                  _LegendChip(
                    label: '0 Late',
                    textColor: Color(0xFFC57D0B),
                    bgColor: Color(0xFFFDF0D6),
                  ),
                  _LegendChip(
                    label: '20 Absent',
                    textColor: Color(0xFFDE3D3D),
                    bgColor: Color(0xFFFCE4E4),
                  ),
                  _LegendChip(
                    label: '0 Leave',
                    textColor: Color(0xFF5B65C5),
                    bgColor: Color(0xFFE8EAFE),
                  ),
                  _LegendChip(
                    label: '1.04h worked',
                    textColor: Color(0xFF1E74D8),
                    bgColor: Color(0xFFE3EEFF),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                Row(
                  children: weekdays
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                color: Color(0xFF98A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  itemCount: items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) => _CalendarDayCell(cell: items[index]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF1F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF7CDCD)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '04 May 2026',
                          style: TextStyle(
                            color: Color(0xFF304561),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '↳ --:--      ⟷      ↳ --:--',
                          style: TextStyle(
                            color: Color(0xFF9AA6BA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE3E3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '• Absent',
                      style: TextStyle(
                        color: Color(0xFFD94848),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard({required double width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E2F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A102A52),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [Color(0xFF1983EB), Color(0xFF2E5FE1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY\'S ATTENDANCE',
                        style: TextStyle(
                          color: Color(0xD9E6F0FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Sunday, 3 May',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shubham Shinde',
                            style: TextStyle(
                              color: Color(0xFF0D203E),
                            fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Super Admin',
                            style: TextStyle(
                              color: Color(0xFF7B879C),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(0xFFEF4444),
                            size: 8,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Absent',
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE4EAF4), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(
                      child: _MiniTimeCard(
                        icon: Icons.login_rounded,
                        iconColor: Color(0xFF22C55E),
                        label: 'Check In',
                        value: '--:--',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _MiniTimeCard(
                        icon: Icons.logout_rounded,
                        iconColor: Color(0xFFF43F5E),
                        label: 'Check Out',
                        value: '--:--',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('Check In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightMetrics({required double width}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final childAspectRatio = cardWidth > 260 ? 1.85 : 1.35;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _StatusCard(
              title: 'Absent',
              subtitle: 'Status Today',
              caption: 'Not checked in',
              value: '',
              icon: Icons.check_circle_outline_rounded,
              iconColor: Color(0xFFF55462),
              bubbleColor: Color(0xFFF9EAEC),
            ),
            _StatusCard(
              title: 'Working Hours',
              subtitle: 'Today so far',
              caption: '',
              value: '--',
              icon: Icons.timer_outlined,
              iconColor: AppColors.primary,
              bubbleColor: Color(0xFFE8EEF7),
            ),
            _StatusCard(
              title: 'Check In',
              subtitle: '',
              caption: 'Not checked in yet',
              value: '--:--',
              icon: Icons.login_rounded,
              iconColor: Color(0xFF22C55E),
              bubbleColor: Color(0xFFE8F6EE),
            ),
            _StatusCard(
              title: 'Check Out',
              subtitle: '',
              caption: 'Not checked out yet',
              value: '--:--',
              icon: Icons.logout_rounded,
              iconColor: Color(0xFFF55462),
              bubbleColor: Color(0xFFF9EAEC),
            ),
          ],
        );
      },
    );
  }
}

class _MiniTimeCard extends StatelessWidget {
  const _MiniTimeCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF57647A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFC0CAD9),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.caption,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bubbleColor,
  });

  final String title;
  final String subtitle;
  final String caption;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E2F0)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -26,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0A2344),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              if (value.isEmpty)
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0A2344),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (value.isNotEmpty)
                const SizedBox(height: 4)
              else
                const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? title : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4A5D7A),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (value.isNotEmpty && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF96A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF96A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD3DAE8)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF637086),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  final String label;
  final Color textColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _CalendarCellState { present, absent, off }

class _CalendarCell {
  const _CalendarCell({
    this.day,
    this.state = _CalendarCellState.off,
    this.isSelected = false,
  });

  const _CalendarCell.empty()
      : day = null,
        state = _CalendarCellState.off,
        isSelected = false;

  final int? day;
  final _CalendarCellState state;
  final bool isSelected;
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.cell});

  final _CalendarCell cell;

  @override
  Widget build(BuildContext context) {
    if (cell.day == null) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color textColor;
    Color dotColor;
    switch (cell.state) {
      case _CalendarCellState.present:
        bgColor = const Color(0xFFE6F7EF);
        textColor = const Color(0xFF0E9A6E);
        dotColor = const Color(0xFF10B981);
        break;
      case _CalendarCellState.absent:
        bgColor = const Color(0xFFFBEEEE);
        textColor = const Color(0xFFE24B4B);
        dotColor = const Color(0xFFEF4444);
        break;
      case _CalendarCellState.off:
        bgColor = const Color(0xFFF4F6FA);
        textColor = const Color(0xFF96A3B8);
        dotColor = Colors.transparent;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cell.isSelected ? AppColors.primary : Colors.transparent,
          width: cell.isSelected ? 2 : 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cell.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (dotColor != Colors.transparent) ...[
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
