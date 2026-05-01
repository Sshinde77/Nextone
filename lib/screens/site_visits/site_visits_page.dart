import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class SiteVisitsPage extends StatefulWidget {
  const SiteVisitsPage({super.key});

  @override
  State<SiteVisitsPage> createState() => _SiteVisitsPageState();
}

enum _VisitStatus { scheduled, inProgress, completed, cancelled }

class _SiteVisit {
  _SiteVisit({
    required this.id,
    required this.property,
    required this.lead,
    required this.location,
    required this.transport,
    required this.dateTime,
    required this.imageUrl,
    required this.assignee,
    this.status = _VisitStatus.scheduled,
    this.feedback = '',
    this.rating = 0,
  });

  final String id;
  String property;
  String lead;
  String location;
  String transport;
  DateTime dateTime;
  String imageUrl;
  String assignee;
  _VisitStatus status;
  String feedback;
  int rating;
}

class _SiteVisitsPageState extends State<SiteVisitsPage> {
  static const List<String> _teamMembers = <String>[
    'Aarav Patel',
    'Priya Sharma',
    'Rohan Verma',
    'Neha Iyer',
    'Karan Mehta',
  ];

  static const List<String> _demoImages = <String>[
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1600585154526-990dbea464dd?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=400&q=80',
  ];

  bool _isCalendarView = false;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  late List<_SiteVisit> _visits;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _visits = <_SiteVisit>[
      _SiteVisit(
        id: 'SV-1001',
        property: 'The Glass Pavilion',
        lead: 'Julianne Moore',
        location: 'Beverly Hills, CA',
        transport: 'Cab',
        dateTime: DateTime(now.year, now.month, now.day, 10, 30),
        imageUrl: _demoImages[0],
        assignee: _teamMembers[1],
        status: _VisitStatus.scheduled,
      ),
      _SiteVisit(
        id: 'SV-1002',
        property: 'Skyloft Penthouse',
        lead: 'Robert Sterling',
        location: 'Downtown Metro',
        transport: 'Self',
        dateTime: DateTime(now.year, now.month, now.day, 14, 00),
        imageUrl: _demoImages[1],
        assignee: _teamMembers[2],
        status: _VisitStatus.inProgress,
      ),
      _SiteVisit(
        id: 'SV-1003',
        property: 'Azure Bay Residence',
        lead: 'Sarah Jenkins',
        location: 'Malibu Shores',
        transport: 'Company Car',
        dateTime: DateTime(now.year, now.month, now.day + 1, 16, 45),
        imageUrl: _demoImages[2],
        assignee: _teamMembers[0],
        status: _VisitStatus.completed,
        rating: 4,
        feedback: 'Client liked the sea-facing balcony and parking layout.',
      ),
      _SiteVisit(
        id: 'SV-1004',
        property: 'Luma Heights',
        lead: 'Adrian Blake',
        location: 'West Valley',
        transport: 'Bike',
        dateTime: DateTime(now.year, now.month, now.day + 2, 12, 15),
        imageUrl: _demoImages[3],
        assignee: _teamMembers[3],
        status: _VisitStatus.cancelled,
      ),
    ];
  }

  List<_SiteVisit> get _selectedDayVisits {
    final list =
        _visits
            .where((visit) => _isSameDate(visit.dateTime, _selectedDate))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<_SiteVisit> get _allVisitsSorted {
    final list = List<_SiteVisit>.from(_visits)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<_SiteVisit> get _visibleVisits {
    return _isCalendarView ? _selectedDayVisits : _allVisitsSorted;
  }

  String get _visitSectionTitle {
    if (_isCalendarView) {
      return _isSameDate(_selectedDate, DateTime.now())
          ? "Today's Visits"
          : 'Visits on $_selectedDateLabel';
    }
    return 'All Scheduled Visits';
  }

  String get _selectedDateLabel {
    const months = <String>[
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
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  double get _screenWidth => MediaQuery.sizeOf(context).width;

  double get _uiScale {
    if (_screenWidth <= 320) return 0.84;
    if (_screenWidth <= 360) return 0.9;
    if (_screenWidth <= 390) return 0.96;
    if (_screenWidth <= 430) return 1.0;
    return 1.02;
  }

  bool get _isCompactMobile => _screenWidth < 360;

  double _s(double value) => value * _uiScale;

  double _fs(double value) => value * (_uiScale.clamp(0.9, 1.0));

  @override
  Widget build(BuildContext context) {
    final visibleVisits = _visibleVisits;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Site Visits'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _s(14)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: _s(14)),
                  Text(
                    'SCHEDULE',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: _fs(10),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Visits',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: _fs(26),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildViewToggle(),
                    ],
                  ),
                  SizedBox(height: _s(10)),
                  _buildQuickActions(),
                  SizedBox(height: _s(14)),
                  if (_isCalendarView) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCalendarCard(),
                    ),
                    SizedBox(height: _s(18)),
                  ] else
                    SizedBox(height: _s(8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _visitSectionTitle,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: _fs(18),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCalendarView)
                        Text(
                          _selectedDateLabel.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.6),
                            fontSize: _fs(9),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: _s(12)),
                  if (visibleVisits.isEmpty)
                    _buildEmptyState()
                  else
                    ...visibleVisits.map(_buildVisitCard),
                  SizedBox(height: _s(90)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final compact = _isCompactMobile;
    return Row(
      children: [
        Expanded(
          child: _buildKpiTile(
            label: 'Scheduled',
            value: _countByStatus(_VisitStatus.scheduled).toString(),
            color: AppColors.warning,
          ),
        ),
        SizedBox(width: _s(8)),
        Expanded(
          child: _buildKpiTile(
            label: 'Completed',
            value: _countByStatus(_VisitStatus.completed).toString(),
            color: AppColors.tertiary,
          ),
        ),
        SizedBox(width: _s(8)),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openVisitEditor(),
            icon: Icon(Icons.add, size: _s(16)),
            label: Text(compact ? 'Add' : 'Schedule'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(_s(52)),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_s(14)),
              ),
              padding: EdgeInsets.symmetric(horizontal: _s(8)),
              textStyle: TextStyle(
                fontSize: _fs(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      height: _s(52),
      padding: EdgeInsets.symmetric(horizontal: _s(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(14)),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: _s(12),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _s(8),
            height: _s(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: _s(8)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: _fs(13),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: _fs(9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: EdgeInsets.all(_s(3)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(_s(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem(
            'List',
            Icons.list_rounded,
            !_isCalendarView,
            () => setState(() => _isCalendarView = false),
          ),
          _toggleItem(
            'Calendar',
            Icons.calendar_today_rounded,
            _isCalendarView,
            () => setState(() => _isCalendarView = true),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _s(9), vertical: _s(6)),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(_s(8)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: _s(3),
                    offset: Offset(0, _s(1)),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: _s(12),
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            SizedBox(width: _s(3)),
            Text(
              label,
              style: TextStyle(
                fontSize: _fs(9.5),
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      key: const ValueKey('calendar'),
      width: double.infinity,
      padding: EdgeInsets.all(_s(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: _s(14),
            offset: Offset(0, _s(6)),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _monthLabel(_focusedMonth),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: _fs(15),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  _calendarNavButton(
                    Icons.chevron_left_rounded,
                    () => _changeMonth(-1),
                  ),
                  SizedBox(width: _s(6)),
                  _calendarNavButton(
                    Icons.chevron_right_rounded,
                    () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: _s(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: _fs(8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: _s(10)),
          _buildCalendarDays(),
          SizedBox(height: _s(12)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: _s(10),
            runSpacing: _s(6),
            children: [
              _statusIndicator(
                _statusColor(_VisitStatus.scheduled),
                'SCHEDULED',
              ),
              _statusIndicator(
                _statusColor(_VisitStatus.inProgress),
                'IN PROGRESS',
              ),
              _statusIndicator(
                _statusColor(_VisitStatus.completed),
                'COMPLETED',
              ),
              _statusIndicator(
                _statusColor(_VisitStatus.cancelled),
                'CANCELLED',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCard() {
    final start = _selectedDate.subtract(const Duration(days: 3));
    final days = List<DateTime>.generate(
      10,
      (index) => DateTime(start.year, start.month, start.day + index),
    );

    return Container(
      key: const ValueKey('slider'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: _s(14), horizontal: _s(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: _s(14),
            offset: Offset(0, _s(6)),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: days.map((date) {
            final isSelected = _isSameDate(date, _selectedDate);
            final dayLabel = _weekDayShort(date);
            final hasVisits = _visitsForDay(date).isNotEmpty;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                  _focusedMonth = DateTime(date.year, date.month, 1);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: _s(7)),
                width: _s(52),
                padding: EdgeInsets.symmetric(vertical: _s(10)),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(_s(16)),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: _s(8),
                            offset: Offset(0, _s(3)),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : AppColors.textSecondary.withOpacity(0.7),
                        fontSize: _fs(8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: _s(8)),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.primary,
                        fontSize: _fs(15),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: _s(4)),
                    Container(
                      width: _s(5),
                      height: _s(5),
                      decoration: BoxDecoration(
                        color: hasVisits
                            ? (isSelected ? Colors.white : AppColors.warning)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _calendarNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_s(6)),
      child: Container(
        padding: EdgeInsets.all(_s(4)),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(_s(6)),
        ),
        child: Icon(icon, size: _s(16), color: AppColors.primary),
      ),
    );
  }

  Widget _buildCalendarDays() {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysBefore = firstWeekday - 1;
    final gridStart = firstDayOfMonth.subtract(Duration(days: daysBefore));

    final days = List<DateTime>.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    );

    return Column(
      children: List<Widget>.generate(6, (week) {
        final weekDays = days.skip(week * 7).take(7).toList();
        return Padding(
          padding: EdgeInsets.symmetric(vertical: _s(2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays.map((dayDate) {
              final isCurrentMonth = dayDate.month == _focusedMonth.month;
              final isSelected = _isSameDate(dayDate, _selectedDate);
              final dayVisits = _visitsForDay(dayDate);

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(
                        dayDate.year,
                        dayDate.month,
                        dayDate.day,
                      );
                      _focusedMonth = DateTime(dayDate.year, dayDate.month, 1);
                    });
                  },
                  borderRadius: BorderRadius.circular(_s(8)),
                  child: Column(
                    children: [
                      Container(
                        width: _s(28),
                        height: _s(28),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEDE6DD)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(_s(8)),
                        ),
                        child: Center(
                          child: Text(
                            '${dayDate.day}',
                            style: TextStyle(
                              fontSize: _fs(10),
                              color: !isCurrentMonth
                                  ? AppColors.textSecondary.withOpacity(0.35)
                                  : isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: _s(2)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _markersForVisits(dayVisits),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  List<Widget> _markersForVisits(List<_SiteVisit> visits) {
    if (visits.isEmpty) {
      return [SizedBox(height: _s(4))];
    }

    final uniqueColors = visits
        .map((v) => _statusColor(v.status))
        .toSet()
        .take(2)
        .toList();

    return uniqueColors.map(_dot).toList();
  }

  Widget _dot(Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _s(1)),
      width: _s(4),
      height: _s(4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _statusIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _s(6),
          height: _s(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: _s(3)),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.8),
            fontSize: _fs(7),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(_SiteVisit visit) {
    final statusColor = _statusColor(visit.status);
    final statusLabel = _statusLabel(visit.status);
    final date = visit.dateTime;
    final dateOnly =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeOnly = _formatTime(date);
    final initials = _projectInitials(visit.property);
    final assigneeInitials = _projectInitials(visit.assignee);

    return Padding(
      padding: EdgeInsets.only(bottom: _s(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(_s(12)),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(_s(16)),
          border: Border.all(color: const Color(0xFFCFE0F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: _s(8),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: _s(18),
                  backgroundColor: const Color(0xFFE8ECF3),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: const Color(0xFF0A7AF6),
                      fontWeight: FontWeight.w800,
                      fontSize: _fs(12),
                    ),
                  ),
                ),
                SizedBox(width: _s(10)),
                Expanded(
                  child: Text(
                    '${visit.property}\n${visit.lead}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: _fs(13.2),
                      height: 1.35,
                    ),
                  ),
                ),
                _miniChip(
                  label: statusLabel.toUpperCase(),
                  background: const Color(0xFFEDE6EF),
                  textColor: const Color(0xFFD11F8A),
                ),
              ],
            ),
            SizedBox(height: _s(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Project',
                    icon: Icons.apartment_outlined,
                    value: visit.property,
                  ),
                ),
                SizedBox(width: _s(14)),
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Transport',
                    icon: Icons.local_taxi_outlined,
                    value: visit.transport,
                  ),
                ),
              ],
            ),
            SizedBox(height: _s(8)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Date',
                    icon: Icons.calendar_today_outlined,
                    value: dateOnly,
                  ),
                ),
                SizedBox(width: _s(14)),
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Time',
                    icon: Icons.schedule_outlined,
                    value: timeOnly,
                  ),
                ),
              ],
            ),
            SizedBox(height: _s(10)),
            Row(
              children: [
                CircleAvatar(
                  radius: _s(14),
                  backgroundColor: const Color(0xFFE8ECF3),
                  child: Text(
                    assigneeInitials,
                    style: TextStyle(
                      color: const Color(0xFF3E6DC8),
                      fontSize: _fs(9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: _s(8)),
                Expanded(
                  child: Text(
                    visit.assignee,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: _fs(12.3),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _cardActionButton(
                  icon: Icons.call_outlined,
                  onTap: () => _handleVisitAction('assign', visit),
                ),
                SizedBox(width: _s(6)),
                _cardActionButton(
                  icon: Icons.check_circle_outline,
                  onTap: () => _handleVisitAction('status', visit),
                ),
                SizedBox(width: _s(6)),
                _cardActionButton(
                  icon: Icons.edit_outlined,
                  onTap: () => _handleVisitAction('reschedule', visit),
                ),
                SizedBox(width: _s(6)),
                _cardActionButton(
                  icon: Icons.visibility_outlined,
                  onTap: () => _handleVisitAction('feedback', visit),
                ),
                SizedBox(width: _s(6)),
                _cardActionButton(
                  icon: Icons.delete_outline,
                  onTap: () {},
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitInfoBlock({
    required String label,
    required IconData icon,
    required String value,
    Color iconColor = AppColors.textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: _fs(9.8),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: _s(4)),
        Row(
          children: [
            Icon(icon, size: _s(13), color: iconColor),
            SizedBox(width: _s(6)),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: _fs(11.2),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _visitDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _s(82),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: _fs(9.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: _fs(10.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_s(10)),
      child: Container(
        width: _s(34),
        height: _s(34),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF2F8),
          borderRadius: BorderRadius.circular(_s(10)),
        ),
        child: Icon(icon, size: _s(16), color: AppColors.textSecondary),
      ),
    );
  }

  String _projectInitials(String project) {
    final cleaned = project.trim();
    if (cleaned.isEmpty) return 'NA';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    if (letters.length == 1) {
      return '${letters}X';
    }
    return letters;
  }

  Widget _miniChip({
    required String label,
    Color? background,
    Color? textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _s(7), vertical: _s(4)),
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF5F3F0),
        borderRadius: BorderRadius.circular(_s(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _fs(8.5),
              fontWeight: FontWeight.w700,
              color: textColor ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: AppColors.textSecondary.withOpacity(0.6),
            size: _s(26),
          ),
          SizedBox(height: _s(8)),
          Text(
            'No visits scheduled for this date',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: _fs(12),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: _s(5)),
          Text(
            'Tap Schedule to create a new site visit.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: _fs(10)),
          ),
          SizedBox(height: _s(10)),
          FilledButton(
            onPressed: () => _openVisitEditor(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_s(10)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: _s(12),
                vertical: _s(8),
              ),
            ),
            child: Text(
              'Schedule Visit',
              style: TextStyle(fontSize: _fs(10.5)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVisitEditor({_SiteVisit? visit}) async {
    final formKey = GlobalKey<FormState>();
    final propertyController = TextEditingController(
      text: visit?.property ?? '',
    );
    final leadController = TextEditingController(text: visit?.lead ?? '');
    final locationController = TextEditingController(
      text: visit?.location ?? '',
    );

    DateTime selectedDate = visit?.dateTime ?? _selectedDate;
    TimeOfDay selectedTime = visit != null
        ? TimeOfDay(hour: visit.dateTime.hour, minute: visit.dateTime.minute)
        : TimeOfDay.now();
    String selectedAssignee = visit?.assignee ?? _teamMembers.first;

    final result = await showDialog<_SiteVisit>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                visit == null ? 'Schedule Site Visit' : 'Reschedule Visit',
              ),
              content: SizedBox(
                width: (_screenWidth * 0.86).clamp(280, 420).toDouble(),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: propertyController,
                          decoration: const InputDecoration(
                            labelText: 'Property Name',
                            prefixIcon: Icon(Icons.home_work_outlined),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter property name'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: leadController,
                          decoration: const InputDecoration(
                            labelText: 'Lead Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter lead name'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter location'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedAssignee,
                          isExpanded: true,
                          menuMaxHeight: 220,
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            hintText: 'Select team member',
                            prefixIcon: Icon(Icons.groups_outlined),
                          ),
                          items: _teamMembers
                              .map(
                                (member) => DropdownMenuItem<String>(
                                  value: member,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(member),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => selectedAssignee = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 90),
                                    ),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null) {
                                    setLocalState(() => selectedDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime,
                                  );
                                  if (picked != null) {
                                    setLocalState(() => selectedTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.schedule),
                                label: Text(selectedTime.format(context)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final dateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    Navigator.pop(
                      context,
                      _SiteVisit(
                        id:
                            visit?.id ??
                            'SV-${DateTime.now().millisecondsSinceEpoch}',
                        property: propertyController.text.trim(),
                        lead: leadController.text.trim(),
                        location: locationController.text.trim(),
                        transport: visit?.transport ?? 'Self',
                        dateTime: dateTime,
                        imageUrl:
                            visit?.imageUrl ?? _demoImages[_visits.length % 4],
                        assignee: selectedAssignee,
                        status: visit?.status ?? _VisitStatus.scheduled,
                        feedback: visit?.feedback ?? '',
                        rating: visit?.rating ?? 0,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(visit == null ? 'Schedule' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    propertyController.dispose();
    leadController.dispose();
    locationController.dispose();

    if (result == null) return;

    setState(() {
      final index = _visits.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _visits[index] = result;
      } else {
        _visits.add(result);
      }
      _selectedDate = DateTime(
        result.dateTime.year,
        result.dateTime.month,
        result.dateTime.day,
      );
      _focusedMonth = DateTime(result.dateTime.year, result.dateTime.month, 1);
    });
  }

  Future<void> _handleVisitAction(String action, _SiteVisit visit) async {
    if (action == 'reschedule') {
      await _openVisitEditor(visit: visit);
      return;
    }
    if (action == 'assign') {
      await _showAssigneePicker(visit);
      return;
    }
    if (action == 'status') {
      await _showStatusPicker(visit);
      return;
    }
    if (action == 'feedback') {
      await _captureFeedback(visit);
      return;
    }
  }

  Future<void> _showAssigneePicker(_SiteVisit visit) async {
    final assignee = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Team Member',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._teamMembers.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member),
                  trailing: member == visit.assignee
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.tertiary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, member),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (assignee == null) return;
    setState(() {
      visit.assignee = assignee;
    });
  }

  Future<void> _showStatusPicker(_SiteVisit visit) async {
    final status = await showModalBottomSheet<_VisitStatus>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Visit Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ..._VisitStatus.values.map(
                (status) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(_statusLabel(status)),
                  trailing: visit.status == status
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.tertiary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, status),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (status == null) return;
    setState(() {
      visit.status = status;
    });
  }

  Future<void> _captureFeedback(_SiteVisit visit) async {
    final noteController = TextEditingController(text: visit.feedback);
    int selectedRating = visit.rating;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Capture Visit Feedback'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        onPressed: () =>
                            setLocalState(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.warning,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Write key points discussed during the visit...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final savedNote = noteController.text.trim();
    noteController.dispose();
    if (result != true) return;
    setState(() {
      visit.feedback = savedNote;
      visit.rating = selectedRating;
      if (visit.status == _VisitStatus.scheduled) {
        visit.status = _VisitStatus.completed;
      }
    });
  }

  int _countByStatus(_VisitStatus status) {
    return _visits.where((visit) => visit.status == status).length;
  }

  List<_SiteVisit> _visitsForDay(DateTime day) {
    return _visits.where((visit) => _isSameDate(visit.dateTime, day)).toList();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      );
      if (_selectedDate.month != _focusedMonth.month ||
          _selectedDate.year != _focusedMonth.year) {
        _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      }
    });
  }

  String _monthLabel(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _weekDayShort(DateTime date) {
    const days = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  String _statusLabel(_VisitStatus status) {
    switch (status) {
      case _VisitStatus.scheduled:
        return 'Scheduled';
      case _VisitStatus.inProgress:
        return 'In Progress';
      case _VisitStatus.completed:
        return 'Completed';
      case _VisitStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(_VisitStatus status) {
    switch (status) {
      case _VisitStatus.scheduled:
        return AppColors.warning;
      case _VisitStatus.inProgress:
        return AppColors.info;
      case _VisitStatus.completed:
        return AppColors.tertiary;
      case _VisitStatus.cancelled:
        return AppColors.error;
    }
  }
}
