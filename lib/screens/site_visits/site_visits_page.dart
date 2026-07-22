// ignore_for_file: use_build_context_synchronously, unused_element

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/site_visits/lead_site_visit_form_page.dart';
import 'package:nextone/screens/site_visits/site_revisits_page.dart';
import 'package:nextone/screens/site_visits/site_visit_details_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/utils/app_feedback.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_error_handler.dart';

class SiteVisitsPage extends StatefulWidget {
  const SiteVisitsPage({super.key});

  @override
  State<SiteVisitsPage> createState() => _SiteVisitsPageState();
}

enum _VisitStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  rescheduled,
  noShow,
}

enum _VisitScope { myItems, team }

class _SiteVisit {
  _SiteVisit({
    required this.id,
    required this.property,
    required this.lead,
    required this.leadPhone,
    required this.location,
    required this.transport,
    required this.dateTime,
    required this.imageUrl,
    required this.assignee,
    this.closingPerson = '',
    this.status = _VisitStatus.scheduled,
    this.feedback = '',
    this.rating = 0,
    this.leadId = '',
    this.projectId = '',
    this.assigneeId = '',
    this.rawData = const <String, dynamic>{},
  });

  final String id;
  String property;
  String lead;
  String leadPhone;
  String location;
  String transport;
  DateTime dateTime;
  String imageUrl;
  String assignee;
  String closingPerson;
  _VisitStatus status;
  String feedback;
  int rating;
  String leadId;
  String projectId;
  String assigneeId;
  Map<String, dynamic> rawData;
}

class _TeamMemberOption {
  const _TeamMemberOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _ScheduleRevisitResult {
  const _ScheduleRevisitResult({
    required this.statusUpdated,
  });

  final bool statusUpdated;
}

class _SiteVisitsPageState extends State<SiteVisitsPage> {
  final AuthProvider _authProvider = AuthProvider();
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
  bool _isExporting = false;
  bool _isLoadingVisits = false;
  String? _loadError;
  String _currentRole = '';
  _VisitScope _selectedScope = _VisitScope.team;
  String _selectedStatus = '';
  int _currentPage = 1;
  final int _perPage = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  late List<_SiteVisit> _visits;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visits = <_SiteVisit>[];
    _loadAccess();
    _loadSiteVisits();
  }

  bool get _canExportData => RoleAccess.canExportModule('site_visits');
  bool get _showExportButton =>
      _canExportData && RoleAccess.isAdminOrSuperAdmin(_currentRole);
  bool get _canDeleteSiteVisits => RoleAccess.canDeleteModule('site_visits');
  bool get _isMyScope => _selectedScope == _VisitScope.myItems;
  bool get _showScopeTabs =>
      _currentRole.isNotEmpty &&
      !RoleAccess.isSuperAdmin(_currentRole) &&
      !RoleAccess.isAdmin(_currentRole);

  Iterable<_SiteVisit> get _statusFilteredVisits {
    if (!_isMyScope || _selectedStatus.trim().isEmpty) {
      return _visits;
    }
    final filterStatus = _statusFromApi(_selectedStatus);
    return _visits.where((visit) => visit.status == filterStatus);
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Export actions stay hidden if access cannot be resolved.
    }
  }

  List<_SiteVisit> get _selectedDayVisits {
    final list = _statusFilteredVisits
        .where((visit) => _isSameDate(visit.dateTime, _selectedDate))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<_SiteVisit> get _allVisitsSorted {
    final list = List<_SiteVisit>.from(_statusFilteredVisits)
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
    return 'All Site Visits';
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  SizedBox(width: _s(6)),
                  _buildExportButton(),
                ],
              ),
              if (_showScopeTabs) ...[
                SizedBox(height: _s(10)),
                _buildScopeTabs(),
              ],
              SizedBox(height: _s(10)),
              _buildQuickActions(),
              SizedBox(height: _s(12)),
              _buildStatusAndRevisitsRow(),
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
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: _fs(9),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
              SizedBox(height: _s(12)),
              if (_isLoadingVisits)
                const Center(child: CircularProgressIndicator())
              else if (_loadError != null)
                _buildErrorState()
              else if (visibleVisits.isEmpty)
                _buildEmptyState()
              else
                ...visibleVisits.map(_buildVisitCard),
              if (!_isLoadingVisits &&
                  _loadError == null &&
                  _totalPages > 1) ...[
                SizedBox(height: _s(12)),
                _buildPaginationControls(),
              ],
              SizedBox(height: _s(90)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final compact = _isCompactMobile;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        final scheduledTile = _buildKpiTile(
          label: 'Scheduled',
          value: _countByStatus(_VisitStatus.scheduled).toString(),
          color: AppColors.warning,
        );
        final completedTile = _buildKpiTile(
          label: 'Completed',
          value: _countByStatus(_VisitStatus.completed).toString(),
          color: AppColors.tertiary,
        );
        final scheduleButton = Builder(
          builder: (buttonContext) {
            return FilledButton.icon(
              onPressed: () => _openScheduleMenu(buttonContext),
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
            );
          },
        );

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: scheduledTile),
                  SizedBox(width: _s(8)),
                  Expanded(child: completedTile),
                ],
              ),
              SizedBox(height: _s(8)),
              SizedBox(width: constraints.maxWidth, child: scheduleButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: scheduledTile),
            SizedBox(width: _s(8)),
            Expanded(child: completedTile),
            SizedBox(width: _s(8)),
            Expanded(child: scheduleButton),
          ],
        );
      },
    );
  }

  Widget _buildStatusAndRevisitsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        final revisitButton = SizedBox(
          height: _s(46),
          width: isNarrow ? constraints.maxWidth : 170,
          child: OutlinedButton.icon(
            onPressed: _openRevisitsPage,
            icon: const Icon(Icons.repeat_rounded, size: 18),
            label: const Text('Open Re-visits'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side:
                  BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
              minimumSize: const Size(0, 46),
              padding: EdgeInsets.symmetric(horizontal: _s(14)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_s(12)),
              ),
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusFilterBar(),
              SizedBox(height: _s(10)),
              revisitButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildStatusFilterBar()),
            SizedBox(width: _s(10)),
            revisitButton,
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterBar() {
    final statusOptions = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: '',
        child: Text('All'),
      ),
      const DropdownMenuItem<String>(
        value: 'scheduled',
        child: Text('scheduled'),
      ),
      const DropdownMenuItem<String>(
        value: 'done',
        child: Text('done'),
      ),
      const DropdownMenuItem<String>(
        value: 'cancelled',
        child: Text('cancelled'),
      ),
      const DropdownMenuItem<String>(
        value: 'rescheduled',
        child: Text('rescheduled'),
      ),
      const DropdownMenuItem<String>(
        value: 'no_show',
        child: Text('no_show'),
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedStatus,
          isExpanded: true,
          iconEnabledColor: AppColors.primary,
          dropdownColor: Colors.white,
          menuMaxHeight: 260,
          borderRadius: BorderRadius.circular(_s(12)),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: _fs(12),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: _s(12),
              vertical: _s(12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_s(12)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_s(12)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_s(12)),
              borderSide: BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
          selectedItemBuilder: (context) {
            return statusOptions.map((item) {
              final label = (item.child as Text).data ?? 'All';
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: _fs(12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList();
          },
          items: statusOptions
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.value,
                  child: Text(
                    (item.child as Text).data ?? 'All',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _isLoadingVisits
              ? null
              : (value) {
                  setState(() {
                    _selectedStatus = value ?? '';
                  });
                  _loadSiteVisits(page: 1);
                },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return PaginationWidget(
      currentPage: _currentPage,
      totalPages: _totalPages,
      totalItems: _totalItems,
      itemLabel: 'records',
      onPageChanged: (page) => _loadSiteVisits(page: page),
    );
  }

  Widget _buildExportButton() {
    if (!_showExportButton) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      onPressed: _isExporting ? null : _exportSiteVisits,
      icon: _isExporting
          ? SizedBox(
              width: _s(16),
              height: _s(16),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.download_rounded,
              size: _s(18),
            ),
      label: Text(_isExporting ? 'Exporting...' : 'Export'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        minimumSize: Size(0, _s(40)),
        padding: EdgeInsets.symmetric(horizontal: _s(12), vertical: _s(8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_s(10)),
        ),
        textStyle: TextStyle(
          fontSize: _fs(12),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<DateTimeRange?> _showExportDateRangeDialog() async {
    final now = DateTime.now();
    DateTime? fromDate;
    DateTime? toDate;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formatDate(DateTime? date) =>
                date == null ? '' : _formatDateForApi(date);

            Future<void> pickFromDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fromDate ?? now,
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                fromDate = DateTime(picked.year, picked.month, picked.day);
                if (toDate != null && toDate!.isBefore(fromDate!)) {
                  toDate = fromDate;
                }
              });
            }

            Future<void> pickToDate() async {
              final baseDate = toDate ?? fromDate ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: baseDate,
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                toDate = DateTime(picked.year, picked.month, picked.day);
              });
            }

            final isValidRange = fromDate != null &&
                toDate != null &&
                !toDate!.isBefore(fromDate!);

            Widget dateField({
              required String label,
              required String value,
              required String placeholder,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(value.isEmpty ? placeholder : value),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Export Site Visits'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dateField(
                    label: 'Start date',
                    value: formatDate(fromDate),
                    placeholder: 'Select start date',
                    onTap: pickFromDate,
                  ),
                  const SizedBox(height: 12),
                  dateField(
                    label: 'End date',
                    value: formatDate(toDate),
                    placeholder: 'Select end date',
                    onTap: pickToDate,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isValidRange
                      ? () => Navigator.of(context).pop(
                            DateTimeRange(start: fromDate!, end: toDate!),
                          )
                      : null,
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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

  Widget _buildScopeTabs() {
    return Container(
      padding: EdgeInsets.all(_s(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(_s(12)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _scopeTabItem(
              label: 'My Site Visit',
              isActive: _isMyScope,
              onTap: () {
                if (_isMyScope) return;
                setState(() {
                  _selectedScope = _VisitScope.myItems;
                  _currentPage = 1;
                });
                _loadSiteVisits(page: 1);
              },
            ),
          ),
          SizedBox(width: _s(6)),
          Expanded(
            child: _scopeTabItem(
              label: 'Team',
              isActive: !_isMyScope,
              onTap: () {
                if (!_isMyScope) return;
                setState(() {
                  _selectedScope = _VisitScope.team;
                  _currentPage = 1;
                });
                _loadSiteVisits(page: 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeTabItem({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(_s(9)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(10)),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(_s(9)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: _s(10),
                    offset: Offset(0, _s(4)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontSize: _fs(12),
            fontWeight: FontWeight.w700,
          ),
        ),
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
                    color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.03),
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
                                  ? AppColors.textSecondary
                                      .withValues(alpha: 0.35)
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

    final uniqueColors =
        visits.map((v) => _statusColor(v.status)).toSet().take(2).toList();

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
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: _fs(7),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(_SiteVisit visit) {
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
              color: Colors.black.withValues(alpha: 0.02),
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
                    '${visit.lead}\n${visit.property}',
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
            SizedBox(height: _s(8)),
            Row(
              children: [
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Rating',
                    icon: Icons.star_rounded,
                    value: visit.rating > 0 ? '${visit.rating}/5' : 'N/A',
                    iconColor: Colors.amber,
                  ),
                ),
                SizedBox(width: _s(14)),
                Expanded(
                  child: _visitInfoBlock(
                    label: 'Closing Person',
                    icon: Icons.person_pin_circle_outlined,
                    value: visit.closingPerson.isNotEmpty
                        ? visit.closingPerson
                        : 'N/A',
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
                  icon: Icons.phone_outlined,
                  iconColor: AppColors.primary,
                  onTap: _isValidPhone(visit.leadPhone)
                      ? () => _launchCaller(visit.leadPhone)
                      : null,
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
                  onTap: () => _handleVisitAction('view', visit),
                ),
                if (_canDeleteSiteVisits) ...[
                  SizedBox(width: _s(6)),
                  _cardActionButton(
                    icon: Icons.delete_outline,
                    onTap: () {},
                  ),
                ]
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

  Widget _cardActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color? iconColor,
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
        child: Icon(
          icon,
          size: _s(16),
          color: onTap == null
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : (iconColor ?? AppColors.textSecondary),
        ),
      ),
    );
  }

  bool _isValidPhone(String phone) {
    final cleaned = phone.trim();
    return cleaned.isNotEmpty && cleaned.toLowerCase() != 'n/a';
  }

  Future<void> _launchCaller(String? phone) async {
    final normalizedPhone = (phone ?? '').trim();
    if (normalizedPhone.isEmpty || normalizedPhone.toLowerCase() == 'n/a') {
      return;
    }
    final uri = Uri.parse('tel:$normalizedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            size: _s(26),
          ),
          SizedBox(height: _s(8)),
          Text(
            _isCalendarView
                ? 'No visits scheduled for this date'
                : 'No site visits found.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: _fs(12),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: _s(5)),
          Text(
            _isCalendarView
                ? 'Tap Schedule to create a new site visit.'
                : 'Try a different status or page.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: _fs(10)),
          ),
          SizedBox(height: _s(10)),
          FilledButton(
            onPressed: () => _openScheduleMenu(context),
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

  Future<void> _openScheduleMenu(BuildContext buttonContext) async {
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      await _openScheduleForm();
      return;
    }

    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = renderBox.localToGlobal(
      Offset(renderBox.size.width, renderBox.size.height),
      ancestor: overlay,
    );

    final choice = await showMenu<String>(
      context: buttonContext,
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy + 8,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - bottomRight.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'existing',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20),
              SizedBox(width: 10),
              Text('Existing Lead'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'new',
          child: Row(
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 10),
              Text('New Lead + Site Visit'),
            ],
          ),
        ),
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == 'new') {
      await _openScheduleWithLeadForm();
      return;
    }

    await _openScheduleForm();
  }

  Future<void> _openScheduleForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    if (_isCalendarView) {
      setState(() {
        _isCalendarView = false;
      });
    }

    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SiteVisitFormPage()),
    );

    if (created == null || !mounted) {
      return;
    }
    await _loadSiteVisits(page: _currentPage);

    _showSnackBar('Site visit scheduled successfully.');
  }

  Future<void> _openScheduleWithLeadForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    if (_isCalendarView) {
      setState(() {
        _isCalendarView = false;
      });
    }

    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LeadSiteVisitFormPage()),
    );

    if (created == null || !mounted) {
      return;
    }
    await _loadSiteVisits(page: _currentPage);

    _showSnackBar('Site visit scheduled successfully.');
  }

  Future<void> _openRevisitsPage() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'revisits',
      action: 'view',
      moduleLabel: 're-visits',
    );
    if (!allowed) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SiteRevisitsPage(showBackButton: true),
      ),
    );
  }

  Future<void> _openEditVisitForm(_SiteVisit visit) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'edit',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    final visitData = <String, dynamic>{
      'lead_id': visit.leadId,
      'lead_name': visit.lead,
      'project_id': visit.projectId,
      'project_name': visit.property,
      'assigned_to': visit.assigneeId,
      'assignee_name': visit.assignee,
      'visit_date': DateTime(
        visit.dateTime.year,
        visit.dateTime.month,
        visit.dateTime.day,
      ).toIso8601String(),
      'visit_time':
          '${visit.dateTime.hour.toString().padLeft(2, '0')}:${visit.dateTime.minute.toString().padLeft(2, '0')}',
      'notes': visit.feedback,
      'transport_arranged': visit.transport.toLowerCase() != 'self',
    };

    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SiteVisitFormPage(
          visitId: visit.id,
          visitData: visitData,
        ),
      ),
    );

    if (updated == null || !mounted) {
      return;
    }
    await _loadSiteVisits(page: _currentPage);

    _showSnackBar('Site visit updated successfully.');
  }

  void _openVisitDetails(_SiteVisit visit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteVisitDetailsPage(
          visitId: visit.id,
          visitData: visit.rawData,
        ),
      ),
    );
  }

  Future<void> _handleVisitAction(String action, _SiteVisit visit) async {
    if (action == 'view') {
      _openVisitDetails(visit);
      return;
    }
    if (action == 'reschedule') {
      await _openScheduleRevisitDialog(visit);
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
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'edit',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

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
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'edit',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    final noteController = TextEditingController();
    final closingPersonController = TextEditingController();
    bool isSubmitting = false;
    _VisitStatus selectedStatus = visit.status;
    bool shouldOpenRevisitDialog = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              if (selectedStatus == _VisitStatus.rescheduled) {
                shouldOpenRevisitDialog = true;
                Navigator.of(context).pop(false);
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.updateSiteVisitStatus(
                  id: visit.id,
                  status: _apiStatus(selectedStatus),
                  note: noteController.text.trim(),
                  closingPerson: closingPersonController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                _showSnackBar(AppErrorHandler.friendlyMessage(e));
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 560,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Update Visit Status',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Status'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<_VisitStatus>(
                          initialValue: selectedStatus,
                          decoration: _fieldDecoration(),
                          items: _VisitStatus.values
                              .map(
                                (status) => DropdownMenuItem<_VisitStatus>(
                                  value: status,
                                  child: Text(_statusLabel(status)),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (value) => setLocalState(
                                    () => selectedStatus =
                                        value ?? _VisitStatus.scheduled,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Note (optional)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: noteController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          decoration: _fieldDecoration(
                            hint: 'Add a note about this status update...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Closing Person (optional)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: closingPersonController,
                          enabled: !isSubmitting,
                          decoration: _fieldDecoration(
                            hint: 'Rajesh Kumar',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSubmitting ? null : submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
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
                                    : const Text('Update Status'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    closingPersonController.dispose();
    if (shouldOpenRevisitDialog && mounted) {
      await _openScheduleRevisitDialog(visit);
      return;
    }
    if (updated == true && mounted) {
      setState(() {
        visit.status = selectedStatus;
      });
      _showSnackBar('Site visit status updated.');
    }
  }

  Future<void> _openScheduleRevisitDialog(_SiteVisit visit) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'revisits',
      action: 'create',
      moduleLabel: 're-visits',
    );
    if (!allowed || !mounted) return;

    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final members = await _loadActiveTeamMembers();
    if (!mounted) return;

    final now = DateTime.now();
    final firstAllowedDate = DateTime(now.year, now.month, now.day);
    final defaultDate = visit.dateTime.isAfter(firstAllowedDate)
        ? DateTime(visit.dateTime.year, visit.dateTime.month, visit.dateTime.day)
        : firstAllowedDate.add(const Duration(days: 1));
    DateTime? selectedDate = defaultDate;
    TimeOfDay? selectedTime = TimeOfDay.fromDateTime(visit.dateTime);
    bool transportArranged = visit.rawData['transport_arranged'] == true;
    bool isSubmitting = false;

    _TeamMemberOption? selectedMember;
    final currentAssigneeId = visit.assigneeId.trim();
    if (currentAssigneeId.isNotEmpty) {
      for (final member in members) {
        if (member.id == currentAssigneeId) {
          selectedMember = member;
          break;
        }
      }
    }

    final result = await showDialog<_ScheduleRevisitResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final dateLabel =
                selectedDate == null ? 'Select date' : _toYmd(selectedDate!);
            final timeLabel = selectedTime == null
                ? '--:--'
                : _formatTimeOfDay(selectedTime!);

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? defaultDate,
                firstDate: firstAllowedDate,
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              setLocalState(() => selectedDate = picked);
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
              );
              if (picked == null) return;
              setLocalState(() => selectedTime = picked);
            }

            Future<void> submit() async {
              final assignedToId =
                  (selectedMember?.id ?? visit.assigneeId).trim();
              if (selectedDate == null || selectedTime == null) {
                _showSnackBar('Visit date and time are required.');
                return;
              }
              if (assignedToId.isEmpty) {
                _showSnackBar('Assign To is required.');
                return;
              }
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar('Reason for re-visit is required.');
                return;
              }

              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.createSiteRevisit(
                  originalVisitId: visit.id,
                  visitDate: _toYmd(selectedDate!),
                  visitTime: _formatTimeOfDay(selectedTime!),
                  assignedTo: assignedToId,
                  reason: reasonController.text.trim(),
                  notes: notesController.text.trim(),
                  transportArranged: transportArranged,
                  token: _authProvider.currentAuthToken,
                );

                var statusUpdated = false;
                try {
                  await _authProvider.updateSiteVisitStatus(
                    id: visit.id,
                    status: _apiStatus(_VisitStatus.rescheduled),
                    note: notesController.text.trim(),
                    token: _authProvider.currentAuthToken,
                  );
                  statusUpdated = true;
                } catch (_) {
                  statusUpdated = false;
                }

                if (!context.mounted) return;
                Navigator.of(context).pop(
                  _ScheduleRevisitResult(statusUpdated: statusUpdated),
                );
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                _showSnackBar(AppErrorHandler.friendlyMessage(e));
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: 560,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Schedule Re-visit',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.tertiary,
                                child: Text(
                                  _visitInitials(visit),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      visit.lead,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${visit.property} - Original Visit: ${_toYmd(visit.dateTime)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Date *',
                                value: dateLabel,
                                icon: Icons.calendar_today_outlined,
                                onTap: isSubmitting ? null : pickDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Time *',
                                value: timeLabel,
                                icon: Icons.access_time_outlined,
                                onTap: isSubmitting ? null : pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Assign To'),
                        const SizedBox(height: 6),
                        SearchableDropdownField<_TeamMemberOption>(
                          label: 'Assign To',
                          sheetTitle: 'Assign To',
                          showFieldLabel: false,
                          value: selectedMember,
                          hintText: 'Select team member',
                          items: members
                              .map(
                                (member) =>
                                    SearchableDropdownItem<_TeamMemberOption>(
                                  value: member,
                                  label: member.name,
                                ),
                              )
                              .toList(),
                          enabled: !isSubmitting,
                          onChanged: (value) =>
                              setLocalState(() => selectedMember = value),
                        ),
                        const SizedBox(height: 12),
                        const Text('Reason for Re-visit *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: reasonController,
                          enabled: !isSubmitting,
                          decoration: _fieldDecoration(
                            hint: 'Client wanted to see units again...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Notes'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          decoration: _fieldDecoration(
                            hint: 'Bring updated price list...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: transportArranged,
                          onChanged: isSubmitting
                              ? null
                              : (value) => setLocalState(
                                    () => transportArranged = value ?? false,
                                  ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Transport arranged for client'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSubmitting ? null : submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
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
                                    : const Text('Schedule Re-visit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    reasonController.dispose();
    notesController.dispose();

    if (result == null || !mounted) return;

    await _loadSiteVisits(page: _currentPage);
    if (!mounted) return;

    if (result.statusUpdated) {
      _showSnackBar('Re-visit scheduled successfully.');
    } else {
      _showSnackBar(
        'Re-visit scheduled, but the original visit status was not updated.',
      );
    }
  }

  Future<void> _captureFeedback(_SiteVisit visit) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'edit',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

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
    try {
      await _authProvider.submitSiteVisitFeedback(
        id: visit.id,
        rating: selectedRating,
        clientReaction: selectedRating >= 4 ? 'positive' : 'neutral',
        interestedIn: visit.property,
        nextStep: 'follow_up',
        remarks: savedNote,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        visit.feedback = savedNote;
        visit.rating = selectedRating;
        if (visit.status == _VisitStatus.scheduled) {
          visit.status = _VisitStatus.completed;
        }
      });
      _showSnackBar('Feedback submitted.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    }
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
      case _VisitStatus.rescheduled:
        return 'Rescheduled';
      case _VisitStatus.noShow:
        return 'No Show';
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
      case _VisitStatus.rescheduled:
        return AppColors.info;
      case _VisitStatus.noShow:
        return const Color(0xFF6B7280);
    }
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                Icon(icon, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<_TeamMemberOption>> _loadActiveTeamMembers() async {
    final usersRaw = await _authProvider.assignmentUsers(
      token: _authProvider.currentAuthToken,
    );
    final membersById = <String, _TeamMemberOption>{};

    for (final raw in usersRaw) {
      if (!_isActiveUser(raw)) continue;
      final id = _readString(
        raw['id'] ?? raw['user_id'] ?? raw['userId'] ?? raw['uuid'],
      );
      if (id.isEmpty) continue;

      final baseName = _readString(
        raw['full_name'] ??
            raw['name'] ??
            '${raw['first_name'] ?? ''} ${raw['last_name'] ?? ''}',
      );
      final readableRole = _roleLabel(raw);
      membersById[id] = _TeamMemberOption(
        id: id,
        name: readableRole.isEmpty ? baseName : '$baseName ($readableRole)',
      );
    }

    final members = membersById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  bool _isActiveUser(Map<String, dynamic> user) {
    final value =
        user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = _readString(value).toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  String _roleLabel(Map<String, dynamic> user) {
    final rawRole = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
    );
    if (rawRole.isEmpty) return '';
    return rawRole
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _toYmd(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _visitInitials(_SiteVisit visit) {
    final source = visit.lead.trim().isNotEmpty ? visit.lead.trim() : visit.property;
    final parts = source
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    if (parts.isEmpty) return 'SV';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts[0].isEmpty ? '' : parts[0][0];
    final second = parts[1].isEmpty ? '' : parts[1][0];
    final initials = '$first$second'.trim().toUpperCase();
    return initials.isEmpty ? 'SV' : initials;
  }

  Future<void> _loadSiteVisits({int? page}) async {
    final targetPage = page ?? _currentPage;
    setState(() {
      _isLoadingVisits = true;
      _loadError = null;
    });

    try {
      final result = _isMyScope
          ? await _authProvider.mySiteVisits(
              token: _authProvider.currentAuthToken,
              page: targetPage,
              perPage: _perPage,
            )
          : await _authProvider.siteVisits(
              token: _authProvider.currentAuthToken,
              status: _selectedStatus.trim().isEmpty
                  ? null
                  : _selectedStatus.trim(),
              page: targetPage,
              perPage: _perPage,
            );
      final mapped = result.items
          .map(_visitFromApi)
          .whereType<_SiteVisit>()
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (!mounted) {
        return;
      }
      setState(() {
        _visits = mapped;
        _currentPage =
            result.currentPage <= 0 ? targetPage : result.currentPage;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _totalItems = result.totalItems;
        _isLoadingVisits = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingVisits = false;
        _loadError = AppErrorHandler.friendlyMessage(e);
      });
    }
  }

  _SiteVisit? _visitFromApi(Map<String, dynamic> json) {
    final id = _readString(json['id']);
    if (id.isEmpty) {
      return null;
    }

    final leadMap = json['lead'] is Map<String, dynamic>
        ? (json['lead'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final projectMap = json['project'] is Map<String, dynamic>
        ? (json['project'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final assignedToMap = json['assigned_to'] is Map<String, dynamic>
        ? (json['assigned_to'] as Map<String, dynamic>)
        : const <String, dynamic>{};

    final visitDate = _readString(json['visit_date']);
    final visitTime = _readString(json['visit_time']);
    final parsedDateTime = _parseVisitDateTime(visitDate, visitTime);

    final leadName = _readString(
      json['lead_name'] ??
          leadMap['name'] ??
          leadMap['full_name'] ??
          leadMap['first_name'],
    );
    final leadPhone = _readString(
      json['lead_phone'] ?? leadMap['phone'] ?? leadMap['mobile'],
    );
    final projectName = _readString(json['project_name'] ?? projectMap['name']);
    final assigneeName = _readString(
      json['assigned_to_name'] ??
          json['assigned_to'] ??
          assignedToMap['full_name'] ??
          assignedToMap['name'] ??
          assignedToMap['first_name'],
    );
    final closingPerson = _readString(
      json['closing_person'] ?? json['closingPerson'],
    );
    final status = _statusFromApi(_readString(json['status']));
    final feedbackMap = json['feedback'] is Map<String, dynamic>
        ? (json['feedback'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final rating =
        _readInt(json['rating']) ?? _readInt(feedbackMap['rating']) ?? 0;
    final feedbackText = _readString(
      feedbackMap['remarks'] ??
          feedbackMap['feedback'] ??
          json['remarks'] ??
          json['feedback'],
    );

    return _SiteVisit(
      id: id,
      property: projectName.isEmpty ? 'N/A' : projectName,
      lead: leadName.isEmpty ? 'N/A' : leadName,
      leadPhone: leadPhone.isEmpty ? 'N/A' : leadPhone,
      location: _readString(
        projectMap['address'] ?? projectMap['locality'] ?? projectMap['city'],
      ).isEmpty
          ? 'N/A'
          : _readString(
              projectMap['address'] ??
                  projectMap['locality'] ??
                  projectMap['city'],
            ),
      transport: _readString(json['transport_arranged']).isEmpty
          ? (json['transport_arranged'] == true ? 'true' : 'false')
          : _readString(json['transport_arranged']),
      dateTime: parsedDateTime,
      imageUrl: _demoImages[id.hashCode.abs() % _demoImages.length],
      assignee: assigneeName.isEmpty ? 'Unassigned' : assigneeName,
      closingPerson: closingPerson,
      status: status,
      feedback: feedbackText,
      rating: rating,
      leadId: _readString(json['lead_id'] ?? leadMap['id']),
      projectId: _readString(json['project_id'] ?? projectMap['id']),
      assigneeId: _readString(json['assigned_to'] ?? assignedToMap['id']),
      rawData: json,
    );
  }

  _VisitStatus _statusFromApi(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'done':
      case 'completed':
        return _VisitStatus.completed;
      case 'in_progress':
      case 'in progress':
        return _VisitStatus.inProgress;
      case 'cancelled':
      case 'canceled':
        return _VisitStatus.cancelled;
      case 'rescheduled':
        return _VisitStatus.rescheduled;
      case 'no_show':
      case 'no show':
        return _VisitStatus.noShow;
      case 'scheduled':
      default:
        return _VisitStatus.scheduled;
    }
  }

  String _apiStatus(_VisitStatus status) {
    switch (status) {
      case _VisitStatus.completed:
        return 'done';
      case _VisitStatus.inProgress:
        return 'in_progress';
      case _VisitStatus.cancelled:
        return 'cancelled';
      case _VisitStatus.rescheduled:
        return 'rescheduled';
      case _VisitStatus.noShow:
        return 'no_show';
      case _VisitStatus.scheduled:
        return 'scheduled';
    }
  }

  DateTime _parseVisitDateTime(String dateValue, String timeValue) {
    final date = DateTime.tryParse(dateValue)?.toLocal() ?? DateTime.now();
    final parts = timeValue.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return date;
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

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loadError ?? 'Unable to load site visits.',
            style: TextStyle(color: AppColors.error, fontSize: _fs(12)),
          ),
          SizedBox(height: _s(10)),
          FilledButton(
            onPressed: _loadSiteVisits,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    AppFeedback.showMessage(message, isError: true);
  }

  Future<void> _exportSiteVisits() async {
    if (!_canExportData) {
      _showSnackBar('You do not have permission to export site visits.');
      return;
    }
    final range = await _showExportDateRangeDialog();
    if (!mounted || range == null) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    final from = _formatDateForApi(range.start);
    final to = _formatDateForApi(range.end);
    try {
      final exported = await _authProvider.exportSiteVisits(
        from: from,
        to: to,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      final safeFileName = exported.fileName.trim().isEmpty
          ? 'site_visits_${from}_to_$to.xlsx'
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Export generated ($safeFileName), but direct file save is not supported on Web in this build.',
        );
        return;
      }
      final outFile = await ExportFileHelper.saveToDownloadNextone(
        fileName: safeFileName,
        bytes: exported.bytes,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Site visits export downloaded and saved to: ${outFile.path}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is UnsupportedError
          ? 'This platform does not support local file save for export yet.'
          : AppErrorHandler.friendlyMessage(error);
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
