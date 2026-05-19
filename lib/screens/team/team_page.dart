import 'package:flutter/material.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/screens/team/team_member_details_page.dart';
import 'package:nextone/utils/csv_export_helper.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/assign_manager_dialog.dart';
import 'package:nextone/widgets/data_card.dart';

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
  final Set<String> _deletingMemberIds = <String>{};
  final Set<String> _changingRoleMemberIds = <String>{};
  final Set<String> _assigningManagerMemberIds = <String>{};
  String _currentRole = '';
  final List<_RoleOption> _roleOptions = const [
    _RoleOption(label: 'Admin', value: 'admin'),
    _RoleOption(label: 'Sales Manager', value: 'sales_manager'),
    _RoleOption(label: 'Sales Executive', value: 'sales_executive'),
    _RoleOption(label: 'External Caller', value: 'external_caller'),
  ];

  final List<_TeamMember> _members = [];

  bool get _canManageUsers => RoleAccess.canManageUsers(_currentRole);
  bool get _canAssignManager =>
      RoleAccess.canManageUsers(_currentRole) ||
      RoleAccess.isSalesManager(_currentRole);
  bool get _canExportData => RoleAccess.canExportData(_currentRole);
  List<_RoleOption> get _assignableRoleOptions {
    return _roleOptions
        .where((role) => RoleAccess.canChangeRole(_currentRole, role.value))
        .toList();
  }

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
    _loadAccess();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Keep management actions hidden if access cannot be resolved.
    }
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
            // if (_isLoadingMembers)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(vertical: 40),
            //     child: Center(child: CircularProgressIndicator()),
            //   )
            // else if (_membersLoadError != null)
            //   _buildInfoCard(
            //     message: _membersLoadError!,
            //     actionLabel: 'Retry',
            //     onActionTap: _loadMembers,
            //   )
            // else ...[
            //   if (bestPerformer != null) _buildBestPerformerCard(bestPerformer),
            //   if (bestPerformer != null) const SizedBox(height: 16),
            // ],
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
      final members = users
          .where(_TeamMember.isActiveUser)
          .map(_TeamMember.fromApi)
          .toList();
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
    if (!_canManageUsers) {
      _showSnackBar('You do not have permission to create users.');
      return;
    }
    final created = await Navigator.push<TeamMemberCreationResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddTeamMemberPage()),
    );

    if (!mounted || created == null) {
      return;
    }

    await _loadMembers();
  }

  Future<void> _viewMemberDetails(_TeamMember member) async {
    final action = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => TeamMemberDetailsPage(memberData: member.originalData),
      ),
    );
    if (!mounted) {
      return;
    }

    if (action == true || action == 'updated' || action == 'deleted') {
      await _loadMembers();
    }
  }

  Future<void> _openEditMember(_TeamMember member) async {
    if (!_canManageUsers) {
      _showSnackBar('You do not have permission to edit users.');
      return;
    }
    if (member.id.isEmpty) {
      _showSnackBar('Unable to edit member: missing user id.');
      return;
    }

    final updated = await Navigator.push<TeamMemberCreationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTeamMemberPage(
          memberId: member.id,
          memberData: member.originalData,
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    await _loadMembers();
  }

  Future<void> _deleteMember(_TeamMember member) async {
    if (!RoleAccess.canDeactivate(_currentRole, member.rawRole)) {
      _showSnackBar('You do not have permission to deactivate this user.');
      return;
    }
    if (member.id.isEmpty) {
      _showSnackBar('Unable to delete member: missing user id.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Member'),
          content: Text(
            'Are you sure you want to delete ${member.name}?',
          ),
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
      _deletingMemberIds.add(member.id);
    });

    try {
      await _authProvider.deleteUser(
        id: member.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _members.removeWhere((m) => m.id == member.id);
      });
      _showSnackBar('Member deleted successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _deletingMemberIds.remove(member.id);
        });
      }
    }
  }

  Future<void> _openChangeRoleSheet(_TeamMember member) async {
    if (_assignableRoleOptions.isEmpty) {
      _showSnackBar('You do not have permission to change roles.');
      return;
    }
    if (!mounted) {
      return;
    }
    if (member.id.isEmpty) {
      _showSnackBar('Unable to change role: missing user id.');
      return;
    }

    final selectedRole = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Change Role',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._assignableRoleOptions.map((option) {
                  final roleLabel = _TeamMember.readableRole(option.value);
                  final isSelected =
                      member.role.toLowerCase() == roleLabel.toLowerCase();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(option.label),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.success)
                        : null,
                    onTap: () => Navigator.pop(context, option.value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedRole == null) {
      return;
    }

    final currentRoleValue = _roleOptions
        .firstWhere(
          (option) =>
              _TeamMember.readableRole(option.value).toLowerCase() ==
              member.role.toLowerCase(),
          orElse: () => _RoleOption(label: '', value: ''),
        )
        .value;
    if (selectedRole == currentRoleValue) {
      return;
    }

    final index = _members.indexWhere((m) => m.id == member.id);
    if (index < 0) {
      return;
    }

    setState(() {
      _changingRoleMemberIds.add(member.id);
    });

    try {
      await _authProvider.editUserRole(
        id: member.id,
        role: selectedRole,
        token: _authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final updatedData = Map<String, dynamic>.from(
          _members[index].originalData,
        )..['role'] = selectedRole;
        _members[index] = _members[index].copyWith(
          role: _TeamMember.readableRole(selectedRole),
          rawRole: selectedRole,
          originalData: updatedData,
        );
      });

      _showSnackBar(
          'Role changed to ${_TeamMember.readableRole(selectedRole)}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _changingRoleMemberIds.remove(member.id);
        });
      }
    }
  }

  List<_TeamMember> get _managerOptions {
    return _members.where((member) {
      return member.rawRole == RoleAccess.salesManager;
    }).toList();
  }

  String _memberManagerId(_TeamMember member) {
    final raw = member.originalData;
    final direct = raw['manager_id'] ?? raw['managerId'];
    final directId = direct?.toString().trim() ?? '';
    if (directId.isNotEmpty) {
      return directId;
    }
    final nested = raw['manager'];
    if (nested is Map<String, dynamic>) {
      final nestedId = nested['id'] ?? nested['user_id'] ?? nested['userId'];
      final nestedValue = nestedId?.toString().trim() ?? '';
      if (nestedValue.isNotEmpty) {
        return nestedValue;
      }
    }
    return '';
  }

  String _memberManagerName(_TeamMember member) {
    final raw = member.originalData;
    final byName = raw['manager_name'] ?? raw['managerName'];
    if (byName is String && byName.trim().isNotEmpty) {
      return byName.trim();
    }
    final nested = raw['manager'];
    if (nested is Map<String, dynamic>) {
      final name = nested['name'] ?? nested['full_name'] ?? nested['fullName'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }
    final selected = _managerOptions.where(
      (m) => m.id == _memberManagerId(member),
    );
    if (selected.isNotEmpty) {
      return selected.first.name;
    }
    return 'Not assigned';
  }

  Future<void> _openAssignManagerDialog(_TeamMember member) async {
    if (!_canAssignManager) {
      _showSnackBar('You do not have permission to assign manager.');
      return;
    }
    if (member.id.isEmpty) {
      _showSnackBar('Unable to assign manager: missing user id.');
      return;
    }
    if (member.rawRole != RoleAccess.salesExecutive &&
        member.rawRole != RoleAccess.externalCaller) {
      _showSnackBar(
        'Manager can only be assigned to sales executives or external callers.',
      );
      return;
    }

    final managers = _managerOptions;
    if (managers.isEmpty) {
      _showSnackBar('No sales manager available to assign.');
      return;
    }

    String selectedManagerId = _memberManagerId(member);
    if (selectedManagerId.isEmpty ||
        managers.every((m) => m.id != selectedManagerId)) {
      selectedManagerId = managers.first.id;
    }

    final assignedId = await showDialog<String>(
      context: context,
      builder: (context) => AssignManagerDialog(
        memberName: member.name,
        memberRole: member.role,
        memberEmail: (member.originalData['email'] ?? '').toString(),
        currentManagerName: _memberManagerName(member),
        managers: managers
            .map(
              (manager) => AssignManagerOption(
                id: manager.id,
                name: manager.name,
              ),
            )
            .toList(),
        initialManagerId: selectedManagerId,
      ),
    );

    if (!mounted || assignedId == null || assignedId.trim().isEmpty) {
      return;
    }

    final manager = managers.firstWhere(
      (m) => m.id == assignedId,
      orElse: () => managers.first,
    );

    setState(() {
      _assigningManagerMemberIds.add(member.id);
    });
    try {
      await _authProvider.assignUserManager(
        id: member.id,
        managerId: manager.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final index = _members.indexWhere((m) => m.id == member.id);
      if (index >= 0) {
        final updatedData =
            Map<String, dynamic>.from(_members[index].originalData)
          ..['manager_id'] = manager.id
          ..['manager_name'] = manager.name;
        setState(() {
          _members[index] = _members[index].copyWith(originalData: updatedData);
        });
      }
      _showSnackBar('Manager assigned to ${member.name}.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _assigningManagerMemberIds.remove(member.id);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportMembers() async {
    if (!_canExportData) {
      _showSnackBar('You do not have permission to export team data.');
      return;
    }
    await CsvExportHelper.exportRowsToClipboard(
      context: context,
      fileLabel: 'Team',
      headers: const <String>[
        'ID',
        'Name',
        'Email',
        'Role',
        'Active Leads',
        'Closed Leads',
        'Conversion Rate',
      ],
      rows: _filteredMembers
          .map(
            (member) => <String>[
              member.id,
              member.name,
              (member.originalData['email'] ?? '').toString(),
              member.role,
              member.activeLeads.toString(),
              member.closedLeads.toString(),
              member.conversionRate.toStringAsFixed(1),
            ],
          )
          .toList(),
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
    final isDeleting =
        member.id.isNotEmpty && _deletingMemberIds.contains(member.id);
    final isChangingRole =
        member.id.isNotEmpty && _changingRoleMemberIds.contains(member.id);
    final isAssigningManager =
        member.id.isNotEmpty && _assigningManagerMemberIds.contains(member.id);
    final isBusy = isDeleting || isChangingRole || isAssigningManager;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildCircleActionButton(
          Icons.visibility_outlined,
          AppColors.info,
          isBusy ? null : () => _viewMemberDetails(member),
        ),
        if (_canAssignManager &&
            (member.rawRole == RoleAccess.salesExecutive ||
                member.rawRole == RoleAccess.externalCaller)) ...[
          const SizedBox(width: 12),
          _buildCircleActionButton(
            Icons.person_add_alt_1_outlined,
            AppColors.primary,
            isBusy ? null : () => _openAssignManagerDialog(member),
            isLoading: isAssigningManager,
          ),
        ],
        if (_canManageUsers) ...[
          const SizedBox(width: 12),
          _buildCircleActionButton(
            Icons.edit_outlined,
            AppColors.warning,
            isBusy ? null : () => _openEditMember(member),
          ),
        ],
        if (_assignableRoleOptions.isNotEmpty) ...[
          const SizedBox(width: 12),
          _buildCircleActionButton(
            Icons.manage_accounts_outlined,
            AppColors.primary,
            isBusy ? null : () => _openChangeRoleSheet(member),
            isLoading: isChangingRole,
          ),
        ],
        if (RoleAccess.canDeactivate(_currentRole, member.rawRole)) ...[
          const SizedBox(width: 12),
          _buildCircleActionButton(
            Icons.delete_outline,
            AppColors.error,
            isBusy ? null : () => _deleteMember(member),
            isLoading: isDeleting,
          ),
        ],
      ],
    );
  }

  Widget _buildCircleActionButton(
    IconData icon,
    Color color,
    VoidCallback? onPressed, {
    bool isLoading = false,
  }) {
    final isDisabled = onPressed == null || isLoading;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(isDisabled ? 0.05 : 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(isDisabled ? 0.12 : 0.2)),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : IconButton(
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
        // if (_canExportData) ...[
        //   OutlinedButton.icon(
        //     onPressed: _exportMembers,
        //     icon: const Icon(Icons.download_rounded, size: 18),
        //     label: const Text('Export'),
        //     style: OutlinedButton.styleFrom(
        //       minimumSize: const Size(104, 50),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(999),
        //       ),
        //     ),
        //   ),
        //   const SizedBox(width: 8),
        // ],
        if (_canManageUsers)
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
    final isDeleting =
        member.id.isNotEmpty && _deletingMemberIds.contains(member.id);
    final isChangingRole =
        member.id.isNotEmpty && _changingRoleMemberIds.contains(member.id);
    final isAssigningManager =
        member.id.isNotEmpty && _assigningManagerMemberIds.contains(member.id);
    final isBusy = isDeleting || isChangingRole || isAssigningManager;
    final conversionColor =
        member.conversionRate >= 30 ? AppColors.success : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DataCard(
        name: member.name,
        leadId: member.role,
        status: 'TEAM MEMBER',
        priority: '${member.conversionRate.toStringAsFixed(1)}% Conv.',
        priorityColor: conversionColor,
        nextFollowUpDate: 'Closed Leads: ${member.closedLeads}',
        budget: 'Active Leads: ${member.activeLeads}',
        phone: 'N/A',
        profileImageUrl: '',
        assigneeName: member.role,
        assigneeImageUrl: '',
        actions: [
          DataCardAction(
            icon: Icons.visibility_outlined,
            onTap: isBusy ? () {} : () => _viewMemberDetails(member),
          ),
          if (_canAssignManager &&
              (member.rawRole == RoleAccess.salesExecutive ||
                  member.rawRole == RoleAccess.externalCaller))
            DataCardAction(
              icon: Icons.person_add_alt_1_outlined,
              onTap: isBusy ? () {} : () => _openAssignManagerDialog(member),
            ),
          if (_canManageUsers)
            DataCardAction(
              icon: Icons.edit_outlined,
              onTap: isBusy ? () {} : () => _openEditMember(member),
            ),
          if (_assignableRoleOptions.isNotEmpty)
            DataCardAction(
              icon: Icons.manage_accounts_outlined,
              onTap: isBusy ? () {} : () => _openChangeRoleSheet(member),
            ),
          if (RoleAccess.canDeactivate(_currentRole, member.rawRole))
            DataCardAction(
              icon: Icons.delete_outline,
              color: AppColors.error,
              onTap: isBusy ? () {} : () => _deleteMember(member),
            ),
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
  final String id;
  final String name;
  final String role;
  final String rawRole;
  final int activeLeads;
  final int closedLeads;
  final double conversionRate;
  final Map<String, dynamic> originalData;

  const _TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.rawRole,
    required this.activeLeads,
    required this.closedLeads,
    required this.conversionRate,
    required this.originalData,
  });

  factory _TeamMember.fromApi(Map<String, dynamic> json) {
    final id = _toCleanString(
      json['id'] ?? json['user_id'] ?? json['userId'] ?? json['uuid'],
    );
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
      id: id,
      name: safeName,
      role: role.isNotEmpty ? readableRole(role) : 'Team Member',
      rawRole: RoleAccess.normalize(role),
      activeLeads: activeLeads,
      closedLeads: closedLeads,
      conversionRate: conversionRate,
      originalData: json,
    );
  }

  _TeamMember copyWith({
    String? id,
    String? name,
    String? role,
    String? rawRole,
    int? activeLeads,
    int? closedLeads,
    double? conversionRate,
    Map<String, dynamic>? originalData,
  }) {
    return _TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      rawRole: rawRole ?? this.rawRole,
      activeLeads: activeLeads ?? this.activeLeads,
      closedLeads: closedLeads ?? this.closedLeads,
      conversionRate: conversionRate ?? this.conversionRate,
      originalData: originalData ?? this.originalData,
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

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
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

  static bool isActiveUser(Map<String, dynamic> json) {
    return _toBool(
      json['is_active'] ?? json['isActive'] ?? json['active'] ?? json['status'],
    );
  }

  static String readableRole(String role) {
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

class _RoleOption {
  final String label;
  final String value;

  const _RoleOption({required this.label, required this.value});
}
