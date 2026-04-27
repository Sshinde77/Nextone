import 'package:flutter/material.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/screens/team/team_member_details_page.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final TextEditingController _searchController = TextEditingController();
  final AuthProvider _authProvider = AuthProvider();
  bool _isLoadingMembers = true;
  String? _membersLoadError;

  final List<_TeamMember> _members = [];

  List<_TeamMember> get _filteredMembers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _members;
    }

    return _members.where((m) {
      return m.name.toLowerCase().contains(query) ||
          m.role.toLowerCase().contains(query);
    }).toList();
  }

  _TeamMember? get _bestPerformer {
    if (_members.isEmpty) {
      return null;
    }

    return _members.reduce(
      (a, b) => a.conversionRate >= b.conversionRate ? a : b,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;
    final bestPerformer = _bestPerformer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Team'),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SizedBox(height: 18),
            if (_isLoadingMembers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_membersLoadError != null)
              _buildInfoCard(
                message: _membersLoadError!,
                actionLabel: 'Retry',
                onActionTap: _loadMembers,
              )
            else ...[
              if (bestPerformer != null) _buildBestPerformerCard(bestPerformer),
              if (bestPerformer != null) const SizedBox(height: 16),
            ],
            _buildSearchAndCreateRow(),
            const SizedBox(height: 16),
            Text(
              'Team Members (${members.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (!_isLoadingMembers &&
                _membersLoadError == null &&
                members.isEmpty)
              _buildInfoCard(
                message: 'No team members found.',
                actionLabel: 'Refresh',
                onActionTap: _loadMembers,
              )
            else
              ...members.map(_buildMemberCard),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoadingMembers = true;
      _membersLoadError = null;
    });

    try {
      final users = await _authProvider.users(
        token: _authProvider.currentAuthToken,
      );
      final members = users.map(_TeamMember.fromApi).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _isLoadingMembers = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _members.clear();
        _isLoadingMembers = false;
        _membersLoadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCreateMember() async {
    final created = await Navigator.push<TeamMemberCreationResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddTeamMemberPage()),
    );

    if (!mounted || created == null) {
      return;
    }

    await _loadMembers();
  }

  void _viewMemberDetails(_TeamMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamMemberDetailsPage(memberData: member.originalData),
      ),
    );
  }

  Widget _buildBestPerformerCard(_TeamMember member) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Performer',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialAvatar(name: member.name, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.role,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'TOP PERFORMER',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Leads Handled',
                  member.activeLeads.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Conversion Rate',
                  '${member.conversionRate.toStringAsFixed(1)}%',
                  valueColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButtonsRow(member),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow(_TeamMember member) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildCircleActionButton(
          Icons.visibility_outlined,
          AppColors.info,
          () => _viewMemberDetails(member),
        ),
        const SizedBox(width: 12),
        _buildCircleActionButton(Icons.edit_outlined, AppColors.warning, () {}),
        const SizedBox(width: 12),
        _buildCircleActionButton(Icons.delete_outline, AppColors.error, () {}),
      ],
    );
  }

  Widget _buildCircleActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndCreateRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search member',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _openCreateMember,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(132, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text('Create Member'),
        ),
      ],
    );
  }

  Widget _buildMemberCard(_TeamMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InitialAvatar(name: member.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.role,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('Leads', member.activeLeads.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  'Conv.',
                  '${member.conversionRate.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButtonsRow(member),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String message,
    required String actionLabel,
    required VoidCallback onActionTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onActionTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _InitialAvatar({required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.44,
        ),
      ),
    );
  }
}

class _TeamMember {
  final String name;
  final String role;
  final int activeLeads;
  final int closedLeads;
  final double conversionRate;
  final Map<String, dynamic> originalData;

  const _TeamMember({
    required this.name,
    required this.role,
    required this.activeLeads,
    required this.closedLeads,
    required this.conversionRate,
    required this.originalData,
  });

  factory _TeamMember.fromApi(Map<String, dynamic> json) {
    final firstName = _toCleanString(
      json['first_name'] ?? json['firstName'] ?? json['firstname'],
    );
    final lastName = _toCleanString(
      json['last_name'] ?? json['lastName'] ?? json['lastname'],
    );
    final fullName = _toCleanString(json['name']);
    final email = _toCleanString(json['email']);
    final role = _toCleanString(json['role']);

    final resolvedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    final activeLeads = _toInt(
      json['active_leads'] ?? json['activeLeads'] ?? json['leads_count'],
    );
    final closedLeads = _toInt(
      json['closed_leads'] ?? json['closedLeads'] ?? json['closed_count'],
    );
    final conversionRate = _toDouble(
      json['conversion_rate'] ?? json['conversionRate'],
    );

    final safeName = resolvedName.isNotEmpty
        ? resolvedName
        : (fullName.isNotEmpty
            ? fullName
            : (email.isNotEmpty ? email : 'Unknown'));

    return _TeamMember(
      name: safeName,
      role: role.isNotEmpty ? _readableRole(role) : 'Team Member',
      activeLeads: activeLeads,
      closedLeads: closedLeads,
      conversionRate: conversionRate,
      originalData: json,
    );
  }

  static int _toInt(dynamic value) {
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

  static double _toDouble(dynamic value) {
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

  static String _toCleanString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  static String _readableRole(String role) {
    return role
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
