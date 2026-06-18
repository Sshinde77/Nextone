// ignore_for_file: use_build_context_synchronously, unused_field

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/access_denied_view.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  final AuthProvider _authProvider = AuthProvider();
  bool _isLoadingAccess = true;
  bool _isLoadingTargets = true;
  bool _isSavingTarget = false;
  String? _targetsError;
  String _currentRole = '';
  String _currentUserId = '';
  late int _selectedMonth;
  late int _selectedYear;
  List<_TargetEntry> _targets = const <_TargetEntry>[];

  bool get _canViewTargets => RoleAccess.canViewModule('targets');
  bool get _canEditTargets =>
      RoleAccess.canEditModule('targets') ||
      RoleAccess.canCreateModule('targets') ||
      RoleAccess.canApproveModule('targets');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadAccessAndTargets();
  }

  Future<void> _loadAccessAndTargets() async {
    setState(() {
      _isLoadingAccess = true;
    });
    try {
      final permissions = await RoleAccess.currentPermissionSet(
        _authProvider,
        forceRefresh: true,
      );
      var currentUserId = _extractUserIdFromToken(_authProvider.currentAuthToken);
      if (currentUserId.isEmpty) {
        try {
          final profile = await _authProvider.profile(
            token: _authProvider.currentAuthToken,
          );
          currentUserId = _extractUserIdFromMap(profile.data);
        } catch (_) {
          // Keep the screen functional even if the profile lookup fails.
        }
      }
      if (!mounted) return;
      setState(() {
        _currentRole = permissions.role;
        _currentUserId = currentUserId;
        _isLoadingAccess = false;
      });
      if (_canViewTargets) {
        await _loadTargets();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccess = false;
      });
    }
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoadingTargets = true;
      _targetsError = null;
    });

    try {
      final response = await _authProvider.targets(
        month: _selectedMonthKey,
        token: _authProvider.currentAuthToken,
      );
      final rawTargets = response['targets'];
      final targets = rawTargets is List
          ? rawTargets
              .whereType<Map>()
              .map(
                (entry) => _TargetEntry.fromApi(
                  Map<String, dynamic>.from(
                    entry.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                ),
              )
              .toList()
          : const <_TargetEntry>[];
      if (!mounted) return;
      setState(() {
        _targets = targets;
        _isLoadingTargets = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _targetsError = AppErrorHandler.friendlyMessage(error);
        _isLoadingTargets = false;
      });
    }
  }

  String get _selectedMonthKey =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  String get _selectedMonthLabel {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedMonth - 1]} $_selectedYear';
  }

  String _extractUserIdFromToken(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return '';
    final parts = value.split('.');
    if (parts.length < 2) return '';
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        final id = payload['id'] ?? payload['user_id'] ?? payload['userId'];
        return id == null ? '' : id.toString().trim();
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  String _extractUserIdFromMap(Map<String, dynamic> data) {
    for (final key in const ['id', 'user_id', 'userId', 'uuid']) {
      final value = data[key];
      if (value == null) continue;
      final normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    final nested = data['user'];
    if (nested is Map<String, dynamic>) {
      return _extractUserIdFromMap(nested);
    }
    if (nested is Map) {
      return _extractUserIdFromMap(
        Map<String, dynamic>.from(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    return '';
  }

  Future<void> _openSetTargetDialog(_TargetEntry target) async {
    if (_isSavingTarget || !_canEditTargets) return;
    if (target.userId.trim().isEmpty || target.userId.trim() == _currentUserId) {
      return;
    }

    final siteVisitController = TextEditingController(
      text: '${target.siteVisitTarget}',
    );
    final closureController = TextEditingController(
      text: '${target.closureTarget}',
    );
    String? validationError;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSavingTarget,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSave() async {
              final siteVisitTarget =
                  int.tryParse(siteVisitController.text.trim());
              final closureTarget = int.tryParse(closureController.text.trim());
              if (siteVisitTarget == null ||
                  closureTarget == null ||
                  siteVisitTarget < 0 ||
                  closureTarget < 0) {
                setDialogState(() {
                  validationError =
                      'Enter valid non-negative numbers for both targets.';
                });
                return;
              }

              setState(() {
                _isSavingTarget = true;
              });
              try {
                await _authProvider.setTarget(
                  userId: target.userId,
                  month: _selectedMonthKey,
                  siteVisitTarget: siteVisitTarget,
                  closureTarget: closureTarget,
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!mounted) return;
                setDialogState(() {
                  validationError = AppErrorHandler.friendlyMessage(error);
                });
              } finally {
                if (mounted) {
                  setState(() {
                    _isSavingTarget = false;
                  });
                }
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Set Custom Target',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSavingTarget
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF60A5FA),
                            child: Text(
                              target.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  target.userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _selectedMonthLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TargetInputField(
                            controller: siteVisitController,
                            label: 'Site Visit Target',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TargetInputField(
                            controller: closureController,
                            label: 'Closure Target',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'This override is applied for $_selectedMonthLabel only.',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSavingTarget
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSavingTarget ? null : handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _isSavingTarget ? 'Saving...' : 'Save Target',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    siteVisitController.dispose();
    closureController.dispose();

    if (saved == true) {
      await _loadTargets();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Target updated for ${target.userName}.')),
        );
    }
  }

  List<int> get _yearOptions {
    final now = DateTime.now();
    return List<int>.generate(7, (index) => now.year - 2 + index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccess) {
      return const Scaffold(
        appBar: CrmAppBar(title: 'Targets'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canViewTargets) {
      return const Scaffold(
        appBar: CrmAppBar(title: 'Targets'),
        body: AccessDeniedView(moduleLabel: 'Targets'),
      );
    }

    final totalSiteVisitsDone = _targets.fold<int>(
      0,
      (sum, item) => sum + item.siteVisitsDone,
    );
    final totalClosuresDone = _targets.fold<int>(
      0,
      (sum, item) => sum + item.closuresDone,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Targets'),
      body: RefreshIndicator(
        onRefresh: _loadTargets,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const Text(
              'Monthly site visit and closure targets per user',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MonthDropdown(
                    value: _selectedMonth,
                    onChanged: (value) {
                      if (value == null || value == _selectedMonth) return;
                      setState(() => _selectedMonth = value);
                      _loadTargets();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _YearDropdown(
                    value: _selectedYear,
                    years: _yearOptions,
                    onChanged: (value) {
                      if (value == null || value == _selectedYear) return;
                      setState(() => _selectedYear = value);
                      _loadTargets();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _loadTargets,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TargetsSummaryCard(
                    icon: Icons.groups_2_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Team Members',
                    value: '${_targets.length}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TargetsSummaryCard(
                    icon: Icons.trending_up_rounded,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                    title: 'Site Visits Done',
                    value: '$totalSiteVisitsDone',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TargetsSummaryCard(
                    icon: Icons.domain_verification_outlined,
                    iconBg: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                    title: 'Closures Done',
                    value: '$totalClosuresDone',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Showing ${_targets.length} targets for $_selectedMonthLabel',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingTargets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_targetsError != null)
              _TargetsInfoCard(
                message: _targetsError!,
                actionLabel: 'Retry',
                onActionTap: _loadTargets,
              )
            else if (_targets.isEmpty)
              _TargetsInfoCard(
                message: 'No targets found for $_selectedMonthLabel.',
                actionLabel: 'Refresh',
                onActionTap: _loadTargets,
              )
            else
              ..._targets.map(_buildTargetCard),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(_TargetEntry target) {
    final canSetTarget =
        _canEditTargets && target.userId.trim().isNotEmpty && target.userId != _currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFF60A5FA),
                child: Text(
                  target.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        RoleAccess.label(target.role),
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (target.isCustom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Custom',
                        style: TextStyle(
                          color: Color(0xFFC2410C),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (canSetTarget)
                    OutlinedButton.icon(
                      onPressed:
                          _isSavingTarget ? null : () => _openSetTargetDialog(target),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        foregroundColor: AppColors.primary,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text(
                        'Set Target',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TargetProgressSection(
            title: 'Site Visits',
            done: target.siteVisitsDone,
            total: target.siteVisitTarget,
            remaining: target.siteVisitsRemaining,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 14),
          _TargetProgressSection(
            title: 'Closures',
            done: target.closuresDone,
            total: target.closureTarget,
            remaining: target.closuresRemaining,
            color: const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }
}

class _TargetEntry {
  const _TargetEntry({
    required this.userId,
    required this.userName,
    required this.role,
    required this.siteVisitTarget,
    required this.siteVisitsDone,
    required this.siteVisitsRemaining,
    required this.closureTarget,
    required this.closuresDone,
    required this.closuresRemaining,
    required this.isCustom,
  });

  final String userId;
  final String userName;
  final String role;
  final int siteVisitTarget;
  final int siteVisitsDone;
  final int siteVisitsRemaining;
  final int closureTarget;
  final int closuresDone;
  final int closuresRemaining;
  final bool isCustom;

  String get initials {
    final parts = userName
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory _TargetEntry.fromApi(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool readBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    String readString(dynamic value) => value == null ? '' : value.toString().trim();

    return _TargetEntry(
      userId: readString(json['user_id'] ?? json['userId']),
      userName: readString(json['user_name'] ?? json['userName']),
      role: readString(json['role']),
      siteVisitTarget: readInt(json['site_visit_target']),
      siteVisitsDone: readInt(json['site_visits_done']),
      siteVisitsRemaining: readInt(json['site_visits_remaining']),
      closureTarget: readInt(json['closure_target']),
      closuresDone: readInt(json['closures_done']),
      closuresRemaining: readInt(json['closures_remaining']),
      isCustom: readBool(json['is_custom']),
    );
  }
}

class _TargetsSummaryCard extends StatelessWidget {
  const _TargetsSummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        final iconSize = compact ? 34.0 : 42.0;
        final titleSize = compact ? 10.0 : 13.0;
        final valueSize = compact ? 16.0 : 22.0;
        final padding = compact ? 10.0 : 16.0;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                ),
                child: Icon(icon, color: iconColor, size: compact ? 18 : 22),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TargetProgressSection extends StatelessWidget {
  const _TargetProgressSection({
    required this.title,
    required this.done,
    required this.total,
    required this.remaining,
    required this.color,
  });

  final String title;
  final int done;
  final int total;
  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();
    final percent = total <= 0 ? 0 : ((done / total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$done / $total',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progress,
            backgroundColor: const Color(0xFFEFF2F7),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$remaining left',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetsInfoCard extends StatelessWidget {
  const _TargetsInfoCard({
    required this.message,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onActionTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TargetInputField extends StatelessWidget {
  const _TargetInputField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const months = <MapEntry<int, String>>[
      MapEntry(1, 'January'),
      MapEntry(2, 'February'),
      MapEntry(3, 'March'),
      MapEntry(4, 'April'),
      MapEntry(5, 'May'),
      MapEntry(6, 'June'),
      MapEntry(7, 'July'),
      MapEntry(8, 'August'),
      MapEntry(9, 'September'),
      MapEntry(10, 'October'),
      MapEntry(11, 'November'),
      MapEntry(12, 'December'),
    ];
    return DropdownButtonFormField<int>(
      initialValue: value,
      onChanged: onChanged,
      decoration: _dropdownDecoration(),
      items: months
          .map(
            (month) => DropdownMenuItem<int>(
              value: month.key,
              child: Text(month.value),
            ),
          )
          .toList(),
    );
  }
}

class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.value,
    required this.years,
    required this.onChanged,
  });

  final int value;
  final List<int> years;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      onChanged: onChanged,
      decoration: _dropdownDecoration(),
      items: years
          .map(
            (year) => DropdownMenuItem<int>(
              value: year,
              child: Text('$year'),
            ),
          )
          .toList(),
    );
  }
}

InputDecoration _dropdownDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
  );
}
