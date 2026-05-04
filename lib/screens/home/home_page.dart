import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/utils/csv_export_helper.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/crm_bottom_nav.dart';

class HomePage extends StatefulWidget {
  final bool showBottomNav;

  const HomePage({super.key, this.showBottomNav = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navReservedHeight = 76.0 + 12.0;
    final bodyBottomPadding =
        widget.showBottomNav ? bottomInset + navReservedHeight + 16.0 : 32.0;
    final compactText = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(0.88));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Home'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bodyBottomPadding),
          child: MediaQuery(
            data: compactText,
            child: Transform.scale(
              scale: 0.92,
              alignment: Alignment.topCenter,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeExportButton(),
                    SizedBox(height: 10),
                    _OverviewCards(),
                  SizedBox(height: 12),
                  _RevenueDualSection(),
                  SizedBox(height: 12),
                  _CommissionPipelineActivitySection(),
                  SizedBox(height: 12),
                  _QuickActionsSection(),
                  SizedBox(height: 12),
                  _UpcomingVisitsSection(),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? CRMAppBottomNav(
              currentIndex: _currentIndex,
              onDashboard: () {
                setState(() => _currentIndex = 0);
              },
              onLeads: () {
                Navigator.pushNamed(context, AppRoutes.leads);
              },
              onFollowUps: () {
                Navigator.pushNamed(context, AppRoutes.followUps);
              },
              onSiteVisits: () {
                setState(() => _currentIndex = 3);
              },
              onProjects: () {
                setState(() => _currentIndex = 4);
              },
              onTeam: () {
                setState(() => _currentIndex = 5);
              },
              onReports: () {
                setState(() => _currentIndex = 6);
              },
              onSettings: () {
                setState(() => _currentIndex = 7);
              },
              onMore: () {},
              onLess: () {},
            )
          : null,
    );
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.42,
      children: const [
        _MetricCard(
          title: 'Total Leads',
          value: '0',
          icon: Icons.group_outlined,
          iconColor: Color(0xFF2C7BE5),
          iconBg: Color(0xFFE7F1FF),
          trend: '0%',
        ),
        _MetricCard(
          title: 'Total Site Visits',
          value: '0',
          icon: Icons.calendar_month_outlined,
          iconColor: Color(0xFF8B5CF6),
          iconBg: Color(0xFFF0E8FF),
          trend: '0%',
        ),
        _MetricCard(
          title: 'Total Follow ups',
          value: '0',
          icon: Icons.call_outlined,
          iconColor: Color(0xFF16A34A),
          iconBg: Color(0xFFE6F8ED),
          trend: '0%',
        ),
        _MetricCard(
          title: 'Total Projects',
          value: '0',
          icon: Icons.apartment_outlined,
          iconColor: Color(0xFF2563EB),
          iconBg: Color(0xFFE7EEFF),
          trend: '0%',
        ),
      ],
    );
  }
}

class _HomeExportButton extends StatelessWidget {
  const _HomeExportButton();

  Future<void> _exportDashboard(BuildContext context) async {
    await CsvExportHelper.exportRowsToClipboard(
      context: context,
      fileLabel: 'Home Dashboard',
      headers: const <String>['Metric', 'Value'],
      rows: const <List<String>>[
        <String>['Total Leads', '0'],
        <String>['Total Site Visits', '0'],
        <String>['Total Follow Ups', '0'],
        <String>['Total Projects', '0'],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => _exportDashboard(context),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export'),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.trend,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String trend;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 36,
              height: 0.95,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueDualSection extends StatelessWidget {
  const _RevenueDualSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RevenueCard(),
        SizedBox(height: 10),
        _RevenueCard(),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Monthly performance overview',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _SegmentToggle(),
            ],
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 190, child: _RevenueChart()),
        ],
      ),
    );
  }
}

class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle();

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [chip('Week', false), chip('Month', true), chip('Year', false)],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 2,
        minY: 0,
        maxY: 1,
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          verticalInterval: 1,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.75),
            strokeWidth: 1,
            dashArray: [3, 5],
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.55),
            strokeWidth: 1,
            dashArray: [3, 5],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 0.25,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 1) {
                  return const Text(
                    'Apr 2026',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(1, 1)],
            color: AppColors.primary,
            isCurved: true,
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, p, bar, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeColor: AppColors.primary,
                  strokeWidth: 2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionPipelineActivitySection extends StatelessWidget {
  const _CommissionPipelineActivitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _CommissionCard(),
        SizedBox(height: 10),
        _PipelineCard(),
        SizedBox(height: 10),
        _ActivityCard(),
      ],
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Earnings and projections',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              color: const Color(0xFFF9FBFF),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Real-time commission tracking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.9),
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

class _PipelineCard extends StatelessWidget {
  const _PipelineCard();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Qualified', 0, Color(0xFF1D86FF)),
      ('Site Visit', 1, Color(0xFF12B886)),
      ('Negotiation', 0, Color(0xFF3BA2F6)),
      ('Booking', 0, Color(0xFF0D63B8)),
      ('Closed Won', 0, Color(0xFF20C073)),
      ('Closed Lost', 0, Color(0xFFEF4444)),
    ];

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lead Pipeline',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Current lead distribution',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ...rows.map((r) {
            final label = r.$1;
            final value = r.$2;
            final color = r.$3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value == 0 ? 0.02 : 1,
                      minHeight: 5,
                      backgroundColor: AppColors.border.withOpacity(0.8),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.chat_bubble_outline,
        Color(0xFFE7ECF3),
        Color(0xFF6B7280),
        'bdfbdfb',
        'Kaushal Sakpal1 · Shubham Shinde',
        '13m ago'
      ),
      (
        Icons.notifications_none,
        Color(0xFFE7ECF3),
        Color(0xFF6B7280),
        'Site visit rescheduled for Kaushal...',
        'Kaushal Sakpal1 · Skyline Heights · Aditya Jha',
        '13m ago'
      ),
      (
        Icons.refresh,
        Color(0xFFE8F2FF),
        Color(0xFF1D86FF),
        'Site visit scheduled for 2026-05-02',
        'Kaushal Sakpal1 · Shubham Shinde',
        '17m ago'
      ),
      (
        Icons.chat_bubble_outline,
        Color(0xFFE7ECF3),
        Color(0xFF6B7280),
        'Visit feedback: positive reaction. Nex...',
        'Kaushal Sakpal1 · Shubham Shinde',
        '1h ago'
      ),
      (
        Icons.check_circle_outline,
        Color(0xFFEAF8EF),
        Color(0xFF12B886),
        'Site visit done for Kaushal Sakpal1',
        'Kaushal Sakpal1 · Skyline Heights · Aditya Jha',
        '1h ago'
      ),
      (
        Icons.person_add_alt_1,
        Color(0xFFE8F2FF),
        Color(0xFF1D86FF),
        'Lead assigned to Aditya Bobya',
        'Kaushal Sakpal1 · Shubham Shinde',
        '29 Apr'
      ),
    ];

    return _DashboardCard(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Latest updates',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: item.$3, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$4,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$5,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$6,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
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

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    const actions = [
      ('Add Lead', Icons.person_add_alt_1, Color(0xFF1D86FF)),
      ('Schedule\nVisit', Icons.calendar_today_outlined, Color(0xFF12B886)),
      ('New Booking', Icons.description_outlined, Color(0xFF8B5CF6)),
      ('Send\nWhatsApp', Icons.chat_bubble_outline, Color(0xFF14B8A6)),
    ];

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: actions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final a = actions[index];
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withOpacity(0.8)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: a.$3,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(a.$2, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
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

class _UpcomingVisitsSection extends StatelessWidget {
  const _UpcomingVisitsSection();

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Site Visits',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kaushal Sakpal1',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Skyline Heights, Andheri West',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '3:04 AM',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rescheduled',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
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
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

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
        border: Border.all(color: const Color(0xFFD6E4F5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
