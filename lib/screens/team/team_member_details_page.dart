import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/team/add_team_member_page.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _memberData = Map<String, dynamic>.from(widget.memberData);
    _memberId = _extractMemberId(_memberData);
    _fetchMemberDetails();
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteMember() async {
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
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
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
      _memberData['last_name'] ?? _memberData['lastName'] ?? _memberData['lastname'],
    );
    final fullName = _buildFullName(firstName, lastName, _memberData);
    final email = _fallbackValue(_asString(_memberData['email']), fallback: 'N/A');
    final phoneNumber = _fallbackValue(
      _asString(_memberData['phone_number'] ?? _memberData['phoneNumber']),
      fallback: 'N/A',
    );
    final role = _readableRole(
      _asString(_memberData['role']).isNotEmpty
          ? _asString(_memberData['role'])
          : 'Team Member',
    );
    final isActive = _asBool(_memberData['is_active'] ?? _memberData['isActive']);
    final lastLoginStr = _asString(_memberData['last_login'] ?? _memberData['lastLogin']);

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    if (_loadError != null) ...[
                      _buildErrorCard(_loadError!),
                      const SizedBox(height: 16),
                    ],
                    _buildHeader(fullName, role, isActive),
                    const SizedBox(height: 24),
                    _buildStatsSection(_memberData),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 20),
                    _buildInfoSection(
                      title: 'System Information',
                      items: [
                        _InfoItem(
                          icon: Icons.history_rounded,
                          label: 'Last Login',
                          value: lastLogin != null
                              ? DateFormat('MMM dd, yyyy - hh:mm a').format(lastLogin)
                              : 'Never',
                        ),
                        _InfoItem(
                          icon: Icons.security_outlined,
                          label: 'Access Level',
                          value: role,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 40,
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
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
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

  Widget _buildInfoSection({required String title, required List<_InfoItem> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 15,
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

  Widget _buildActionButtons() {
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
          Expanded(
            child: _buildRoundedButton(
              icon: Icons.edit_outlined,
              label: 'Edit Member',
              color: AppColors.primary,
              onTap: _isDeleting ? null : _openEditMember,
            ),
          ),
          const SizedBox(width: 12),
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
          color: color.withOpacity(isDisabled ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(isDisabled ? 0.12 : 0.2)),
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

  String _readableRole(String role) {
    return role
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
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

  String _buildFullName(String firstName, String lastName, Map<String, dynamic> source) {
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
