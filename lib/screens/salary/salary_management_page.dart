// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/salary_models.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/salary/salary_detail_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SalaryManagementPage extends StatefulWidget {
  const SalaryManagementPage({
    super.key,
    this.showBackButton = false,
  });

  final bool showBackButton;

  @override
  State<SalaryManagementPage> createState() => _SalaryManagementPageState();
}

class _SalaryManagementPageState extends State<SalaryManagementPage> {
  final AuthProvider _authProvider = AuthProvider();

  String _currentRole = '';
  bool _isLoadingAccess = true;
  bool _isLoadingEmployees = false;
  String? _employeesError;
  int _employeesTotal = 0;
  int _employeesCurrentPage = 1;
  int _employeesTotalPages = 1;
  final int _employeesPerPage = 10;
  List<SalaryEmployee> _employees = <SalaryEmployee>[];
  bool _isLoadingSlips = false;
  bool _isGeneratingAllSlips = false;
  String? _slipsError;
  int _slipsTotal = 0;
  int _slipsCurrentPage = 1;
  int _slipsTotalPages = 1;
  final int _slipsPerPage = 10;
  List<SalarySlip> _salarySlips = <SalarySlip>[];
  bool _isLoadingCommissions = false;
  String? _commissionsError;
  int _commissionsTotal = 0;
  List<SalaryCommission> _commissions = <SalaryCommission>[];
  final Set<String> _commissionBusyIds = <String>{};
  final TextEditingController _commissionEmployeeController =
      TextEditingController();
  String _commissionEmployeeFilter = '';
  String _commissionStatusFilter = 'all';
  DateTime? _commissionFromDate;
  DateTime? _commissionToDate;
  bool _isLoadingAdvances = false;
  String? _advancesError;
  int _advancesTotal = 0;
  List<SalaryAdvance> _advances = <SalaryAdvance>[];
  final Set<String> _advanceBusyIds = <String>{};
  final TextEditingController _advanceEmployeeController =
      TextEditingController();
  String _advanceEmployeeFilter = '';
  DateTime? _advanceFromDate;
  DateTime? _advanceToDate;
  bool _isLoadingMySalary = false;
  String? _mySalaryError;
  MySalaryResult? _mySalaryResult;
  List<SalaryHistoryEntry> _mySalaryHistory = <SalaryHistoryEntry>[];
  List<_MySalaryIncentiveRow> _myIncentives = <_MySalaryIncentiveRow>[];
  List<SalaryCommission> _myCommissions = <SalaryCommission>[];
  List<SalaryAdvance> _myAdvances = <SalaryAdvance>[];
  List<_MyDailyEarningRow> _myDailyEarningRows = <_MyDailyEarningRow>[];
  int _myDailyPresentFullCount = 0;
  int _myDailyPresentHalfCount = 0;
  double _myDailyPresentDays = 0;
  double _myDailyPerDaySalary = 0;
  double _myDailyMonthlySalary = 0;
  double _myDailyEarnedTotal = 0;
  int _mySalaryTab = 0;
  String? _expandedMySalarySlipId;
  int _selectedMonth = DateTime.now().month;
  int _mySalarySelectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedTab = 0;
  String _myCommissionStatusFilter = 'all';
  DateTime? _myCommissionFromDate;
  DateTime? _myCommissionToDate;
  DateTime? _myAdvanceFromDate;
  DateTime? _myAdvanceToDate;

  bool get _isAdminSalaryView => RoleAccess.canManageSalary(_currentRole);

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _commissionEmployeeController.dispose();
    _advanceEmployeeController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      final isAdmin = RoleAccess.canManageSalary(role);
      setState(() {
        _currentRole = role;
        _isLoadingAccess = false;
      });
      if (isAdmin) {
        await _loadEmployees(page: 1);
        await _loadSalarySlips(page: 1);
        await _loadCommissions();
        await _loadAdvances();
      } else {
        await _loadMySalary();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAccess = false);
      await _loadMySalary();
    }
  }

  Future<void> _loadEmployees({int page = 1}) async {
    setState(() {
      _isLoadingEmployees = true;
      _employeesError = null;
    });
    try {
      final result = await _authProvider.salaryEmployeesPaged(
        token: _authProvider.currentAuthToken,
        page: page,
        perPage: _employeesPerPage,
      );
      if (!mounted) return;
      setState(() {
        _employees = result.employees;
        _employeesTotal = result.total;
        _employeesCurrentPage =
            result.currentPage <= 0 ? page : result.currentPage;
        _employeesTotalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _isLoadingEmployees = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingEmployees = false;
        _employeesError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _refreshAdminData() async {
    await _loadRole();
  }

  Future<void> _loadSalarySlips({int page = 1}) async {
    setState(() {
      _isLoadingSlips = true;
      _slipsError = null;
    });
    try {
      final result = await _authProvider.salarySlips(
        month: _selectedMonth,
        year: _selectedYear,
        page: page,
        perPage: _slipsPerPage,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _salarySlips = result.items;
        _slipsTotal = result.total;
        _slipsCurrentPage = result.page <= 0 ? page : result.page;
        _slipsTotalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _isLoadingSlips = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlips = false;
        _slipsError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadCommissions() async {
    setState(() {
      _isLoadingCommissions = true;
      _commissionsError = null;
    });
    try {
      final result = await _authProvider.salaryCommissions(
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final sorted = List<SalaryCommission>.from(result.items)
        ..sort((a, b) => _commissionDateOf(b).compareTo(_commissionDateOf(a)));
      setState(() {
        _commissions = sorted;
        _commissionsTotal = result.total > 0 ? result.total : sorted.length;
        _isLoadingCommissions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingCommissions = false;
        _commissionsError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadAdvances() async {
    setState(() {
      _isLoadingAdvances = true;
      _advancesError = null;
    });
    try {
      final result = await _authProvider.salaryAdvances(
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final sorted = List<SalaryAdvance>.from(result.items)
        ..sort((a, b) => _advanceDateOf(b).compareTo(_advanceDateOf(a)));
      setState(() {
        _advances = sorted;
        _advancesTotal = result.total > 0 ? result.total : sorted.length;
        _isLoadingAdvances = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingAdvances = false;
        _advancesError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadMySalary() async {
    setState(() {
      _isLoadingMySalary = true;
      _mySalaryError = null;
    });
    try {
      final int month = _mySalarySelectedMonth;
      final futures = await Future.wait<dynamic>([
        if (month == 0)
          _authProvider.mySalary(
            year: _selectedYear,
            token: _authProvider.currentAuthToken,
          )
        else
          _authProvider.mySalary(
            month: month,
            year: _selectedYear,
            token: _authProvider.currentAuthToken,
          ),
        _authProvider.mySalaryHistory(token: _authProvider.currentAuthToken),
        _authProvider.myIncentives(token: _authProvider.currentAuthToken),
        _authProvider.myCommissions(token: _authProvider.currentAuthToken),
        _authProvider.myAdvances(token: _authProvider.currentAuthToken),
      ]);
      final result = futures[0] as MySalaryResult;
      final history = (futures[1] as List<SalaryHistoryEntry>)
        ..sort((a, b) => _historyDateOf(b).compareTo(_historyDateOf(a)));
      final incentives = (futures[2] as List<Map<String, dynamic>>)
          .map(_mapMyIncentiveRow)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final commissions = (futures[3] as List<SalaryCommission>)
        ..sort((a, b) => _commissionDateOf(b).compareTo(_commissionDateOf(a)));
      final advances = (futures[4] as List<SalaryAdvance>)
        ..sort((a, b) => _advanceDateOf(b).compareTo(_advanceDateOf(a)));

      final dayWise = await _buildMyDailyEarnings(result);
      if (!mounted) return;
      setState(() {
        _mySalaryResult = result;
        _mySalaryHistory = history;
        _myIncentives = incentives;
        _myCommissions = commissions;
        _myAdvances = advances;
        _myDailyEarningRows = dayWise.rows;
        _myDailyPresentFullCount = dayWise.fullDays;
        _myDailyPresentHalfCount = dayWise.halfDays;
        _myDailyPresentDays = dayWise.presentDays;
        _myDailyPerDaySalary = dayWise.perDaySalary;
        _myDailyMonthlySalary = dayWise.monthlySalary;
        _myDailyEarnedTotal = dayWise.earnedTotal;
        _isLoadingMySalary = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingMySalary = false;
        _mySalaryError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  List<_SummaryStat> get _stats {
    final totalEmployees =
        _employeesTotal > 0 ? _employeesTotal : _employees.length;
    final salarySetCount = _employees.where((e) => e.salarySet).length;
    final pendingCount = totalEmployees - salarySetCount;
    final monthlyPayroll = _employees.fold<double>(
      0,
      (sum, item) => sum + (item.monthlySalary ?? 0),
    );
    final now = DateTime.now();
    final slipsThisMonth =
        (_selectedMonth == now.month && _selectedYear == now.year)
            ? _salarySlips.length
            : 0;

    return <_SummaryStat>[
      _SummaryStat(
        title: 'Total Employees',
        value: totalEmployees.toString(),
        subtitle: '',
        icon: Icons.groups_outlined,
        iconBg: const Color(0xFFE4EEF8),
        iconColor: const Color(0xFF0075E5),
      ),
      _SummaryStat(
        title: 'Salary Set',
        value: salarySetCount.toString(),
        subtitle: '$pendingCount pending',
        icon: Icons.check_circle_outline,
        iconBg: const Color(0xFFD5F1E1),
        iconColor: const Color(0xFF11A255),
      ),
      _SummaryStat(
        title: 'Monthly Payroll',
        value: _formatCurrency(monthlyPayroll),
        subtitle: '',
        icon: Icons.account_balance_wallet_outlined,
        iconBg: const Color(0xFFECE0FA),
        iconColor: const Color(0xFF8D34F5),
      ),
      _SummaryStat(
        title: 'Slips This Month',
        value: slipsThisMonth.toString(),
        subtitle: DateFormat('MMM yyyy').format(now),
        icon: Icons.receipt_long_outlined,
        iconBg: const Color(0xFFF7E9B7),
        iconColor: const Color(0xFFE18300),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: CrmAppBar(
        title: 'Salary Management',
        showBackButton: widget.showBackButton,
      ),
      body: _isLoadingAccess
          ? const Center(child: CircularProgressIndicator())
          : _isAdminSalaryView
              ? _buildAdminBody()
              : _buildOtherRoleBody(),
    );
  }

  Widget _buildAdminBody() {
    return RefreshIndicator(
      onRefresh: _refreshAdminData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 540;
          final sidePadding = 16.0;

          Widget actionButtons() {
            final refreshButton = SizedBox(
              width: isNarrow ? double.infinity : null,
              child: OutlinedButton.icon(
                onPressed: _refreshAdminData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            );

            final primaryButton = SizedBox(
              width: isNarrow ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: _selectedTab == 2
                    ? _showAddCommissionDialog
                    : _selectedTab == 3
                        ? _showAddAdvanceDialog
                        : (_isGeneratingAllSlips
                            ? null
                            : _showGenerateAllSalarySlipsDialog),
                icon: Icon(
                  _selectedTab == 2
                      ? Icons.add_circle_outline
                      : _selectedTab == 3
                          ? Icons.add_card_outlined
                          : Icons.receipt_long_outlined,
                  size: 18,
                ),
                label: _selectedTab == 2
                    ? const Text('Add Commission')
                    : _selectedTab == 3
                        ? const Text('Add Advance')
                        : _isGeneratingAllSlips
                            ? const Text('Generating...')
                            : const Text('Generate All Slips'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  refreshButton,
                  const SizedBox(height: 8),
                  primaryButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: refreshButton),
                const SizedBox(width: 8),
                Expanded(child: primaryButton),
              ],
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 120),
            children: [
              const Text(
                'Set salaries, generate slips and track payroll',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              actionButtons(),
              const SizedBox(height: 12),
              _buildSummaryGrid(),
              const SizedBox(height: 20),
              _buildTabBar(),
              const SizedBox(height: 12),
              if (_selectedTab == 0)
                _buildEmployeesSection()
              else if (_selectedTab == 1) ...[
                _buildFilterTile(
                  DateFormat('MMMM')
                      .format(DateTime(_selectedYear, _selectedMonth)),
                  onTap: _pickMonth,
                ),
                const SizedBox(height: 10),
                _buildFilterTile(
                  _selectedYear.toString(),
                  onTap: _pickYear,
                ),
                const SizedBox(height: 10),
                _buildSalarySlipsSection(),
                const SizedBox(height: 150),
              ] else if (_selectedTab == 2) ...[
                _buildCommissionFilters(),
                const SizedBox(height: 12),
                _buildCommissionsSection(),
                const SizedBox(height: 150),
              ] else ...[
                _buildAdvanceFilters(),
                const SizedBox(height: 12),
                _buildAdvancesSection(),
                const SizedBox(height: 150),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 760
                ? 3
                : 2;
        final aspectRatio = width >= 1100
            ? 3.0
            : width >= 760
                ? 2.7
                : 2.45;

        return GridView.builder(
          itemCount: _stats.length,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => _buildSummaryCard(_stats[index]),
        );
      },
    );
  }

  Widget _buildOtherRoleBody() {
    final current = _mySalaryResult?.currentMonthlySalary;
    final slips = _mySalaryResult?.salarySlips ?? const <MySalarySlip>[];
    final history = _filteredMySalaryHistory();
    final incentives = _filteredMyIncentives();
    final commissions = _filteredMyCommissions();
    final advances = _filteredMyAdvances();
    final latestSlip = slips.isNotEmpty ? slips.first : null;
    final perDay = current?.perDaySalary ?? latestSlip?.perDaySalary ?? 0;
    final effectiveFrom = current?.effectiveFrom;
    final totalEarned = slips.fold<double>(0, (sum, s) => sum + s.finalSalary);
    final monthName = _mySalarySelectedMonth == 0
        ? 'All Months'
        : DateFormat('MMMM').format(DateTime(2000, _mySalarySelectedMonth));
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 380;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final horizontalPadding = 16.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Salary',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Your salary, daily earnings and payment history',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoadingMySalary)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_mySalaryError != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mySalaryError!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _loadMySalary, child: const Text('Retry')),
              ],
            ),
          )
        else ...[
          _mySalaryTopSection(
            isCompact: isCompact,
            isMobile: width < 700,
            monthly: current?.amount ?? 0,
            perDay: perDay,
            effectiveFrom: effectiveFrom,
            totalSlips: slips.length,
            latestMonth: latestSlip?.monthLabel ?? '-',
            totalEarned: totalEarned,
          ),
          const SizedBox(height: 10),
          _mySalaryTabBar(),
          const SizedBox(height: 10),
          if (_mySalaryTab == 3) ...[
            _buildMyCommissionFilters(),
            const SizedBox(height: 10),
          ] else if (_mySalaryTab == 4) ...[
            _buildMyAdvanceFilters(),
            const SizedBox(height: 10),
          ] else ...[
            _buildFilterTile(monthName, onTap: _pickMySalaryMonth),
            const SizedBox(height: 8),
            _buildFilterTile(_selectedYear.toString(),
                onTap: _pickMySalaryYear),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _loadMySalary,
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (_mySalaryTab == 0)
            _mySalarySlipsList(slips)
          else if (_mySalaryTab == 1)
            _mySalaryHistoryList(history)
          else if (_mySalaryTab == 2)
            _myIncentivesList(incentives)
          else if (_mySalaryTab == 3)
            _myCommissionsList(commissions)
          else
            _myAdvancesList(advances),
        ],
      ],
    );

    return RefreshIndicator(
      onRefresh: _loadMySalary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          bottomInset + 120,
        ),
        children: [content],
      ),
    );
  }

  Widget _mySalaryTopSection({
    required bool isCompact,
    required bool isMobile,
    required double monthly,
    required double perDay,
    required DateTime? effectiveFrom,
    required int totalSlips,
    required String latestMonth,
    required double totalEarned,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final latestMonthText =
            latestMonth.trim().isEmpty || latestMonth.trim() == '-'
                ? 'No slips yet'
                : latestMonth;

        final stats = isWide
            ? Row(
                children: [
                  Expanded(child: _smallStatCard('Total Slips', '$totalSlips')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _smallStatCard('Latest Month', latestMonthText)),
                ],
              )
            : Column(
                children: [
                  _smallStatCard('Total Slips', '$totalSlips'),
                  const SizedBox(height: 8),
                  _smallStatCard('Latest Month', latestMonthText),
                ],
              );

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A7CFF), Color(0xFF2F5FE3)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MONTHLY SALARY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(monthly),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 21 : (isMobile ? 23 : 26),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Effective from ${_formatDate(effectiveFrom)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const Divider(height: 18, color: Colors.white24),
                  const Text(
                    'Total earned this period',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _formatCurrency(totalEarned),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            stats,
          ],
        );
      },
    );
  }

  Widget _smallStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mySalaryTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _myTabButton('Salary Slips', 0),
            _myTabButton('Salary History', 1),
            _myTabButton('Incentives', 2),
            _myTabButton('Commissions', 3),
            _myTabButton('Advances', 4),
          ],
        ),
      ),
    );
  }

  Widget _myTabButton(String label, int index) {
    final selected = _mySalaryTab == index;
    return GestureDetector(
      onTap: () => setState(() => _mySalaryTab = index),
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DateTime _historyDateOf(SalaryHistoryEntry item) {
    return item.effectiveFrom ??
        item.createdAt ??
        item.updatedAt ??
        DateTime(1970, 1, 1);
  }

  String _readStringValue(dynamic value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  double _readDoubleValue(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  DateTime _parseOptionalDateValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return DateTime.now();
  }

  _MySalaryIncentiveRow _mapMyIncentiveRow(Map<String, dynamic> json) {
    final amount = _readDoubleValue(
      json['amount'] ??
          json['incentive_amount'] ??
          json['incentive'] ??
          json['value'],
    );
    final note = _readStringValue(
      json['note'] ??
          json['notes'] ??
          json['description'] ??
          json['reason'] ??
          json['title'],
    );
    final date = _parseOptionalDateValue(
      json['date'] ??
          json['incentive_date'] ??
          json['created_at'] ??
          json['updated_at'],
    );

    return _MySalaryIncentiveRow(
      id: _readStringValue(json['id'] ?? json['_id']),
      amount: amount,
      note: note.isEmpty ? 'Incentive' : note,
      date: date,
    );
  }

  List<SalaryHistoryEntry> _filteredMySalaryHistory() {
    return _mySalaryHistory.where((item) {
      final date = _historyDateOf(item);
      final matchesYear = date.year == _selectedYear;
      final matchesMonth =
          _mySalarySelectedMonth == 0 || date.month == _mySalarySelectedMonth;
      return matchesYear && matchesMonth;
    }).toList();
  }

  List<_MySalaryIncentiveRow> _filteredMyIncentives() {
    return _myIncentives.where((item) {
      final matchesYear = item.date.year == _selectedYear;
      final matchesMonth = _mySalarySelectedMonth == 0 ||
          item.date.month == _mySalarySelectedMonth;
      return matchesYear && matchesMonth;
    }).toList();
  }

  List<SalaryCommission> _filteredMyCommissions() {
    return _myCommissions.where((item) {
      final matchesStatus = _myCommissionStatusFilter == 'all' ||
          (_myCommissionStatusFilter == 'paid' && item.isPaid) ||
          (_myCommissionStatusFilter == 'unpaid' && !item.isPaid);
      final date = _commissionDateOf(item);
      final matchesFrom = _myCommissionFromDate == null ||
          !date.isBefore(_myCommissionFromDate!);
      final matchesTo =
          _myCommissionToDate == null || !date.isAfter(_myCommissionToDate!);
      return matchesStatus && matchesFrom && matchesTo;
    }).toList();
  }

  List<SalaryAdvance> _filteredMyAdvances() {
    return _myAdvances.where((item) {
      final date = _advanceDateOf(item);
      final matchesFrom =
          _myAdvanceFromDate == null || !date.isBefore(_myAdvanceFromDate!);
      final matchesTo =
          _myAdvanceToDate == null || !date.isAfter(_myAdvanceToDate!);
      return matchesFrom && matchesTo;
    }).toList();
  }

  DateTime _commissionDateOf(SalaryCommission item) {
    return item.createdAt ?? item.updatedAt ?? DateTime(1970, 1, 1);
  }

  List<SalaryCommission> _filteredCommissions() {
    final query = _commissionEmployeeFilter.trim().toLowerCase();
    return _commissions.where((item) {
      final employeeName = item.employeeName.toLowerCase();
      final matchesEmployee = query.isEmpty || employeeName.contains(query);
      final matchesStatus = _commissionStatusFilter == 'all' ||
          (_commissionStatusFilter == 'paid' && item.isPaid) ||
          (_commissionStatusFilter == 'unpaid' && !item.isPaid);
      final date = _commissionDateOf(item);
      final matchesFrom =
          _commissionFromDate == null || !date.isBefore(_commissionFromDate!);
      final matchesTo =
          _commissionToDate == null || !date.isAfter(_commissionToDate!);
      return matchesEmployee && matchesStatus && matchesFrom && matchesTo;
    }).toList();
  }

  DateTime _advanceDateOf(SalaryAdvance item) {
    return item.advanceDate ??
        item.createdAt ??
        item.updatedAt ??
        DateTime(1970, 1, 1);
  }

  List<SalaryAdvance> _filteredAdvances() {
    final query = _advanceEmployeeFilter.trim().toLowerCase();
    return _advances.where((item) {
      final matchesEmployee =
          query.isEmpty || item.employeeName.toLowerCase().contains(query);
      final date = _advanceDateOf(item);
      final matchesFrom =
          _advanceFromDate == null || !date.isBefore(_advanceFromDate!);
      final matchesTo =
          _advanceToDate == null || !date.isAfter(_advanceToDate!);
      return matchesEmployee && matchesFrom && matchesTo;
    }).toList();
  }

  Widget _mySalarySlipsList(List<MySalarySlip> slips) {
    if (slips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No salary slips for selected month/year.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      children: slips.map((s) {
        final isExpanded = _expandedMySalarySlipId == s.id;
        final monthLabel = s.monthLabel.isNotEmpty
            ? s.monthLabel
            : '${DateFormat('MMMM').format(DateTime(s.year, s.month))} ${s.year}';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _expandedMySalarySlipId = isExpanded ? null : s.id;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              monthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${s.presentDays} / ${s.workingDays} working days',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Final Salary',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                          Text(
                            _formatCurrency(s.finalSalary),
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _mySlipInfoCard(
                              'Monthly Salary',
                              _formatCurrency(s.monthlySalary),
                              subtitle: 'Base',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _mySlipInfoCard(
                              'Per Day',
                              _formatCurrency(s.perDaySalary),
                              subtitle: '${s.workingDays} days',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _mySlipInfoCard(
                              'Days Present',
                              '${s.presentDays}',
                              subtitle: 'Absent: ${s.absentDays}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _mySlipInfoCard(
                              'Earned Salary',
                              _formatCurrency(s.earnedSalary),
                              subtitle: 'Before deductions',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8EFD7)),
                        ),
                        child: Column(
                          children: [
                            _previewRow('Earned Salary',
                                _formatCurrency(s.earnedSalary)),
                            const Divider(height: 14, color: Color(0xFFC8EFD7)),
                            _previewRow(
                              'Final Salary',
                              _formatCurrency(s.finalSalary),
                              color: const Color(0xFF16A34A),
                            ),
                          ],
                        ),
                      ),
                      if ((s.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.notes!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _mySlipInfoCard(String title, String value, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if ((subtitle ?? '').isNotEmpty)
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _mySalaryDayWise(List<MySalarySlip> slips) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (_myDailyEarningRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No day-wise earnings for selected month/year.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final title = _mySalarySelectedMonth == 0
        ? '$_selectedYear SALARY SUMMARY'
        : '${DateFormat('MMM').format(DateTime(_selectedYear, _mySalarySelectedMonth)).toUpperCase()} $_selectedYear SALARY SUMMARY';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                  colors: [Color(0xFF0A7CFF), Color(0xFF2F5FE3)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(_myDailyEarnedTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Earned so far - ${_formatPresentDays(_myDailyPresentDays)} days present',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _miniInfo(
                      'Monthly Base', _formatCurrency(_myDailyMonthlySalary)),
                ),
                Expanded(
                    child: _miniInfo(
                        'Per Day', _formatCurrency(_myDailyPerDaySalary))),
                Expanded(
                  child: _miniInfo(
                    'Days Present',
                    _formatPresentDays(_myDailyPresentDays),
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: const [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'DATE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'STATUS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'HOURS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'EARNED',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            ..._myDailyEarningRows.map((row) => _myDailyRowTile(row)),
          ] else ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _myDailyEarningRows
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _myDailyMobileTile(row),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_myDailyPresentFullCount full + $_myDailyPresentHalfCount half days',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Earned This Period',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatCurrency(_myDailyEarnedTotal),
                      style: const TextStyle(
                        color: Color(0xFF0A7CFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
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

  Widget _mySalaryHistoryList(List<SalaryHistoryEntry> history) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No salary history for selected month/year.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: history.map((item) {
        final effectiveDate = _historyDateOf(item);
        final setter =
            item.setByName.trim().isEmpty ? 'Unknown' : item.setByName.trim();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F111827),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D7CFF), Color(0xFF4E46E5)],
                  ),
                ),
                child: const Icon(Icons.currency_rupee,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(item.monthlySalary),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Per day: ${_formatCurrency(item.perDaySalary ?? 0)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((item.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.notes!.trim(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Effective ${_formatDate(effectiveDate)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set by $setter',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _myIncentivesList(List<_MySalaryIncentiveRow> incentives) {
    if (incentives.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No incentives for selected month/year.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: incentives.map((item) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFFBF3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD3F7DF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(item.amount),
                      style: const TextStyle(
                        color: Color(0xFF08A651),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.note,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(item.date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMyCommissionFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Commissions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loadMySalary,
              icon: const Icon(
                Icons.refresh,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _myCommissionStatusFilter,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _myCommissionStatusFilter = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFilterTile(
          _myCommissionFromDate == null
              ? 'From date'
              : _formatDate(_myCommissionFromDate),
          onTap: _pickMyCommissionFromDate,
        ),
        const SizedBox(height: 8),
        _buildFilterTile(
          _myCommissionToDate == null
              ? 'To date'
              : _formatDate(_myCommissionToDate),
          onTap: _pickMyCommissionToDate,
        ),
      ],
    );
  }

  Widget _buildMyAdvanceFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Advances',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loadMySalary,
              icon: const Icon(
                Icons.refresh,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildFilterTile(
          _myAdvanceFromDate == null
              ? 'From date'
              : _formatDate(_myAdvanceFromDate),
          onTap: _pickMyAdvanceFromDate,
        ),
        const SizedBox(height: 8),
        _buildFilterTile(
          _myAdvanceToDate == null ? 'To date' : _formatDate(_myAdvanceToDate),
          onTap: _pickMyAdvanceToDate,
        ),
      ],
    );
  }

  Widget _myCommissionsList(List<SalaryCommission> commissions) {
    if (commissions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No commissions found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: commissions.map((item) {
        final amount = _formatCurrency(item.commissionAmount);
        final percentage = item.commissionPercentage == null
            ? '-'
            : '${item.commissionPercentage!.toStringAsFixed(1)}%';
        final projectName =
            item.projectName.trim().isEmpty ? '-' : item.projectName.trim();
        final leadName = item.leadName.trim().isEmpty
            ? ''
            : item.leadName.trim().toLowerCase();
        final date = _commissionDateOf(item);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '- - $percentage',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      projectName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (leadName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          leadName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(item.isPaid ? 'Paid' : 'Unpaid', item.isPaid),
                  const SizedBox(height: 10),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _myAdvancesList(List<SalaryAdvance> advances) {
    if (advances.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No advances found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: advances.map((item) {
        final amount = _formatCurrency(item.amount);
        final date = _advanceDateOf(item);
        final proofUrl = _resolvePaymentProofUrl(item.paymentProofUrl);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (proofUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showProofDialog(proofUrl),
                      icon: const Icon(Icons.link, size: 14),
                      label: const Text('Proof'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _myDailyMobileTile(_MyDailyEarningRow row) {
    final isPositive = row.earned > 0;
    final statusText = row.statusLabel.toLowerCase();
    final isHalfDay = statusText.contains('half');
    final statusBg = isHalfDay
        ? const Color(0xFFFBEAF4)
        : (isPositive ? const Color(0xFFDDF6E8) : const Color(0xFFF1F5F9));
    final statusFg = isHalfDay
        ? const Color(0xFFC2185B)
        : (isPositive ? const Color(0xFF14864A) : AppColors.textSecondary);
    final earnedFg =
        isPositive ? const Color(0xFF16A34A) : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy').format(row.date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (row.timeLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              row.timeLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _myDailyMeta('Hours', row.hoursLabel)),
              Expanded(
                child: _myDailyMeta(
                  'Earned',
                  isPositive
                      ? '+${_formatCurrency(row.earned)}'
                      : _formatCurrency(0),
                  alignRight: true,
                  valueColor: earnedFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _myDailyMeta(
    String label,
    String value, {
    bool alignRight = false,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _myDailyRowTile(_MyDailyEarningRow row) {
    final isPositive = row.earned > 0;
    final statusBg =
        isPositive ? const Color(0xFFDDF6E8) : const Color(0xFFF1F5F9);
    final statusFg =
        isPositive ? const Color(0xFF14864A) : AppColors.textSecondary;
    final earnedFg =
        isPositive ? const Color(0xFF16A34A) : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(row.date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                if (row.timeLabel.isNotEmpty)
                  Text(
                    row.timeLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.hoursLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isPositive
                  ? '+${_formatCurrency(row.earned)}'
                  : _formatCurrency(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: earnedFg,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<_MyDailyEarningSummary> _buildMyDailyEarnings(
      MySalaryResult salaryResult) async {
    final payload = await _fetchAttendancePayload();
    final allRows = payload.rows;
    final salarySummary = payload.salarySummary;
    final double perDaySalary = (salarySummary?.perDaySalary ?? 0) > 0
        ? salarySummary!.perDaySalary
        : _resolvePerDaySalary(salaryResult);
    final double monthlySalary = (salarySummary?.monthlySalary ?? 0) > 0
        ? salarySummary!.monthlySalary
        : _resolveMonthlySalary(salaryResult);

    final filtered = allRows
        .where((row) => row.date.year == _selectedYear)
        .where((row) =>
            _mySalarySelectedMonth == 0 ||
            row.date.month == _mySalarySelectedMonth)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int fullDays = 0;
    int halfDays = 0;
    double presentDays = 0;
    double earnedTotal = 0;
    final List<_MyDailyEarningRow> rows = <_MyDailyEarningRow>[];

    for (final row in filtered) {
      final status = row.status.toLowerCase();
      final isHalf = status.contains('half');
      final isPresent =
          status.contains('present') || status.contains('approved') || isHalf;
      final double earned =
          isPresent ? (isHalf ? perDaySalary / 2 : perDaySalary) : 0.0;

      if (isPresent && !isHalf) fullDays += 1;
      if (isHalf) halfDays += 1;
      if (isPresent) presentDays += isHalf ? 0.5 : 1;
      earnedTotal += earned;

      rows.add(
        _MyDailyEarningRow(
          date: row.date,
          statusLabel: _toTitleCase(row.status),
          timeLabel: row.timeLabel,
          hoursLabel: row.hoursLabel,
          earned: earned,
        ),
      );
    }

    if ((salarySummary?.presentDays ?? 0) > 0) {
      presentDays = salarySummary!.presentDays;
    }
    if ((salarySummary?.earnedSalary ?? 0) > 0) {
      earnedTotal = salarySummary!.earnedSalary;
    }

    return _MyDailyEarningSummary(
      rows: rows,
      fullDays: fullDays,
      halfDays: halfDays,
      presentDays: presentDays,
      perDaySalary: perDaySalary,
      monthlySalary: monthlySalary,
      earnedTotal: earnedTotal,
    );
  }

  double _resolvePerDaySalary(MySalaryResult result) {
    final selected = _mySalarySelectedMonth == 0
        ? null
        : result.salarySlips
            .where((s) => s.month == _mySalarySelectedMonth)
            .toList();
    if (selected != null && selected.isNotEmpty) {
      return selected.first.perDaySalary;
    }
    if (result.currentMonthlySalary?.perDaySalary != null) {
      return result.currentMonthlySalary!.perDaySalary!;
    }
    if (result.salarySlips.isNotEmpty) {
      return result.salarySlips.first.perDaySalary;
    }
    return 0;
  }

  double _resolveMonthlySalary(MySalaryResult result) {
    final selected = _mySalarySelectedMonth == 0
        ? null
        : result.salarySlips
            .where((s) => s.month == _mySalarySelectedMonth)
            .toList();
    if (selected != null && selected.isNotEmpty) {
      return selected.first.monthlySalary;
    }
    if (result.currentMonthlySalary != null) {
      return result.currentMonthlySalary!.amount;
    }
    if (result.salarySlips.isNotEmpty) {
      return result.salarySlips.first.monthlySalary;
    }
    return 0;
  }

  Future<_AttendanceMePayload> _fetchAttendancePayload() async {
    final List<_AttendanceRow> rows = <_AttendanceRow>[];
    _AttendanceSalarySummary? salarySummary;
    int page = 1;
    const int perPage = 30;

    while (page <= 12) {
      final data = await _authProvider.attendanceMe(
        page: page,
        perPage: perPage,
        token: _authProvider.currentAuthToken,
      );
      salarySummary ??= _extractAttendanceSalary(data);
      final pageRows = _extractAttendanceRows(data);
      if (pageRows.isEmpty) break;
      rows.addAll(pageRows);
      if (pageRows.length < perPage) break;
      page += 1;
    }

    final Map<String, _AttendanceRow> unique = <String, _AttendanceRow>{};
    for (final row in rows) {
      final key =
          '${row.date.toIso8601String()}-${row.status}-${row.timeLabel}';
      unique[key] = row;
    }
    return _AttendanceMePayload(
      rows: unique.values.toList(),
      salarySummary: salarySummary,
    );
  }

  List<_AttendanceRow> _extractAttendanceRows(Map<String, dynamic> raw) {
    final directList = raw['data'];
    final root = _pickFirstMap(raw, const ['data']) ?? raw;
    final list = directList is List
        ? directList
        : _pickFirstList(root, const [
            'data',
            'attendance',
            'attendances',
            'items',
            'rows',
            'results',
            'history',
          ]);
    if (list == null) return const <_AttendanceRow>[];

    final List<_AttendanceRow> parsed = <_AttendanceRow>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final date = _readFirstDate(map, const [
        'attendance_date',
        'attendanceDate',
        'date',
        'created_at',
      ]);
      if (date == null) continue;

      final status = _readFirstString(map, const [
        'status',
        'attendance_status',
        'attendanceStatus',
      ]);
      final timeLabel = _readFirstTimeLabel(map);
      final hoursLabel = _readWorkingHoursLabel(map);
      parsed.add(
        _AttendanceRow(
          date: date.toLocal(),
          status: status.isEmpty ? 'absent' : status,
          timeLabel: timeLabel,
          hoursLabel: hoursLabel,
        ),
      );
    }
    return parsed;
  }

  _AttendanceSalarySummary? _extractAttendanceSalary(Map<String, dynamic> raw) {
    final salaryRaw = raw['salary'];
    if (salaryRaw is! Map) return null;
    final salary = Map<String, dynamic>.from(salaryRaw);
    return _AttendanceSalarySummary(
      monthlySalary: _readAsDouble(salary['monthly_salary']),
      presentDays: _readAsDouble(salary['present_days']),
      perDaySalary: _readAsDouble(salary['per_day_salary']),
      earnedSalary: _readAsDouble(salary['earned_salary']),
    );
  }

  Map<String, dynamic>? _pickFirstMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<dynamic>? _pickFirstList(
      Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
    }
    return null;
  }

  String _readFirstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  DateTime? _readFirstDate(Map<String, dynamic> source, List<String> keys) {
    final raw = _readFirstString(source, keys);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _readFirstTimeLabel(Map<String, dynamic> source) {
    final checkInRaw = _readFirstString(source, const [
      'check_in_time',
      'checkInTime',
      'check_in',
      'checkIn',
      'in_time',
    ]);
    final checkOutRaw = _readFirstString(source, const [
      'check_out_time',
      'checkOutTime',
      'check_out',
      'checkOut',
      'out_time',
    ]);
    String formatOne(String raw) {
      if (raw.isEmpty) return '';
      final dt = DateTime.tryParse(raw);
      return dt == null
          ? raw
          : DateFormat('hh:mm a').format(dt.toLocal()).toLowerCase();
    }

    final checkIn = formatOne(checkInRaw);
    final checkOut = formatOne(checkOutRaw);
    if (checkIn.isNotEmpty && checkOut.isNotEmpty) {
      return '→$checkIn   ←$checkOut';
    }
    if (checkIn.isNotEmpty) return '→$checkIn';
    if (checkOut.isNotEmpty) return '←$checkOut';
    return '';
  }

  String _readWorkingHoursLabel(Map<String, dynamic> source) {
    final raw = _readFirstString(
        source, const ['working_hours', 'workingHours', 'hours']);
    if (raw.isEmpty) return '--';
    final value = double.tryParse(raw);
    if (value == null) return raw;
    return '${value.toStringAsFixed(2)}h';
  }

  double _readAsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatPresentDays(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _pickMySalaryMonth() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 13,
            itemBuilder: (context, index) {
              final month = index == 0 ? 0 : index;
              return ListTile(
                title: Text(
                  month == 0
                      ? 'All Months'
                      : DateFormat('MMMM').format(DateTime(2000, month)),
                ),
                trailing: month == _mySalarySelectedMonth
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(month),
              );
            },
          ),
        );
      },
    );
    if (selected == null || selected == _mySalarySelectedMonth) return;
    setState(() => _mySalarySelectedMonth = selected);
    await _loadMySalary();
  }

  Future<void> _pickMySalaryYear() async {
    final current = DateTime.now().year;
    final years = List<int>.generate(8, (index) => current - index);
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: years
                .map(
                  (year) => ListTile(
                    title: Text(year.toString()),
                    trailing: year == _selectedYear
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(year),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected == null || selected == _selectedYear) return;
    setState(() => _selectedYear = selected);
    await _loadMySalary();
  }

  Future<void> _pickMyCommissionFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _myCommissionFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _myCommissionFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_myCommissionToDate != null &&
          _myCommissionToDate!.isBefore(_myCommissionFromDate!)) {
        _myCommissionToDate = _myCommissionFromDate;
      }
    });
  }

  Future<void> _pickMyCommissionToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _myCommissionToDate ?? _myCommissionFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _myCommissionToDate =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      if (_myCommissionFromDate != null &&
          _myCommissionToDate!.isBefore(_myCommissionFromDate!)) {
        _myCommissionFromDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _pickMyAdvanceFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _myAdvanceFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _myAdvanceFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_myAdvanceToDate != null &&
          _myAdvanceToDate!.isBefore(_myAdvanceFromDate!)) {
        _myAdvanceToDate = _myAdvanceFromDate;
      }
    });
  }

  Future<void> _pickMyAdvanceToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _myAdvanceToDate ?? _myAdvanceFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _myAdvanceToDate =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      if (_myAdvanceFromDate != null &&
          _myAdvanceToDate!.isBefore(_myAdvanceFromDate!)) {
        _myAdvanceFromDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Widget _buildSummaryCard(_SummaryStat stat) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 180;
          return Row(
            children: [
              Container(
                width: compact ? 38 : 44,
                height: compact ? 38 : 44,
                decoration: BoxDecoration(
                  color: stat.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.iconColor,
                  size: compact ? 20 : 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (stat.subtitle.isNotEmpty)
                      Text(
                        stat.subtitle,
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton('Employees & Salaries', 0)),
          Expanded(child: _tabButton('Salary Slips', 1)),
          Expanded(child: _tabButton('Commissions', 2)),
          Expanded(child: _tabButton('Advances', 3)),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesSection() {
    if (_isLoadingEmployees) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_employeesError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _employeesError!,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _loadEmployees(page: _employeesCurrentPage),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_employees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No employees found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final rows = _employees.map(_mapEmployeeToRow).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map(_buildEmployeeCard),
        const SizedBox(height: 14),
        PaginationWidget(
          currentPage: _employeesCurrentPage,
          totalPages: _employeesTotalPages,
          totalItems: _employeesTotal,
          itemLabel: 'employees',
          onPageChanged: (page) => _loadEmployees(page: page),
        ),
      ],
    );
  }

  Widget _buildSalarySlipsSection() {
    if (_isLoadingSlips) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_slipsError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _slipsError!,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _loadSalarySlips(page: _slipsCurrentPage),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_salarySlips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No salary slips found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final rows = _salarySlips.map(_mapSalarySlipToRow).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_slipsTotal > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Total slips: $_slipsTotal',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ...rows.map(_buildSalarySlipCard),
        const SizedBox(height: 14),
        PaginationWidget(
          currentPage: _slipsCurrentPage,
          totalPages: _slipsTotalPages,
          totalItems: _slipsTotal,
          itemLabel: 'slips',
          onPageChanged: (page) => _loadSalarySlips(page: page),
        ),
      ],
    );
  }

  Widget _buildCommissionFilters() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _commissionEmployeeController,
            onChanged: (value) =>
                setState(() => _commissionEmployeeFilter = value.trim()),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Filter by employee...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _commissionStatusFilter,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _commissionStatusFilter = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildFilterTile(
          _commissionFromDate == null
              ? 'From date'
              : _formatDate(_commissionFromDate),
          onTap: _pickCommissionFromDate,
        ),
        const SizedBox(height: 10),
        _buildFilterTile(
          _commissionToDate == null
              ? 'To date'
              : _formatDate(_commissionToDate),
          onTap: _pickCommissionToDate,
        ),
        if (_commissionEmployeeFilter.isNotEmpty ||
            _commissionStatusFilter != 'all' ||
            _commissionFromDate != null ||
            _commissionToDate != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _commissionEmployeeController.clear();
                  _commissionEmployeeFilter = '';
                  _commissionStatusFilter = 'all';
                  _commissionFromDate = null;
                  _commissionToDate = null;
                });
              },
              child: const Text('Clear Filters'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommissionsSection() {
    if (_isLoadingCommissions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_commissionsError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _commissionsError!,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadCommissions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final rows = _filteredCommissions().map(_mapCommissionToRow).toList();
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No commissions found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Showing ${rows.length} of ${_commissionsTotal > 0 ? _commissionsTotal : _commissions.length} commissions',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...rows.map(_buildCommissionCard),
      ],
    );
  }

  Widget _buildAdvanceFilters() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _advanceEmployeeController,
            onChanged: (value) =>
                setState(() => _advanceEmployeeFilter = value.trim()),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Filter by employee...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildFilterTile(
          _advanceFromDate == null
              ? 'From date'
              : _formatDate(_advanceFromDate),
          onTap: _pickAdvanceFromDate,
        ),
        const SizedBox(height: 10),
        _buildFilterTile(
          _advanceToDate == null ? 'To date' : _formatDate(_advanceToDate),
          onTap: _pickAdvanceToDate,
        ),
        if (_advanceEmployeeFilter.isNotEmpty ||
            _advanceFromDate != null ||
            _advanceToDate != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _advanceEmployeeController.clear();
                  _advanceEmployeeFilter = '';
                  _advanceFromDate = null;
                  _advanceToDate = null;
                });
              },
              child: const Text('Clear Filters'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancesSection() {
    if (_isLoadingAdvances) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_advancesError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _advancesError!,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadAdvances,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final rows = _filteredAdvances().map(_mapAdvanceToRow).toList();
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No advances found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Showing ${rows.length} of ${_advancesTotal > 0 ? _advancesTotal : _advances.length} advances',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...rows.map(_buildAdvanceCard),
      ],
    );
  }

  Widget _buildAdvanceCard(_AdvanceRow row) {
    final isBusy = _advanceBusyIds.contains(row.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final details = [
            _metaSection(
              label: 'Date',
              value: row.date,
              icon: Icons.calendar_month_outlined,
            ),
            _metaSection(
              label: 'Amount',
              value: row.amount,
              valueColor: const Color(0xFF1D4ED8),
            ),
            _metaSection(
              label: 'Reference',
              value: row.reference,
              icon: Icons.receipt_long_outlined,
            ),
            _metaSection(
              label: 'Notes',
              value: row.notes,
              icon: Icons.notes_outlined,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE4EEF8),
                    child: Text(
                      row.initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employee,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          row.role,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: const Color(0xFFDC2626),
                    onPressed: isBusy ? null : () => _deleteAdvance(row.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isCompact) ...[
                ...details.map(
                  (meta) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: meta,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: details[0]),
                    const SizedBox(width: 10),
                    Expanded(child: details[1]),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: details[2]),
                    const SizedBox(width: 10),
                    Expanded(child: details[3]),
                  ],
                ),
              ],
              if (row.proofUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showProofDialog(row.proofUrl),
                    icon: const Icon(Icons.link, size: 14),
                    label: const Text('View Proof'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommissionCard(_CommissionRow row) {
    final isBusy = _commissionBusyIds.contains(row.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final amountColor =
              row.isPaid ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8);
          final details = [
            _metaSection(
              label: 'Lead / Project',
              value: row.projectLeadLabel,
              icon: Icons.apartment_outlined,
            ),
            _metaSection(
              label: 'Amount',
              value: row.amount,
              valueColor: amountColor,
            ),
            _metaSection(
              label: 'Commission %',
              value: row.percentage,
              icon: Icons.percent,
            ),
            _metaSection(
              label: 'Date',
              value: row.date,
              icon: Icons.calendar_month_outlined,
            ),
          ];

          final actionButtons = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionIcon(
                icon: row.isPaid
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: row.isPaid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFE18300),
                onPressed: isBusy || row.isPaid
                    ? null
                    : () => _markCommissionPaid(row.id),
              ),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: const Color(0xFFDC2626),
                onPressed: isBusy ? null : () => _deleteCommission(row.id),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE4EEF8),
                    child: Text(
                      row.initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employee,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          row.role,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(row.isPaid ? 'Paid' : 'Unpaid', row.isPaid),
                ],
              ),
              const SizedBox(height: 12),
              if (isCompact) ...[
                ...details.map(
                  (meta) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: meta,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: details[0]),
                    const SizedBox(width: 10),
                    Expanded(child: details[1]),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: details[2]),
                    const SizedBox(width: 10),
                    Expanded(child: details[3]),
                  ],
                ),
              ],
              if (row.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    row.notes,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : actionButtons,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmployeeCard(_EmployeeSalaryRow row) {
    final salaryColor =
        row.isNotSet ? const Color(0xFFF59E0B) : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final details = [
            _metaSection(
              label: 'Monthly Salary',
              value: row.salary,
              valueColor: salaryColor,
              leadingDot: !row.isNotSet,
            ),
            _metaSection(
              label: 'Effective From',
              value: row.effectiveFrom,
              icon: Icons.calendar_month_outlined,
            ),
            _metaSection(
              label: 'Set By',
              value: row.setBy,
              icon: Icons.badge_outlined,
            ),
          ];

          final actionButtons = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionIcon(
                icon: Icons.visibility_outlined,
                onPressed: () => _openSalaryDetail(row),
              ),
              _ActionIcon(
                icon: row.isNotSet
                    ? Icons.currency_rupee
                    : Icons.trending_up_rounded,
                color: row.isNotSet
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFF59E0B),
                onPressed: row.isNotSet
                    ? () => _showSetSalaryDialog(row)
                    : () => _showAppraisalDialog(row),
              ),
              _ActionIcon(
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF16A34A),
                onPressed: () => _showGenerateSlipDialog(row),
              ),
              _ActionIcon(
                icon: Icons.history_outlined,
                onPressed: () => _showSalaryHistoryDialog(row),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.email,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _roleChip(row.role),
                  ],
                ),
                const SizedBox(height: 12),
                ...details.map(
                  (meta) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: meta,
                  ),
                ),
                Align(alignment: Alignment.centerLeft, child: actionButtons),
              ],
            );
          }

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.email,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roleChip(row.role),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: details[0]),
                  const SizedBox(width: 10),
                  Expanded(child: details[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: details[2]),
                  const SizedBox(width: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionButtons,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSalarySlipCard(_SalarySlipRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final infoBlocks = [
            _metaSection(label: 'Monthly Salary', value: row.monthlySalary),
            _metaSection(label: 'Days', value: row.days),
            _metaSection(
              label: 'Earned',
              value: row.earned,
              valueColor: const Color(0xFF1D4ED8),
            ),
            _metaSection(
              label: 'Deductions',
              value: row.deductions,
              valueColor: const Color(0xFFDC2626),
            ),
            _metaSection(
              label: 'Final',
              value: row.finalAmount,
              valueColor: const Color(0xFF16A34A),
            ),
            _metaSection(label: 'Generated By', value: row.generatedBy),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.employee,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            row.role,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _roleChip(row.month),
                  ],
                ),
                const SizedBox(height: 10),
                ...infoBlocks.map(
                  (block) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: block,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employee,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          row.role,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _roleChip(row.month),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: infoBlocks[0]),
                  const SizedBox(width: 10),
                  Expanded(child: infoBlocks[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: infoBlocks[2]),
                  const SizedBox(width: 10),
                  Expanded(child: infoBlocks[3]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: infoBlocks[4]),
                  const SizedBox(width: 10),
                  Expanded(child: infoBlocks[5]),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metaSection({
    required String label,
    required String value,
    Color valueColor = AppColors.textPrimary,
    bool leadingDot = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (leadingDot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0A7CFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EAF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFFC2185B),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFilterTile(String value, {VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }

  _EmployeeSalaryRow _mapEmployeeToRow(SalaryEmployee employee) {
    return _EmployeeSalaryRow(
      userId: employee.id,
      name: employee.fullName.isEmpty ? 'Unknown' : employee.fullName,
      email: employee.email.isEmpty ? '-' : employee.email,
      role: _toTitleCase(employee.role),
      salary: employee.monthlySalary == null
          ? 'Not set'
          : _formatCurrency(employee.monthlySalary!),
      monthlySalaryAmount: employee.monthlySalary,
      perDaySalaryAmount: employee.perDaySalary,
      effectiveFrom: _formatDate(employee.effectiveFrom),
      setBy: employee.setByName.trim().isEmpty ? '-' : employee.setByName,
      isNotSet: !employee.salarySet || employee.monthlySalary == null,
    );
  }

  String _formatCurrency(double value) {
    return 'Rs. ${NumberFormat('#,##,##0.00').format(value)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _toTitleCase(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized.isEmpty) return '-';
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _pickMonth() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              return ListTile(
                title: Text(DateFormat('MMMM').format(DateTime(2000, month))),
                trailing: month == _selectedMonth
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(month),
              );
            },
          ),
        );
      },
    );

    if (selected == null || selected == _selectedMonth) return;
    setState(() => _selectedMonth = selected);
    await _loadSalarySlips(page: 1);
  }

  Future<void> _pickYear() async {
    final current = DateTime.now().year;
    final years = List<int>.generate(8, (index) => current - index);
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: years
                .map(
                  (year) => ListTile(
                    title: Text(year.toString()),
                    trailing: year == _selectedYear
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(year),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected == null || selected == _selectedYear) return;
    setState(() => _selectedYear = selected);
    await _loadSalarySlips(page: 1);
  }

  Future<void> _pickCommissionFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _commissionFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _commissionFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_commissionToDate != null &&
          _commissionToDate!.isBefore(_commissionFromDate!)) {
        _commissionToDate = _commissionFromDate;
      }
    });
  }

  Future<void> _pickCommissionToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _commissionToDate ?? _commissionFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _commissionToDate =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      if (_commissionFromDate != null &&
          _commissionToDate!.isBefore(_commissionFromDate!)) {
        _commissionFromDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      }
    });
  }

  Future<void> _pickAdvanceFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _advanceFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _advanceFromDate = DateTime(picked.year, picked.month, picked.day);
      if (_advanceToDate != null &&
          _advanceToDate!.isBefore(_advanceFromDate!)) {
        _advanceToDate = _advanceFromDate;
      }
    });
  }

  Future<void> _pickAdvanceToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _advanceToDate ?? _advanceFromDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _advanceToDate =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      if (_advanceFromDate != null &&
          _advanceToDate!.isBefore(_advanceFromDate!)) {
        _advanceFromDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  _CommissionRow _mapCommissionToRow(SalaryCommission commission) {
    final primaryProject = commission.projectName.trim();
    final leadName = commission.leadName.trim();
    final projectLeadLabel = primaryProject.isNotEmpty
        ? (leadName.isNotEmpty ? '$primaryProject\n$leadName' : primaryProject)
        : (leadName.isNotEmpty ? leadName : '-');
    final name = commission.employeeName.trim().isEmpty
        ? 'Unknown'
        : commission.employeeName.trim();
    final initials = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();
    return _CommissionRow(
      id: commission.id,
      employee: name,
      role: _toTitleCase(commission.employeeRole),
      initials: initials.isEmpty ? 'NA' : initials,
      projectLeadLabel: projectLeadLabel,
      amount: _formatCurrency(commission.commissionAmount),
      percentage: commission.commissionPercentage == null
          ? '-'
          : '${commission.commissionPercentage!.toStringAsFixed(1)}%',
      date: _formatDate(_commissionDateOf(commission)),
      notes: commission.notes?.trim() ?? '',
      isPaid: commission.isPaid,
    );
  }

  _AdvanceRow _mapAdvanceToRow(SalaryAdvance advance) {
    final name = advance.employeeName.trim().isEmpty
        ? 'Unknown'
        : advance.employeeName.trim();
    final initials = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();
    return _AdvanceRow(
      id: advance.id,
      employee: name,
      role: _toTitleCase(advance.employeeRole),
      initials: initials.isEmpty ? 'NA' : initials,
      date: _formatDate(_advanceDateOf(advance)),
      amount: _formatCurrency(advance.amount),
      reference: (advance.transactionReference ?? '').trim().isEmpty
          ? '---'
          : advance.transactionReference!.trim(),
      notes:
          (advance.notes ?? '').trim().isEmpty ? '---' : advance.notes!.trim(),
      proofUrl: (advance.paymentProofUrl ?? '').trim(),
    );
  }

  Widget _statusChip(String label, bool isPaid) {
    final background =
        isPaid ? const Color(0xFFDDF6E8) : const Color(0xFFFFF1D6);
    final textColor =
        isPaid ? const Color(0xFF16A34A) : const Color(0xFFE18300);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  _SalarySlipRow _mapSalarySlipToRow(SalarySlip slip) {
    return _SalarySlipRow(
      employee: slip.employeeName.isEmpty ? '-' : slip.employeeName,
      role: _toTitleCase(slip.employeeRole),
      month:
          '${DateFormat('MMM').format(DateTime(slip.year, slip.month))} ${slip.year}',
      monthlySalary: _formatCurrency(slip.monthlySalary),
      days: '${slip.presentDays}/${slip.workingDays}',
      earned: _formatCurrency(slip.earnedSalary),
      deductions: _formatCurrency(slip.deductions),
      finalAmount: _formatCurrency(slip.finalSalary),
      generatedBy: slip.generatedByName.isEmpty ? '-' : slip.generatedByName,
    );
  }

  Future<void> _openSalaryDetail(_EmployeeSalaryRow row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalaryDetailPage(
          userId: row.userId,
          name: row.name,
          role: row.role,
          email: row.email,
          monthlySalary: row.monthlySalaryAmount ?? 0,
          perDaySalary: row.perDaySalaryAmount ?? 0,
          effectiveFrom: _parseDisplayDate(row.effectiveFrom),
          setBy: row.setBy,
        ),
      ),
    );
  }

  DateTime? _parseDisplayDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == '-') return null;
    try {
      return DateFormat('dd MMM yyyy').parseStrict(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAddCommissionDialog() async {
    _SelectionOption? selectedEmployee;
    _SelectionOption? selectedLead;
    _SelectionOption? selectedProject;
    final amountController = TextEditingController();
    final percentageController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        bool isSaving = false;

        Widget selectorField({
          required String label,
          required String placeholder,
          required _SelectionOption? value,
          required Future<void> Function() onTap,
          bool requiredField = false,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requiredField ? '$label *' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value?.title ?? placeholder,
                              style: TextStyle(
                                color: value == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                fontWeight: value == null
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            if (value != null && value.subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  value.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.search, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        Widget textField({
          required String label,
          required TextEditingController controller,
          required String hint,
          TextInputType? keyboardType,
          int maxLines = 1,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickEmployee() async {
              final option = await _showSearchPicker(
                title: 'Select Employee',
                hintText: 'Type to search employees...',
                initialOptions: _employees
                    .map(
                      (employee) => _SelectionOption(
                        id: employee.id,
                        title: employee.fullName.isEmpty
                            ? 'Unknown Employee'
                            : employee.fullName,
                        subtitle: [
                          employee.email,
                          _toTitleCase(employee.role),
                        ].where((item) => item.trim().isNotEmpty).join(' - '),
                        raw: employee.rawData,
                      ),
                    )
                    .toList(),
              );
              if (option == null) return;
              setModalState(() => selectedEmployee = option);
            }

            Future<void> pickLead() async {
              final option = await _showSearchPicker(
                title: 'Select Lead',
                hintText: 'Type to search leads...',
                loader: _searchLeadOptions,
              );
              if (option == null) return;
              setModalState(() {
                selectedLead = option;
                final autoProjectId = _readStringValue(
                  option.raw['project_id'] ??
                      option.raw['projectId'] ??
                      option.raw['project_uuid'],
                );
                final nestedProject = option.raw['project'];
                final autoProjectName = _readStringValue(
                  option.raw['project_name'] ??
                      (nestedProject is Map ? nestedProject['name'] : null) ??
                      option.raw['project'],
                );
                if (selectedProject == null &&
                    (autoProjectId.isNotEmpty || autoProjectName.isNotEmpty)) {
                  selectedProject = _SelectionOption(
                    id: autoProjectId.isNotEmpty
                        ? autoProjectId
                        : autoProjectName,
                    title: autoProjectName.isNotEmpty
                        ? autoProjectName
                        : 'Selected Project',
                    subtitle: '',
                    raw: <String, dynamic>{
                      'id': autoProjectId,
                      'name': autoProjectName,
                    },
                  );
                }
              });
            }

            Future<void> pickProject() async {
              final option = await _showSearchPicker(
                title: 'Select Project',
                hintText: 'Type to search projects...',
                loader: _searchProjectOptions,
              );
              if (option == null) return;
              setModalState(() => selectedProject = option);
            }

            Future<void> submit() async {
              final employeeId = selectedEmployee?.id.trim() ?? '';
              final amount = double.tryParse(
                  amountController.text.trim().replaceAll(',', ''));
              final percentageText = percentageController.text.trim();
              final percentage = percentageText.isEmpty
                  ? null
                  : double.tryParse(percentageText.replaceAll(',', ''));
              if (employeeId.isEmpty) {
                _showMessage('Employee is required.', isError: true);
                return;
              }
              if (amount == null || amount <= 0) {
                _showMessage('Enter a valid commission amount.', isError: true);
                return;
              }
              setModalState(() => isSaving = true);
              try {
                final result = await _authProvider.salaryAddCommission(
                  userId: employeeId,
                  leadId: selectedLead?.id,
                  projectId: selectedProject?.id,
                  projectName: selectedProject?.title,
                  commissionAmount: amount,
                  commissionPercentage: percentage,
                  notes: notesController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                _showMessage(result.message);
                await _loadCommissions();
              } catch (error) {
                if (!mounted) return;
                setModalState(() => isSaving = false);
                _showMessage(
                  AppErrorHandler.friendlyMessage(error),
                  isError: true,
                );
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(22, 18, 10, 12),
              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Commission',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      selectorField(
                        label: 'Team',
                        placeholder: 'Type to search employees...',
                        value: selectedEmployee,
                        onTap: pickEmployee,
                        requiredField: true,
                      ),
                      const SizedBox(height: 14),
                      selectorField(
                        label: 'Lead',
                        placeholder: 'Type to search leads (optional)...',
                        value: selectedLead,
                        onTap: pickLead,
                      ),
                      const SizedBox(height: 14),
                      selectorField(
                        label: 'Project',
                        placeholder: 'Type to search projects (optional)...',
                        value: selectedProject,
                        onTap: pickProject,
                      ),
                      const SizedBox(height: 14),
                      textField(
                        label: 'Commission Amount (Rs.) *',
                        controller: amountController,
                        hint: '25000',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      textField(
                        label: 'Commission Percentage (optional)',
                        controller: percentageController,
                        hint: '2.5',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      textField(
                        label: 'Notes (optional)',
                        controller: notesController,
                        hint: 'Referral commission for closed deal',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : submit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(isSaving ? 'Saving...' : 'Add Commission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAdvanceDialog() async {
    _SelectionOption? selectedEmployee;
    DateTime selectedDate = DateTime.now();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    PlatformFile? selectedProof;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickEmployee() async {
              final option = await _showSearchPicker(
                title: 'Select Employee',
                hintText: 'Type to search employees...',
                initialOptions: _employees
                    .map(
                      (employee) => _SelectionOption(
                        id: employee.id,
                        title: employee.fullName.isEmpty
                            ? 'Unknown Employee'
                            : employee.fullName,
                        subtitle: [
                          employee.email,
                          _toTitleCase(employee.role),
                        ].where((item) => item.trim().isNotEmpty).join(' - '),
                        raw: employee.rawData,
                      ),
                    )
                    .toList(),
              );
              if (option == null) return;
              setModalState(() => selectedEmployee = option);
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setModalState(() => selectedDate = picked);
            }

            Future<void> pickProof() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: true,
                type: FileType.custom,
                allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
              );
              if (result == null || result.files.isEmpty) return;
              setModalState(() => selectedProof = result.files.single);
            }

            Future<void> submit() async {
              final employeeId = selectedEmployee?.id.trim() ?? '';
              final amount = double.tryParse(
                  amountController.text.trim().replaceAll(',', ''));
              if (employeeId.isEmpty) {
                _showMessage('Employee is required.', isError: true);
                return;
              }
              if (amount == null || amount <= 0) {
                _showMessage('Enter a valid amount.', isError: true);
                return;
              }
              final proof = selectedProof;
              final hasProofBytes =
                  proof?.bytes != null && proof!.bytes!.isNotEmpty;
              final hasProofPath = !kIsWeb &&
                  proof?.path != null &&
                  proof!.path!.trim().isNotEmpty;
              if (proof == null || (!hasProofBytes && !hasProofPath)) {
                _showMessage('Payment proof is required.', isError: true);
                return;
              }

              setModalState(() => isSaving = true);
              try {
                final proofUrl = await _authProvider.uploadPaymentProofFile(
                  filePath: hasProofPath ? proof.path! : '',
                  fileBytes: hasProofBytes ? proof.bytes : null,
                  fileName: proof.name,
                  token: _authProvider.currentAuthToken,
                );
                final result = await _authProvider.salaryAddAdvance(
                  userId: employeeId,
                  advanceDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                  amount: amount,
                  transactionReference: referenceController.text.trim(),
                  paymentProofUrl: proofUrl,
                  notes: notesController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                _showMessage(result.message);
                await _loadAdvances();
              } catch (error) {
                if (!mounted) return;
                setModalState(() => isSaving = false);
                _showMessage(
                  AppErrorHandler.friendlyMessage(error),
                  isError: true,
                );
              }
            }

            InputDecoration inputDecoration(String hint, {IconData? icon}) {
              return InputDecoration(
                hintText: hint,
                prefixIcon: icon == null
                    ? null
                    : Icon(icon, color: AppColors.textSecondary),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              );
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(22, 18, 10, 12),
              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Advance',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: pickEmployee,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedEmployee?.title ??
                                      'Type to search employees...',
                                  style: TextStyle(
                                    color: selectedEmployee == null
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    fontWeight: selectedEmployee == null
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.search,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Advance Date *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: IgnorePointer(
                          child: TextField(
                            controller: TextEditingController(
                              text: DateFormat('dd MMM yyyy')
                                  .format(selectedDate),
                            ),
                            decoration: inputDecoration(
                              'Advance Date',
                              icon: Icons.calendar_today_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Amount (Rs.) *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: inputDecoration('10000',
                            icon: Icons.currency_rupee),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Transaction Reference (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: referenceController,
                        decoration: inputDecoration(
                          'TXN123456789',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Payment Proof *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            OutlinedButton(
                              onPressed: isSaving ? null : pickProof,
                              child: const Text('Choose File'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedProof?.name ?? 'No file chosen',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: inputDecoration('e.g. Emergency advance'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : submit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_card_outlined, size: 18),
                  label: Text(isSaving ? 'Saving...' : 'Add Advance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAdvance(String advanceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Advance'),
        content: const Text(
          'This advance record will be removed. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _advanceBusyIds.add(advanceId));
    try {
      final message = await _authProvider.salaryDeleteAdvance(
        advanceId: advanceId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showMessage(message);
      await _loadAdvances();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppErrorHandler.friendlyMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _advanceBusyIds.remove(advanceId));
      }
    }
  }

  Future<void> _markCommissionPaid(String commissionId) async {
    setState(() => _commissionBusyIds.add(commissionId));
    try {
      final result = await _authProvider.salaryMarkCommissionPaid(
        commissionId: commissionId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showMessage(result.message);
      await _loadCommissions();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppErrorHandler.friendlyMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _commissionBusyIds.remove(commissionId));
      }
    }
  }

  Future<void> _deleteCommission(String commissionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission'),
        content: const Text(
          'This commission record will be removed. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _commissionBusyIds.add(commissionId));
    try {
      final message = await _authProvider.salaryDeleteCommission(
        commissionId: commissionId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showMessage(message);
      await _loadCommissions();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppErrorHandler.friendlyMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _commissionBusyIds.remove(commissionId));
      }
    }
  }

  Future<_SelectionOption?> _showSearchPicker({
    required String title,
    required String hintText,
    List<_SelectionOption> initialOptions = const <_SelectionOption>[],
    Future<List<_SelectionOption>> Function(String query)? loader,
  }) async {
    final queryController = TextEditingController();
    List<_SelectionOption> visibleOptions = initialOptions;
    bool isLoading = loader != null;
    String? error;
    bool hasRequested = false;

    return showModalBottomSheet<_SelectionOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> loadOptions([String query = '']) async {
              if (loader == null) {
                final normalized = query.trim().toLowerCase();
                final filtered = initialOptions.where((option) {
                  if (normalized.isEmpty) return true;
                  final haystack =
                      '${option.title} ${option.subtitle}'.toLowerCase();
                  return haystack.contains(normalized);
                }).toList();
                setModalState(() {
                  visibleOptions = filtered;
                  isLoading = false;
                  error = null;
                });
                return;
              }

              setModalState(() {
                isLoading = true;
                error = null;
              });
              try {
                final loaded = await loader(query);
                if (!context.mounted) return;
                setModalState(() {
                  visibleOptions = loaded;
                  isLoading = false;
                });
              } catch (e) {
                if (!context.mounted) return;
                setModalState(() {
                  isLoading = false;
                  error = AppErrorHandler.friendlyMessage(e);
                });
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!hasRequested) {
                hasRequested = true;
                loadOptions();
              }
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 18,
                        right: 18,
                        top: 14,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: queryController,
                            onChanged: loadOptions,
                            decoration: InputDecoration(
                              hintText: hintText,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : error != null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            error!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () => loadOptions(
                                              queryController.text,
                                            ),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      )
                                    : visibleOptions.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No results found.',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            controller: scrollController,
                                            itemCount: visibleOptions.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final option =
                                                  visibleOptions[index];
                                              return ListTile(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                title: Text(
                                                  option.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                subtitle:
                                                    option.subtitle.isEmpty
                                                        ? null
                                                        : Text(option.subtitle),
                                                onTap: () =>
                                                    Navigator.of(context).pop(
                                                  option,
                                                ),
                                              );
                                            },
                                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<_SelectionOption>> _searchLeadOptions(String query) async {
    final result = await _authProvider.leads(
      token: _authProvider.currentAuthToken,
      search: query.trim().isEmpty ? null : query.trim(),
      page: 1,
      perPage: 20,
    );
    return result.items.map((item) {
      final name = _readStringValue(
        item['full_name'] ?? item['name'] ?? item['lead_name'],
      );
      final nestedProject = item['project'];
      final project = _readStringValue(
        item['project_name'] ??
            (nestedProject is Map ? nestedProject['name'] : null) ??
            item['project'],
      );
      final phone = _readStringValue(
        item['phone_number'] ?? item['phone'] ?? item['mobile'],
      );
      return _SelectionOption(
        id: _readStringValue(item['id'] ?? item['lead_id'] ?? item['leadId']),
        title: name.isEmpty ? 'Unnamed Lead' : name,
        subtitle: [project, phone]
            .where((value) => value.trim().isNotEmpty)
            .join(' - '),
        raw: item,
      );
    }).toList();
  }

  Future<List<_SelectionOption>> _searchProjectOptions(String query) async {
    final result = await _authProvider.projects(
      token: _authProvider.currentAuthToken,
      search: query.trim().isEmpty ? null : query.trim(),
      page: 1,
      perPage: 20,
    );
    return result.items.map((item) {
      final name = _readStringValue(
        item['name'] ?? item['project_name'] ?? item['title'],
      );
      final city = _readStringValue(item['city']);
      final locality = _readStringValue(item['locality']);
      return _SelectionOption(
        id: _readStringValue(
          item['id'] ?? item['project_id'] ?? item['projectId'] ?? item['uuid'],
        ),
        title: name.isEmpty ? 'Unnamed Project' : name,
        subtitle: [city, locality]
            .where((value) => value.trim().isNotEmpty)
            .join(' - '),
        raw: item,
      );
    }).toList();
  }

  String _resolvePaymentProofUrl(String? rawUrl) {
    final trimmed = (rawUrl ?? '').trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://api.nextonerealty.in$trimmed';
    }
    return 'https://api.nextonerealty.in/$trimmed';
  }

  Future<void> _showProofDialog(String rawUrl) async {
    final resolvedUrl = _resolvePaymentProofUrl(rawUrl);
    if (resolvedUrl.isEmpty) {
      _showMessage('Invalid proof URL.', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.sizeOf(context);
        final dialogWidth =
            (screenSize.width - 32).clamp(320.0, 720.0).toDouble();
        final dialogHeight =
            (screenSize.height - 48).clamp(320.0, 760.0).toDouble();

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Payment Proof',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox.expand(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            resolvedUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Preview unavailable.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        resolvedUrl,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        ElevatedButton(
                          onPressed: () => _openExternalUrl(resolvedUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Open Externally'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final resolvedUrl = _resolvePaymentProofUrl(rawUrl);
    if (resolvedUrl.isEmpty) return;
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      _showMessage('Invalid proof URL.', isError: true);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Unable to open proof URL.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _showGenerateAllSalarySlipsDialog() async {
    int selectedMonth = _selectedMonth;
    int selectedYear = _selectedYear;
    int? workingDaysOverride;
    final overrideController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isGeneratingAllSlips,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Generate All Salary Slips',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate salary slips for all employees who have a salary set. Existing slips for the chosen month will be overwritten.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInlineDropdown<int>(
                            label: 'Month *',
                            value: selectedMonth,
                            items: List<int>.generate(12, (i) => i + 1),
                            itemLabel: (m) =>
                                DateFormat('MMMM').format(DateTime(2000, m)),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => selectedMonth = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInlineDropdown<int>(
                            label: 'Year *',
                            value: selectedYear,
                            items: List<int>.generate(
                              8,
                              (index) => DateTime.now().year - index,
                            ),
                            itemLabel: (year) => year.toString(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => selectedYear = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Working Days Override (optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: overrideController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Auto',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        workingDaysOverride = parsed;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _isGeneratingAllSlips
                      ? null
                      : () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Generate All'),
                ),
              ],
            );
          },
        );
      },
    );

    overrideController.dispose();

    if (confirmed != true || !mounted) return;

    setState(() => _isGeneratingAllSlips = true);
    try {
      final result = await _authProvider.salaryGenerateAll(
        month: selectedMonth,
        year: selectedYear,
        workingDaysOverride: workingDaysOverride,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;

      setState(() {
        _selectedMonth = selectedMonth;
        _selectedYear = selectedYear;
      });
      await _loadSalarySlips(page: 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${result.message} (Processed: ${result.totalProcessed}, Failed: ${result.totalFailed})',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.friendlyMessage(error)),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAllSlips = false);
      }
    }
  }

  Widget _buildInlineDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSetSalaryDialog(_EmployeeSalaryRow row) async {
    final workingDaysController = TextEditingController(text: '26');
    final monthlyController = TextEditingController(
      text: (row.monthlySalaryAmount ?? 0).toStringAsFixed(0),
    );
    final perDayController = TextEditingController(
      text: (row.perDaySalaryAmount ?? 0).toStringAsFixed(2),
    );
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool perDayEdited = false;
    bool isSaving = false;

    void recalcPerDay() {
      if (perDayEdited) return;
      final monthly = double.tryParse(monthlyController.text.trim()) ?? 0;
      final days = int.tryParse(workingDaysController.text.trim()) ?? 0;
      if (days > 0 && monthly > 0) {
        perDayController.text = (monthly / days).toStringAsFixed(2);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set Salary - ${row.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF3FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              row.name.isNotEmpty
                                  ? row.name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  row.role.toLowerCase(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Working Days / Month (used for monthly â†” per day conversion)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: workingDaysController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        setModalState(recalcPerDay);
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Monthly Salary (â‚¹)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: monthlyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        setModalState(recalcPerDay);
                      },
                      decoration: const InputDecoration(
                        prefixText: 'â‚¹  ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Per Day Salary (â‚¹) - auto-calculated or enter directly',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: perDayController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => perDayEdited = true,
                      decoration: const InputDecoration(
                        prefixText: 'â‚¹  ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _previewRow(
                            'Monthly',
                            _formatCurrency(
                              double.tryParse(monthlyController.text.trim()) ??
                                  0,
                            ),
                          ),
                          _previewRow(
                            'Per Day',
                            _formatCurrency(
                              double.tryParse(perDayController.text.trim()) ??
                                  0,
                            ),
                            color: const Color(0xFF059669),
                          ),
                          _previewRow(
                            'Working days / month',
                            '${int.tryParse(workingDaysController.text.trim()) ?? 0} days',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Effective From',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setModalState(() => selectedDate = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('dd-MM-yyyy').format(selectedDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Notes (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Revised after appraisal',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final monthly =
                              double.tryParse(monthlyController.text.trim()) ??
                                  0;
                          final perDay =
                              double.tryParse(perDayController.text.trim()) ??
                                  0;
                          final days =
                              int.tryParse(workingDaysController.text.trim()) ??
                                  0;
                          if (monthly <= 0 || perDay <= 0 || days <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter valid working days, monthly salary, and per day salary.',
                                ),
                              ),
                            );
                            return;
                          }
                          setModalState(() => isSaving = true);
                          try {
                            final result = await _authProvider.salarySet(
                              userId: row.userId,
                              monthlySalary: monthly,
                              perDaySalary: perDay,
                              workingDaysInMonth: days,
                              effectiveFrom:
                                  DateFormat('yyyy-MM-dd').format(selectedDate),
                              notes: notesController.text.trim(),
                              token: _authProvider.currentAuthToken,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _loadEmployees(page: _employeesCurrentPage);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                          } catch (error) {
                            if (!mounted) return;
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppErrorHandler.friendlyMessage(error),
                                  ),
                                ),
                              );
                          }
                        },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(isSaving ? 'Saving...' : 'Save Salary'),
                ),
              ],
            );
          },
        );
      },
    );

    workingDaysController.dispose();
    monthlyController.dispose();
    perDayController.dispose();
    notesController.dispose();
  }

  Future<void> _showAppraisalDialog(_EmployeeSalaryRow row) async {
    final currentSalary = row.monthlySalaryAmount ?? 0;
    final monthlyController = TextEditingController(
      text: currentSalary.toStringAsFixed(0),
    );
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    double difference() {
      final monthly = double.tryParse(monthlyController.text.trim()) ?? 0;
      return monthly - currentSalary;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final salaryDifference = difference();
            final initials = row.name
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part[0].toUpperCase())
                .join();

            Widget fieldLabel(String text) {
              return Text(
                text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              );
            }

            InputDecoration fieldDecoration({
              String? hintText,
              String? prefixText,
            }) {
              return InputDecoration(
                hintText: hintText,
                prefixText: prefixText,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                isDense: true,
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 20, 24, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Appraisal - ${row.name}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(30, 24, 30, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    backgroundColor: const Color(0xFF1684F8),
                                    child: Text(
                                      initials.isEmpty ? 'U' : initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Current: ${_formatCurrency(currentSalary)}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            fieldLabel('New Monthly Salary (Rs.)'),
                            const SizedBox(height: 7),
                            TextField(
                              controller: monthlyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setModalState(() {}),
                              decoration: fieldDecoration(prefixText: 'Rs.  '),
                            ),
                            const SizedBox(height: 16),
                            fieldLabel('Effective From'),
                            const SizedBox(height: 7),
                            InkWell(
                              onTap: isSaving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked == null) return;
                                      setModalState(() {
                                        selectedDate = picked;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: fieldDecoration(),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd-MM-yyyy')
                                            .format(selectedDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            fieldLabel('Notes (Optional)'),
                            const SizedBox(height: 7),
                            TextField(
                              controller: notesController,
                              decoration: fieldDecoration(
                                hintText: 'Reason for appraisal',
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Difference',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(salaryDifference),
                                    style: TextStyle(
                                      color: salaryDifference > 0
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 0, 30, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final monthly = double.tryParse(
                                          monthlyController.text.trim(),
                                        ) ??
                                        0;
                                    if (monthly <= 0) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Enter a valid monthly salary.',
                                            ),
                                          ),
                                        );
                                      return;
                                    }
                                    setModalState(() => isSaving = true);
                                    try {
                                      final result =
                                          await _authProvider.salaryAppraisal(
                                        userId: row.userId,
                                        newSalary: monthly,
                                        effectiveFrom: DateFormat('yyyy-MM-dd')
                                            .format(selectedDate),
                                        appraisalNote:
                                            notesController.text.trim(),
                                        workingDaysInMonth: 26,
                                        token: _authProvider.currentAuthToken,
                                      );
                                      if (!mounted) return;
                                      Navigator.of(dialogContext).pop();
                                      await _loadEmployees(
                                          page: _employeesCurrentPage);
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(result.message),
                                          ),
                                        );
                                    } catch (error) {
                                      if (!mounted) return;
                                      setModalState(() => isSaving = false);
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppErrorHandler.friendlyMessage(
                                                error,
                                              ),
                                            ),
                                          ),
                                        );
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.trending_up_rounded,
                                    size: 17),
                            label: Text(
                              isSaving ? 'Saving...' : 'Save Appraisal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    monthlyController.dispose();
    notesController.dispose();
  }

  Future<void> _showGenerateSlipDialog(_EmployeeSalaryRow row) async {
    int selectedMonth = _selectedMonth;
    int selectedYear = _selectedYear;
    bool isGenerating = false;

    final deductionsController = TextEditingController(text: '0');
    final workingDaysController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Generate Slip - ${row.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isGenerating ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF7F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              row.name.isNotEmpty
                                  ? row.name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Monthly: ${row.salary}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInlineDropdown<int>(
                            label: 'Month *',
                            value: selectedMonth,
                            items: List<int>.generate(12, (i) => i + 1),
                            itemLabel: (m) =>
                                DateFormat('MMMM').format(DateTime(2000, m)),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => selectedMonth = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInlineDropdown<int>(
                            label: 'Year *',
                            value: selectedYear,
                            items: List<int>.generate(
                              8,
                              (index) => DateTime.now().year - index,
                            ),
                            itemLabel: (year) => year.toString(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => selectedYear = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Deductions (â‚¹)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: deductionsController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        prefixText: 'â‚¹  ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Working Days Override (leave blank for auto)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: workingDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Auto (Mon-Fri count)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isGenerating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () async {
                          final deductions = double.tryParse(
                                  deductionsController.text.trim()) ??
                              0;
                          final workingOverride =
                              int.tryParse(workingDaysController.text.trim());
                          setModalState(() => isGenerating = true);
                          try {
                            final result = await _authProvider.salaryGenerate(
                              userId: row.userId,
                              month: selectedMonth,
                              year: selectedYear,
                              deductions: deductions,
                              workingDaysOverride: workingOverride,
                              notes: notesController.text.trim(),
                              token: _authProvider.currentAuthToken,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            setState(() {
                              _selectedMonth = selectedMonth;
                              _selectedYear = selectedYear;
                            });
                            await _loadSalarySlips(page: 1);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                          } catch (error) {
                            if (!mounted) return;
                            setModalState(() => isGenerating = false);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppErrorHandler.friendlyMessage(error),
                                  ),
                                ),
                              );
                          }
                        },
                  icon: const Icon(Icons.description_outlined, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  label: Text(isGenerating ? 'Generating...' : 'Generate'),
                ),
              ],
            );
          },
        );
      },
    );

    deductionsController.dispose();
    workingDaysController.dispose();
    notesController.dispose();
  }

  Widget _previewRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSalaryHistoryDialog(_EmployeeSalaryRow row) async {
    bool isLoading = true;
    String? error;
    Map<String, dynamic>? employee;
    List<SalaryHistoryEntry> history = const <SalaryHistoryEntry>[];
    bool hasRequested = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> load() async {
              setModalState(() {
                isLoading = true;
                error = null;
              });
              try {
                final result = await _authProvider.salaryHistory(
                  userId: row.userId,
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                setModalState(() {
                  employee = result.employee;
                  history = result.history;
                  isLoading = false;
                });
              } catch (e) {
                setModalState(() {
                  isLoading = false;
                  error = AppErrorHandler.friendlyMessage(e);
                });
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!hasRequested) {
                hasRequested = true;
                load();
              }
            });

            String read(dynamic value) => value?.toString().trim() ?? '';
            final employeeName = read(employee?['full_name']);
            final role = _toTitleCase(read(employee?['role']));

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Salary History',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : error != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                error!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: load,
                                child: const Text('Retry'),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        (employeeName.isNotEmpty
                                                ? employeeName
                                                : row.name)
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            employeeName.isNotEmpty
                                                ? employeeName
                                                : row.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            role.isNotEmpty
                                                ? role.toLowerCase()
                                                : row.role.toLowerCase(),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (history.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'No salary history found.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              else
                                ...history.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  final effective = item.effectiveFrom == null
                                      ? '-'
                                      : DateFormat('dd MMM yyyy').format(
                                          item.effectiveFrom!.toLocal());
                                  final isCurrent = index == 0;
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatCurrency(
                                                    item.monthlySalary),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Effective: $effective',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Set by\n${item.setByName.isNotEmpty ? item.setByName : '-'}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isCurrent)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    top: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDDF6E8),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: const Text(
                                                  'Current',
                                                  style: TextStyle(
                                                    color: Color(0xFF16A34A),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 17,
          color: color ?? AppColors.textSecondary,
        ),
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}

class _SummaryStat {
  const _SummaryStat({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
}

class _EmployeeSalaryRow {
  const _EmployeeSalaryRow({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.salary,
    this.monthlySalaryAmount,
    this.perDaySalaryAmount,
    required this.effectiveFrom,
    required this.setBy,
    this.isNotSet = false,
  });

  final String userId;
  final String name;
  final String email;
  final String role;
  final String salary;
  final double? monthlySalaryAmount;
  final double? perDaySalaryAmount;
  final String effectiveFrom;
  final String setBy;
  final bool isNotSet;
}

class _SalarySlipRow {
  const _SalarySlipRow({
    required this.employee,
    required this.role,
    required this.month,
    required this.monthlySalary,
    required this.days,
    required this.earned,
    required this.deductions,
    required this.finalAmount,
    required this.generatedBy,
  });

  final String employee;
  final String role;
  final String month;
  final String monthlySalary;
  final String days;
  final String earned;
  final String deductions;
  final String finalAmount;
  final String generatedBy;
}

class _CommissionRow {
  const _CommissionRow({
    required this.id,
    required this.employee,
    required this.role,
    required this.initials,
    required this.projectLeadLabel,
    required this.amount,
    required this.percentage,
    required this.date,
    required this.notes,
    required this.isPaid,
  });

  final String id;
  final String employee;
  final String role;
  final String initials;
  final String projectLeadLabel;
  final String amount;
  final String percentage;
  final String date;
  final String notes;
  final bool isPaid;
}

class _AdvanceRow {
  const _AdvanceRow({
    required this.id,
    required this.employee,
    required this.role,
    required this.initials,
    required this.date,
    required this.amount,
    required this.reference,
    required this.notes,
    required this.proofUrl,
  });

  final String id;
  final String employee;
  final String role;
  final String initials;
  final String date;
  final String amount;
  final String reference;
  final String notes;
  final String proofUrl;
}

class _SelectionOption {
  const _SelectionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.raw,
  });

  final String id;
  final String title;
  final String subtitle;
  final Map<String, dynamic> raw;
}

class _AttendanceRow {
  const _AttendanceRow({
    required this.date,
    required this.status,
    required this.timeLabel,
    required this.hoursLabel,
  });

  final DateTime date;
  final String status;
  final String timeLabel;
  final String hoursLabel;
}

class _MyDailyEarningRow {
  const _MyDailyEarningRow({
    required this.date,
    required this.statusLabel,
    required this.timeLabel,
    required this.hoursLabel,
    required this.earned,
  });

  final DateTime date;
  final String statusLabel;
  final String timeLabel;
  final String hoursLabel;
  final double earned;
}

class _MySalaryIncentiveRow {
  const _MySalaryIncentiveRow({
    required this.id,
    required this.amount,
    required this.note,
    required this.date,
  });

  final String id;
  final double amount;
  final String note;
  final DateTime date;
}

class _MyDailyEarningSummary {
  const _MyDailyEarningSummary({
    required this.rows,
    required this.fullDays,
    required this.halfDays,
    required this.presentDays,
    required this.perDaySalary,
    required this.monthlySalary,
    required this.earnedTotal,
  });

  final List<_MyDailyEarningRow> rows;
  final int fullDays;
  final int halfDays;
  final double presentDays;
  final double perDaySalary;
  final double monthlySalary;
  final double earnedTotal;
}

class _AttendanceSalarySummary {
  const _AttendanceSalarySummary({
    required this.monthlySalary,
    required this.presentDays,
    required this.perDaySalary,
    required this.earnedSalary,
  });

  final double monthlySalary;
  final double presentDays;
  final double perDaySalary;
  final double earnedSalary;
}

class _AttendanceMePayload {
  const _AttendanceMePayload({
    required this.rows,
    required this.salarySummary,
  });

  final List<_AttendanceRow> rows;
  final _AttendanceSalarySummary? salarySummary;
}
