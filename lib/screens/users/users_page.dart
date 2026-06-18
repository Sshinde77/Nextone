import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/screens/team/team_member_details_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/assign_manager_dialog.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final AuthProvider _authProvider = AuthProvider();
  String _selectedRole = 'All Roles';
  String _selectedStatus = 'All Status';
  bool _isLoading = true;
  final Set<String> _assigningManagerUserIds = <String>{};
  String? _error;
  List<_UserItem> _users = <_UserItem>[];
  String _currentRole = '';

  static const List<String> _fallbackRoleFilters = <String>[
    'All Roles',
    'Super Admin',
    'Admin',
    'Sales Manager',
    'Sales Executive',
    'External Caller',
  ];
  List<String> _roleFilters = List<String>.from(_fallbackRoleFilters);

  static const List<String> _statusFilters = <String>[
    'All Status',
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadRoles();
    _loadUsers();
  }

  bool get _canCreateUsers => RoleAccess.canCreateUsers(_currentRole);
  bool get _canEditUsers => RoleAccess.canEditUsers(_currentRole);
  bool get _canDeleteUsers => RoleAccess.canDeleteUsers(_currentRole);
  bool get _canAssignManager => RoleAccess.canAssignManager(_currentRole);

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

  List<_UserItem> get _filteredUsers {
    return _users.where((u) {
      final roleMatch = _selectedRole == 'All Roles' || u.role == _selectedRole;
      final statusMatch =
          _selectedStatus == 'All Status' || u.status == _selectedStatus;
      return roleMatch && statusMatch;
    }).toList();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await _authProvider.users(token: _authProvider.currentAuthToken);
      if (!mounted) return;
      setState(() {
        _users = data.map(_UserItem.fromApi).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadRoles() async {
    try {
      final data =
          await _authProvider.usersRoles(token: _authProvider.currentAuthToken);
      if (!mounted) return;
      final labels = data
          .map((entry) => _readString(entry['label']))
          .where((label) => label.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (labels.isEmpty) {
        return;
      }
      final nextFilters = <String>['All Roles', ...labels];
      setState(() {
        _roleFilters = nextFilters;
        if (!_roleFilters.contains(_selectedRole)) {
          _selectedRole = 'All Roles';
        }
      });
    } catch (_) {
      // Keep fallback role filters if API fails.
    }
  }

  String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<void> _openCreateUser() async {
    if (!_canCreateUsers) {
      _showSnackBar('You do not have permission to create users.');
      return;
    }
    final created = await Navigator.of(context).push<TeamMemberCreationResult>(
      MaterialPageRoute(builder: (_) => const AddTeamMemberPage()),
    );
    if (created != null && mounted) {
      _loadUsers();
    }
  }

  Future<void> _openEditUser(_UserItem user) async {
    if (!_canEditUsers) {
      _showSnackBar('You do not have permission to edit users.');
      return;
    }
    final memberId = user.id.trim();
    if (memberId.isEmpty) {
      _showSnackBar('Unable to edit member: missing user id.');
      return;
    }
    final updated = await Navigator.of(context).push<TeamMemberCreationResult>(
      MaterialPageRoute(
        builder: (_) => AddTeamMemberPage(
          memberId: memberId,
          memberData: user.rawData,
        ),
      ),
    );
    if (updated != null && mounted) {
      _loadUsers();
    }
  }

  Future<void> _deleteUser(_UserItem user) async {
    if (!_canDeleteUsers) {
      _showSnackBar('You do not have permission to deactivate this user.');
      return;
    }
    final userId = user.id.trim();
    if (userId.isEmpty) {
      _showSnackBar('Unable to delete member: missing user id.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete ${user.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _authProvider.deleteUser(
        id: userId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showSnackBar('User deleted successfully.');
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Future<void> _viewUser(_UserItem user) async {
    final action = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => TeamMemberDetailsPage(memberData: user.rawData),
      ),
    );
    if (!mounted) return;
    if (action == true || action == 'updated' || action == 'deleted') {
      await _loadUsers();
    }
  }

  List<_UserItem> get _managerOptions {
    return _users.where((u) {
      return u.rawRole == RoleAccess.salesManager && u.status == 'Active';
    }).toList();
  }

  String _userManagerId(_UserItem user) {
    final raw = user.rawData;
    final direct = raw['manager_id'] ?? raw['managerId'];
    final directId = direct?.toString().trim() ?? '';
    if (directId.isNotEmpty) return directId;
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

  String _userManagerName(_UserItem user) {
    final raw = user.rawData;
    final byName = raw['manager_name'] ?? raw['managerName'];
    if (byName is String && byName.trim().isNotEmpty) return byName.trim();
    final nested = raw['manager'];
    if (nested is Map<String, dynamic>) {
      final nestedName =
          nested['name'] ?? nested['full_name'] ?? nested['fullName'];
      if (nestedName is String && nestedName.trim().isNotEmpty) {
        return nestedName.trim();
      }
    }
    final managerId = _userManagerId(user);
    final manager = _managerOptions.where((m) => m.id == managerId);
    return manager.isNotEmpty ? manager.first.name : 'Not assigned';
  }

  Future<void> _openAssignManagerDialog(_UserItem user) async {
    if (!_canAssignManager) {
      _showSnackBar('You do not have permission to assign manager.');
      return;
    }
    if (user.id.trim().isEmpty) {
      _showSnackBar('Unable to assign manager: missing user id.');
      return;
    }
    if (user.rawRole != RoleAccess.salesExecutive &&
        user.rawRole != RoleAccess.externalCaller) {
      _showSnackBar(
          'Manager can only be assigned to sales executives or external callers.');
      return;
    }

    final managers = _managerOptions;
    if (managers.isEmpty) {
      _showSnackBar('No sales manager available to assign.');
      return;
    }

    String selectedManagerId = _userManagerId(user);
    if (selectedManagerId.isEmpty ||
        managers.every((m) => m.id != selectedManagerId)) {
      selectedManagerId = managers.first.id;
    }

    final assignedId = await showDialog<String>(
      context: context,
      builder: (context) => AssignManagerDialog(
        memberName: user.name,
        memberRole: user.role,
        memberEmail: user.email,
        currentManagerName: _userManagerName(user),
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
      _assigningManagerUserIds.add(user.id);
    });
    try {
      await _authProvider.assignUserManager(
        id: user.id,
        managerId: manager.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index >= 0) {
        final updatedRaw = Map<String, dynamic>.from(_users[index].rawData)
          ..['manager_id'] = manager.id
          ..['manager_name'] = manager.name;
        setState(() {
          _users[index] = _users[index].copyWith(rawData: updatedRaw);
        });
      }
      _showSnackBar('Manager assigned to ${user.name}.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _assigningManagerUserIds.remove(user.id);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Users'),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: _filterDropdown(
                    value: _selectedRole,
                    values: _roleFilters,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedRole = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterDropdown(
                    value: _selectedStatus,
                    values: _statusFilters,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedStatus = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 430;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment:
                      isCompact ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    // if (_canExportData)
                    //   OutlinedButton.icon(
                    //     onPressed: _isExporting ? null : _exportUsers,
                    //     icon: _isExporting
                    //         ? const SizedBox(
                    //             width: 14,
                    //             height: 14,
                    //             child:
                    //                 CircularProgressIndicator(strokeWidth: 2),
                    //           )
                    //         : const Icon(Icons.download_rounded, size: 16),
                    //     label: const Text('Export'),
                    //   ),
                    if (_canCreateUsers)
                      FilledButton.icon(
                        onPressed: _openCreateUser,
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 16),
                        label: const Text('New User'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: _loadUsers, child: const Text('Retry')),
                  ],
                ),
              )
            else if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...users.map(_buildUserCard),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: values
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUserCard(_UserItem user) {
    final isAssigning = _assigningManagerUserIds.contains(user.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DataCard(
        name: user.name,
        leadId: user.lastSeen,
        status: user.role.toUpperCase(),
        priority: user.status,
        priorityColor: user.status == 'Active'
            ? AppColors.success
            : AppColors.textSecondary,
        nextFollowUpDate: user.email,
        budget: user.phone,
        phone: user.role,
        profileImageUrl: '',
        assigneeName: user.status,
        assigneeImageUrl: '',
        actions: [
          DataCardAction(
            icon: Icons.visibility_outlined,
            onTap: isAssigning ? () {} : () => _viewUser(user),
          ),
          if (_canAssignManager &&
              (user.rawRole == RoleAccess.salesExecutive ||
                  user.rawRole == RoleAccess.externalCaller))
            DataCardAction(
              icon: Icons.person_add_alt_1_outlined,
              onTap: isAssigning ? () {} : () => _openAssignManagerDialog(user),
            ),
          if (_canEditUsers)
            DataCardAction(
              icon: Icons.edit_outlined,
              onTap: isAssigning ? () {} : () => _openEditUser(user),
            ),
          if (user.status != 'Inactive')
            DataCardAction(
              icon: Icons.delete_outline,
              color: AppColors.error,
              onTap: isAssigning ? () {} : () => _deleteUser(user),
            ),
        ],
      ),
    );
  }
}

class _UserItem {
  const _UserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.rawRole,
    required this.status,
    required this.lastSeen,
    required this.rawData,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String rawRole;
  final String status;
  final String lastSeen;
  final Map<String, dynamic> rawData;

  factory _UserItem.fromApi(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value == null) return '';
      return value.toString().trim();
    }

    String roleLabel(String raw) {
      if (raw.isEmpty) return 'Team Member';
      return raw
          .split('_')
          .map((part) {
            if (part.isEmpty) return '';
            final lower = part.toLowerCase();
            return '${lower[0].toUpperCase()}${lower.substring(1)}';
          })
          .where((part) => part.isNotEmpty)
          .join(' ');
    }

    final first = read(json['first_name'] ?? json['firstName']);
    final last = read(json['last_name'] ?? json['lastName']);
    final fallbackName = read(json['name']);
    final fullName = [if (first.isNotEmpty) first, if (last.isNotEmpty) last]
        .join(' ')
        .trim();
    final active = json['is_active'] == true ||
        read(json['status']).toLowerCase() == 'active';
    final lastLogin = read(json['last_login'] ?? json['lastLogin']);
    return _UserItem(
      id: read(json['id'] ?? json['user_id'] ?? json['userId'] ?? json['uuid']),
      name: fullName.isNotEmpty
          ? fullName
          : (fallbackName.isNotEmpty ? fallbackName : 'Unknown'),
      email: read(json['email']),
      phone: read(json['phone_number'] ?? json['phone'] ?? json['mobile']),
      role: roleLabel(read(json['role'])),
      rawRole: RoleAccess.normalize(read(json['role'])),
      status: active ? 'Active' : 'Inactive',
      lastSeen: lastLogin.isEmpty ? 'Never logged in' : 'Last: $lastLogin',
      rawData: Map<String, dynamic>.from(json),
    );
  }

  _UserItem copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? rawRole,
    String? status,
    String? lastSeen,
    Map<String, dynamic>? rawData,
  }) {
    return _UserItem(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      rawRole: rawRole ?? this.rawRole,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      rawData: rawData ?? this.rawData,
    );
  }
}
