import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/routes/app_routes.dart';
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
  final PageController _summaryPageController = PageController(
    viewportFraction: 0.5,
  );

  @override
  void dispose() {
    _summaryPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navReservedHeight = 76.0 + 12.0; // CRMAppBottomNav height + bottom margin
    final bodyBottomPadding = widget.showBottomNav
        ? bottomInset + navReservedHeight + 16.0
        : 32.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Home'),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bodyBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Summary Cards Slider
              SizedBox(
                height: 140,
                child: PageView(
                  padEnds: false,
                  controller: _summaryPageController,
                  children: const [
                    _SummaryCard(
                      icon: Icons.people_outline,
                      label: 'Total Leads',
                      value: '1250',
                      trend: '\u2197 +12.5%',
                      trendColor: AppColors.success,
                    ),
                    _SummaryCard(
                      icon: Icons.phone_outlined,
                      label: 'Active Leads',
                      value: '420',
                      trend: '\u2197 +8.2%',
                      trendColor: AppColors.success,
                    ),
                    _SummaryCard(
                      icon: Icons.location_on_outlined,
                      label: 'Site Visits',
                      value: '145',
                      trend: '\u2197 +15.3%',
                      trendColor: AppColors.success,
                    ),
                    _SummaryCard(
                      icon: Icons.description_outlined,
                      label: 'Bookings',
                      value: '12',
                      trend: '\u2197 +5.7%',
                      trendColor: AppColors.success,
                    ),
                    _SummaryCard(
                      icon: Icons.currency_rupee,
                      label: 'Revenue',
                      value: '\u20B94.50 Cr',
                      trend: '\u2197 +18.9%',
                      trendColor: AppColors.success,
                    ),
                    _SummaryCard(
                      icon: Icons.trending_up,
                      label: 'Commission',
                      value: '\u20B985.00 L',
                      trend: '\u2198 -3.2%',
                      trendColor: AppColors.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Revenue & Bookings
              const _SectionCard(
                title: 'Revenue & Bookings',
                subtitle: 'Monthly performance overview',
                trailing: _TimeRangePicker(),
                child: SizedBox(height: 220, child: _RevenueLineChart()),
              ),
              const SizedBox(height: 16),

              // Lead Sources
              const _SectionCard(
                title: 'Lead Sources',
                subtitle: 'Distribution by source',
                child: SizedBox(height: 300, child: _LeadSourcesPieChart()),
              ),
              const SizedBox(height: 16),

              const _SectionCard(
                title: 'Commission Overview',
                subtitle: 'Earned vs Pending',
                child: SizedBox(height: 220, child: _CommissionBarChart()),
              ),
              const SizedBox(height: 16),

              const _SectionCard(
                title: 'Lead Pipeline',
                subtitle: 'Current lead distribution',
                child: _LeadPipelineList(),
              ),
              const SizedBox(height: 16),

              const _SectionCard(
                title: 'Recent Activity',
                subtitle: 'Latest updates',

                child: _RecentActivityList(),
              ),
              const SizedBox(height: 16),

              // const _SectionCard(
              //   title: 'Quick Actions',
              //   subtitle: 'Frequently used actions',
              //   child: _QuickActionsGrid(),
              // ),
              const SizedBox(height: 16),

              const _SectionCard(
                title: 'Upcoming Site Visits',
                subtitle: 'Next 3 days',

                child: _UpcomingVisitsList(),
              ),
              const SizedBox(height: 102),
            ],
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

        onMore: () {
          // optional: analytics / log
        },

        onLess: () {
          // optional
        },
      )

          : null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String trend;
  final Color trendColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 20),
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _TimeRangePicker extends StatelessWidget {
  const _TimeRangePicker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption('Week', false),
          _buildOption('Month', true),
          _buildOption('Year', false),
        ],
      ),
    );
  }

  Widget _buildOption(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// class _ViewAllButton extends StatelessWidget {
//   const _ViewAllButton();

//   @override
//   Widget build(BuildContext context) {
//     // return const Text(
//     //   'View All',
//     //   style: TextStyle(
//     //     color: AppColors.primary,
//     //     fontSize: 12,
//     //     fontWeight: FontWeight.bold,
//     //   ),
//     // );
//   }
// }

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart();

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (value >= 0 && value < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      months[value.toInt()],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 4),
              FlSpot(1, 6),
              FlSpot(2, 5),
              FlSpot(3, 8),
              FlSpot(4, 13),
              FlSpot(5, 17),
            ],
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.orange.withOpacity(0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadSourcesPieChart extends StatelessWidget {
  const _LeadSourcesPieChart();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: [
                PieChartSectionData(
                  color: Colors.blue,
                  value: 30,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.lightBlue,
                  value: 15,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.orange,
                  value: 10,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.teal,
                  value: 15,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.pink,
                  value: 10,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.cyan,
                  value: 10,
                  title: '',
                  radius: 25,
                ),
                PieChartSectionData(
                  color: Colors.amber,
                  value: 10,
                  title: '',
                  radius: 25,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            _ChartLegend(color: Colors.blue, label: 'Website'),
            _ChartLegend(color: Colors.lightBlue, label: 'Facebook'),
            _ChartLegend(color: Colors.orange, label: 'Google Ads'),
            _ChartLegend(color: Colors.teal, label: 'Referral'),
            _ChartLegend(color: Colors.pink, label: '99acres'),
            _ChartLegend(color: Colors.cyan, label: 'MagicBricks'),
            _ChartLegend(color: Colors.amber, label: 'Walk-in'),
            _ChartLegend(color: Colors.black54, label: 'Other'),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CommissionBarChart extends StatelessWidget {
  const _CommissionBarChart();

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (value >= 0 && value < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      months[value.toInt()],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 10, 6),
          _makeGroupData(1, 14, 8),
          _makeGroupData(2, 12, 11),
          _makeGroupData(3, 10, 6),
          _makeGroupData(4, 16, 12),
          _makeGroupData(5, 18, 14),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: AppColors.success,
          width: 8,
          borderRadius: BorderRadius.circular(2),
        ),
        BarChartRodData(
          toY: y2,
          color: Colors.orange,
          width: 8,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

class _LeadPipelineList extends StatelessWidget {
  const _LeadPipelineList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _PipelineItem(label: 'New', count: 180, total: 250, color: Colors.blue),
        _PipelineItem(
          label: 'Contacted',
          count: 220,
          total: 250,
          color: Colors.lightBlue,
        ),
        _PipelineItem(
          label: 'Qualified',
          count: 150,
          total: 250,
          color: Colors.teal,
        ),
        _PipelineItem(
          label: 'Site Visit',
          count: 145,
          total: 250,
          color: Colors.orange,
        ),
        _PipelineItem(
          label: 'Negotiation',
          count: 80,
          total: 250,
          color: Colors.deepOrange,
        ),
        _PipelineItem(
          label: 'Booking',
          count: 45,
          total: 250,
          color: Colors.amber,
        ),
      ],
    );
  }
}

class _PipelineItem extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PipelineItem({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: count / total,
            backgroundColor: AppColors.card,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ActivityTile(
          icon: Icons.person_add_alt_1,
          color: Colors.blue,
          title: 'New lead assigned',
          subtitle: 'Rajesh Khanna - Lodha Park',
          time: '5 min ago',
        ),
        _ActivityTile(
          icon: Icons.location_on_outlined,
          color: Colors.green,
          title: 'Site visit completed',
          subtitle: 'Suresh Iyer - Site visit done',
          time: '1 hour ago',
        ),
        _ActivityTile(
          icon: Icons.description_outlined,
          color: Colors.purple,
          title: 'New booking',
          subtitle: 'Karthik Menon - Unit T-301',
          time: '2 hours ago',
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
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

// class _QuickActionsGrid extends StatelessWidget {
//   const _QuickActionsGrid();
//
//   @override
//   Widget build(BuildContext context) {
//     return GridView.count(
//       crossAxisCount: 2,
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       mainAxisSpacing: 12,
//       crossAxisSpacing: 12,
//       childAspectRatio: 1.5,
//       children: const [
//         _QuickActionCard(
//           icon: Icons.person_add_outlined,
//           label: 'Add Lead',
//           color: Colors.blue,
//         ),
//         _QuickActionCard(
//           icon: Icons.calendar_today_outlined,
//           label: 'Schedule Visit',
//           color: Colors.green,
//         ),
//         _QuickActionCard(
//           icon: Icons.description_outlined,
//           label: 'New Booking',
//           color: Colors.purple,
//         ),
//         _QuickActionCard(
//           icon: Icons.chat_outlined,
//           label: 'Send WhatsApp',
//           color: Colors.teal,
//         ),
//       ],
//     );
//   }
// }
//
// class _QuickActionCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//
//   const _QuickActionCard({
//     required this.icon,
//     required this.label,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.border.withOpacity(0.5)),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: color, size: 24),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.bold,
//               color: AppColors.textPrimary,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _UpcomingVisitsList extends StatelessWidget {
  const _UpcomingVisitsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _VisitTile(
          name: 'Rajesh Khanna',
          project: 'Lodha Park',
          time: '10:00 AM',
          status: 'confirmed',
        ),
        _VisitTile(
          name: 'Priya Nair',
          project: 'Godrej Emerald',
          time: '2:00 PM',
          status: 'scheduled',
        ),
        _VisitTile(
          name: 'Vikram Shah',
          project: 'Prestige Jindal',
          time: '11:30 AM',
          status: 'scheduled',
        ),
      ],
    );
  }
}

class _VisitTile extends StatelessWidget {
  final String name;
  final String project;
  final String time;
  final String status;

  const _VisitTile({
    required this.name,
    required this.project,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  project,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'confirmed'
                      ? Colors.black
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: status != 'confirmed'
                      ? Border.all(color: AppColors.border)
                      : null,
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: status == 'confirmed'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

