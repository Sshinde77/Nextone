import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/utils/export_file_helper.dart';
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
  bool _isExporting = false;
  String? _error;
  List<_UserItem> _users = <_UserItem>[];

  static const List<String> _roleFilters = <String>[
    'All Roles',
    'Super Admin',
    'Admin',
    'Sales Manager',
    'Sales Executive',
    'External Caller',
  ];

  static const List<String> _statusFilters = <String>[
    'All Status',
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
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
      final data = await _authProvider.users(token: _authProvider.currentAuthToken);
      if (!mounted) return;
      setState(() {
        _users = data.map(_UserItem.fromApi).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCreateUser() async {
    final created = await Navigator.of(context).push<TeamMemberCreationResult>(
      MaterialPageRoute(builder: (_) => const AddTeamMemberPage()),
    );
    if (created != null && mounted) {
      _loadUsers();
    }
  }

  Future<void> _openEditUser(_UserItem user) async {
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
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _exportUsers() async {
    setState(() {
      _isExporting = true;
    });
    try {
      final exported = await _authProvider.exportUsers(
        token: _authProvider.currentAuthToken,
      );
      final fileName = exported.fileName.trim().isEmpty
          ? 'users_export.xlsx'
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Export generated ($fileName), but direct file save is not supported on Web in this build.',
        );
        return;
      }
      final file = await ExportFileHelper.saveToDownloadNextone(
        fileName: fileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;
      _showSnackBar('Users export downloaded: ${file.path}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
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
                    OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportUsers,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export'),
                    ),
                    FilledButton.icon(
                      onPressed: _openCreateUser,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
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
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadUsers, child: const Text('Retry')),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DataCard(
        name: user.name,
        leadId: user.lastSeen,
        status: user.role.toUpperCase(),
        priority: user.status,
        priorityColor: user.status == 'Active' ? AppColors.success : AppColors.textSecondary,
        nextFollowUpDate: user.email,
        budget: user.phone,
        phone: user.role,
        profileImageUrl: '',
        assigneeName: user.status,
        assigneeImageUrl: '',
        actions: [
          DataCardAction(
            icon: Icons.edit_outlined,
            onTap: () => _openEditUser(user),
          ),
          if (user.status != 'Inactive')
            DataCardAction(
              icon: Icons.delete_outline,
              color: AppColors.error,
              onTap: () => _deleteUser(user),
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
    required this.status,
    required this.lastSeen,
    required this.rawData,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
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
      name: fullName.isNotEmpty ? fullName : (fallbackName.isNotEmpty ? fallbackName : 'Unknown'),
      email: read(json['email']),
      phone: read(json['phone_number'] ?? json['phone'] ?? json['mobile']),
      role: roleLabel(read(json['role'])),
      status: active ? 'Active' : 'Inactive',
      lastSeen: lastLogin.isEmpty ? 'Never logged in' : 'Last: $lastLogin',
      rawData: Map<String, dynamic>.from(json),
    );
  }
}
