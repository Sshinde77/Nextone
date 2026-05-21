import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';

class SalaryDetailPage extends StatelessWidget {
  const SalaryDetailPage({
    super.key,
    required this.name,
    required this.role,
    required this.email,
    required this.monthlySalary,
    required this.perDaySalary,
    required this.effectiveFrom,
    required this.setBy,
  });

  final String name;
  final String role;
  final String email;
  final double monthlySalary;
  final double perDaySalary;
  final DateTime? effectiveFrom;
  final String setBy;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 380;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    final effectiveLabel = effectiveFrom == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(effectiveFrom!.toLocal());

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
            name: name,
            role: role,
            email: email,
            monthlySalary: monthlySalary,
            perDaySalary: perDaySalary,
            effectiveFrom: effectiveLabel,
            setBy: setBy,
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
              _statCard('Present Days', '1', 'Full day', const Color(0xFF10B981)),
              _statCard('Absent Days', '0', 'No pay', const Color(0xFFEF4444)),
              _statCard('On Leave', '0', 'Leave days', const Color(0xFFF59E0B)),
              _statCard(
                'Earned (Est.)',
                _currency(perDaySalary),
                monthLabel,
                const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _daywiseCard(
            monthLabel: monthLabel,
            perDaySalary: perDaySalary,
            date: DateFormat('dd MMM yyyy').format(DateTime.now()),
            earned: perDaySalary,
          ),
        ],
      ),
    );
  }

  static String _currency(double value) {
    return 'Rs. ${NumberFormat('#,##,##0.00').format(value)}';
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
                  backgroundColor: Colors.white.withOpacity(0.2),
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
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
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
        _navCircle(Icons.chevron_left),
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
        _navCircle(Icons.chevron_right),
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
    required String date,
    required double earned,
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
                  '$monthLabel - 1 records',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$date\nPresent',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '+${_currency(earned)}',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
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
              ],
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
