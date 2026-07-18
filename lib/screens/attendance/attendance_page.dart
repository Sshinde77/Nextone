// ignore_for_file: unused_element

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/screens/attendance/holiday_form_page.dart';
import 'package:nextone/screens/attendance/attendance_user_history_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nextone/widgets/pagination_widget.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  int _selectedTabIndex = 0;
  final AuthProvider _authProvider = AuthProvider();
  final ScrollController _monthGridHorizontalController = ScrollController();
  String _currentRole = '';
  bool _isAttendanceSubmitting = false;
  bool _isExporting = false;
  bool _isCheckedIn = false;
  bool _isLoadingToday = false;
  String? _todayError;
  Map<String, dynamic> _todayAttendance = <String, dynamic>{};
  bool _isLoadingCalendar = false;
  String? _calendarError;
  Map<String, dynamic> _calendarData = <String, dynamic>{};
  bool _isLoadingMyHistory = false;
  String? _myHistoryError;
  Map<String, dynamic> _myHistoryData = <String, dynamic>{};
  bool _isLoadingMonthGrid = false;
  String? _monthGridError;
  Map<String, dynamic> _monthGridData = <String, dynamic>{};
  bool _isLoadingDailyView = false;
  String? _dailyViewError;
  Map<String, dynamic> _dailyViewData = <String, dynamic>{};
  int _dailyViewCurrentPage = 1;
  int _dailyViewTotalPages = 1;
  int _dailyViewTotalItems = 0;
  bool _isLoadingSummary = false;
  String? _summaryError;
  Map<String, dynamic> _summaryData = <String, dynamic>{};
  bool _isLoadingLateReports = false;
  String? _lateReportsError;
  Map<String, dynamic> _lateReportsData = <String, dynamic>{};
  late DateTime _lateReportsFromDate;
  late DateTime _lateReportsToDate;
  bool _isLoadingApprovals = false;
  bool _isApprovingStatus = false;
  String? _approvalsError;
  List<Map<String, dynamic>> _approvalRows = <Map<String, dynamic>>[];
  bool _isLoadingHolidays = false;
  String? _holidaysError;
  List<Map<String, dynamic>> _holidayRows = <Map<String, dynamic>>[];
  int _holidaysCurrentPage = 1;
  int _holidaysTotalPages = 1;
  int _holidaysTotalItems = 0;
  int _selectedHolidayYear = DateTime.now().year;
  List<int> _holidayYears = <int>[];
  late DateTime _calendarMonth;
  late DateTime _dailyViewDate;
  late DateTime _summaryFromDate;
  late DateTime _summaryToDate;
  late DateTime _approvalDate;
  static const List<_TabData> _baseTabs = [
    _TabData('Overview', Icons.bar_chart_rounded),
    _TabData('Calendar', Icons.calendar_month_outlined),
    _TabData('My History', Icons.watch_later_outlined),
    _TabData('Month Grid', Icons.group_outlined),
    _TabData('Daily View', Icons.person_search_outlined),
    _TabData('Summary', Icons.trending_up_rounded),
  ];
  static const List<_TabData> _associateTabs = [
    _TabData('Overview', Icons.bar_chart_rounded),
    _TabData('Calendar', Icons.calendar_month_outlined),
    _TabData('My History', Icons.watch_later_outlined),
    _TabData('Month Grid', Icons.group_outlined),
    _TabData('Daily View', Icons.person_search_outlined),
  ];
  static const List<_TabData> _tierFourTabs = [
    _TabData('Overview', Icons.bar_chart_rounded),
    _TabData('Calendar', Icons.calendar_month_outlined),
    _TabData('My History', Icons.watch_later_outlined),
  ];
  static const List<_TabData> _salesManagerTabs = [
    _TabData('Overview', Icons.bar_chart_rounded),
    _TabData('Calendar', Icons.calendar_month_outlined),
    _TabData('My History', Icons.watch_later_outlined),
    _TabData('Team Month', Icons.group_outlined),
    _TabData('Team Daily', Icons.person_search_outlined),
    _TabData('Team Summary', Icons.trending_up_rounded),
  ];
  static const _TabData _lateReportsTab =
      _TabData('Late Reports', Icons.watch_later_rounded);
  static const _TabData _approvalTab =
      _TabData('Approvals', Icons.how_to_reg_outlined);
  static const _TabData _holidaysTab =
      _TabData('Holidays', Icons.event_available_outlined);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
    _dailyViewDate = DateTime(now.year, now.month, now.day);
    _summaryFromDate = DateTime(now.year, now.month, now.day - 4);
    _summaryToDate = DateTime(now.year, now.month, now.day);
    _lateReportsFromDate = DateTime(now.year, now.month, 1);
    _lateReportsToDate = DateTime(now.year, now.month, now.day);
    _approvalDate = DateTime(now.year, now.month, now.day);
    _loadAccess();
    _loadTodayAttendance();
    _loadCalendarAttendance();
    _loadMyHistoryAttendance();
  }

  @override
  void dispose() {
    _monthGridHorizontalController.dispose();
    super.dispose();
  }

  bool get _canExportData => RoleAccess.canExportModule('attendance');
  bool get _showExportButton =>
      _canExportData && RoleAccess.isAdminOrSuperAdmin(_currentRole);
  bool get _canViewWorkingHours =>
      RoleAccess.isAdmin(_currentRole) || RoleAccess.isSuperAdmin(_currentRole);
  bool get _canViewLateReports =>
      RoleAccess.isAdmin(_currentRole) || RoleAccess.isSuperAdmin(_currentRole);
  bool get _isAssociateRole =>
      RoleAccess.normalize(_currentRole) == 'associate';
  bool get _isSalesManager => RoleAccess.isSalesManager(_currentRole);
  bool get _usesTeamDailyView {
    final normalizedRole = RoleAccess.normalize(_currentRole);
    return {
      'associate',
      'associate_partner',
      'cluster_head',
      'cluster',
      'partner',
      'team_leader',
      'sales_manager',
      'sales_manger',
    }.contains(normalizedRole);
  }

  bool get _usesTeamMonthView => _usesTeamDailyView;

  bool get _hideSummaryAndApprovalsForRole {
    final normalizedRole = RoleAccess.normalize(_currentRole);
    return {
      'associate',
      'associate_partner',
      'cluster_head',
      'cluster',
      'partner',
      'team_leader',
      'sales_manager',
      'sales_manger',
    }.contains(normalizedRole);
  }

  List<_TabData> get _tabs =>
      _currentRole.isEmpty ? _baseTabs : _tabsForRole(_currentRole);

  int get _lateReportsTabIndex => _tabsForRole(_currentRole)
      .indexWhere((tab) => tab.label == 'Late Reports');
  int get _approvalsTabIndex =>
      _tabsForRole(_currentRole).indexWhere((tab) => tab.label == 'Approvals');
  int get _holidaysTabIndex =>
      _tabsForRole(_currentRole).indexWhere((tab) => tab.label == 'Holidays');
  int get _dailyViewTabIndex => _tabsForRole(_currentRole)
      .indexWhere((tab) => tab.label.contains('Daily'));
  int get _summaryTabIndex => _tabsForRole(_currentRole)
      .indexWhere((tab) => tab.label.contains('Summary'));

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        final tabs = _tabsForRole(role);
        if (_selectedTabIndex >= tabs.length) {
          _selectedTabIndex = tabs.length - 1;
        }
        if (RoleAccess.isSalesManager(role)) {
          _approvalRows = <Map<String, dynamic>>[];
          _approvalsError = null;
        }
      });
      final tabs = _tabsForRole(role);
      if (tabs.any((tab) => tab.label.contains('Month'))) {
        _loadMonthGridAttendance();
      }
      if (tabs.any((tab) => tab.label.contains('Daily'))) {
        _loadDailyViewAttendance();
      }
      if (tabs.any((tab) => tab.label.contains('Summary'))) {
        _loadSummaryAttendance();
      }
      if (tabs.any((tab) => tab.label == 'Late Reports')) {
        _loadLateReports();
      }
      if (tabs.any((tab) => tab.label == 'Approvals')) {
        _loadApprovalPending();
      }
      if (tabs.any((tab) => tab.label == 'Holidays')) {
        _loadHolidays();
      }
    } catch (_) {
      // Export actions stay hidden if access cannot be resolved.
    }
  }

  List<_TabData> _tabsForRole(String role) {
    final normalizedRole = RoleAccess.normalize(role);
    if (RoleAccess.isTierFour(role)) {
      return _tierFourTabs;
    }
    final restrictedTabs = _hideSummaryAndApprovalsForRole
        ? <String>{'summary', 'approvals', 'team summary'}
        : <String>{};

    final tabs = RoleAccess.isSalesManager(role)
        ? _salesManagerTabs
        : normalizedRole == 'associate'
            ? _associateTabs
            : <_TabData>[
                ..._baseTabs,
                if (RoleAccess.isAdmin(role) || RoleAccess.isSuperAdmin(role))
                  _lateReportsTab,
                _approvalTab,
                if (RoleAccess.isAdmin(role) || RoleAccess.isSuperAdmin(role))
                  _holidaysTab,
              ];

    if (restrictedTabs.isEmpty) {
      return tabs;
    }

    return tabs.where((tab) {
      final label = tab.label.toLowerCase();
      return !restrictedTabs.any((blocked) => label.contains(blocked));
    }).toList(growable: false);
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                color: Color(0xFF071A3A),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _todayDateLabel(),
              style: const TextStyle(
                color: Color(0xFF5D6B82),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        final actions = [
          _RoundActionButton(
            icon: Icons.refresh_rounded,
            onTap: _loadTodayAttendance,
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.leaveManagement),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.event_busy_outlined, size: 18),
            label: const Text(
              'Leaves',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (_showExportButton)
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportAttendance,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1C3159),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD4DBEA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _isExporting ? 'Exporting...' : 'Export Excel',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAttendanceAction() async {
    if (_isAttendanceSubmitting) return;

    final isCheckingIn = !_isCheckedIn;
    final attendanceType = isCheckingIn ? 'checkin' : 'checkout';

    try {
      setState(() => _isAttendanceSubmitting = true);

      final granted = await _ensureAttendancePermissions();
      if (!granted) return;

      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) {
        _showSnackBar('Photo is required to continue.');
        return;
      }
      final uploadPath = await _prepareAttendancePhotoForUpload(photo.path);
      final confirmed = await _confirmAttendancePhoto(uploadPath);
      if (confirmed != true) {
        _showSnackBar('Attendance cancelled.');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _showSnackBar(
            'Location services are disabled. Please enable location.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final address =
          await _resolveAddress(position.latitude, position.longitude);
      final device = _deviceDescription();

      final uploadRes = await _authProvider.uploadAttendancePhoto(
        type: attendanceType,
        photoPath: uploadPath,
        token: _authProvider.currentAuthToken,
      );
      final photoUrl = _extractPhotoUrl(uploadRes);
      if (photoUrl.isEmpty) {
        throw Exception('Photo uploaded but photo URL is missing in response.');
      }

      if (isCheckingIn) {
        await _authProvider.attendanceCheckIn(
          photoUrl: photoUrl,
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          device: device,
          notes: '',
          token: _authProvider.currentAuthToken,
        );
      } else {
        await _authProvider.attendanceCheckOut(
          photoUrl: photoUrl,
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          device: device,
          notes: '',
          token: _authProvider.currentAuthToken,
        );
      }

      if (!mounted) return;
      setState(() => _isCheckedIn = isCheckingIn);
      await _loadTodayAttendance();
      _showSnackBar(isCheckingIn
          ? 'Checked in successfully.'
          : 'Checked out successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isAttendanceSubmitting = false);
      }
    }
  }

  Future<bool> _ensureAttendancePermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showSnackBar('Camera permission is required for attendance.');
      if (cameraStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      _showSnackBar('Location permission is required for attendance.');
      if (locationStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    return true;
  }

  Future<String> _resolveAddress(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return 'Unknown location';
      final place = places.first;
      final parts = <String>[
        place.subLocality ?? '',
        place.locality ?? '',
        place.administrativeArea ?? '',
      ].where((part) => part.trim().isNotEmpty).toList();
      return parts.isEmpty ? 'Unknown location' : parts.join(', ');
    } catch (_) {
      return 'Unknown location';
    }
  }

  Future<String> _prepareAttendancePhotoForUpload(String sourcePath) async {
    final lower = sourcePath.toLowerCase();
    final isAllowed = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (isAllowed) {
      return sourcePath;
    }

    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        format: CompressFormat.jpeg,
        quality: 90,
      );
      if (result != null) {
        return result.path;
      }
    } catch (_) {
      // fallback below
    }

    throw Exception(
      'Captured photo format is not supported. Please try again.',
    );
  }

  Future<bool?> _confirmAttendancePhoto(String imagePath) async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Selfie'),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Retake'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use Photo'),
            ),
          ],
        );
      },
    );
  }

  String _extractPhotoUrl(Map<String, dynamic> response) {
    String read(dynamic value) => value is String ? value.trim() : '';

    final direct = read(response['photo_url']);
    if (direct.isNotEmpty) return direct;

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nested = read(data['photo_url']);
      if (nested.isNotEmpty) return nested;
      final url = read(data['url']);
      if (url.isNotEmpty) return url;
      final path = read(data['path']);
      if (path.isNotEmpty) return path;
    }
    return '';
  }

  String _deviceDescription() {
    if (kIsWeb) return 'Web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadTodayAttendance() async {
    setState(() {
      _isLoadingToday = true;
      _todayError = null;
    });
    try {
      final data = await _authProvider.attendanceToday(
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _todayAttendance = data;
        _isCheckedIn = _readBool(data,
            const ['is_checked_in', 'isCheckedIn', 'checked_in', 'checkedIn']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _todayError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingToday = false;
        });
      }
    }
  }

  Future<void> _loadCalendarAttendance() async {
    setState(() {
      _isLoadingCalendar = true;
      _calendarError = null;
    });
    try {
      final data = await _authProvider.attendanceCalendar(
        month: _calendarMonth.month,
        year: _calendarMonth.year,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _calendarData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calendarError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalendar = false;
        });
      }
    }
  }

  Future<void> _loadMyHistoryAttendance() async {
    setState(() {
      _isLoadingMyHistory = true;
      _myHistoryError = null;
    });
    try {
      final data = await _authProvider.attendanceMe(
        page: 1,
        perPage: 30,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _myHistoryData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _myHistoryError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMyHistory = false;
        });
      }
    }
  }

  Future<void> _loadMonthGridAttendance() async {
    setState(() {
      _isLoadingMonthGrid = true;
      _monthGridError = null;
    });
    try {
      if (_usesTeamMonthView) {
        final from = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
        final to = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
        final firstPage = await _authProvider.attendanceByMonth(
          month: _calendarMonth.month,
          year: _calendarMonth.year,
          page: 1,
          perPage: 10,
          token: _authProvider.currentAuthToken,
        );

        final allRows = <dynamic>[];
        final firstRows = _sourceRows(firstPage);
        if (firstRows.isNotEmpty) {
          allRows.addAll(firstRows);
        }

        final paginationRaw = firstPage['pagination'];
        final pagination = paginationRaw is Map
            ? Map<String, dynamic>.from(
                paginationRaw.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
            : const <String, dynamic>{};
        final totalPages = _readIntValue(pagination['total_pages'], 1);

        for (var page = 2; page <= totalPages; page++) {
          final nextPage = await _authProvider.attendanceByMonth(
            month: _calendarMonth.month,
            year: _calendarMonth.year,
            page: page,
            perPage: 10,
            token: _authProvider.currentAuthToken,
          );
          final nextRows = _sourceRows(nextPage);
          if (nextRows.isNotEmpty) {
            allRows.addAll(nextRows);
          }
        }

        if (!mounted) return;
        setState(() {
          _monthGridData = _buildTeamMonthGridData(
            source: firstPage,
            rows: allRows,
            from: from,
            to: to,
          );
        });
        return;
      }

      if (_isSalesManager) {
        final from = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
        final to = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
        final firstPage = await _authProvider.attendanceTeam(
          from: _formatDateForApi(from),
          to: _formatDateForApi(to),
          page: 1,
          perPage: 100,
          token: _authProvider.currentAuthToken,
        );

        final allRows = <dynamic>[];
        final firstRows = firstPage['data'];
        if (firstRows is List) {
          allRows.addAll(firstRows);
        }

        final paginationRaw = firstPage['pagination'];
        final pagination = paginationRaw is Map
            ? Map<String, dynamic>.from(
                paginationRaw.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
            : const <String, dynamic>{};
        final totalPages = _readIntValue(pagination['total_pages'], 1);

        for (var page = 2; page <= totalPages; page++) {
          final nextPage = await _authProvider.attendanceTeam(
            from: _formatDateForApi(from),
            to: _formatDateForApi(to),
            page: page,
            perPage: 100,
            token: _authProvider.currentAuthToken,
          );
          final nextRows = nextPage['data'];
          if (nextRows is List) {
            allRows.addAll(nextRows);
          }
        }

        if (!mounted) return;
        setState(() {
          _monthGridData = _buildSalesManagerMonthGridData(
            source: firstPage,
            rows: allRows,
            from: from,
            to: to,
          );
        });
        return;
      }

      final firstPage = await _authProvider.attendanceByMonth(
        month: _calendarMonth.month,
        year: _calendarMonth.year,
        page: 1,
        perPage: 50,
        token: _authProvider.currentAuthToken,
      );

      final allRows = <dynamic>[];
      final firstRows = firstPage['data'];
      if (firstRows is List) {
        allRows.addAll(firstRows);
      }

      final paginationRaw = firstPage['pagination'];
      final pagination = paginationRaw is Map
          ? Map<String, dynamic>.from(
              paginationRaw
                  .map((key, value) => MapEntry(key.toString(), value)),
            )
          : const <String, dynamic>{};
      final totalPages = _readIntValue(pagination['total_pages'], 1);

      for (var page = 2; page <= totalPages; page++) {
        final nextPage = await _authProvider.attendanceByMonth(
          month: _calendarMonth.month,
          year: _calendarMonth.year,
          page: page,
          perPage: 50,
          token: _authProvider.currentAuthToken,
        );
        final nextRows = nextPage['data'];
        if (nextRows is List) {
          allRows.addAll(nextRows);
        }
      }

      final data = Map<String, dynamic>.from(firstPage);
      data['data'] = allRows;

      if (!mounted) return;
      setState(() {
        _monthGridData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monthGridError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMonthGrid = false;
        });
      }
    }
  }

  void _changeCalendarMonth(int delta) {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month + delta, 1);
    });
    _loadCalendarAttendance();
    _loadMonthGridAttendance();
  }

  int _readIntValue(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime? _parseApiDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  String _monthLabel(DateTime date) {
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
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  List<_CalendarCell> _buildCalendarItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final apiMonth =
        _readIntValue(_calendarData['month'], _calendarMonth.month);
    final apiYear = _readIntValue(_calendarData['year'], _calendarMonth.year);
    final monthStart = DateTime(apiYear, apiMonth, 1);
    final monthEnd = DateTime(apiYear, apiMonth + 1, 0);
    final leadingSlots = monthStart.weekday % 7;

    final List<_CalendarCell> items = <_CalendarCell>[];
    for (var i = 0; i < leadingSlots; i++) {
      items.add(const _CalendarCell.empty());
    }

    final dayMap = <int, Map<String, dynamic>>{};
    final daysRaw = _calendarData['days'];
    if (daysRaw is List) {
      for (final entry in daysRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final date = _parseApiDate(entry['date']);
        if (date == null) continue;
        if (date.year == apiYear && date.month == apiMonth) {
          dayMap[date.day] = entry;
        }
      }
    }

    for (var day = 1; day <= monthEnd.day; day++) {
      final date = DateTime(apiYear, apiMonth, day);
      final isFuture = date.isAfter(today);
      final data = dayMap[day];
      final status = _readStringFromMap(
        data ?? const <String, dynamic>{},
        const ['status'],
        fallback: '',
      ).toLowerCase();

      final _CalendarCellState state;
      if (isFuture) {
        state = _CalendarCellState.off;
      } else if (status == 'present' || status == 'late') {
        state = _CalendarCellState.present;
      } else if (status == 'weekend') {
        state = _CalendarCellState.off;
      } else {
        state = _CalendarCellState.absent;
      }

      items.add(
        _CalendarCell(
          day: day,
          state: state,
          isSelected: date.year == today.year &&
              date.month == today.month &&
              date.day == today.day,
        ),
      );
    }

    while (items.length % 7 != 0) {
      items.add(const _CalendarCell.empty());
    }

    return items;
  }

  Map<String, int> _calendarSummary() {
    final summaryRaw = _calendarData['summary'];
    if (summaryRaw is Map<String, dynamic>) {
      return <String, int>{
        'present': _readIntValue(summaryRaw['present'], 0),
        'late': _readIntValue(summaryRaw['late'], 0),
        'absent': _readIntValue(summaryRaw['absent'], 0),
      };
    }
    return const <String, int>{'present': 0, 'late': 0, 'absent': 0};
  }

  Map<String, int> _myHistorySummary() {
    final summaryRaw = _myHistorySummaryMap();
    if (summaryRaw.isNotEmpty) {
      return <String, int>{
        'present': _historySummaryValue(
          summaryRaw,
          const ['present', 'present_count', 'presentCount'],
        ),
        'absent': _historySummaryValue(
          summaryRaw,
          const ['absent', 'absent_count', 'absentCount'],
        ),
        'late': _historySummaryValue(
          summaryRaw,
          const ['late', 'late_count', 'lateCount'],
        ),
        'leave': _historySummaryValue(
          summaryRaw,
          const ['leave', 'on_leave', 'onLeave', 'leave_count', 'leaveCount'],
        ),
      };
    }

    final entries = _myHistoryEntries();
    return <String, int>{
      'present': entries.where((entry) => entry.status == 'present').length,
      'absent': entries.where((entry) => entry.status == 'absent').length,
      'late': entries.where((entry) => entry.status == 'late').length,
      'leave': entries.where((entry) => entry.status == 'leave').length,
    };
  }

  int _historySummaryValue(Map<String, dynamic> summary, List<String> keys) {
    for (final key in keys) {
      if (summary.containsKey(key)) {
        return _readIntValue(summary[key], 0);
      }
    }
    return 0;
  }

  List<_HistoryEntry> _myHistoryEntries() {
    final daysRaw = _myHistoryRows();
    if (daysRaw.isEmpty) return const <_HistoryEntry>[];

    final todayRaw = DateTime.now();
    final today = DateTime(todayRaw.year, todayRaw.month, todayRaw.day);
    final entries = <_HistoryEntry>[];

    for (final raw in daysRaw) {
      final day = Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
      final parsedDate = _historyDate(day);
      if (parsedDate == null) continue;
      final date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      if (date.isAfter(today)) continue;

      final status = _historyStatus(day);
      if (status.isEmpty || status == 'weekend' || status == 'off') continue;

      entries.add(
        _HistoryEntry(
          date: date,
          dateLabel: _historyDateLabel(date),
          status: status,
          statusLabel: _statusLabel(status),
          checkIn: _historyCheckIn(day),
          checkOut: _historyCheckOut(day),
          hours: _historyHours(day),
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  DateTime? _historyDate(Map<String, dynamic> day) {
    return _parseApiDate(
      _readStringFromMap(
        day,
        const [
          'date',
          'attendance_date',
          'attendanceDate',
          'created_at',
          'createdAt',
        ],
        fallback: '',
      ),
    );
  }

  Map<String, dynamic> _myHistorySummaryMap() {
    final summary = _myHistoryData['summary'];
    if (summary is Map<String, dynamic>) return summary;
    if (summary is Map) {
      return Map<String, dynamic>.from(
        summary.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final data = _myHistoryData['data'];
    if (data is Map) {
      final nestedSummary = data['summary'];
      if (nestedSummary is Map<String, dynamic>) return nestedSummary;
      if (nestedSummary is Map) {
        return Map<String, dynamic>.from(
          nestedSummary.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _myHistoryRows() {
    dynamic rowsRaw = _myHistoryData['data'];
    if (rowsRaw is Map) {
      rowsRaw = rowsRaw['data'] ??
          rowsRaw['items'] ??
          rowsRaw['records'] ??
          rowsRaw['attendance'] ??
          rowsRaw['attendances'];
    }
    rowsRaw ??= _myHistoryData['items'] ??
        _myHistoryData['records'] ??
        _myHistoryData['attendance'] ??
        _myHistoryData['attendances'];

    if (rowsRaw is! List) return const <Map<String, dynamic>>[];
    return rowsRaw
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  String _historyStatus(Map<String, dynamic> day) {
    final rawStatus = _readStringFromMap(
      day,
      const ['status', 'attendance_status', 'attendanceStatus'],
      fallback: '',
    ).trim().toLowerCase();
    if (rawStatus == 'on_leave' || rawStatus == 'on leave') return 'leave';
    if (rawStatus == 'checked_in' || rawStatus == 'checked in') {
      return 'present';
    }
    if (rawStatus.isNotEmpty) return rawStatus;
    final hasCheckIn = _readStringFromMap(
      day,
      const [
        'check_in_time',
        'checkInTime',
        'check_in',
        'checkIn',
        'check_in_at',
      ],
      fallback: '',
    ).isNotEmpty;
    return hasCheckIn ? 'present' : 'absent';
  }

  String _historyDateLabel(DateTime date) {
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
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${months[date.month - 1]} ${date.year}';
  }

  String _historyCheckIn(Map<String, dynamic> day) {
    return _formatTimeValue(
      _readStringFromMap(
        day,
        const [
          'check_in_time',
          'checkInTime',
          'check_in',
          'checkIn',
          'check_in_at',
        ],
        fallback: '--:--',
      ),
    );
  }

  String _historyCheckOut(Map<String, dynamic> day) {
    return _formatTimeValue(
      _readStringFromMap(
        day,
        const [
          'check_out_time',
          'checkOutTime',
          'check_out',
          'checkOut',
          'check_out_at',
        ],
        fallback: '--:--',
      ),
    );
  }

  String _historyHours(Map<String, dynamic> day) {
    final raw = _readStringFromMap(
      day,
      const [
        'working_hours',
        'workingHours',
        'hours_worked',
        'hoursWorked',
        'total_working_hours',
      ],
      fallback: '',
    );
    if (raw.isEmpty || raw == '--') return '';
    return raw.toLowerCase().endsWith('h') ? raw : '${raw}h';
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<Map<String, dynamic>> _monthGridDays() {
    final allDaysRaw = _monthGridData['all_days'];
    if (allDaysRaw is List) {
      return allDaysRaw.whereType<String>().map((date) {
        final parsed = _parseApiDate(date);
        return <String, dynamic>{
          'date': date,
          'day': parsed == null ? '' : _shortWeekday(parsed),
          'status': parsed != null && parsed.weekday >= 6 ? 'weekend' : '',
        };
      }).toList();
    }

    final rows = _monthGridRows();
    if (rows.isNotEmpty) {
      return _daysFromMonthGridRow(rows.first);
    }

    final daysRaw = _calendarData['days'];
    if (daysRaw is! List) return const <Map<String, dynamic>>[];
    final days = daysRaw
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    days.sort((a, b) {
      final aDate = _parseApiDate(a['date']) ?? DateTime(1900);
      final bDate = _parseApiDate(b['date']) ?? DateTime(1900);
      return aDate.compareTo(bDate);
    });
    return days;
  }

  List<Map<String, dynamic>> _monthGridRows() {
    var rowsRaw = _monthGridData['data'];
    if (rowsRaw is Map) {
      rowsRaw = rowsRaw['data'] ?? rowsRaw['items'] ?? rowsRaw['records'];
    }
    if (rowsRaw is! List) return const <Map<String, dynamic>>[];
    return rowsRaw
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _daysFromMonthGridRow(Map<String, dynamic> row) {
    final daysRaw = row['days'];
    if (daysRaw is! List) return const <Map<String, dynamic>>[];
    final days = daysRaw
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    days.sort((a, b) {
      final aDate = _parseApiDate(a['date']) ?? DateTime(1900);
      final bDate = _parseApiDate(b['date']) ?? DateTime(1900);
      return aDate.compareTo(bDate);
    });
    return days;
  }

  Map<String, dynamic> _userFromMonthGridRow(Map<String, dynamic> row) {
    final user = row['user'];
    if (user is Map<String, dynamic>) return user;
    return const <String, dynamic>{};
  }

  String _monthGridEmployeeName([Map<String, dynamic>? row]) {
    final fromCalendar = _readStringFromMap(
      row == null ? const <String, dynamic>{} : _userFromMonthGridRow(row),
      const ['full_name', 'fullName', 'name'],
      fallback: '',
    );
    return fromCalendar.isNotEmpty ? fromCalendar : _userName();
  }

  String _monthGridEmployeeRole([Map<String, dynamic>? row]) {
    final fromCalendar = _readStringFromMap(
      row == null ? const <String, dynamic>{} : _userFromMonthGridRow(row),
      const ['role', 'designation'],
      fallback: '',
    );
    return fromCalendar.isNotEmpty ? fromCalendar : _userRole();
  }

  Future<void> _openMonthGridUserHistory(Map<String, dynamic> row) async {
    final userId = _salesManagerUserKey(row);
    if (userId.isEmpty) {
      _showSnackBar('User id is missing for this employee.');
      return;
    }

    final from = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final to = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AttendanceUserHistoryPage(
          userId: userId,
          initialName: _monthGridEmployeeName(row),
          initialRole: _monthGridEmployeeRole(row),
          initialFrom: from,
          initialTo: to,
        ),
      ),
    );
  }

  String _shortWeekday(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _dateKey(DateTime? date) {
    if (date == null) return '';
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

  Future<void> _pickDailyViewDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dailyViewDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      _dailyViewDate = DateTime(picked.year, picked.month, picked.day);
      _calendarMonth = DateTime(picked.year, picked.month, 1);
      _dailyViewCurrentPage = 1;
    });
    _loadDailyViewAttendance();
  }

  Future<void> _loadDailyViewAttendance({int page = 1}) async {
    setState(() {
      _isLoadingDailyView = true;
      _dailyViewError = null;
    });
    try {
      if (_usesTeamDailyView) {
        final date = _formatDateForApi(_dailyViewDate);
        final data = await _authProvider.attendanceTeam(
          from: date,
          to: date,
          page: page,
          perPage: 10,
          token: _authProvider.currentAuthToken,
        );
        if (!mounted) return;
        final pagination = _paginationMap(data['pagination']);
        final dailyViewData = _buildSalesManagerDailyViewData(
          source: data,
          selectedDate: _dailyViewDate,
        );
        final visibleRows = _dailyViewRowsFromSource(dailyViewData).length;
        setState(() {
          _dailyViewCurrentPage = _readIntValue(pagination['page'],
              _readIntValue(pagination['current_page'], page));
          _dailyViewTotalPages = _readIntValue(
            pagination['total_pages'],
            _readIntValue(pagination['last_page'], 1),
          );
          _dailyViewTotalItems = _readIntValue(
            pagination['total'],
            _readIntValue(pagination['total_items'], visibleRows),
          );
          if (_dailyViewTotalItems < visibleRows) {
            _dailyViewTotalItems = visibleRows;
          }
          _dailyViewData = dailyViewData;
        });
        return;
      }

      final data = await _authProvider.attendanceByDate(
        date: _formatDateForApi(_dailyViewDate),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _dailyViewCurrentPage = 1;
        _dailyViewTotalPages = 1;
        _dailyViewTotalItems = 0;
        _dailyViewData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dailyViewError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDailyView = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _dailyViewRows() {
    return _dailyViewRowsFromSource(_dailyViewData);
  }

  List<Map<String, dynamic>> _dailyViewRowsFromSource(
      Map<String, dynamic> source) {
    final rows = <Map<String, dynamic>>[];

    for (final key in const ['records', 'data', 'items', 'rows']) {
      final rawRows = source[key];
      if (rawRows is! List) continue;
      for (final entry in rawRows) {
        if (entry is! Map) continue;
        rows.add(
          Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
      if (rows.isNotEmpty) break;
    }

    final noRecordRaw = source['no_record'];
    if (noRecordRaw is List) {
      for (final entry in noRecordRaw) {
        if (entry is! Map) continue;
        rows.add(
          Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }

    return rows;
  }

  Map<String, dynamic> _paginationMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, val) => MapEntry(key.toString(), val)),
      );
    }
    return const <String, dynamic>{};
  }

  Map<String, int> _dailyViewSummaryCounts(List<Map<String, dynamic>> rows) {
    final summaryRaw = _dailyViewData['summary'];
    if (summaryRaw is Map<String, dynamic>) {
      return <String, int>{
        'present': _readIntValue(summaryRaw['present'], 0),
        'late': _readIntValue(summaryRaw['late'], 0),
        'absent': _readIntValue(summaryRaw['absent'], 0),
        'leave': _readIntValue(summaryRaw['on_leave'], 0),
      };
    }

    return _dailySummaryCounts(rows);
  }

  String _attendanceLetter(String status) {
    switch (status.trim().toLowerCase()) {
      case 'present':
        return 'P';
      case 'late':
        return 'L';
      case 'on_leave':
      case 'leave':
        return 'OL';
      case 'half_day':
      case 'half day':
        return 'H';
      case 'weekend':
        return 'W';
      case 'absent':
      default:
        return 'A';
    }
  }

  bool _isFutureDate(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellDate = DateTime(date.year, date.month, date.day);
    return cellDate.isAfter(today);
  }

  Color _attendanceBadgeBg(String status, DateTime? date) {
    if (_isFutureDate(date)) {
      return const Color(0xFFEFF3F8);
    }
    switch (status.trim().toLowerCase()) {
      case 'present':
        return const Color(0xFFDDF7E9);
      case 'late':
        return const Color(0xFFFFF2CC);
      case 'on_leave':
      case 'leave':
        return const Color(0xFFE8EAFE);
      case 'half_day':
      case 'half day':
        return const Color(0xFFFFE4F1);
      case 'weekend':
        return const Color(0xFFEFF3F8);
      case 'absent':
      default:
        return const Color(0xFFFFE0E0);
    }
  }

  Color _attendanceBadgeFg(String status, DateTime? date) {
    if (_isFutureDate(date)) {
      return const Color(0xFF8B98AA);
    }
    switch (status.trim().toLowerCase()) {
      case 'present':
        return const Color(0xFF07885F);
      case 'late':
        return const Color(0xFFB77900);
      case 'on_leave':
      case 'leave':
        return const Color(0xFF5461C8);
      case 'half_day':
      case 'half day':
        return const Color(0xFFC2185B);
      case 'weekend':
        return const Color(0xFF8B98AA);
      case 'absent':
      default:
        return const Color(0xFFE02020);
    }
  }

  int _summaryCountForRow(Map<String, dynamic> row, String key) {
    final summary = row['summary'];
    if (summary is Map<String, dynamic>) return _readIntValue(summary[key], 0);
    return 0;
  }

  Map<String, dynamic> _dailyDayForRow(Map<String, dynamic> row) {
    final selectedKey = _dateKey(_dailyViewDate);
    for (final day in _daysFromMonthGridRow(row)) {
      if (_dateKey(_parseApiDate(day['date'])) == selectedKey) {
        return day;
      }
    }
    return <String, dynamic>{
      'date': selectedKey,
      'status': _dailyViewDate.weekday >= 6 ? 'weekend' : 'absent',
    };
  }

  Map<String, int> _dailySummaryCounts(List<Map<String, dynamic>> rows) {
    var present = 0;
    var late = 0;
    var absent = 0;
    var leave = 0;

    for (final row in rows) {
      final status = _readStringFromMap(
        _dailyDayForRow(row),
        const ['status'],
        fallback: 'absent',
      ).toLowerCase();
      if (status == 'present') {
        present++;
      } else if (status == 'late') {
        late++;
      } else if (status == 'on_leave' || status == 'leave') {
        leave++;
      } else if (status != 'weekend') {
        absent++;
      }
    }

    return <String, int>{
      'present': present,
      'late': late,
      'absent': absent,
      'leave': leave,
    };
  }

  Map<String, int> _approvalSummaryCounts(List<Map<String, dynamic>> rows) {
    var present = 0;
    var late = 0;
    var absent = 0;
    var leave = 0;

    for (final row in rows) {
      final status = _readStringFromMap(
        row,
        const ['status', 'attendance_status'],
        fallback: 'absent',
      ).toLowerCase();
      if (status == 'present') {
        present++;
      } else if (status == 'late') {
        late++;
      } else if (status == 'on_leave' || status == 'leave') {
        leave++;
      } else if (status != 'weekend') {
        absent++;
      }
    }

    return <String, int>{
      'present': present,
      'late': late,
      'absent': absent,
      'leave': leave,
    };
  }

  int _approvalNotCheckedOutCount(List<Map<String, dynamic>> rows) {
    var count = 0;
    for (final row in rows) {
      final checkOut = _readStringFromMap(
        row,
        const ['check_out_time', 'checkOutTime', 'check_out'],
        fallback: '',
      );
      if (checkOut.trim().isEmpty || checkOut.trim() == '--:--') {
        count++;
      }
    }
    return count;
  }

  Map<String, dynamic> _approvalEmployeeMap(Map<String, dynamic> row) {
    final employee = row['employee'];
    if (employee is Map<String, dynamic>) {
      return employee;
    }
    if (employee is Map) {
      return Map<String, dynamic>.from(
        employee.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  String _approvalName(Map<String, dynamic> row) {
    final employee = _approvalEmployeeMap(row);
    final nested = _readStringFromMap(
      employee,
      const ['name', 'full_name', 'fullName', 'first_name'],
      fallback: '',
    );
    if (nested.isNotEmpty) return nested;
    return _readStringFromMap(
      row,
      const ['name', 'full_name', 'employee_name', 'employeeName'],
      fallback: 'Employee',
    );
  }

  String _approvalRole(Map<String, dynamic> row) {
    final employee = _approvalEmployeeMap(row);
    final nested = _readStringFromMap(
      employee,
      const ['role', 'designation', 'title'],
      fallback: '',
    );
    if (nested.isNotEmpty) return nested;
    return _readStringFromMap(
      row,
      const ['role', 'designation', 'title'],
      fallback: 'Sales Executive',
    );
  }

  String _approvalId(Map<String, dynamic> row) {
    return _readStringFromMap(
      row,
      const [
        'id',
        '_id',
        'attendance_id',
        'attendanceId',
        'pending_id',
        'pendingId'
      ],
      fallback: '',
    );
  }

  String _approvalStatus(Map<String, dynamic> row) {
    return _readStringFromMap(
      row,
      const ['status', 'attendance_status', 'attendanceStatus'],
      fallback: 'present',
    );
  }

  String _approvalCheckIn(Map<String, dynamic> row) {
    return _formatTimeValue(
      _readStringFromMap(
        row,
        const ['check_in_time', 'checkInTime', 'check_in', 'checkIn'],
        fallback: '--:--',
      ),
    );
  }

  String _approvalCheckOut(Map<String, dynamic> row) {
    return _formatTimeValue(
      _readStringFromMap(
        row,
        const ['check_out_time', 'checkOutTime', 'check_out', 'checkOut'],
        fallback: '--:--',
      ),
    );
  }

  String _readStringFromMap(Map<String, dynamic> map, List<String> keys,
      {String fallback = ''}) {
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
        final lower = value.trim().toLowerCase();
        if (lower == 'true' || lower == '1' || lower == 'yes') return true;
        if (lower == 'false' || lower == '0' || lower == 'no') return false;
      }
    }
    return false;
  }

  String _todayDateLabel() {
    final dateRaw = _readStringFromMap(_todayAttendance,
        const ['date', 'today', 'attendance_date', 'attendanceDate']);
    final parsed = DateTime.tryParse(dateRaw);
    final date = parsed ?? DateTime.now();
    const week = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
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
      'Dec'
    ];
    return '${week[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String _userName() {
    final user = _todayAttendance['user'];
    if (user is Map<String, dynamic>) {
      final fromUser = _readStringFromMap(
          user, const ['name', 'full_name', 'fullName', 'first_name'],
          fallback: '');
      if (fromUser.isNotEmpty) return fromUser;
    }
    return _readStringFromMap(
      _todayAttendance,
      const ['user_name', 'name', 'employee_name', 'employeeName'],
      fallback: 'N/A',
    );
  }

  String _userRole() {
    final user = _todayAttendance['user'];
    if (user is Map<String, dynamic>) {
      final fromUser = _readStringFromMap(
          user, const ['role', 'designation', 'title'],
          fallback: '');
      if (fromUser.isNotEmpty) return fromUser;
    }
    return _readStringFromMap(
      _todayAttendance,
      const ['role', 'designation', 'title'],
      fallback: 'N/A',
    );
  }

  String _todayStatus() {
    return _readStringFromMap(
      _todayAttendance,
      const ['status', 'attendance_status', 'attendanceStatus'],
      fallback: _isCheckedIn ? 'Present' : 'Absent',
    );
  }

  String _todayCheckIn() {
    final raw = _readStringFromMap(
      _todayAttendance,
      const ['check_in_time', 'checkInTime', 'check_in', 'checkIn'],
      fallback: '--:--',
    );
    return _formatTimeValue(raw);
  }

  String _todayCheckOut() {
    final raw = _readStringFromMap(
      _todayAttendance,
      const ['check_out_time', 'checkOutTime', 'check_out', 'checkOut'],
      fallback: '--:--',
    );
    return _formatTimeValue(raw);
  }

  String _todayWorkingHours() {
    return _readStringFromMap(
      _todayAttendance,
      const ['working_hours', 'workingHours', 'hours_worked', 'hoursWorked'],
      fallback: '--',
    );
  }

  bool _isCheckedOutToday() {
    return _readBool(_todayAttendance,
        const ['is_checked_out', 'isCheckedOut', 'checked_out', 'checkedOut']);
  }

  String _formatTimeValue(String value) {
    final v = value.trim();
    if (v.isEmpty || v == '--:--') return '--:--';
    final parsed = DateTime.tryParse(v);
    if (parsed == null) return v;
    final local = parsed.toLocal();
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final amPm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$m $amPm';
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

            return AlertDialog(
              title: const Text('Export Attendance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: pickFromDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Text(
                        formatDate(fromDate).isEmpty
                            ? 'Select start date'
                            : formatDate(fromDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: pickToDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Text(
                        formatDate(toDate).isEmpty
                            ? 'Select end date'
                            : formatDate(toDate),
                      ),
                    ),
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

  Future<void> _exportAttendance() async {
    if (!_canExportData) {
      _showSnackBar('You do not have permission to export attendance.');
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
      final exported = await _authProvider.exportAttendance(
        from: from,
        to: to,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      final safeFileName = exported.fileName.trim().isEmpty
          ? 'attendance_${from}_to_$to.xlsx'
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
        'Attendance export downloaded and saved to: ${outFile.path}',
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
                  onTap: () {
                    setState(() => _selectedTabIndex = index);
                    if (index == 1) {
                      _loadCalendarAttendance();
                    } else if (index == 2) {
                      _loadMyHistoryAttendance();
                    } else if (index == 3) {
                      _loadMonthGridAttendance();
                    } else if (index == _dailyViewTabIndex) {
                      _loadDailyViewAttendance();
                    } else if (index == _summaryTabIndex) {
                      _loadSummaryAttendance();
                    } else if (index == _lateReportsTabIndex) {
                      _loadLateReports();
                    } else if (index == _approvalsTabIndex) {
                      _loadApprovalPending();
                    } else if (index == _holidaysTabIndex) {
                      _loadHolidays();
                    }
                  },
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
        if (_selectedTabIndex == 2) {
          return _buildMyHistoryTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == 3) {
          return _buildMonthGridTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == _dailyViewTabIndex) {
          return _buildDailyViewTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == _summaryTabIndex) {
          return _buildSummaryTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == _lateReportsTabIndex) {
          return _buildLateReportsTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == _approvalsTabIndex) {
          return _buildApprovalsTabContent(constraints.maxWidth);
        }
        if (_selectedTabIndex == _holidaysTabIndex) {
          return _buildHolidaysTabContent(constraints.maxWidth);
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
              child:
                  _buildRightMetrics(width: constraints.maxWidth * 0.675 - 12),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthGridTabContent(double maxWidth) {
    final days = _monthGridDays();
    final rows = _monthGridRows();
    final dayColumnWidth = maxWidth < 390 ? 36.0 : 42.0;
    final employeeWidth = maxWidth < 390 ? 142.0 : 182.0;
    final summaryWidth = maxWidth < 390 ? 32.0 : 38.0;
    final tableWidth =
        employeeWidth + (days.length * dayColumnWidth) + (summaryWidth * 3);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _usesTeamMonthView
                          ? 'Team Month'
                          : 'Monthly Attendance Grid',
                      style: TextStyle(
                        color: Color(0xFF172B4D),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rows.length} employees - ${_monthLabel(_calendarMonth)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF95A1B6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundActionButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _changeCalendarMonth(-1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _monthLabel(_calendarMonth),
                      style: const TextStyle(
                        color: Color(0xFF2C3E5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundActionButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _changeCalendarMonth(1),
                    ),
                    const SizedBox(width: 8),
                    // if (_canExportData)
                    //   OutlinedButton.icon(
                    //     onPressed: _isExporting ? null : _exportAttendance,
                    //     icon: const Icon(Icons.download_rounded, size: 16),
                    //     label: const Text('Export'),
                    //     style: OutlinedButton.styleFrom(
                    //       minimumSize: const Size(0, 34),
                    //       padding: const EdgeInsets.symmetric(horizontal: 10),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //     ),
                    //   ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: controls,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    controls,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingMonthGrid)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_monthGridError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _monthGridError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (days.isEmpty || rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Text(
                  'No monthly attendance grid data available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF71809A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Scrollbar(
              controller: _monthGridHorizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 5,
              radius: const Radius.circular(999),
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _monthGridHorizontalController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildMonthGridHeader(
                        days: days,
                        employeeWidth: employeeWidth,
                        dayColumnWidth: dayColumnWidth,
                        summaryWidth: summaryWidth,
                      ),
                      const Divider(height: 1, color: Color(0xFFEFF3F8)),
                      ...rows.expand(
                        (row) => [
                          _buildMonthGridEmployeeRow(
                            row: row,
                            days: days,
                            employeeWidth: employeeWidth,
                            dayColumnWidth: dayColumnWidth,
                            summaryWidth: summaryWidth,
                          ),
                          const Divider(height: 1, color: Color(0xFFF0F3F8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _LegendChip(
                  label: 'P = Present',
                  textColor: Color(0xFF07885F),
                  bgColor: Color(0xFFDDF7E9),
                ),
                _LegendChip(
                  label: 'L = Late',
                  textColor: Color(0xFFB77900),
                  bgColor: Color(0xFFFFF2CC),
                ),
                _LegendChip(
                  label: 'A = Absent',
                  textColor: Color(0xFFE02020),
                  bgColor: Color(0xFFFFE0E0),
                ),
                _LegendChip(
                  label: 'OL = On Leave',
                  textColor: Color(0xFF5461C8),
                  bgColor: Color(0xFFE8EAFE),
                ),
                _LegendChip(
                  label: 'H = Half Day',
                  textColor: Color(0xFFC2185B),
                  bgColor: Color(0xFFFFE4F1),
                ),
                _LegendChip(
                  label: 'W = Weekend / Future',
                  textColor: Color(0xFF6B788C),
                  bgColor: Color(0xFFEFF3F8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGridHeader({
    required List<Map<String, dynamic>> days,
    required double employeeWidth,
    required double dayColumnWidth,
    required double summaryWidth,
  }) {
    return Container(
      color: const Color(0xFFF8FAFD),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: employeeWidth,
            child: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'Employee',
                style: TextStyle(
                  color: Color(0xFF4A5D7A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          ...days.map((day) {
            final date = _parseApiDate(day['date']);
            return SizedBox(
              width: dayColumnWidth,
              child: Column(
                children: [
                  Text(
                    date?.day.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF8793A8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _readStringFromMap(day, const ['day'], fallback: ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9BA6B8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          _summaryHeaderCell('P', summaryWidth),
          _summaryHeaderCell('A', summaryWidth),
          _summaryHeaderCell('L', summaryWidth),
        ],
      ),
    );
  }

  Widget _buildMonthGridEmployeeRow({
    required Map<String, dynamic> row,
    required List<Map<String, dynamic>> days,
    required double employeeWidth,
    required double dayColumnWidth,
    required double summaryWidth,
  }) {
    final rowDays = _daysFromMonthGridRow(row);
    final dayByDate = <String, Map<String, dynamic>>{};
    for (final day in rowDays) {
      dayByDate[_dateKey(_parseApiDate(day['date']))] = day;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: employeeWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openMonthGridUserHistory(row),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _monthGridEmployeeName(row),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0A66C2),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF0A66C2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _monthGridEmployeeRole(row).replaceAll('_', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E9AAF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...days.map((day) {
            final date = _parseApiDate(day['date']);
            final rowDay = dayByDate[_dateKey(date)] ?? day;
            final status = _readStringFromMap(
              rowDay,
              const ['status'],
              fallback: 'absent',
            );
            final isFuture = _isFutureDate(date);
            return SizedBox(
              width: dayColumnWidth,
              child: Center(
                child: Container(
                  width: dayColumnWidth < 38 ? 26 : 28,
                  height: dayColumnWidth < 38 ? 26 : 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _attendanceBadgeBg(status, date),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFuture
                          ? const Color(0xFFDCE3EE)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    _attendanceLetter(status),
                    maxLines: 1,
                    style: TextStyle(
                      color: _attendanceBadgeFg(status, date),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          }),
          _summaryValueCell(_summaryCountForRow(row, 'present'), summaryWidth,
              const Color(0xFF008060)),
          _summaryValueCell(_summaryCountForRow(row, 'absent'), summaryWidth,
              const Color(0xFFE02020)),
          _summaryValueCell(_summaryCountForRow(row, 'late'), summaryWidth,
              const Color(0xFFB77900)),
        ],
      ),
    );
  }

  Widget _summaryHeaderCell(String value, double width) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF4A5D7A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _summaryValueCell(int value, double width, Color color) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyViewTabContent(double maxWidth) {
    final rows = _dailyViewRows();
    final summary = _dailyViewSummaryCounts(rows);
    final compact = maxWidth < 560;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDailyViewTitle(summary),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildDailyDateButton(),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildDailyViewTitle(summary)),
                      _buildDailyDateButton(),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          _buildDailySummaryStrip(summary, compact),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingDailyView)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_dailyViewError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _dailyViewError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Text(
                'No daily attendance data available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF71809A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.separated(
              itemCount: rows.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF0F3F8)),
              itemBuilder: (context, index) {
                return _buildDailyEmployeeRow(rows[index], compact);
              },
            ),
          if (_usesTeamDailyView) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PaginationWidget(
                currentPage: _dailyViewCurrentPage,
                totalPages: _dailyViewTotalPages,
                totalItems: _dailyViewTotalItems,
                itemLabel: 'records',
                onPageChanged: (page) {
                  if (_isLoadingDailyView) return;
                  _loadDailyViewAttendance(page: page);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyViewTitle(Map<String, int> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _usesTeamDailyView ? 'Team Daily' : 'Daily Attendance View',
          style: TextStyle(
            color: Color(0xFF172B4D),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary['present']} present - ${summary['absent']} absent - ${summary['leave']} on leave',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF95A1B6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyDateButton() {
    return OutlinedButton.icon(
      onPressed: _pickDailyViewDate,
      icon: const Icon(Icons.calendar_today_rounded, size: 15),
      label: Text(_displayDate(_dailyViewDate)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1C3159),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD9E2F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDailySummaryStrip(Map<String, int> summary, bool compact) {
    final tiles = [
      _DailySummaryTile(
        value: summary['present'] ?? 0,
        label: 'Present',
        color: const Color(0xFF0F9D71),
        compact: compact,
      ),
      _DailySummaryTile(
        value: summary['late'] ?? 0,
        label: 'Late',
        color: const Color(0xFFE07900),
        compact: compact,
      ),
      _DailySummaryTile(
        value: summary['absent'] ?? 0,
        label: 'Absent',
        color: const Color(0xFFF04452),
        compact: compact,
      ),
      _DailySummaryTile(
        value: summary['leave'] ?? 0,
        label: 'On Leave',
        color: const Color(0xFF5655F6),
        compact: compact,
      ),
    ];

    if (compact) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.0,
        children: tiles,
      );
    }

    return Row(
      children: tiles.map((tile) => Expanded(child: tile)).toList(),
    );
  }

  Widget _buildDailyEmployeeRow(Map<String, dynamic> row, bool compact) {
    final status =
        _readStringFromMap(row, const ['status'], fallback: 'absent');
    final statusLower = status.toLowerCase();
    final checkIn = _formatTimeValue(_readStringFromMap(
      row,
      const ['check_in_time', 'checkInTime'],
      fallback: '--:--',
    ));
    final checkOut = _formatTimeValue(_readStringFromMap(
      row,
      const ['check_out_time', 'checkOutTime'],
      fallback: '--:--',
    ));
    final hours = _readStringFromMap(
      row,
      const ['working_hours', 'workingHours'],
      fallback: '',
    );
    final accent = _attendanceBadgeFg(status, _dailyViewDate);
    final bubble = _attendanceBadgeBg(status, _dailyViewDate);

    final details = Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        if (checkIn != '--:--')
          _DailyDetailPill(
            icon: Icons.login_rounded,
            color: const Color(0xFF16A34A),
            text: checkIn,
          ),
        if (checkOut != '--:--')
          _DailyDetailPill(
            icon: Icons.logout_rounded,
            color: const Color(0xFFF04452),
            text: checkOut,
          ),
        if (_canViewWorkingHours && hours.isNotEmpty)
          _DailyDetailPill(
            icon: Icons.timer_outlined,
            color: AppColors.primary,
            text: '${hours}h',
          ),
      ],
    );

    return Container(
      color: statusLower == 'absent' ? const Color(0xFFFBFCFE) : Colors.white,
      padding:
          EdgeInsets.fromLTRB(16, compact ? 14 : 16, 16, compact ? 14 : 16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDailyEmployeeMain(row, status, accent, bubble),
                if (details.children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  details,
                ],
              ],
            )
          : Row(
              children: [
                Expanded(
                    child:
                        _buildDailyEmployeeMain(row, status, accent, bubble)),
                if (details.children.isNotEmpty) details,
              ],
            ),
    );
  }

  Widget _buildDailyEmployeeMain(
    Map<String, dynamic> row,
    String status,
    Color accent,
    Color bubble,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.person_outline_rounded, color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _readStringFromMap(
                        row,
                        const ['full_name', 'fullName', 'name'],
                        fallback: 'N/A',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B1F3A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DailyStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _readStringFromMap(
                    row,
                    const ['role', 'designation'],
                    fallback: 'N/A',
                  ).replaceAll('_', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E9AAF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickSummaryFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _summaryFromDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _summaryFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_summaryToDate.isBefore(_summaryFromDate)) {
        _summaryToDate = _summaryFromDate;
      }
    });
    _loadSummaryAttendance();
  }

  Future<void> _pickSummaryToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _summaryToDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _summaryToDate = DateTime(picked.year, picked.month, picked.day);
      if (_summaryToDate.isBefore(_summaryFromDate)) {
        _summaryFromDate = _summaryToDate;
      }
    });
    _loadSummaryAttendance();
  }

  Future<void> _loadSummaryAttendance() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });
    try {
      if (_isSalesManager) {
        final data = await _authProvider.attendanceTeam(
          from: _formatDateForApi(_summaryFromDate),
          to: _formatDateForApi(_summaryToDate),
          page: 1,
          perPage: 100,
          token: _authProvider.currentAuthToken,
        );
        if (!mounted) return;
        setState(() {
          _summaryData = _buildSalesManagerSummaryData(data);
        });
        return;
      }

      final data = await _authProvider.attendanceSummary(
        from: _formatDateForApi(_summaryFromDate),
        to: _formatDateForApi(_summaryToDate),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final periodRaw = data['period'];
      DateTime? parsedFrom;
      DateTime? parsedTo;
      if (periodRaw is Map<String, dynamic>) {
        parsedFrom = _parseApiDate(periodRaw['from']);
        parsedTo = _parseApiDate(periodRaw['to']);
      }
      setState(() {
        _summaryData = data;
        if (parsedFrom != null) {
          _summaryFromDate =
              DateTime(parsedFrom.year, parsedFrom.month, parsedFrom.day);
        }
        if (parsedTo != null) {
          _summaryToDate =
              DateTime(parsedTo.year, parsedTo.month, parsedTo.day);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  Future<void> _loadLateReports() async {
    setState(() {
      _isLoadingLateReports = true;
      _lateReportsError = null;
    });
    try {
      final data = await _authProvider.attendanceLate(
        token: _authProvider.currentAuthToken,
      );
      final rows = _extractLateReportRows(data);
      final period = _lateReportsPeriod(data);
      if (!mounted) return;
      final normalized = Map<String, dynamic>.from(data);
      normalized['data'] = rows;
      setState(() {
        _lateReportsData = normalized;
        if (period != null) {
          _lateReportsFromDate =
              DateTime(period.start.year, period.start.month, period.start.day);
          _lateReportsToDate =
              DateTime(period.end.year, period.end.month, period.end.day);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lateReportsError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLateReports = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _summaryRows() {
    final dataRaw = _summaryData['data'];
    if (dataRaw is! List) return const <Map<String, dynamic>>[];
    return dataRaw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  List<Map<String, dynamic>> _extractLateReportRows(
      Map<String, dynamic> source) {
    dynamic data = source['data'];
    if (data is Map<String, dynamic>) {
      data = data['data'] ?? data['items'] ?? data['rows'] ?? data['records'];
    }
    if (data is! List) {
      return const <Map<String, dynamic>>[];
    }
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList(growable: false);
  }

  _LateReportsPeriod? _lateReportsPeriod(Map<String, dynamic> source) {
    final periodRaw = source['period'];
    if (periodRaw is! Map<String, dynamic>) {
      final data = source['data'];
      if (data is Map<String, dynamic>) {
        final nested = data['period'];
        if (nested is Map<String, dynamic>) {
          return _lateReportsPeriodFromMap(nested);
        }
      }
      return null;
    }
    return _lateReportsPeriodFromMap(periodRaw);
  }

  _LateReportsPeriod? _lateReportsPeriodFromMap(Map<String, dynamic> period) {
    final from = _parseApiDate(period['from']);
    final to = _parseApiDate(period['to']);
    if (from == null || to == null) {
      return null;
    }
    return _LateReportsPeriod(start: from, end: to);
  }

  List<Map<String, dynamic>> _lateReportsRows() {
    final dataRaw = _lateReportsData['data'];
    if (dataRaw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return dataRaw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((row) {
      final date = _parseApiDate(row['date']);
      if (date == null) {
        return true;
      }
      final normalized = DateTime(date.year, date.month, date.day);
      final from = DateTime(
        _lateReportsFromDate.year,
        _lateReportsFromDate.month,
        _lateReportsFromDate.day,
      );
      final to = DateTime(
        _lateReportsToDate.year,
        _lateReportsToDate.month,
        _lateReportsToDate.day,
      );
      return !normalized.isBefore(from) && !normalized.isAfter(to);
    }).toList(growable: false);
  }

  String _lateReportsTitleRange() {
    return '${_displayDate(_lateReportsFromDate)} to ${_displayDate(_lateReportsToDate)}';
  }

  String _lateReportsDisplayDate(dynamic value) {
    final date = _parseApiDate(value);
    if (date == null) {
      return '--';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _lateReportsDisplayTime(dynamic value) {
    final date = _parseApiDate(value);
    if (date == null) {
      return '--';
    }
    return DateFormat('hh:mm a').format(date.toLocal()).toLowerCase();
  }

  String _lateReportsRoleLabel(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return 'N/A';
    }
    return raw
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> _pickLateReportsFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lateReportsFromDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _lateReportsFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_lateReportsToDate.isBefore(_lateReportsFromDate)) {
        _lateReportsToDate = _lateReportsFromDate;
      }
    });
  }

  Future<void> _pickLateReportsToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lateReportsToDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _lateReportsToDate = DateTime(picked.year, picked.month, picked.day);
      if (_lateReportsToDate.isBefore(_lateReportsFromDate)) {
        _lateReportsFromDate = _lateReportsToDate;
      }
    });
  }

  Map<String, dynamic> _buildSalesManagerMonthGridData({
    required Map<String, dynamic> source,
    required List<dynamic> rows,
    required DateTime from,
    required DateTime to,
  }) {
    return <String, dynamic>{
      ...source,
      'data': _normalizeSalesManagerTeamRows(
        source: source,
        rows: rows,
        from: from,
        to: to,
      ),
      'all_days': _dateRangeStrings(from, to),
    };
  }

  Map<String, dynamic> _buildTeamMonthGridData({
    required Map<String, dynamic> source,
    required List<dynamic> rows,
    required DateTime from,
    required DateTime to,
  }) {
    return <String, dynamic>{
      ...source,
      'data': _normalizeTeamMonthRows(
        source: source,
        rows: rows,
        from: from,
        to: to,
      ),
      'all_days': _dateRangeStrings(from, to),
    };
  }

  List<Map<String, dynamic>> _normalizeTeamMonthRows({
    required Map<String, dynamic> source,
    required List<dynamic> rows,
    required DateTime from,
    required DateTime to,
  }) {
    final attendanceRows = <String, Map<String, dynamic>>{};
    for (final entry in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      final key = _salesManagerUserKey(row);
      if (key.isNotEmpty) {
        attendanceRows[key] = row;
      }
    }

    final mergedRows = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addCandidate(Map<String, dynamic> candidate) {
      final key = _salesManagerUserKey(candidate);
      final fallbackKey = key.isNotEmpty
          ? key
          : _readStringFromMap(
              candidate,
              const ['full_name', 'fullName', 'name', 'email'],
              fallback: '',
            );
      if (fallbackKey.isEmpty || seen.contains(fallbackKey)) {
        return;
      }
      seen.add(fallbackKey);
      mergedRows.add(
        _normalizeSalesManagerTeamRow(
          candidate,
          from,
          to,
        ),
      );
    }

    for (final entry in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      final key = _salesManagerUserKey(row);
      final merged = key.isNotEmpty && attendanceRows.containsKey(key)
          ? <String, dynamic>{...row, ...attendanceRows[key]!}
          : row;
      addCandidate(merged);
    }

    for (final teamMember in _teamMemberRows(source)) {
      final key = _salesManagerUserKey(teamMember);
      final merged = key.isNotEmpty && attendanceRows.containsKey(key)
          ? <String, dynamic>{...teamMember, ...attendanceRows[key]!}
          : teamMember;
      addCandidate(merged);
    }

    final sourceUser = _sourceUserRow(source);
    if (sourceUser.isNotEmpty) {
      final key = _salesManagerUserKey(sourceUser);
      final merged = key.isNotEmpty && attendanceRows.containsKey(key)
          ? <String, dynamic>{...sourceUser, ...attendanceRows[key]!}
          : sourceUser;
      addCandidate(merged);
    }

    if (mergedRows.isNotEmpty) {
      return mergedRows;
    }

    return _salesManagerFallbackRows(source, from, to);
  }

  Widget _buildLateReportsTabContent(double maxWidth) {
    final compact = maxWidth < 760;
    final rows = _lateReportsRows();
    final total = rows.length;
    final rangeLabel = _lateReportsTitleRange();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 740;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Late Arrivals Report',
                      style: TextStyle(
                        color: Color(0xFF071A3A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total records found',
                      style: const TextStyle(
                        color: Color(0xFF6B7B91),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        color: Color(0xFF8B96A8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );

                final controls = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _LateReportDateButton(
                      value: _displayDate(_lateReportsFromDate),
                      onTap: _pickLateReportsFromDate,
                    ),
                    const Text(
                      'to',
                      style: TextStyle(
                        color: Color(0xFF8C97AA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _LateReportDateButton(
                      value: _displayDate(_lateReportsToDate),
                      onTap: _pickLateReportsToDate,
                    ),
                    _RoundActionButton(
                      icon: Icons.refresh_rounded,
                      onTap: _loadLateReports,
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: controls),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    controls,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingLateReports)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_lateReportsError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lateReportsError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadLateReports,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No late arrivals found.',
                style: TextStyle(
                  color: Color(0xFF7C8DA6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (compact)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(rows.length, (index) {
                  final row = rows[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == rows.length - 1 ? 0 : 12,
                    ),
                    child: _LateReportCard(
                      name: _readStringFromMap(
                        row,
                        const ['full_name', 'fullName', 'name'],
                        fallback: 'N/A',
                      ),
                      role: _lateReportsRoleLabel(
                        _readStringFromMap(
                          row,
                          const ['role', 'designation'],
                          fallback: 'N/A',
                        ),
                      ),
                      dateLabel: _lateReportsDisplayDate(
                        row['date'] ?? row['late_date'],
                      ),
                      checkInLabel: _lateReportsDisplayTime(
                        row['check_in_time'] ?? row['checkInTime'],
                      ),
                      location: _readStringFromMap(
                        row,
                        const ['checkin_address', 'checkinAddress', 'location'],
                        fallback: '-',
                      ),
                      email: _readStringFromMap(
                        row,
                        const ['email'],
                        fallback: '',
                      ),
                    ),
                  );
                }),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Employee',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Check In',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Location',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == rows.length - 1
                                ? Colors.transparent
                                : const Color(0xFFF0F3F8),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _LateReportEmployeeCell(
                              name: _readStringFromMap(
                                row,
                                const ['full_name', 'fullName', 'name'],
                                fallback: 'N/A',
                              ),
                              role: _lateReportsRoleLabel(
                                _readStringFromMap(
                                  row,
                                  const ['role', 'designation'],
                                  fallback: 'N/A',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _lateReportsDisplayDate(
                                  row['date'] ?? row['late_date'],
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF44546A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                    color: Color(0xFFE07A00),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _lateReportsDisplayTime(
                                        row['check_in_time'] ??
                                            row['checkInTime'],
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFFE07A00),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: Color(0xFF8B96A8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _readStringFromMap(
                                      row,
                                      const [
                                        'checkin_address',
                                        'checkinAddress',
                                        'location'
                                      ],
                                      fallback: '-',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF52657D),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildSalesManagerDailyViewData({
    required Map<String, dynamic> source,
    required DateTime selectedDate,
  }) {
    final rows = _buildSalesManagerDailyRows(
      source: source,
      selectedDate: selectedDate,
    );
    final records = rows.map((row) {
      final user = _userFromMonthGridRow(row);
      final day = _dailyDayForRow(row);
      return <String, dynamic>{
        'full_name': _readStringFromMap(
          user,
          const ['full_name', 'fullName', 'name'],
          fallback: 'N/A',
        ),
        'email': _readStringFromMap(user, const ['email']),
        'role': _readStringFromMap(
          user,
          const ['role', 'designation'],
          fallback: 'N/A',
        ),
        'status': _readStringFromMap(day, const ['status'], fallback: 'absent'),
        'check_in_time': _readStringFromMap(
          day,
          const ['check_in_time', 'checkInTime'],
          fallback: '--:--',
        ),
        'check_out_time': _readStringFromMap(
          day,
          const ['check_out_time', 'checkOutTime'],
          fallback: '--:--',
        ),
        'working_hours': _readStringFromMap(
          day,
          const ['working_hours', 'workingHours'],
          fallback: '',
        ),
      };
    }).toList();

    return <String, dynamic>{
      ...source,
      'records': records,
      'summary': source['summary'] ?? _dailySummaryCounts(rows),
    };
  }

  List<Map<String, dynamic>> _buildSalesManagerDailyRows({
    required Map<String, dynamic> source,
    required DateTime selectedDate,
  }) {
    final attendanceRows = _sourceRows(source);
    final teamMemberRows = _teamMemberRows(source);
    final attendanceByUserId = <String, Map<String, dynamic>>{};

    for (final entry in attendanceRows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      final userId = _salesManagerUserKey(row);
      if (userId.isNotEmpty) {
        attendanceByUserId[userId] = row;
      }
    }

    final baseRows = teamMemberRows.isNotEmpty
        ? teamMemberRows
        : attendanceRows
            .whereType<Map>()
            .map(
              (entry) => Map<String, dynamic>.from(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();

    if (baseRows.isEmpty) {
      return _salesManagerFallbackRows(source, selectedDate, selectedDate);
    }

    return baseRows.map((entry) {
      final row = Map<String, dynamic>.from(entry);
      final user = _extractSalesManagerUser(row);
      final userId = _salesManagerUserKey(user).isNotEmpty
          ? _salesManagerUserKey(user)
          : _salesManagerUserKey(row);
      final attendance = userId.isNotEmpty ? attendanceByUserId[userId] : null;
      final mergedDay = attendance == null
          ? _defaultSalesManagerDay(selectedDate)
          : _normalizeSalesManagerTeamDay(
              <String, dynamic>{
                ...attendance,
                'date': _formatDateForApi(selectedDate),
              },
            );
      final summary = _extractSalesManagerSummary(
        {
          ...row,
          'summary': <String, dynamic>{
            'present': mergedDay['status'] == 'present' ? 1 : 0,
            'late': mergedDay['status'] == 'late' ? 1 : 0,
            'absent': mergedDay['status'] == 'absent' ? 1 : 0,
            'on_leave': mergedDay['status'] == 'on_leave' ||
                    mergedDay['status'] == 'leave'
                ? 1
                : 0,
            'total_working_hours': mergedDay['working_hours'] ?? 0,
          },
        },
        <Map<String, dynamic>>[mergedDay],
      );
      return <String, dynamic>{
        ...row,
        'user': user,
        'days': <Map<String, dynamic>>[mergedDay],
        'summary': summary,
        'present': summary['present'],
        'late': summary['late'],
        'absent': summary['absent'],
        'on_leave': summary['on_leave'],
        'total_working_hours': summary['total_working_hours'],
      };
    }).toList();
  }

  List<dynamic> _sourceRows(Map<String, dynamic> source) {
    for (final key in const ['data', 'records', 'items', 'rows']) {
      final value = source[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nestedKey in const ['data', 'records', 'items', 'rows']) {
          final nestedValue = value[nestedKey];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return const <dynamic>[];
  }

  List<Map<String, dynamic>> _teamMemberRows(Map<String, dynamic> source) {
    for (final key in const ['team_members', 'teamMembers', 'members']) {
      final value = source[key];
      if (value is! List) continue;
      return value.whereType<Map>().map((entry) {
        return Map<String, dynamic>.from(
          entry.map((key, val) => MapEntry(key.toString(), val)),
        );
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _sourceUserRow(Map<String, dynamic> source) {
    for (final key in const ['user', 'current_user', 'currentUser', 'me']) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return const <String, dynamic>{};
  }

  String _salesManagerUserKey(Map<String, dynamic> row) {
    final key = _readStringFromMap(
      row,
      const ['user_id', 'id', 'userId', 'member_id', 'memberId'],
      fallback: '',
    );
    if (key.isNotEmpty) {
      return key;
    }
    final user = row['user'];
    if (user is Map) {
      return _readStringFromMap(
        Map<String, dynamic>.from(
          user.map((k, v) => MapEntry(k.toString(), v)),
        ),
        const ['id', 'user_id', 'userId'],
        fallback: '',
      );
    }
    return '';
  }

  Map<String, dynamic> _buildSalesManagerSummaryData(
    Map<String, dynamic> source,
  ) {
    final rows = _normalizeSalesManagerTeamRows(
      source: source,
      rows: source['data'] is List
          ? source['data'] as List<dynamic>
          : const <dynamic>[],
      from: _summaryFromDate,
      to: _summaryToDate,
    );
    return <String, dynamic>{
      ...source,
      'data': rows.map((row) {
        final user = _userFromMonthGridRow(row);
        final summary = row['summary'] is Map<String, dynamic>
            ? row['summary'] as Map<String, dynamic>
            : const <String, dynamic>{};
        final present = _readIntValue(summary['present'] ?? row['present'], 0);
        final late = _readIntValue(summary['late'] ?? row['late'], 0);
        final absent = _readIntValue(summary['absent'] ?? row['absent'], 0);
        final leave = _readIntValue(summary['on_leave'] ?? row['on_leave'], 0);
        final denominator = present + late + absent + leave;
        return <String, dynamic>{
          'full_name': _readStringFromMap(
            user,
            const ['full_name', 'fullName', 'name'],
            fallback: 'N/A',
          ),
          'email': _readStringFromMap(user, const ['email']),
          'role': _readStringFromMap(
            user,
            const ['role', 'designation'],
            fallback: 'N/A',
          ),
          'present': present,
          'late': late,
          'absent': absent,
          'on_leave': leave,
          'total_working_hours':
              summary['total_working_hours'] ?? row['total_working_hours'] ?? 0,
          'attendance_percent':
              denominator == 0 ? 0.0 : ((present + late) / denominator) * 100,
        };
      }).toList(),
    };
  }

  List<Map<String, dynamic>> _normalizeSalesManagerTeamRows({
    required Map<String, dynamic> source,
    required List<dynamic> rows,
    required DateTime from,
    required DateTime to,
  }) {
    final normalized = rows
        .whereType<Map>()
        .map((entry) => _normalizeSalesManagerTeamRow(
              Map<String, dynamic>.from(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
              from,
              to,
            ))
        .toList();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return _salesManagerFallbackRows(source, from, to);
  }

  Map<String, dynamic> _normalizeSalesManagerTeamRow(
    Map<String, dynamic> row,
    DateTime from,
    DateTime to,
  ) {
    final user = _extractSalesManagerUser(row);
    final days = _normalizeSalesManagerTeamDays(row, from, to);
    final summary = _extractSalesManagerSummary(row, days);
    return <String, dynamic>{
      ...row,
      'user': user,
      'days': days,
      'summary': summary,
      'present': summary['present'],
      'late': summary['late'],
      'absent': summary['absent'],
      'on_leave': summary['on_leave'],
      'total_working_hours': summary['total_working_hours'],
    };
  }

  Map<String, dynamic> _extractSalesManagerUser(Map<String, dynamic> row) {
    for (final candidate in [
      row['user'],
      row['employee'],
      row['team_member'],
      row['member']
    ]) {
      if (candidate is Map<String, dynamic>) {
        return candidate;
      }
      if (candidate is Map) {
        return Map<String, dynamic>.from(
          candidate.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    return <String, dynamic>{
      'id': _readStringFromMap(row, const ['id', 'user_id', 'userId']),
      'full_name': _readStringFromMap(
        row,
        const ['full_name', 'fullName', 'name'],
        fallback: 'N/A',
      ),
      'role': _readStringFromMap(
        row,
        const ['role', 'designation'],
        fallback: 'N/A',
      ),
      'email': _readStringFromMap(row, const ['email']),
    };
  }

  List<Map<String, dynamic>> _normalizeSalesManagerTeamDays(
    Map<String, dynamic> row,
    DateTime from,
    DateTime to,
  ) {
    dynamic rawDays = row['days'] ??
        row['attendance'] ??
        row['attendances'] ??
        row['records'] ??
        row['entries'] ??
        row['items'];
    if (rawDays is Map) {
      rawDays = rawDays['data'] ??
          rawDays['days'] ??
          rawDays['attendance'] ??
          rawDays['attendances'] ??
          rawDays['records'];
    }
    if (rawDays is! List) {
      return _defaultSalesManagerDays(from, to);
    }

    final byDate = <String, Map<String, dynamic>>{};
    for (final entry in rawDays.whereType<Map>()) {
      final normalized = _normalizeSalesManagerTeamDay(
        Map<String, dynamic>.from(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      final key = normalized['date']?.toString() ?? '';
      if (key.isNotEmpty) {
        byDate[key] = normalized;
      }
    }

    return _dateRangeStrings(from, to).map((date) {
      return byDate[date] ?? _defaultSalesManagerDay(DateTime.parse(date));
    }).toList();
  }

  Map<String, dynamic> _normalizeSalesManagerTeamDay(Map<String, dynamic> day) {
    final nestedAttendance = day['attendance'];
    final source = nestedAttendance is Map<String, dynamic>
        ? <String, dynamic>{...nestedAttendance, ...day}
        : nestedAttendance is Map
            ? <String, dynamic>{
                ...Map<String, dynamic>.from(
                  nestedAttendance.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
                ...day,
              }
            : day;
    final checkIn = _readStringFromMap(
      source,
      const ['check_in_time', 'checkInTime', 'check_in', 'checkIn'],
      fallback: '',
    );
    return <String, dynamic>{
      'date': _readStringFromMap(
        source,
        const ['date', 'attendance_date', 'attendanceDate'],
        fallback: '',
      ),
      'status': _normalizeAttendanceStatus(
        _readStringFromMap(
          source,
          const ['status', 'attendance_status', 'attendanceStatus'],
          fallback: checkIn.isNotEmpty ? 'present' : 'absent',
        ),
      ),
      'check_in_time': checkIn,
      'check_out_time': _readStringFromMap(
        source,
        const ['check_out_time', 'checkOutTime', 'check_out', 'checkOut'],
        fallback: '',
      ),
      'working_hours': _readStringFromMap(
        source,
        const [
          'working_hours',
          'workingHours',
          'hours_worked',
          'hoursWorked',
          'total_working_hours'
        ],
        fallback: '',
      ),
    };
  }

  Map<String, dynamic> _extractSalesManagerSummary(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> days,
  ) {
    final nestedSummary = row['summary'];
    if (nestedSummary is Map<String, dynamic>) {
      return <String, dynamic>{
        'present': _readIntValue(nestedSummary['present'], 0),
        'late': _readIntValue(nestedSummary['late'], 0),
        'absent': _readIntValue(nestedSummary['absent'], 0),
        'on_leave': _readIntValue(nestedSummary['on_leave'], 0),
        'total_working_hours': nestedSummary['total_working_hours'] ?? 0,
      };
    }

    final present =
        row.containsKey('present') ? _readIntValue(row['present'], 0) : -1;
    final late = row.containsKey('late') ? _readIntValue(row['late'], 0) : -1;
    final absent =
        row.containsKey('absent') ? _readIntValue(row['absent'], 0) : -1;
    final leave =
        row.containsKey('on_leave') ? _readIntValue(row['on_leave'], 0) : -1;

    if (present >= 0 || late >= 0 || absent >= 0 || leave >= 0) {
      return <String, dynamic>{
        'present': present < 0 ? 0 : present,
        'late': late < 0 ? 0 : late,
        'absent': absent < 0 ? 0 : absent,
        'on_leave': leave < 0 ? 0 : leave,
        'total_working_hours': row['total_working_hours'] ?? 0,
      };
    }

    return <String, dynamic>{
      ..._countsFromSalesManagerDays(days),
      'total_working_hours': row['total_working_hours'] ?? 0,
    };
  }

  Map<String, dynamic> _countsFromSalesManagerDays(
      List<Map<String, dynamic>> days) {
    var present = 0;
    var late = 0;
    var absent = 0;
    var leave = 0;
    for (final day in days) {
      final status =
          _readStringFromMap(day, const ['status'], fallback: 'absent');
      switch (status) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'on_leave':
        case 'leave':
          leave++;
          break;
        case 'weekend':
          break;
        default:
          absent++;
      }
    }
    return <String, dynamic>{
      'present': present,
      'late': late,
      'absent': absent,
      'on_leave': leave,
    };
  }

  List<Map<String, dynamic>> _salesManagerFallbackRows(
    Map<String, dynamic> source,
    DateTime from,
    DateTime to,
  ) {
    final membersRaw = source['team_members'];
    if (membersRaw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return membersRaw.whereType<Map>().map((entry) {
      final member = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      final days = _defaultSalesManagerDays(from, to);
      final summary = _countsFromSalesManagerDays(days);
      return <String, dynamic>{
        'user': member,
        'days': days,
        'summary': summary,
        'present': summary['present'],
        'late': summary['late'],
        'absent': summary['absent'],
        'on_leave': summary['on_leave'],
        'total_working_hours': 0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _defaultSalesManagerDays(
      DateTime from, DateTime to) {
    return _dateRangeStrings(from, to)
        .map((date) => _defaultSalesManagerDay(DateTime.parse(date)))
        .toList();
  }

  Map<String, dynamic> _defaultSalesManagerDay(DateTime date) {
    return <String, dynamic>{
      'date': _formatDateForApi(date),
      'status': date.weekday >= 6 ? 'weekend' : 'absent',
      'check_in_time': '',
      'check_out_time': '',
      'working_hours': '',
    };
  }

  List<String> _dateRangeStrings(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    if (end.isBefore(start)) {
      return <String>[_formatDateForApi(start)];
    }
    final dates = <String>[];
    var current = start;
    while (!current.isAfter(end)) {
      dates.add(_formatDateForApi(current));
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  String _normalizeAttendanceStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'on leave') return 'on_leave';
    if (normalized == 'checked_in' || normalized == 'checked in') {
      return 'present';
    }
    if (normalized.isEmpty) return 'absent';
    return normalized;
  }

  double _readDoubleValue(dynamic value, [double fallback = 0.0]) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Widget _buildSummaryTabContent(double maxWidth) {
    final rows = _summaryRows();
    final compact = maxWidth < 620;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _SummaryDateButton(
                            value: _displayDate(_summaryFromDate),
                            onTap: _pickSummaryFromDate,
                          ),
                          const Text(
                            'to',
                            style: TextStyle(
                              color: Color(0xFF8B98AA),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _SummaryDateButton(
                            value: _displayDate(_summaryToDate),
                            onTap: _pickSummaryToDate,
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team Summary',
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _SummaryDateButton(
                            value: _displayDate(_summaryFromDate),
                            onTap: _pickSummaryFromDate,
                          ),
                          const Text(
                            'to',
                            style: TextStyle(
                              color: Color(0xFF8B98AA),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _SummaryDateButton(
                            value: _displayDate(_summaryToDate),
                            onTap: _pickSummaryToDate,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingSummary)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_summaryError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _summaryError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Text(
                'No summary data available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF71809A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: rows.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final name = _readStringFromMap(
                  row,
                  const ['full_name', 'fullName', 'name'],
                  fallback: 'N/A',
                );
                final email = _readStringFromMap(
                  row,
                  const ['email'],
                  fallback: '',
                );
                final role = _readStringFromMap(
                  row,
                  const ['role', 'designation'],
                  fallback: 'N/A',
                ).replaceAll('_', ' ');
                final present = _readIntValue(row['present'], 0);
                final late = _readIntValue(row['late'], 0);
                final absent = _readIntValue(row['absent'], 0);
                final leave = _readIntValue(row['on_leave'], 0);
                final hours = _readDoubleValue(row['total_working_hours'], 0.0)
                    .toStringAsFixed(1);
                final percent =
                    _readDoubleValue(row['attendance_percent'], 0.0);

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2EAF5)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0B1F3A),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9AA7BB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _SummaryTextCell(text: role, width: double.infinity),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SummaryMetricPill(
                            label: 'Present',
                            value: '$present',
                            color: const Color(0xFF008A63),
                          ),
                          _SummaryMetricPill(
                            label: 'Late',
                            value: '$late',
                            color: const Color(0xFFE07900),
                          ),
                          _SummaryMetricPill(
                            label: 'Absent',
                            value: '$absent',
                            color: const Color(0xFFF04452),
                          ),
                          _SummaryMetricPill(
                            label: 'Leave',
                            value: '$leave',
                            color: const Color(0xFF4D4BFF),
                          ),
                          if (_canViewWorkingHours)
                            _SummaryMetricPill(
                              label: 'Working Hrs',
                              value: '${hours}h',
                              color: const Color(0xFF1E74D8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Attendance',
                            style: TextStyle(
                              color: const Color(0xFF5A6C86),
                              fontSize: compact ? 12 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 7,
                                value: (percent / 100).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFFE8EDF4),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1DB074),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: percent > 0
                                  ? const Color(0xFF008A63)
                                  : const Color(0xFFF04452),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarTabContent(double maxWidth) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final items = _buildCalendarItems();
    final summary = _calendarSummary();

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
                Expanded(
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
                        "${summary['present']} present - ${summary['absent']} absent - ${summary['late']} late",
                        style: TextStyle(
                          color: Color(0xFF95A1B6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundActionButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _changeCalendarMonth(-1),
                ),
                const SizedBox(width: 8),
                Text(
                  _monthLabel(_calendarMonth),
                  style: TextStyle(
                    color: Color(0xFF2C3E5D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _RoundActionButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _changeCalendarMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingCalendar)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_calendarError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _calendarError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LegendChip(
                    label: "${summary['present']} Present",
                    textColor: Color(0xFF0F9D71),
                    bgColor: Color(0xFFDDF7E9),
                  ),
                  _LegendChip(
                    label: "${summary['late']} Late",
                    textColor: Color(0xFFC57D0B),
                    bgColor: Color(0xFFFDF0D6),
                  ),
                  _LegendChip(
                    label: "${summary['absent']} Absent",
                    textColor: Color(0xFFDE3D3D),
                    bgColor: Color(0xFFFCE4E4),
                  ),
                  _LegendChip(
                    label: '0 Leave',
                    textColor: Color(0xFF5B65C5),
                    bgColor: Color(0xFFE8EAFE),
                  ),
                  if (_canViewWorkingHours)
                    _LegendChip(
                      label:
                          "${_readStringFromMap(_calendarData['summary'] is Map<String, dynamic> ? _calendarData['summary'] as Map<String, dynamic> : const <String, dynamic>{}, const [
                                'total_working_hours'
                              ], fallback: '0')}h worked",
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
                  itemBuilder: (context, index) =>
                      _CalendarDayCell(cell: items[index]),
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
                  Expanded(
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
                          '--:--      to      --:--',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE3E3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Absent',
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
    final statusLabel = _todayStatus();
    final statusLower = statusLabel.toLowerCase();
    final isPresentStatus =
        statusLower == 'present' || statusLower == 'checked in' || _isCheckedIn;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TODAY\'S ATTENDANCE',
                        style: TextStyle(
                          color: Color(0xD9E6F0FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _todayDateLabel(),
                        style: const TextStyle(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName(),
                            style: const TextStyle(
                              color: Color(0xFF0D203E),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userRole(),
                            style: const TextStyle(
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
                        color: isPresentStatus
                            ? const Color(0xFFE7F8EE)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: isPresentStatus
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444),
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: isPresentStatus
                                  ? const Color(0xFF166534)
                                  : const Color(0xFFB91C1C),
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
                  children: [
                    Expanded(
                      child: _MiniTimeCard(
                        icon: Icons.login_rounded,
                        iconColor: const Color(0xFF22C55E),
                        label: 'Check In',
                        value: _todayCheckIn(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniTimeCard(
                        icon: Icons.logout_rounded,
                        iconColor: const Color(0xFFF43F5E),
                        label: 'Check Out',
                        value: _todayCheckOut(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAttendanceSubmitting
                        ? null
                        : _handleAttendanceAction,
                    icon: Icon(
                      _isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _isAttendanceSubmitting
                          ? (_isCheckedIn
                              ? 'Checking Out...'
                              : 'Checking In...')
                          : (_isCheckedIn ? 'Check Out' : 'Check In'),
                    ),
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
    final statusLabel = _todayStatus();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final childAspectRatio = cardWidth > 260
            ? 1.85
            : cardWidth > 220
                ? 1.35
                : cardWidth > 180
                    ? 1.15
                    : 0.95;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatusCard(
              title: statusLabel,
              subtitle: 'Status Today',
              caption: _todayError ?? (_isLoadingToday ? 'Loading...' : ''),
              value: '',
              icon: Icons.check_circle_outline_rounded,
              iconColor: statusLabel.toLowerCase() == 'present'
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFF55462),
              bubbleColor: statusLabel.toLowerCase() == 'present'
                  ? const Color(0xFFE8F6EE)
                  : const Color(0xFFF9EAEC),
            ),
            if (_canViewWorkingHours)
              _StatusCard(
                title: 'Working Hours',
                subtitle: 'Today so far',
                caption: '',
                value: _todayWorkingHours(),
                icon: Icons.timer_outlined,
                iconColor: AppColors.primary,
                bubbleColor: const Color(0xFFE8EEF7),
              ),
            _StatusCard(
              title: 'Check In',
              subtitle: '',
              caption: _isCheckedIn ? 'Checked in' : 'Not checked in yet',
              value: _todayCheckIn(),
              icon: Icons.login_rounded,
              iconColor: const Color(0xFF22C55E),
              bubbleColor: const Color(0xFFE8F6EE),
            ),
            _StatusCard(
              title: 'Check Out',
              subtitle: '',
              caption:
                  _isCheckedOutToday() ? 'Checked out' : 'Not checked out yet',
              value: _todayCheckOut(),
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFF55462),
              bubbleColor: const Color(0xFFF9EAEC),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyHistoryTabContent(double maxWidth) {
    final summary = _myHistorySummary();
    final entries = _myHistoryEntries();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Attendance History',
                    style: TextStyle(
                      color: Color(0xFF172B4D),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _RoundActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadMyHistoryAttendance,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: GridView.count(
              crossAxisCount: maxWidth < 430 ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: maxWidth < 430 ? 1.95 : 1.45,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _HistoryStatTile(
                  value: summary['present'] ?? 0,
                  label: 'Present',
                  color: const Color(0xFF009966),
                ),
                _HistoryStatTile(
                  value: summary['absent'] ?? 0,
                  label: 'Absent',
                  color: const Color(0xFFF04452),
                ),
                _HistoryStatTile(
                  value: summary['late'] ?? 0,
                  label: 'Late',
                  color: const Color(0xFFE88700),
                ),
                _HistoryStatTile(
                  value: summary['leave'] ?? 0,
                  label: 'Leave',
                  color: const Color(0xFF4F46E5),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (_isLoadingMyHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myHistoryError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _myHistoryError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadMyHistoryAttendance,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No attendance history available.',
                style: TextStyle(
                  color: Color(0xFF7C8DA6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.separated(
              itemCount: entries.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF0F3F8)),
              itemBuilder: (context, index) {
                return _HistoryAttendanceRow(
                  entry: entries[index],
                  canViewWorkingHours: _canViewWorkingHours,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickApprovalDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _approvalDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _approvalDate = DateTime(picked.year, picked.month, picked.day);
      _dailyViewDate = DateTime(picked.year, picked.month, picked.day);
    });
    _loadDailyViewAttendance();
    _loadApprovalPending();
  }

  Future<void> _loadApprovalPending() async {
    setState(() {
      _isLoadingApprovals = true;
      _approvalsError = null;
    });
    try {
      final data = await _authProvider.attendancePending(
        date: _formatDateForApi(_approvalDate),
        token: _authProvider.currentAuthToken,
      );
      final parsedRows = _extractApprovalRows(data);
      if (!mounted) return;
      setState(() {
        _approvalRows = parsedRows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _approvalsError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApprovals = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractApprovalRows(Map<String, dynamic> source) {
    dynamic list = source['records'] ??
        source['items'] ??
        source['rows'] ??
        source['pending'] ??
        source['data'];

    if (list is Map<String, dynamic>) {
      list = list['records'] ?? list['items'] ?? list['rows'] ?? list['data'];
    }

    if (list is! List) {
      return const <Map<String, dynamic>>[];
    }

    return list
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<void> _loadHolidays({int? page}) async {
    final nextPage = page ?? _holidaysCurrentPage;
    setState(() {
      _isLoadingHolidays = true;
      _holidaysError = null;
    });

    try {
      final data = await _authProvider.holidays(
        page: nextPage,
        perPage: 10,
        token: _authProvider.currentAuthToken,
      );
      final rows = _extractHolidayRows(data);
      final pagination = _extractPaginationMap(data);
      final resolvedCurrentPage = _readIntValue(
        pagination['page'],
        _readIntValue(pagination['current_page'], nextPage),
      ).clamp(1, 999999);
      final resolvedTotalPages = _readIntValue(
        pagination['total_pages'],
        _readIntValue(pagination['last_page'], 1),
      ).clamp(1, 999999);
      final resolvedTotalItems = _readIntValue(
        pagination['total'],
        _readIntValue(pagination['total_items'], rows.length),
      );
      final years = _holidayYearOptions(rows);

      if (!mounted) return;
      setState(() {
        _holidayRows = rows;
        _holidaysCurrentPage = resolvedCurrentPage.toInt();
        _holidaysTotalPages = resolvedTotalPages.toInt();
        _holidaysTotalItems = resolvedTotalItems;
        _holidayYears = years;
        if (_holidayYears.isNotEmpty &&
            !_holidayYears.contains(_selectedHolidayYear)) {
          _selectedHolidayYear = _holidayYears.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _holidaysError = AppErrorHandler.friendlyMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHolidays = false;
        });
      }
    }
  }

  Future<void> _openHolidayForm({Map<String, dynamic>? holiday}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => HolidayFormPage(holidayData: holiday),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      await _loadHolidays(page: _holidaysCurrentPage);
    }
  }

  Future<void> _deleteHoliday(Map<String, dynamic> holiday) async {
    final id = _holidayId(holiday);
    final name = _holidayName(holiday);
    if (id.isEmpty) {
      _showSnackBar('Holiday id is missing.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Holiday'),
          content: Text('Delete "$name"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _authProvider.deleteHoliday(
        id: id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showSnackBar('Holiday deleted.');
      await _loadHolidays(page: _holidaysCurrentPage);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    }
  }

  List<Map<String, dynamic>> _extractHolidayRows(Map<String, dynamic> source) {
    dynamic list = source['records'] ??
        source['items'] ??
        source['rows'] ??
        source['holidays'] ??
        source['data'];
    if (list is Map<String, dynamic>) {
      list = list['records'] ??
          list['items'] ??
          list['rows'] ??
          list['holidays'] ??
          list['data'];
    }
    if (list is! List) {
      return const <Map<String, dynamic>>[];
    }
    return list
        .whereType<Map>()
        .map(
          (entry) => Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _extractPaginationMap(Map<String, dynamic> source) {
    final pagination = source['pagination'] ?? source['meta'];
    if (pagination is Map<String, dynamic>) return pagination;
    if (pagination is Map) {
      return Map<String, dynamic>.from(
        pagination.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  int? _holidayYear(Map<String, dynamic> holiday) {
    final date = _holidayDate(holiday);
    return date?.year;
  }

  DateTime? _holidayDate(Map<String, dynamic> holiday) {
    return _parseApiDate(
      _readStringFromMap(
        holiday,
        const [
          'date',
          'holiday_date',
          'holidayDate',
          'start_date',
          'startDate',
        ],
        fallback: '',
      ),
    );
  }

  String _holidayId(Map<String, dynamic> holiday) {
    return _readStringFromMap(
      holiday,
      const ['id', 'holiday_id', 'holidayId', 'uuid'],
      fallback: '',
    );
  }

  String _holidayName(Map<String, dynamic> holiday) {
    return _readStringFromMap(
      holiday,
      const ['name', 'holiday_name', 'holidayName'],
      fallback: 'Holiday',
    );
  }

  String _holidayDescription(Map<String, dynamic> holiday) {
    return _readStringFromMap(
      holiday,
      const ['description', 'notes', 'remark'],
      fallback: '',
    );
  }

  List<String> _holidayRoles(Map<String, dynamic> holiday) {
    return _holidayStringList(holiday, const [
      'roles',
      'role_ids',
      'roleIds',
      'apply_to_roles',
    ]);
  }

  List<String> _holidayUsers(Map<String, dynamic> holiday) {
    return _holidayStringList(holiday, const [
      'user_ids',
      'userIds',
      'users',
      'specific_users',
    ]);
  }

  List<String> _holidayStringList(
    Map<String, dynamic> holiday,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = holiday[key];
      if (value is List) {
        return value
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty && entry.toLowerCase() != 'null')
            .toList(growable: false);
      }
      if (value is Map) {
        final nested = value.values
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty && entry.toLowerCase() != 'null')
            .toList(growable: false);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return const <String>[];
  }

  List<int> _holidayYearOptions(List<Map<String, dynamic>> rows) {
    final currentYear = DateTime.now().year;
    final yearCount = currentYear >= 2000 ? currentYear - 2000 + 1 : 0;
    final years = <int>{
      for (final year in rows.map(_holidayYear).whereType<int>()) year,
      _selectedHolidayYear,
      currentYear,
      ...List<int>.generate(
        yearCount,
        (index) => 2000 + index,
      ),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  String _holidaySelectionSummary(
    Map<String, dynamic> holiday,
  ) {
    final roles = _holidayRoles(holiday);
    final normalizedRoles =
        roles.map(_normalizeHolidayRoleId).toList(growable: false);
    final users = _holidayUsers(holiday);
    final roleLabels = normalizedRoles
        .map<String>((role) => role == 'all' ? 'All roles' : _formatRole(role))
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);

    if (normalizedRoles.contains('all')) {
      return users.isEmpty
          ? 'All roles'
          : 'All roles + ${users.length} specific user${users.length == 1 ? '' : 's'}';
    }

    final parts = <String>[];
    if (roleLabels.isNotEmpty) {
      parts.add(
        '${roleLabels.length} role${roleLabels.length == 1 ? '' : 's'}',
      );
    }
    if (users.isNotEmpty) {
      parts.add(
        '${users.length} specific user${users.length == 1 ? '' : 's'}',
      );
    }
    return parts.isEmpty ? 'No targets selected' : parts.join(' + ');
  }

  String _formatHolidayDate(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatRole(String value) {
    return RoleAccess.label(value);
  }

  String _normalizeHolidayRoleId(String value) {
    final normalized = RoleAccess.normalize(value);
    if (normalized == 'all_roles' || normalized == 'allrole') {
      return 'all';
    }
    return normalized;
  }

  Widget _buildHolidaysTabContent(double maxWidth) {
    final filteredRows = _holidayRows.where((holiday) {
      final year = _holidayYear(holiday);
      if (year == null) return false;
      return year == _selectedHolidayYear;
    }).toList(growable: false);
    final compact = maxWidth < 720;
    final years = _holidayYears.isEmpty
        ? <int>[_selectedHolidayYear]
        : _holidayYears.toList(growable: false);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFFA855F7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Holidays',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Declare company or team-specific holidays',
                          style: TextStyle(
                            color: Color(0xFFF2E9FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _HolidayYearDropdown(
                              value: _selectedHolidayYear,
                              years: years,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedHolidayYear = value;
                                });
                                _loadHolidays(page: 1);
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _openHolidayForm(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF6D28D9),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('New Holiday'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Holidays',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Declare company or team-specific holidays',
                                style: TextStyle(
                                  color: Color(0xFFF2E9FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HolidayYearDropdown(
                          value: _selectedHolidayYear,
                          years: years,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedHolidayYear = value;
                            });
                            _loadHolidays(page: 1);
                          },
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => _openHolidayForm(),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6D28D9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Holiday'),
                        ),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFFF8FAFD),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: _isLoadingHolidays
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _holidaysError != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Text(
                                _holidaysError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _loadHolidays,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filteredRows.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1E8FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.event_available_outlined,
                                      color: Color(0xFF7C3AED),
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'No holidays found for this year.',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Create the first holiday to make it visible here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: () => _openHolidayForm(),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('New Holiday'),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${filteredRows.length} holiday${filteredRows.length == 1 ? '' : 's'} in $_selectedHolidayYear'
                                    '${_holidaysTotalItems > 0 ? ' | $_holidaysTotalItems total' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  itemCount: filteredRows.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final holiday = filteredRows[index];
                                    return _HolidayCard(
                                      date: _holidayDate(holiday),
                                      title: _holidayName(holiday),
                                      description: _holidayDescription(holiday),
                                      summary:
                                          _holidaySelectionSummary(holiday),
                                      onEdit: () =>
                                          _openHolidayForm(holiday: holiday),
                                      onDelete: () => _deleteHoliday(holiday),
                                    );
                                  },
                                ),
                                if (_holidaysTotalPages > 1) ...[
                                  const SizedBox(height: 14),
                                  PaginationWidget(
                                    currentPage: _holidaysCurrentPage,
                                    totalPages: _holidaysTotalPages,
                                    totalItems: _holidaysTotalItems,
                                    itemLabel: 'holidays',
                                    onPageChanged: (page) => _loadHolidays(
                                      page: page,
                                    ),
                                  ),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsTabContent(double maxWidth) {
    final compact = maxWidth < 700;
    final displayDate = _displayDate(_approvalDate);
    final rows = _approvalRows;
    final summary = _approvalSummaryCounts(rows);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Approvals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 22 : 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Review and approve employee attendance status',
                        style: TextStyle(
                          color: Color(0xFFD8D3FF),
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_rounded,
                    color: Color(0xFFEDE9FE),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFD),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EDF5)),
              ),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ApprovalDateButton(
                        value: displayDate,
                        onTap: _pickApprovalDate,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ApprovalCountChip(
                            icon: Icons.logout_rounded,
                            label:
                                '${_approvalNotCheckedOutCount(rows)} not checked out',
                            textColor: Color(0xFFF97316),
                            bgColor: Color(0xFFFFF1E8),
                          ),
                          _ApprovalCountChip(
                            icon: Icons.cancel_outlined,
                            label: '${summary['absent'] ?? 0} absent',
                            textColor: Color(0xFFEF4444),
                            bgColor: Color(0xFFFFECEC),
                          ),
                          _ApprovalCountChip(
                            icon: Icons.schedule_rounded,
                            label: '${summary['late'] ?? 0} late',
                            textColor: Color(0xFFD97706),
                            bgColor: Color(0xFFFFF6E5),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _ApprovalDateButton(
                        value: displayDate,
                        onTap: _pickApprovalDate,
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ApprovalCountChip(
                            icon: Icons.logout_rounded,
                            label:
                                '${_approvalNotCheckedOutCount(rows)} not checked out',
                            textColor: Color(0xFFF97316),
                            bgColor: Color(0xFFFFF1E8),
                          ),
                          _ApprovalCountChip(
                            icon: Icons.cancel_outlined,
                            label: '${summary['absent'] ?? 0} absent',
                            textColor: Color(0xFFEF4444),
                            bgColor: Color(0xFFFFECEC),
                          ),
                          _ApprovalCountChip(
                            icon: Icons.schedule_rounded,
                            label: '${summary['late'] ?? 0} late',
                            textColor: Color(0xFFD97706),
                            bgColor: Color(0xFFFFF6E5),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _isLoadingApprovals
                ? const Center(child: CircularProgressIndicator())
                : _approvalsError != null
                    ? Center(
                        child: Text(
                          _approvalsError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : rows.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'All caught up!',
                                style: TextStyle(
                                  color: const Color(0xFF1E3A5F),
                                  fontSize: compact ? 22 : 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No pending approvals for $displayDate',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF98A4B8),
                                  fontSize: compact ? 14 : 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${rows.length} employees | ${summary['present'] ?? 0} present',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...rows.map((row) {
                                final name = _approvalName(row);
                                final role = _approvalRole(row);
                                final status = _approvalStatus(row);
                                final checkIn = _approvalCheckIn(row);
                                final checkOut = _approvalCheckOut(row);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ApprovalEmployeeCard(
                                    name: name,
                                    role: role,
                                    status: status,
                                    checkIn: checkIn,
                                    checkOut: checkOut,
                                    onChange: () {
                                      _openApprovalStatusDialog(row);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _openApprovalStatusDialog(Map<String, dynamic> row) async {
    final name = _approvalName(row);

    final role = _approvalRole(row);
    final approvalId = _approvalId(row);
    if (approvalId.trim().isEmpty) {
      _showSnackBar('Cannot update status: approval id missing.');
      return;
    }
    final checkIn = _approvalCheckIn(row);
    final checkOut = _approvalCheckOut(row);
    final currentStatus = _approvalStatus(row);

    final reasonController = TextEditingController();
    final options = <String>[
      'present',
      'late',
      'absent',
      'on_leave',
      'half_day'
    ];
    var selectedStatus = options.contains(currentStatus.toLowerCase())
        ? currentStatus.toLowerCase()
        : 'present';

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactDialog = constraints.maxWidth < 430;
                  return Container(
                    padding: EdgeInsets.all(compactDialog ? 12 : 14),
                    constraints:
                        const BoxConstraints(maxWidth: 760, maxHeight: 640),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Change Status for ${name.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                icon: const Icon(Icons.link_off_rounded,
                                    size: 14),
                                label: const Text('Cancel'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF4F46E5),
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _statusPreviewChip(selectedStatus),
                                _ApprovalMetaText(
                                  icon: Icons.login_rounded,
                                  color: const Color(0xFF10B981),
                                  text: checkIn,
                                ),
                                _ApprovalMetaText(
                                  icon: Icons.logout_rounded,
                                  color: const Color(0xFFEF4444),
                                  text: checkOut == '--:--'
                                      ? 'Not checked out'
                                      : checkOut,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'New Status',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: options.map((status) {
                              final selected = selectedStatus == status;
                              return ChoiceChip(
                                selected: selected,
                                onSelected: (_) => setStateDialog(
                                    () => selectedStatus = status),
                                label: Text(_approvalStatusLabel(status)),
                                selectedColor: const Color(0xFFDDF7E9),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFD1D5DB),
                                ),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? const Color(0xFF0E9A6E)
                                      : const Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Reason (optional)',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Employee was on field visit...',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          compactDialog
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          side: const BorderSide(
                                              color: Color(0xFFD1D5DB)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isApprovingStatus
                                            ? null
                                            : () => Navigator.of(dialogContext)
                                                .pop(true),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          backgroundColor:
                                              const Color(0xFF6D28D9),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: Text(
                                          _isApprovingStatus
                                              ? 'Updating...'
                                              : 'Confirm Change',
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          side: const BorderSide(
                                              color: Color(0xFFD1D5DB)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isApprovingStatus
                                            ? null
                                            : () => Navigator.of(dialogContext)
                                                .pop(true),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          backgroundColor:
                                              const Color(0xFF6D28D9),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: Text(
                                          _isApprovingStatus
                                              ? 'Updating...'
                                              : 'Confirm Change',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (changed == true) {
      try {
        setState(() {
          _isApprovingStatus = true;
        });
        await _authProvider.attendanceApprove(
          id: approvalId,
          status: selectedStatus,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
          token: _authProvider.currentAuthToken,
        );
        if (!mounted) return;
        await _loadApprovalPending();
        _showSnackBar('Status updated for $name.');
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(AppErrorHandler.friendlyMessage(e));
      } finally {
        if (mounted) {
          setState(() {
            _isApprovingStatus = false;
          });
        }
      }
    }

    reasonController.dispose();
  }

  Widget _statusPreviewChip(String status) {
    final isPresent = status == 'present';
    final bg = isPresent ? const Color(0xFFDDF7E9) : const Color(0xFFFFE7E7);
    final fg = isPresent ? const Color(0xFF0E9A6E) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: fg),
          const SizedBox(width: 6),
          Text(
            _approvalStatusLabel(status),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _approvalStatusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

class _DailySummaryTile extends StatelessWidget {
  const _DailySummaryTile({
    required this.value,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final int value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: compact
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE8EDF5)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF8E9AAF),
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyStatusChip extends StatelessWidget {
  const _DailyStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final isPresent = lower == 'present';
    final isLate = lower == 'late';
    final isLeave = lower == 'on_leave' || lower == 'leave';
    final color = isPresent
        ? const Color(0xFF0F9D71)
        : isLate
            ? const Color(0xFFE07900)
            : isLeave
                ? const Color(0xFF5655F6)
                : const Color(0xFFF04452);
    final bg = isPresent
        ? const Color(0xFFDDF7E9)
        : isLate
            ? const Color(0xFFFFF2CC)
            : isLeave
                ? const Color(0xFFE8EAFE)
                : const Color(0xFFFFE0E0);
    final label = status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? 'Absent' : label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyDetailPill extends StatelessWidget {
  const _DailyDetailPill({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF71809A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.date,
    required this.dateLabel,
    required this.status,
    required this.statusLabel,
    required this.checkIn,
    required this.checkOut,
    required this.hours,
  });

  final DateTime date;
  final String dateLabel;
  final String status;
  final String statusLabel;
  final String checkIn;
  final String checkOut;
  final String hours;
}

class _HistoryStatTile extends StatelessWidget {
  const _HistoryStatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7C8DA6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAttendanceRow extends StatelessWidget {
  const _HistoryAttendanceRow({
    required this.entry,
    required this.canViewWorkingHours,
  });

  final _HistoryEntry entry;
  final bool canViewWorkingHours;

  @override
  Widget build(BuildContext context) {
    final colors = _historyColors(entry.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      entry.dateLabel,
                      style: const TextStyle(
                        color: Color(0xFF0F1F3D),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _HistoryStatusPill(
                      label: entry.statusLabel.isEmpty
                          ? 'Absent'
                          : entry.statusLabel,
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _HistoryMetaText(
                      icon: Icons.login_rounded,
                      color: const Color(0xFF10B981),
                      text: entry.checkIn,
                    ),
                    _HistoryMetaText(
                      icon: Icons.logout_rounded,
                      color: const Color(0xFFF55462),
                      text: entry.checkOut,
                    ),
                    if (canViewWorkingHours && entry.hours.isNotEmpty)
                      _HistoryMetaText(
                        icon: Icons.timer_outlined,
                        color: const Color(0xFF0A84FF),
                        text: entry.hours,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _HistoryStatusColors _historyColors(String status) {
    switch (status) {
      case 'present':
      case 'checked in':
        return const _HistoryStatusColors(
          accent: Color(0xFF10B981),
          foreground: Color(0xFF008A63),
          background: Color(0xFFDDF7E9),
        );
      case 'late':
        return const _HistoryStatusColors(
          accent: Color(0xFFF59E0B),
          foreground: Color(0xFFC56B00),
          background: Color(0xFFFFF0C6),
        );
      case 'leave':
      case 'on_leave':
        return const _HistoryStatusColors(
          accent: Color(0xFF4F46E5),
          foreground: Color(0xFF4F46E5),
          background: Color(0xFFE8EAFE),
        );
      default:
        return const _HistoryStatusColors(
          accent: Color(0xFFF04452),
          foreground: Color(0xFFDC2626),
          background: Color(0xFFFFE7E7),
        );
    }
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({
    required this.label,
    required this.colors,
  });

  final String label;
  final _HistoryStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetaText extends StatelessWidget {
  const _HistoryMetaText({
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
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF7C8DA6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HistoryStatusColors {
  const _HistoryStatusColors({
    required this.accent,
    required this.foreground,
    required this.background,
  });

  final Color accent;
  final Color foreground;
  final Color background;
}

class _SummaryDateButton extends StatelessWidget {
  const _SummaryDateButton({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 14),
      label: Text(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF42536D),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD5DEEB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryTextCell extends StatelessWidget {
  const _SummaryTextCell({
    required this.text,
    required this.width,
  });

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF5A6C86),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricPill extends StatelessWidget {
  const _SummaryMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2EAF5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF6A7B93),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LateReportDateButton extends StatelessWidget {
  const _LateReportDateButton({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 15),
      label: Text(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF334155),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD6DEEA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LateReportEmployeeCell extends StatelessWidget {
  const _LateReportEmployeeCell({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0B1F3A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF8A97A8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LateReportCard extends StatelessWidget {
  const _LateReportCard({
    required this.name,
    required this.role,
    required this.dateLabel,
    required this.checkInLabel,
    required this.location,
    required this.email,
  });

  final String name;
  final String role;
  final String dateLabel;
  final String checkInLabel;
  final String location;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EBDD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFE07A00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LateReportEmployeeCell(name: name, role: role),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: Color(0xFF7F8CA1),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Color(0xFF55677F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.login_rounded,
                size: 16,
                color: Color(0xFFE07A00),
              ),
              const SizedBox(width: 6),
              Text(
                checkInLabel,
                style: const TextStyle(
                  color: Color(0xFFE07A00),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFF8B96A8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    color: Color(0xFF52657D),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (email.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(
                color: Color(0xFF8A97A8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LateReportsPeriod {
  const _LateReportsPeriod({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

class _ApprovalDateButton extends StatelessWidget {
  const _ApprovalDateButton({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.calendar_today_rounded,
        size: 15,
        color: Color(0xFF94A3B8),
      ),
      label: Text(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF334155),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD6DEEA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ApprovalCountChip extends StatelessWidget {
  const _ApprovalCountChip({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalEmployeeCard extends StatelessWidget {
  const _ApprovalEmployeeCard({
    required this.name,
    required this.role,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.onChange,
  });

  final String name;
  final String role;
  final String status;
  final String checkIn;
  final String checkOut;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final statusLower = status.trim().toLowerCase();
    final isPresent = statusLower == 'present' || statusLower == 'checked in';
    final statusBg =
        isPresent ? const Color(0xFFDDF7E9) : const Color(0xFFFFE7E7);
    final statusFg =
        isPresent ? const Color(0xFF0E9A6E) : const Color(0xFFDC2626);
    final statusLabel = status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE4F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF0E9A6E),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle,
                                            size: 7, color: statusFg),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusLabel.isEmpty
                                              ? 'Absent'
                                              : statusLabel,
                                          style: TextStyle(
                                            color: statusFg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _ApprovalMetaText(
                          icon: Icons.login_rounded,
                          color: const Color(0xFF10B981),
                          text: checkIn == '--:--' ? 'Not checked in' : checkIn,
                        ),
                        _ApprovalMetaText(
                          icon: Icons.logout_rounded,
                          color: const Color(0xFFEF4444),
                          text: checkOut == '--:--'
                              ? 'Not checked out'
                              : checkOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onChange,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Change'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          backgroundColor: const Color(0xFFEEF2FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF0E9A6E),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        size: 7, color: statusFg),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusLabel.isEmpty
                                          ? 'Absent'
                                          : statusLabel,
                                      style: TextStyle(
                                        color: statusFg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              _ApprovalMetaText(
                                icon: Icons.login_rounded,
                                color: const Color(0xFF10B981),
                                text: checkIn == '--:--'
                                    ? 'Not checked in'
                                    : checkIn,
                              ),
                              _ApprovalMetaText(
                                icon: Icons.logout_rounded,
                                color: const Color(0xFFEF4444),
                                text: checkOut == '--:--'
                                    ? 'Not checked out'
                                    : checkOut,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: onChange,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFFEEF2FF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ApprovalMetaText extends StatelessWidget {
  const _ApprovalMetaText({
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
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF7C8DA6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

class _HolidayYearDropdown extends StatelessWidget {
  const _HolidayYearDropdown({
    required this.value,
    required this.years,
    required this.onChanged,
  });

  final int value;
  final List<int> years;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = years.isEmpty ? <int>[value] : years;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x45FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map(
                (year) => DropdownMenuItem<int>(
                  value: year,
                  child: Text(year.toString()),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({
    required this.date,
    required this.title,
    required this.description,
    required this.summary,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime? date;
  final String title;
  final String description;
  final String summary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final month =
        date == null ? '--' : DateFormat('MMM').format(date!).toUpperCase();
    final day = date == null ? '--' : DateFormat('d').format(date!);
    final dateLabel =
        date == null ? '--' : DateFormat('dd MMM yyyy').format(date!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4E8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  month,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB14AD5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day,
                  style: const TextStyle(
                    color: Color(0xFF7C2AE8),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _HolidayMetaPill(
                      icon: Icons.group_outlined,
                      text: summary,
                    ),
                  ],
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF7C8799),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundActionButton(
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _RoundActionButton(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HolidayMetaPill extends StatelessWidget {
  const _HolidayMetaPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF667085)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
