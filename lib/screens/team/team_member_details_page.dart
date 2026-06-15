import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

enum _HistoryTab { leads, followUps, siteVisits }

class TeamMemberDetailsPage extends StatefulWidget {
  final Map<String, dynamic> memberData;

  const TeamMemberDetailsPage({super.key, required this.memberData});

  @override
  State<TeamMemberDetailsPage> createState() => _TeamMemberDetailsPageState();
}

class _TeamMemberDetailsPageState extends State<TeamMemberDetailsPage> {
  final AuthProvider _authProvider = AuthProvider();

  late Map<String, dynamic> _memberData;
  String? _memberId;
  bool _isLoading = true;
  String? _loadError;
  bool _isDeleting = false;
  String _currentRole = '';
  String _currentUserId = '';
  _HistoryTab _activeHistoryTab = _HistoryTab.leads;
  bool _isHistoryLoading = false;
  String? _historyError;
  List<Map<String, dynamic>> _historyItems = <Map<String, dynamic>>[];

  DateTime _performanceFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _performanceTo = DateTime.now();
  bool _isPerformanceLoading = false;
  String? _performanceError;
  Map<String, dynamic> _performanceData = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _memberData = Map<String, dynamic>.from(widget.memberData);
    _memberId = _extractMemberId(_memberData);
    _loadAccess();
    _fetchMemberDetails();
  }

  String get _memberRole => RoleAccess.normalize(_asString(_memberData['role']));
  bool get _canManageUsers => RoleAccess.canManageUsers(_currentRole);
  bool get _canDeleteMember => RoleAccess.canDeactivate(_currentRole, _memberRole);

  Future<void> _loadAccess() async {
    try {
      await RoleAccess.currentPermissionSet(_authProvider);
      final profile =
          await _authProvider.profile(token: _authProvider.currentAuthToken);
      final role = RoleAccess.readRole(profile.data);
      final currentUserId = _extractMemberId(profile.data) ?? '';
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        _currentUserId = currentUserId;
      });
      await _loadTeamHistory();
    } catch (_) {
      // Keep member management actions hidden if access cannot be resolved.
    }
  }

  Future<void> _fetchMemberDetails() async {
    final memberId = _memberId;
    if (memberId == null || memberId.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load member details: missing user id.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final details = await _authProvider.usersDetail(
        id: memberId,
        token: _authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _memberData = {..._memberData, ...details};
        _isLoading = false;
      });
      await _loadTeamHistory();
      await _loadPerformance();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadTeamHistory() async {
    final targetUserId = _resolveTeamHistoryUserId();
    if (targetUserId == null || targetUserId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
        _historyItems = <Map<String, dynamic>>[];
        _historyError =
            'You do not have permission to view activity history for this member.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isHistoryLoading = true;
      _historyError = null;
    });

    try {
      late final List<Map<String, dynamic>> items;
      switch (_activeHistoryTab) {
        case _HistoryTab.leads:
          final response = await _authProvider.teamHistoryLeads(
            userId: targetUserId,
            page: 1,
            perPage: 20,
            token: _authProvider.currentAuthToken,
          );
          items = response.items;
          break;
        case _HistoryTab.followUps:
          final response = await _authProvider.teamHistoryFollowUps(
            userId: targetUserId,
            page: 1,
            perPage: 20,
            token: _authProvider.currentAuthToken,
          );
          items = response.items;
          break;
        case _HistoryTab.siteVisits:
          final response = await _authProvider.teamHistorySiteVisits(
            userId: targetUserId,
            page: 1,
            perPage: 20,
            token: _authProvider.currentAuthToken,
          );
          items = response.items;
          break;
      }

      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
        _historyItems = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
        _historyError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadPerformance() async {
    final targetUserId = _resolvePerformanceUserId();
    if (targetUserId == null || targetUserId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isPerformanceLoading = false;
        _performanceData = <String, dynamic>{};
        _performanceError =
            'You do not have permission to view performance for this member.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isPerformanceLoading = true;
      _performanceError = null;
    });

    try {
      final response = await _authProvider.userPerformance(
        id: targetUserId,
        from: DateFormat('yyyy-MM-dd').format(_performanceFrom),
        to: DateFormat('yyyy-MM-dd').format(_performanceTo),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _isPerformanceLoading = false;
        _performanceData = response;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPerformanceLoading = false;
        _performanceError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _pickPerformanceDate({required bool isFrom}) async {
    final initialDate = isFrom ? _performanceFrom : _performanceTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _performanceFrom = DateTime(picked.year, picked.month, picked.day);
        if (_performanceFrom.isAfter(_performanceTo)) {
          _performanceTo = _performanceFrom;
        }
      } else {
        _performanceTo = DateTime(picked.year, picked.month, picked.day);
        if (_performanceTo.isBefore(_performanceFrom)) {
          _performanceFrom = _performanceTo;
        }
      }
    });
    await _loadPerformance();
  }

  Future<void> _deleteMember() async {
    if (!_canDeleteMember) {
      _showSnackBar('You do not have permission to deactivate this user.');
      return;
    }
    final memberId = _memberId;
    if (memberId == null || memberId.isEmpty) {
      _showSnackBar('Unable to delete member: missing user id.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Member'),
          content: const Text('Are you sure you want to delete this member?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _authProvider.deleteUser(
        id: memberId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Member deleted successfully.');
      Navigator.pop(context, 'deleted');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditMember() async {
    if (!_canManageUsers) {
      _showSnackBar('You do not have permission to edit users.');
      return;
    }
    final memberId = _memberId;
    if (memberId == null || memberId.isEmpty) {
      _showSnackBar('Unable to edit member: missing user id.');
      return;
    }

    final updated = await Navigator.push<TeamMemberCreationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTeamMemberPage(
          memberId: memberId,
          memberData: _memberData,
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    Navigator.pop(context, 'updated');
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _asString(
      _memberData['first_name'] ??
          _memberData['firstName'] ??
          _memberData['firstname'],
    );
    final lastName = _asString(
      _memberData['last_name'] ??
          _memberData['lastName'] ??
          _memberData['lastname'],
    );
    final fullName = _buildFullName(firstName, lastName, _memberData);
    final email =
        _fallbackValue(_asString(_memberData['email']), fallback: 'N/A');
    final phoneNumber = _fallbackValue(
      _asString(_memberData['phone_number'] ?? _memberData['phoneNumber']),
      fallback: 'N/A',
    );
    final role = _readableRole(
      _asString(_memberData['role']).isNotEmpty
          ? _asString(_memberData['role'])
          : 'Team Member',
    );
    final isActive =
        _asBool(_memberData['is_active'] ?? _memberData['isActive']);
    final lastLoginStr =
        _asString(_memberData['last_login'] ?? _memberData['lastLogin']);

    DateTime? lastLogin;
    if (lastLoginStr.isNotEmpty) {
      lastLogin = DateTime.tryParse(lastLoginStr);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: 'Member Details',
        showBackButton: true,
        onBackTap: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchMemberDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Column(
                  children: [
                    if (_loadError != null) ...[
                      _buildErrorCard(_loadError!),
                      const SizedBox(height: 16),
                    ],
                    _buildHeader(fullName, role, isActive),
                    const SizedBox(height: 14),
                    _buildPerformanceSection(),
                    const SizedBox(height: 14),
                    _buildInfoSection(
                      title: 'Personal Information',
                      items: [
                        _InfoItem(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          value: email,
                        ),
                        _InfoItem(
                          icon: Icons.phone_android_outlined,
                          label: 'Phone Number',
                          value: phoneNumber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInfoSection(
                      title: 'System Information',
                      items: [
                        _InfoItem(
                          icon: Icons.history_rounded,
                          label: 'Last Login',
                          value: lastLogin != null
                              ? DateFormat('MMM dd, yyyy - hh:mm a')
                                  .format(lastLogin)
                              : 'Never',
                        ),
                        _InfoItem(
                          icon: Icons.security_outlined,
                          label: 'Access Level',
                          value: role,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildActivityHistorySection(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String? _resolvePerformanceUserId() {
    final selectedUserId = _memberId?.trim() ?? '';
    final currentUserId = _currentUserId.trim();

    if (selectedUserId.isEmpty) {
      return null;
    }

    if (RoleAccess.canViewTeam(_currentRole) ||
        RoleAccess.canViewUsers(_currentRole)) {
      return selectedUserId;
    }

    return currentUserId == selectedUserId ? selectedUserId : null;
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _fetchMemberDetails,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String role, bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection() {
    final totalLeads = _readInt(_performanceData['total_leads'] ??
        _performanceData['totalLeads'] ??
        _performanceData['leads_count']);
    final contacted = _readInt(_performanceData['contacted']);
    final interested = _readInt(_performanceData['interested']);
    final siteVisitsScheduled = _readInt(
      _performanceData['site_visits_scheduled'] ??
          _performanceData['site_visit_scheduled'],
    );
    final siteVisitsDone = _readInt(
      _performanceData['site_visits_done'] ?? _performanceData['site_visit_done'],
    );
    final negotiation = _readInt(_performanceData['negotiation']);
    final booked = _readInt(_performanceData['booked']);
    final lost = _readInt(_performanceData['lost']);
    final conversion = _readNum(
      _performanceData['conversion'] ?? _performanceData['conversion_rate'],
    );
    final computedContactRate =
        totalLeads > 0 ? (contacted * 100.0 / totalLeads) : 0.0;
    final computedVisitRate =
        totalLeads > 0 ? (siteVisitsDone * 100.0 / totalLeads) : 0.0;
    final computedBookingRate =
        totalLeads > 0 ? (booked * 100.0 / totalLeads) : 0.0;
    final contactRate = _performanceData.containsKey('contact_rate') ||
            _performanceData.containsKey('contactRate')
        ? _readNum(_performanceData['contact_rate'] ?? _performanceData['contactRate'])
        : computedContactRate;
    final visitRate = _performanceData.containsKey('visit_rate') ||
            _performanceData.containsKey('visitRate')
        ? _readNum(_performanceData['visit_rate'] ?? _performanceData['visitRate'])
        : computedVisitRate;
    final bookingRate = _performanceData.containsKey('booking_rate') ||
            _performanceData.containsKey('bookingRate')
        ? _readNum(_performanceData['booking_rate'] ?? _performanceData['bookingRate'])
        : computedBookingRate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.equalizer_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lead conversion & activity stats',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPerformanceDateFilters(),
          const SizedBox(height: 8),
          if (_isPerformanceLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_performanceError != null)
            _buildPerformanceError(_performanceError!)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetricCard(
                    icon: Icons.group_outlined,
                    iconBg: const Color(0xFFE8F2FF),
                    iconColor: AppColors.primary,
                    value: '$totalLeads',
                    label: 'TOTAL LEADS',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPerformanceMetricCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconBg: const Color(0xFFE5F8EC),
                    iconColor: const Color(0xFF16A34A),
                    value: '$booked',
                    label: 'BOOKED',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetricCard(
                    icon: Icons.adjust_rounded,
                    iconBg: const Color(0xFFF1E9FF),
                    iconColor: const Color(0xFF7C3AED),
                    value: '${conversion.toStringAsFixed(1)}%',
                    label: 'CONVERSION',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPerformanceMetricCard(
                    icon: Icons.cancel_outlined,
                    iconBg: const Color(0xFFFFECEB),
                    iconColor: const Color(0xFFEF4444),
                    value: '$lost',
                    label: 'LOST',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildPipelineCard(
              totalLeads: totalLeads,
              contacted: contacted,
              interested: interested,
              siteVisitsScheduled: siteVisitsScheduled,
              siteVisitsDone: siteVisitsDone,
              negotiation: negotiation,
              booked: booked,
              lost: lost,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildRateCard(
                    value: contactRate,
                    label: 'CONTACT RATE',
                    bg: const Color(0xFFEAF1FF),
                    text: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRateCard(
                    value: visitRate,
                    label: 'VISIT RATE',
                    bg: const Color(0xFFE9F7F3),
                    text: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRateCard(
                    value: bookingRate,
                    label: 'BOOKING RATE',
                    bg: const Color(0xFFEFF8EC),
                    text: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceDateFilters() {
    final formatter = DateFormat('dd-MM-yyyy');
    return Row(
      children: [
        _buildDatePickerChip(
          label: 'From',
          value: formatter.format(_performanceFrom),
          onTap: () => _pickPerformanceDate(isFrom: true),
        ),
        const SizedBox(width: 8),
        _buildDatePickerChip(
          label: 'To',
          value: formatter.format(_performanceTo),
          onTap: () => _pickPerformanceDate(isFrom: false),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _loadPerformance,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.calendar_today_outlined, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: _loadPerformance, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineCard({
    required int totalLeads,
    required int contacted,
    required int interested,
    required int siteVisitsScheduled,
    required int siteVisitsDone,
    required int negotiation,
    required int booked,
    required int lost,
  }) {
    final stages = _pipelineRows(
      totalLeads: totalLeads,
      contacted: contacted,
      interested: interested,
      siteVisitsScheduled: siteVisitsScheduled,
      siteVisitsDone: siteVisitsDone,
      negotiation: negotiation,
      booked: booked,
      lost: lost,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Pipeline Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$totalLeads leads total',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...stages.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${row.count} (${row.percent.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: row.percent / 100,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(row.color),
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

  Widget _buildRateCard({
    required double value,
    required String label,
    required Color bg,
    required Color text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: text.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<_PipelineRow> _pipelineRows({
    required int totalLeads,
    required int contacted,
    required int interested,
    required int siteVisitsScheduled,
    required int siteVisitsDone,
    required int negotiation,
    required int booked,
    required int lost,
  }) {
    final source = _performanceData['pipeline'] ?? _performanceData['stages'];
    final rows = <_PipelineRow>[];
    const defaultStages = <_PipelineSeed>[
      _PipelineSeed('Contacted', 'contacted', Color(0xFF4F46E5)),
      _PipelineSeed('Interested', 'interested', Color(0xFF6366F1)),
      _PipelineSeed(
          'Site Visit Scheduled', 'site_visits_scheduled', Color(0xFF14B8A6)),
      _PipelineSeed('Site Visit Done', 'site_visits_done', Color(0xFF0EA5E9)),
      _PipelineSeed('Negotiation', 'negotiation', Color(0xFFF59E0B)),
      _PipelineSeed('Booked', 'booked', Color(0xFF22C55E)),
      _PipelineSeed('Lost', 'lost', Color(0xFFEF4444)),
    ];

    int countFromMap(Map<String, dynamic> map, String key) {
      final singularKey = key.endsWith('s')
          ? key.replaceFirst(RegExp(r's(?=_[^_]+$|$)'), '')
          : key;
      return _readInt(
        map[key] ??
            map[singularKey] ??
            map[key.replaceAll('_', '')] ??
            map[singularKey.replaceAll('_', '')] ??
            map[_titleCase(key)] ??
            map[_titleCase(singularKey)] ??
            map[key.toUpperCase()],
      );
    }

    if (source is Map<String, dynamic>) {
      for (final seed in defaultStages) {
        final count = countFromMap(source, seed.key);
        final percent = totalLeads > 0 ? (count * 100 / totalLeads) : 0.0;
        rows.add(_PipelineRow(seed.label, count, percent, seed.color));
      }
      if (rows.any((row) => row.count > 0)) {
        return rows;
      }
      rows.clear();
    }

    if (source is List) {
      for (final raw in source.whereType<Map>()) {
        final map = raw.map((key, value) => MapEntry('$key', value));
        final label = _firstNonEmpty(<dynamic>[
          map['label'],
          map['name'],
          map['stage'],
          'Stage',
        ]);
        final count = _readInt(map['count'] ?? map['value']);
        final percent = totalLeads > 0 ? (count * 100 / totalLeads) : 0.0;
        rows.add(_PipelineRow(label, count, percent, const Color(0xFF6366F1)));
      }
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    final fallbackMap = <String, int>{
      'contacted': contacted,
      'interested': interested,
      'site_visits_scheduled': siteVisitsScheduled,
      'site_visits_done': siteVisitsDone,
      'negotiation': negotiation,
      'booked': booked,
      'lost': lost,
    };
    for (final seed in defaultStages) {
      final count = fallbackMap[seed.key] ?? _readInt(_performanceData[seed.key]);
      final percent = totalLeads > 0 ? (count * 100 / totalLeads) : 0.0;
      rows.add(_PipelineRow(seed.label, count, percent, seed.color));
    }
    return rows;
  }

  Widget _buildStatsSection(Map<String, dynamic> memberData) {
    final activeLeads = _readInt(
      memberData['active_leads'] ??
          memberData['activeLeads'] ??
          memberData['leads_count'],
    );
    final conversionRate = _readNum(
      memberData['conversion_rate'] ?? memberData['conversionRate'],
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: 'Total Leads',
            value: activeLeads.toString(),
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            label: 'Conversion',
            value: '${conversionRate.toStringAsFixed(1)}%',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      {required String title, required List<_InfoItem> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
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

  Widget _buildActivityHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity History',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Leads, follow-ups and site visits',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHistoryTabs(),
          const SizedBox(height: 10),
          if (_isHistoryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyError != null)
            _buildHistoryError(_historyError!)
          else if (_historyItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No activity found.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ..._historyItems.map(_buildHistoryItemCard),
        ],
      ),
    );
  }

  Widget _buildHistoryTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildHistoryTabButton(
            tab: _HistoryTab.leads,
            icon: Icons.person_search_outlined,
            label: 'Leads',
          ),
          _buildHistoryTabButton(
            tab: _HistoryTab.followUps,
            icon: Icons.phone_in_talk_outlined,
            label: 'Follow-ups',
          ),
          _buildHistoryTabButton(
            tab: _HistoryTab.siteVisits,
            icon: Icons.event_outlined,
            label: 'Site Visits',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabButton({
    required _HistoryTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeHistoryTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isActive) return;
          setState(() {
            _activeHistoryTab = tab;
          });
          _loadTeamHistory();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: _loadTeamHistory, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHistoryItemCard(Map<String, dynamic> item) {
    switch (_activeHistoryTab) {
      case _HistoryTab.leads:
        return _buildLeadHistoryCard(item);
      case _HistoryTab.followUps:
        return _buildFollowUpHistoryCard(item);
      case _HistoryTab.siteVisits:
        return _buildSiteVisitHistoryCard(item);
    }
  }

  Widget _buildLeadHistoryCard(Map<String, dynamic> item) {
    final name = _firstNonEmpty(<dynamic>[
      item['name'],
      item['lead_name'],
      item['title'],
      item['customer_name'],
      'Lead',
    ]);
    final phone = _firstNonEmpty(<dynamic>[item['phone'], item['phone_number']]);
    final source = _firstNonEmpty(<dynamic>[item['source'], item['channel']]);
    final budget = _firstNonEmpty(<dynamic>[item['budget'], item['budget_range']]);
    final status = _titleCase(_firstNonEmpty(<dynamic>[item['status'], 'New']));

    return _buildHistoryShell(
      title: name,
      subtitle: [phone, source].where((v) => v.isNotEmpty).join(' - '),
      trailingWidgets: [
        if (budget.isNotEmpty) _smallMutedText(budget),
        _statusPill(status, const Color(0xFFEAF1FF), AppColors.primary),
      ],
    );
  }

  Widget _buildFollowUpHistoryCard(Map<String, dynamic> item) {
    final title = _firstNonEmpty(<dynamic>[item['title'], 'Follow up']);
    final assignee = _firstNonEmpty(<dynamic>[
      item['assigned_name'],
      item['assignee_name'],
      item['customer_name'],
    ]);
    final dueRaw = _firstNonEmpty(<dynamic>[item['due_date'], item['created_at']]);
    final dueLabel = _formatDateLabel(dueRaw);
    final priority = _titleCase(_firstNonEmpty(<dynamic>[item['priority'], 'Medium']));
    final status = _titleCase(_firstNonEmpty(<dynamic>[item['status'], 'Pending']));

    return _buildHistoryShell(
      title: title,
      subtitle: [assignee, dueLabel].where((v) => v.isNotEmpty).join(' - '),
      trailingWidgets: [
        _statusPill(priority, const Color(0xFFEAF1FF), AppColors.primary),
        _statusPill(status, const Color(0xFFF3F4F6), AppColors.textPrimary),
      ],
    );
  }

  Widget _buildSiteVisitHistoryCard(Map<String, dynamic> item) {
    final title = _firstNonEmpty(<dynamic>[
      item['lead_name'],
      item['customer_name'],
      item['title'],
      'Site Visit',
    ]);
    final project = _firstNonEmpty(<dynamic>[item['project_name'], item['project']]);
    final visitDateRaw =
        _firstNonEmpty(<dynamic>[item['visit_date'], item['scheduled_date']]);
    final visitDate = _formatDateLabel(visitDateRaw);
    final status = _titleCase(_firstNonEmpty(<dynamic>[item['status'], 'Scheduled']));

    return _buildHistoryShell(
      title: title,
      subtitle: [project, visitDate].where((v) => v.isNotEmpty).join(' - '),
      trailingWidgets: [
        _statusPill(status, const Color(0xFFDBF5EE), const Color(0xFF047857)),
      ],
    );
  }

  Widget _buildHistoryShell({
    required String title,
    required String subtitle,
    required List<Widget> trailingWidgets,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: trailingWidgets,
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _smallMutedText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_canManageUsers && !_canDeleteMember) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (_canManageUsers)
            Expanded(
              child: _buildRoundedButton(
                icon: Icons.edit_outlined,
                label: 'Edit Member',
                color: AppColors.primary,
                onTap: _isDeleting ? null : _openEditMember,
              ),
            ),
          if (_canManageUsers && _canDeleteMember) const SizedBox(width: 12),
          if (_canDeleteMember)
            Expanded(
              child: _buildRoundedButton(
                icon: Icons.delete_outline,
                label: _isDeleting ? 'Deleting...' : 'Delete Member',
                color: AppColors.error,
                onTap: _isDeleting ? null : _deleteMember,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundedButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDisabled ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDisabled ? 0.12 : 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveTeamHistoryUserId() {
    final selectedUserId = _memberId?.trim() ?? '';
    final currentUserId = _currentUserId.trim();

    if (selectedUserId.isEmpty) {
      return null;
    }

    if (RoleAccess.canViewTeam(_currentRole) ||
        RoleAccess.canViewUsers(_currentRole)) {
      return selectedUserId;
    }

    return currentUserId == selectedUserId ? selectedUserId : null;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        final asText = value.toString().trim();
        if (asText.isNotEmpty) {
          return asText;
        }
      }
    }
    return '';
  }

  String _titleCase(String value) {
    final normalized = value.trim().replaceAll('_', ' ').toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatDateLabel(String raw) {
    if (raw.trim().isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      return raw.trim();
    }
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  String _readableRole(String role) {
    return role
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String? _extractMemberId(Map<String, dynamic> source) {
    final keys = ['id', 'user_id', 'userId', 'uuid'];
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _buildFullName(
      String firstName, String lastName, Map<String, dynamic> source) {
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }

    final fromName = _asString(source['name']);
    if (fromName.isNotEmpty) {
      return fromName;
    }

    final fromEmail = _asString(source['email']);
    if (fromEmail.isNotEmpty) {
      return fromEmail;
    }

    return 'Unknown Member';
  }

  String _fallbackValue(String value, {required String fallback}) {
    return value.isNotEmpty ? value : fallback;
  }

  String _asString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _readNum(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem({required this.icon, required this.label, required this.value});
}

class _PipelineRow {
  const _PipelineRow(this.label, this.count, this.percent, this.color);

  final String label;
  final int count;
  final double percent;
  final Color color;
}

class _PipelineSeed {
  const _PipelineSeed(this.label, this.key, this.color);

  final String label;
  final String key;
  final Color color;
}
