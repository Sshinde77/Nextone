import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/screens/attendance/attendance_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/crm_bottom_nav.dart';

class HomePage extends StatefulWidget {
  final bool showBottomNav;

  const HomePage({super.key, this.showBottomNav = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final int _currentIndex = 0;
  final AuthProvider _authProvider = AuthProvider();
  bool _statsLoading = true;
  String? _statsError;
  Map<String, dynamic>? _dashboardStats;
  bool _upcomingVisitsLoading = true;
  String? _upcomingVisitsError;
  List<Map<String, dynamic>> _upcomingVisits = const <Map<String, dynamic>>[];
  bool _recentActivityLoading = true;
  String? _recentActivityError;
  List<Map<String, dynamic>> _recentActivity = const <Map<String, dynamic>>[];
  bool _leadPipelineLoading = true;
  String? _leadPipelineError;
  Map<String, dynamic>? _leadPipeline;
  bool _leadSourcesLoading = true;
  String? _leadSourcesError;
  Map<String, dynamic>? _leadSources;
  String _leadTrendPeriod = 'month';
  bool _leadTrendLoading = true;
  String? _leadTrendError;
  Map<String, dynamic>? _leadTrendData;
  String _currentRole = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
    _loadUpcomingSiteVisits();
    _loadRecentActivity();
    _loadLeadPipeline();
    _loadLeadSources();
    _loadLeadTrend();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Keep the lowest-privilege UI fallback if profile cannot be read.
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<void> _loadDashboardStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    final now = DateTime.now();
    final from = '${now.year}-${_twoDigits(now.month)}-01';
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final to =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(lastDayOfMonth)}';

    try {
      final stats = await _authProvider.dashboardStats(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _dashboardStats = stats;
        _statsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsError = error.toString();
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadUpcomingSiteVisits() async {
    setState(() {
      _upcomingVisitsLoading = true;
      _upcomingVisitsError = null;
    });

    try {
      final visits = await _authProvider.dashboardUpcomingSiteVisits(limit: 5);
      if (!mounted) return;
      setState(() {
        _upcomingVisits = visits;
        _upcomingVisitsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _upcomingVisitsError = error.toString();
        _upcomingVisitsLoading = false;
      });
    }
  }

  Future<void> _loadRecentActivity() async {
    setState(() {
      _recentActivityLoading = true;
      _recentActivityError = null;
    });

    try {
      final activity = await _authProvider.dashboardRecentActivity(limit: 5);
      if (!mounted) return;
      setState(() {
        _recentActivity = activity;
        _recentActivityLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recentActivityError = error.toString();
        _recentActivityLoading = false;
      });
    }
  }

  Future<void> _loadLeadPipeline() async {
    setState(() {
      _leadPipelineLoading = true;
      _leadPipelineError = null;
    });

    try {
      final pipeline = await _authProvider.dashboardLeadPipeline();
      if (!mounted) return;
      setState(() {
        _leadPipeline = pipeline;
        _leadPipelineLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _leadPipelineError = error.toString();
        _leadPipelineLoading = false;
      });
    }
  }

  Future<void> _loadLeadSources() async {
    setState(() {
      _leadSourcesLoading = true;
      _leadSourcesError = null;
    });

    final now = DateTime.now();
    final from = '${now.year}-${_twoDigits(now.month)}-01';
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final to =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(lastDayOfMonth)}';

    try {
      final sources = await _authProvider.dashboardLeadSources(
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _leadSources = sources;
        _leadSourcesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _leadSourcesError = error.toString();
        _leadSourcesLoading = false;
      });
    }
  }

  Future<void> _loadLeadTrend() async {
    setState(() {
      _leadTrendLoading = true;
      _leadTrendError = null;
    });

    try {
      final trend = await _authProvider.dashboardRevenue(range: _leadTrendPeriod);
      if (!mounted) return;
      setState(() {
        _leadTrendData = trend;
        _leadTrendLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _leadTrendError = error.toString();
        _leadTrendLoading = false;
      });
    }
  }

  void _openMainTab(int index) {
    if (!mounted) return;
    if (!RoleAccess.canAccessMainTab(_currentRole, index)) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home, arguments: index);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navReservedHeight = 76.0 + 12.0;
    final bodyBottomPadding =
        widget.showBottomNav ? bottomInset + navReservedHeight + 16.0 : 32.0;
    final compactText = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(0.9));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: const CrmAppBar(title: 'Home'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, bodyBottomPadding),
          child: MediaQuery(
            data: compactText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderBlock(),
                const SizedBox(height: 12),
                _StatsGrid(
                  stats: _dashboardStats,
                  isLoading: _statsLoading,
                  hasError: _statsError != null,
                  onRetry: _loadDashboardStats,
                  onLeadsTap: () => _openMainTab(1),
                  onSiteVisitsTap: () => _openMainTab(3),
                  onFollowUpsTap: () => _openMainTab(2),
                  onProjectsTap: () => _openMainTab(5),
                  showProjects: RoleAccess.canViewProjects(_currentRole),
                ),
                const SizedBox(height: 10),
                _RowWrap(
                  leftChild: _QuickAccessCard(
                    onLeadsTap: () => _openMainTab(1),
                    onSiteVisitsTap: () => _openMainTab(3),
                    onFollowUpsTap: () => _openMainTab(2),
                    onProjectsTap: () => _openMainTab(5),
                    onTeamTap: () => _openMainTab(6),
                    onAttendanceTap: () => _openMainTab(7),
                    onNotificationsTap: () {
                      Navigator.pushNamed(context, AppRoutes.notifications);
                    },
                    onReportsTap: () => _openMainTab(8),
                    showProjects: RoleAccess.canViewProjects(_currentRole),
                    showTeam: RoleAccess.canViewTeam(_currentRole),
                  ),
                  rightChild: _UpcomingVisitsCard(
                    visits: _upcomingVisits,
                    isLoading: _upcomingVisitsLoading,
                    hasError: _upcomingVisitsError != null,
                    onRetry: _loadUpcomingSiteVisits,
                    onViewAllTap: () => _openMainTab(3),
                  ),
                ),
                const SizedBox(height: 10),
                _RecentActivityCard(
                  activity: _recentActivity,
                  isLoading: _recentActivityLoading,
                  hasError: _recentActivityError != null,
                  onRetry: _loadRecentActivity,
                ),
                const SizedBox(height: 10),
                _RowWrap(
                  leftChild: _LeadPipelineCard(
                    pipeline: _leadPipeline,
                    isLoading: _leadPipelineLoading,
                    hasError: _leadPipelineError != null,
                    onRetry: _loadLeadPipeline,
                  ),
                  rightChild: _LeadSourcesCard(
                    leadSources: _leadSources,
                    isLoading: _leadSourcesLoading,
                    hasError: _leadSourcesError != null,
                    onRetry: _loadLeadSources,
                  ),
                ),
                const SizedBox(height: 10),
                _RowWrap(
                  leftChild: _LeadTrendCard(
                    selectedPeriod: _leadTrendPeriod,
                    onPeriodChanged: (period) {
                      if (_leadTrendPeriod == period) return;
                      setState(() {
                        _leadTrendPeriod = period;
                      });
                      _loadLeadTrend();
                    },
                    trendData: _leadTrendData,
                    isLoading: _leadTrendLoading,
                    hasError: _leadTrendError != null,
                    onRetry: _loadLeadTrend,
                  ),
                  rightChild: _PerformanceCard(),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? CRMAppBottomNav(
              currentIndex: _currentIndex,
              showProjects: RoleAccess.canViewProjects(_currentRole),
              showTeam: RoleAccess.canViewTeam(_currentRole),
              showUsers: RoleAccess.canViewUsers(_currentRole),
              onDashboard: () {
                _openMainTab(0);
              },
              onLeads: () {
                _openMainTab(1);
              },
              onFollowUps: () {
                _openMainTab(2);
              },
              onSiteVisits: () {
                _openMainTab(3);
              },
              onRevisits: () {
                _openMainTab(4);
              },
              onProjects: () {
                _openMainTab(5);
              },
              onTeam: () {
                _openMainTab(6);
              },
              onReports: () {
                _openMainTab(7);
              },
              onSettings: () {
                _openMainTab(8);
              },
              onNotifications: () {
                Navigator.pushNamed(context, '/notifications');
              },
              onMore: () {},
              onLess: () {},
            )
          : null,
    );
  }
}

class _HeaderBlock extends StatefulWidget {
  const _HeaderBlock();

  @override
  State<_HeaderBlock> createState() => _HeaderBlockState();
}

class _HeaderBlockState extends State<_HeaderBlock> {
  final AuthProvider _authProvider = AuthProvider();
  bool _isExporting = false;
  String _currentRole = '';

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Export actions stay hidden if the role cannot be resolved.
    }
  }

  String _greetingForHour(int hour) {
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  String _formatDate(DateTime now) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month ${now.year}';
  }

  ({String from, String to}) _currentMonthRange() {
    final now = DateTime.now();
    final from =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final toDate = DateTime(now.year, now.month + 1, 0);
    final to =
        '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
    return (from: from, to: to);
  }

  Future<void> _exportModule(_ExportModuleType moduleType) async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
    });

    try {
      final token = _authProvider.currentAuthToken;
      final range = _currentMonthRange();
      final exported = switch (moduleType) {
        _ExportModuleType.leads => await _authProvider.exportLeads(
            from: range.from,
            to: range.to,
            token: token,
          ),
        _ExportModuleType.siteVisits =>
          await _authProvider.exportSiteVisits(token: token),
        _ExportModuleType.followUps =>
          await _authProvider.exportFollowUps(token: token),
        _ExportModuleType.attendance => await _authProvider.exportAttendance(
            from: range.from,
            to: range.to,
            token: token,
          ),
        _ExportModuleType.projects =>
          await _authProvider.exportProjects(token: token),
        _ExportModuleType.teamMembers =>
          await _authProvider.exportUsers(token: token),
        _ExportModuleType.allModules =>
          await _authProvider.exportAll(token: token),
      };

      if (!mounted) return;

      final fileName = exported.fileName.trim().isEmpty
          ? '${moduleType.fallbackFileName}.xlsx'
          : exported.fileName.trim();

      if (kIsWeb) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Export generated ($fileName), but direct file save is not supported on Web in this build.',
              ),
            ),
          );
        return;
      }

      final file = await ExportFileHelper.saveToDownloadNextone(
        fileName: fileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${moduleType.label} export downloaded: ${file.path}')),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppErrorHandler.friendlyMessage(error))),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _greetingForHour(now.hour);
    final formattedDate = _formatDate(now);
    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AttendancePage(),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF344054),
            side: const BorderSide(color: Color(0xFFD8DFEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.access_time_rounded, size: 16),
          label: const Text(
            'Attendance',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        // if (canExport)
        //   OutlinedButton.icon(
        //     onPressed: _isExporting ? null : _openExportMenu,
        //     style: OutlinedButton.styleFrom(
        //       foregroundColor: const Color(0xFF344054),
        //       side: const BorderSide(color: Color(0xFFD8DFEA)),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        //       visualDensity: VisualDensity.compact,
        //     ),
        //     icon: _isExporting
        //         ? const SizedBox(
        //             width: 14,
        //             height: 14,
        //             child: CircularProgressIndicator(strokeWidth: 2),
        //           )
        //         : const Icon(Icons.download_rounded, size: 16),
        //     label: Text(
        //       _isExporting && _activeExportType != null
        //           ? 'Exporting ${_activeExportType!.label}'
        //           : 'Export Data',
        //       style: const TextStyle(fontWeight: FontWeight.w700),
        //     ),
        //   ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10213D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              actionButtons,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10213D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actionButtons,
          ],
        );
      },
    );
  }
}

enum _ExportModuleType {
  leads(
    label: 'Leads',
    icon: Icons.download_rounded,
    color: Color(0xFF2563EB),
    fallbackFileName: 'leads_export',
  ),
  siteVisits(
    label: 'Site Visits',
    icon: Icons.download_rounded,
    color: Color(0xFF7C3AED),
    fallbackFileName: 'site_visits_export',
  ),
  followUps(
    label: 'Follow-Ups',
    icon: Icons.download_rounded,
    color: Color(0xFF16A34A),
    fallbackFileName: 'follow_ups_export',
  ),
  attendance(
    label: 'Attendance',
    icon: Icons.download_rounded,
    color: Color(0xFF4F46E5),
    fallbackFileName: 'attendance_export',
  ),
  projects(
    label: 'Projects',
    icon: Icons.download_rounded,
    color: Color(0xFFEA580C),
    fallbackFileName: 'projects_export',
  ),
  teamMembers(
    label: 'Team Members',
    icon: Icons.download_rounded,
    color: Color(0xFFE11D48),
    fallbackFileName: 'users_export',
  ),
  allModules(
    label: 'All Modules',
    icon: Icons.download_rounded,
    color: Color(0xFF0EA5E9),
    fallbackFileName: 'all_modules_export',
  );

  const _ExportModuleType({
    required this.label,
    required this.icon,
    required this.color,
    required this.fallbackFileName,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String fallbackFileName;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.stats,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onLeadsTap,
    required this.onSiteVisitsTap,
    required this.onFollowUpsTap,
    required this.onProjectsTap,
    required this.showProjects,
  });

  final Map<String, dynamic>? stats;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;
  final VoidCallback onLeadsTap;
  final VoidCallback onSiteVisitsTap;
  final VoidCallback onFollowUpsTap;
  final VoidCallback onProjectsTap;
  final bool showProjects;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _DashCard(
        child: SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (hasError || stats == null) {
      return _DashCard(
        child: SizedBox(
          height: 90,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Unable to load dashboard stats.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onRetry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map(
          (key, val) => MapEntry(key.toString(), val),
        );
      }
      return const <String, dynamic>{};
    }

    int readInt(Map<String, dynamic> map, String key) {
      final dynamic value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final leads = asMap(stats!['total_leads']);
    final siteVisits = asMap(stats!['total_site_visits']);
    final followUps = asMap(stats!['total_follow_ups']);
    final projects = asMap(stats!['total_projects']);

    final totalLeads = readInt(leads, 'value');
    final bookedLeads = readInt(leads, 'booked');
    final totalSiteVisits = readInt(siteVisits, 'value');
    final upcomingSiteVisits = readInt(siteVisits, 'upcoming');
    final doneSiteVisits = readInt(siteVisits, 'done');
    final totalFollowUps = readInt(followUps, 'value');
    final pendingFollowUps = readInt(followUps, 'pending');
    final totalProjects = readInt(projects, 'value');
    final activeProjects = readInt(projects, 'active');
    final upcomingProjects = readInt(projects, 'upcoming');

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final compact = constraints.maxWidth < 420;
        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: wide ? 1.85 : (compact ? 1.25 : 1.38),
          children: [
            _StatCard(
              icon: Icons.group_outlined,
              iconBg: const Color(0xFF3B82F6),
              bubbleColor: const Color(0xFFDBEAFE),
              title: 'Total Leads',
              value: '$totalLeads',
              subtitle: '$bookedLeads booked',
              compact: compact,
              onTap: onLeadsTap,
            ),
            _StatCard(
              icon: Icons.calendar_month_outlined,
              iconBg: const Color(0xFF8B5CF6),
              bubbleColor: const Color(0xFFEDE9FE),
              title: 'Site Visits',
              value: '$totalSiteVisits',
              subtitle: '$upcomingSiteVisits upcoming',
              tag: '$doneSiteVisits done',
              compact: compact,
              onTap: onSiteVisitsTap,
            ),
            _StatCard(
              icon: Icons.call_outlined,
              iconBg: const Color(0xFF10B981),
              bubbleColor: const Color(0xFFD1FAE5),
              title: 'Follow-Ups',
              value: '$totalFollowUps',
              subtitle: '$pendingFollowUps pending',
              compact: compact,
              onTap: onFollowUpsTap,
            ),
            if (showProjects)
              _StatCard(
                icon: Icons.apartment_outlined,
                iconBg: const Color(0xFFF59E0B),
                bubbleColor: const Color(0xFFFEF3C7),
                title: 'Projects',
                value: '$totalProjects',
                subtitle: '$activeProjects active',
                tag: '$upcomingProjects upcoming',
                compact: compact,
                onTap: onProjectsTap,
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.bubbleColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.tag,
    this.compact = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color bubbleColor;
  final String title;
  final String value;
  final String subtitle;
  final String? tag;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: _DashCard(
        padding: EdgeInsets.all(compact ? 10 : 11),
        child: Stack(
          children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bubbleColor,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 28 : 30,
                    height: compact ? 28 : 30,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: compact ? 15 : 16),
                  ),
                  const Spacer(),
                  if (tag != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 8,
                        vertical: compact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag!,
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 24 : 28,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F1F3A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class _RowWrap extends StatelessWidget {
  const _RowWrap({required this.leftChild, required this.rightChild});

  final Widget leftChild;
  final Widget rightChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 950) {
          return Column(
            children: [
              leftChild,
              const SizedBox(height: 10),
              rightChild,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: leftChild),
            const SizedBox(width: 10),
            Expanded(flex: 5, child: rightChild),
          ],
        );
      },
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.onLeadsTap,
    required this.onSiteVisitsTap,
    required this.onFollowUpsTap,
    required this.onProjectsTap,
    required this.onTeamTap,
    required this.onAttendanceTap,
    required this.onNotificationsTap,
    required this.onReportsTap,
    required this.showProjects,
    required this.showTeam,
  });

  final VoidCallback onLeadsTap;
  final VoidCallback onSiteVisitsTap;
  final VoidCallback onFollowUpsTap;
  final VoidCallback onProjectsTap;
  final VoidCallback onTeamTap;
  final VoidCallback onAttendanceTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onReportsTap;
  final bool showProjects;
  final bool showTeam;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAccessItem>[
      _QuickAccessItem(
        title: 'Leads',
        icon: Icons.group_outlined,
        color: const Color(0xFF3B82F6),
        onTap: onLeadsTap,
      ),
      _QuickAccessItem(
        title: 'Site Visits',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: onSiteVisitsTap,
      ),
      _QuickAccessItem(
        title: 'Follow-Ups',
        icon: Icons.call_outlined,
        color: const Color(0xFF10B981),
        onTap: onFollowUpsTap,
      ),
      if (showProjects)
        _QuickAccessItem(
          title: 'Projects',
          icon: Icons.apartment_outlined,
          color: const Color(0xFFF59E0B),
          onTap: onProjectsTap,
        ),
      if (showTeam)
        _QuickAccessItem(
          title: 'Team',
          icon: Icons.groups_outlined,
          color: const Color(0xFFEC4899),
          onTap: onTeamTap,
        ),
      _QuickAccessItem(
        title: 'Attendance',
        icon: Icons.badge_outlined,
        color: const Color(0xFFEF4444),
        onTap: onAttendanceTap,
      ),
      // _QuickAccessItem(
      //   title: 'Notifications',
      //   icon: Icons.notifications_none_rounded,
      //   color: const Color(0xFF06B6D4),
      //   onTap: onNotificationsTap,
      // ),
      // _QuickAccessItem(
      //   title: 'Reports',
      //   icon: Icons.bar_chart_rounded,
      //   color: const Color(0xFF2563EB),
      //   onTap: onReportsTap,
      // ),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Quick Access'),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: items.length,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 12,
              childAspectRatio: 2.55,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF13233E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _UpcomingVisitsCard extends StatelessWidget {
  const _UpcomingVisitsCard({
    required this.visits,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onViewAllTap,
  });

  final List<Map<String, dynamic>> visits;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;
  final VoidCallback onViewAllTap;

  String _formatTime(dynamic rawTime) {
    if (rawTime is! String || rawTime.trim().isEmpty) return '--';
    try {
      final parts = rawTime.split(':');
      if (parts.length < 2) return '--';
      final parsedHour = int.tryParse(parts[0]) ?? 0;
      final parsedMinute = int.tryParse(parts[1]) ?? 0;
      final hour = parsedHour % 12 == 0 ? 12 : parsedHour % 12;
      final minute = parsedMinute.toString().padLeft(2, '0');
      final meridian = parsedHour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $meridian';
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = visits.map((visit) {
      final leadName = (visit['lead_name']?.toString().trim().isNotEmpty ?? false)
          ? visit['lead_name'].toString()
          : 'Unknown Lead';
      final projectName =
          (visit['project_name']?.toString().trim().isNotEmpty ?? false)
              ? visit['project_name'].toString()
              : 'Unknown Project';
      final status = (visit['status']?.toString() ?? '').toLowerCase();
      final dotColor = status == 'rescheduled'
          ? const Color(0xFFF59E0B)
          : (status == 'scheduled'
              ? const Color(0xFF3B82F6)
              : const Color(0xFF9CA3AF));
      final time = _formatTime(visit['visit_time']);
      return (leadName, projectName, time, dotColor);
    }).toList();

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Upcoming Visits',
            actionLabel: 'View all',
            onActionTap: onViewAllTap,
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (hasError)
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load upcoming visits.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (rows.isEmpty)
            const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'No upcoming visits.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...rows.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r.$4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF13233E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r.$3,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F334F),
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
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.activity,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> activity;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;

  String _timeAgo(dynamic createdAtRaw) {
    if (createdAtRaw is! String || createdAtRaw.trim().isEmpty) return '';
    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final activities = activity.map((item) {
      final title = (item['title']?.toString().trim().isNotEmpty ?? false)
          ? item['title'].toString()
          : (item['message']?.toString() ?? 'Activity update');
      final actor = (item['actor_name']?.toString().trim().isNotEmpty ?? false)
          ? item['actor_name'].toString()
          : (item['created_by_name']?.toString() ?? 'System');
      final type = (item['type']?.toString() ?? '').toLowerCase();
      final when = _timeAgo(item['created_at']);

      IconData icon;
      Color bgColor;
      Color iconColor;

      if (type.contains('status') || type.contains('update')) {
        icon = Icons.cached_rounded;
        bgColor = const Color(0xFFDBEAFE);
        iconColor = const Color(0xFF3B82F6);
      } else if (type.contains('assign')) {
        icon = Icons.person_add_alt_1_rounded;
        bgColor = const Color(0xFFE8F2FF);
        iconColor = const Color(0xFF3B82F6);
      } else if (type.contains('complete') || type.contains('done')) {
        icon = Icons.check_circle_outline_rounded;
        bgColor = const Color(0xFFEAF8EF);
        iconColor = const Color(0xFF12B886);
      } else {
        icon = Icons.bolt_rounded;
        bgColor = const Color(0xFFE5E7EB);
        iconColor = const Color(0xFF6B7280);
      }

      return (icon, bgColor, iconColor, title, actor, when);
    }).toList();

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Recent Activity'),
          const SizedBox(height: 10),
          if (isLoading)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (hasError)
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load recent activity.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (activities.isEmpty)
            const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'No recent activity.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...activities.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: a.$2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(a.$1, size: 14, color: a.$3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.$4,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF13233E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.$6.isEmpty ? a.$5 : '${a.$5} · ${a.$6}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
}

class _LeadPipelineCard extends StatelessWidget {
  const _LeadPipelineCard({
    required this.pipeline,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final Map<String, dynamic>? pipeline;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    (Color, Color) rowColors(String key, String label) {
      final normalized = key.toLowerCase().trim();
      if (normalized == 'new' || label.toLowerCase().contains('qualified')) {
        return (const Color(0xFF3B82F6), const Color(0xFFE8F0FF));
      }
      if (normalized == 'site_visit') {
        return (const Color(0xFF8B5CF6), const Color(0xFFF1ECFF));
      }
      if (normalized == 'negotiation') {
        return (const Color(0xFFF59E0B), const Color(0xFFFFF5E6));
      }
      if (normalized == 'booking') {
        return (const Color(0xFF10B981), const Color(0xFFE7F9F1));
      }
      if (normalized == 'closed_won') {
        return (const Color(0xFF06B6D4), const Color(0xFFE7FAFD));
      }
      if (normalized == 'closed_lost') {
        return (const Color(0xFFEF4444), const Color(0xFFFFEAEA));
      }
      return (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    }

    final dynamic stagesRaw = pipeline?['stages'];
    final List<(String, int, Color, Color)> rows = stagesRaw is List
        ? stagesRaw
            .whereType<Map>()
            .map((stage) {
              final map = stage.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              final label = map['label']?.toString() ?? 'Unknown';
              final key = map['key']?.toString() ?? '';
              final value = asInt(map['value']);
              final colors = rowColors(key, label);
              return (label, value, colors.$1, colors.$2);
            })
            .toList()
        : const <(String, int, Color, Color)>[];

    final int maxValue = rows.isEmpty
        ? 1
        : rows
            .map((r) => r.$2)
            .fold<int>(1, (previous, current) => current > previous ? current : previous);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Lead Pipeline'),
          const SizedBox(height: 2),
          const Text(
            'Current distribution across stages',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (hasError || pipeline == null)
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load lead pipeline.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (rows.isEmpty)
            const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'No lead pipeline data.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: isNarrow ? 74 : 88,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.$4,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.$1,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          color: r.$3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 6 : 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: r.$2 == 0 ? 0 : r.$2 / maxValue,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(r.$3),
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 6 : 10),
                    SizedBox(
                      width: isNarrow ? 14 : 16,
                      child: Text(
                        '${r.$2}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF13233E),
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
}

class _LeadSourcesCard extends StatelessWidget {
  const _LeadSourcesCard({
    required this.leadSources,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final Map<String, dynamic>? leadSources;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;

  Color _parseHexColor(String? hex, Color fallback) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final total = asInt(leadSources?['total']);
    final dynamic rawSources = leadSources?['sources'];
    final sources = rawSources is List
        ? rawSources
            .whereType<Map>()
            .map((entry) {
              final map = entry.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              final name = map['source']?.toString() ?? 'Unknown';
              final count = asInt(map['count']);
              final color = _parseHexColor(
                map['color']?.toString(),
                const Color(0xFF9CA3AF),
              );
              return (name, color, count);
            })
            .toList()
        : const <(String, Color, int)>[];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Lead Sources'),
          SizedBox(height: isLoading ? 10 : 2),
          if (isLoading)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (hasError || leadSources == null)
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load lead sources.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            ...[
              Text(
                '$total total leads · distribution',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;

                  Widget pie = PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sectionsSpace: 0,
                      sections: sources.isEmpty || total == 0
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color: const Color(0xFFE5E7EB),
                                radius: 34,
                                showTitle: false,
                              ),
                            ]
                          : sources
                              .where((s) => s.$3 > 0)
                              .map(
                                (s) => PieChartSectionData(
                                  value: s.$3.toDouble(),
                                  color: s.$2,
                                  radius: 34,
                                  showTitle: false,
                                ),
                              )
                              .toList(),
                    ),
                  );

                  Widget legendList = ListView.builder(
                    itemCount: sources.length,
                    itemBuilder: (context, index) {
                      final s = sources[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: s.$2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.$1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${s.$3}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF13233E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        SizedBox(height: 180, child: pie),
                        const SizedBox(height: 8),
                        SizedBox(height: 130, child: legendList),
                      ],
                    );
                  }

                  return SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(child: pie),
                        Expanded(child: legendList),
                      ],
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _LeadTrendCard extends StatelessWidget {
  const _LeadTrendCard({
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.trendData,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final Map<String, dynamic>? trendData;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionTitle(title: 'Lead Trend')),
              _SegmentToggle(
                selected: selectedPeriod,
                onChanged: onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            selectedPeriod == 'week'
                ? 'Daily this week'
                : (selectedPeriod == 'year'
                    ? 'Monthly this year'
                    : 'Daily this month'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const SizedBox(
              height: 190,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (hasError || trendData == null)
            SizedBox(
              height: 190,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load lead trend.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 190,
              child: _LeadTrendChart(
                period: selectedPeriod,
                trendData: trendData!,
              ),
            ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _Legend(color: Color(0xFF3B82F6), label: 'Total Leads'),
              SizedBox(width: 18),
              _Legend(color: Color(0xFF10B981), label: 'Booked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeadTrendChart extends StatelessWidget {
  const _LeadTrendChart({
    required this.period,
    required this.trendData,
  });

  final String period;
  final Map<String, dynamic> trendData;

  @override
  Widget build(BuildContext context) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final dynamic raw = trendData['data'];
    final bars = raw is List
        ? raw
            .whereType<Map>()
            .map((entry) {
              final map = entry.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              return (
                map['label']?.toString() ?? '',
                asInt(map['total_leads']).toDouble(),
                asInt(map['booked']).toDouble(),
              );
            })
            .toList()
        : <(String, double, double)>[];

    final maxY = bars.isEmpty
        ? 2.0
        : (bars
                    .map((e) => e.$2 > e.$3 ? e.$2 : e.$3)
                    .reduce((a, b) => a > b ? a : b) +
                0.5)
            .clamp(1.0, 1000000.0);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY <= 4 ? 0.5 : (maxY / 4),
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFDCE4F0),
            strokeWidth: 1,
            dashArray: [2, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 0.5,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(value == value.toInt() ? 0 : 1),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < bars.length) {
                  return Text(
                    bars[index].$1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: List<BarChartGroupData>.generate(
          bars.length,
          (index) => BarChartGroupData(
            x: index,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: bars[index].$2,
                width: period == 'week' ? 12 : 20,
                color: const Color(0xFF1E88E5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              BarChartRodData(
                toY: bars[index].$3,
                width: period == 'week' ? 12 : 20,
                color: const Color(0xFF10B981),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context) {
    const cards = [
      ('Booked Leads', '0', Icons.emoji_events_outlined, Color(0xFFF59E0B)),
      ('Conversion Rate', '—', Icons.show_chart_rounded, Color(0xFF3B82F6)),
      ('Active Projects', '1', Icons.castle_outlined, Color(0xFFD97706)),
      ('Visits Done', '1', Icons.task_alt_rounded, Color(0xFF22C55E)),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Performance'),
          const SizedBox(height: 2),
          const Text(
            'Key metrics snapshot',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: cards.length,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.42,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(card.$3, color: card.$4, size: 20),
                    const Spacer(),
                    Text(
                      card.$2,
                      style: TextStyle(
                        color: card.$4,
                        fontSize: 28,
                        height: 0.95,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF13233E),
            ),
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
      ],
    );
  }
}

class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value) {
      final isSelected = selected == value;
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? const Color(0xFF13233E)
                  : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('Week', 'week'),
          chip('Month', 'month'),
          chip('Year', 'year'),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2C6B),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

