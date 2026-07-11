// ignore_for_file: use_build_context_synchronously, unused_element, unused_element_parameter

import 'dart:async';
// import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_detail_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/screens/follow_ups/lead_follow_up_form_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class FollowUpPage extends StatefulWidget {
  const FollowUpPage({super.key});

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

enum _FollowUpScope { myFollowUp, team }

class _FollowUpPageState extends State<FollowUpPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFollowUpIds = <String>{};
  final AuthProvider _authProvider = AuthProvider();
  bool _isBulkSelectionMode = false;
  Timer? _searchDebounce;

  int _currentPage = 1;
  final int _pageSize = 10;
  String _searchQuery = '';
  String _selectedTeamId = '';
  bool _isLoadingFollowUps = false;
  bool _isLoadingTeams = false;
  String? _loadError;
  String _currentRole = '';
  _FollowUpScope _selectedScope = _FollowUpScope.team;
  int _totalItems = 0;
  int _totalPages = 1;

  final List<_FollowUpModel> _followUps = <_FollowUpModel>[];
  final List<_TeamOption> _teamOptions = <_TeamOption>[];

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadTeamOptions();
    _loadFollowUps();
  }

  bool get _isMyScope => _selectedScope == _FollowUpScope.myFollowUp;
  bool get _canDeleteFollowUps => RoleAccess.canDeleteModule('follow_ups');
  bool get _showScopeTabs =>
      _currentRole.isNotEmpty &&
      !RoleAccess.isSuperAdmin(_currentRole) &&
      !RoleAccess.isAdmin(_currentRole);

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Export actions stay hidden if access cannot be resolved.
    }
  }

  Future<void> _loadTeamOptions() async {
    setState(() {
      _isLoadingTeams = true;
    });

    try {
      final users = await _authProvider.assignmentUsers(
        token: _authProvider.currentAuthToken,
      );
      final options = users
          .map(_teamOptionFromUser)
          .whereType<_TeamOption>()
          .toList()
        ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

      if (!mounted) {
        return;
      }
      setState(() {
        _teamOptions
          ..clear()
          ..addAll(options);
        _isLoadingTeams = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTeams = false;
      });
    }
  }

  void _scheduleFollowUpReload({bool resetPage = false}) {
    if (resetPage) {
      _currentPage = 1;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      _loadFollowUps(page: _currentPage);
    });
  }

  Future<void> _openCreateFollowUpMenu(BuildContext buttonContext) async {
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = renderBox.localToGlobal(
      Offset(renderBox.size.width, renderBox.size.height),
      ancestor: overlay,
    );

    final choice = await showMenu<String>(
      context: buttonContext,
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy + 8,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - bottomRight.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'existing',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20),
              SizedBox(width: 10),
              Text('Existing Lead'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'new',
          child: Row(
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 10),
              Text('New Lead + Follow-up'),
            ],
          ),
        ),
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == 'new') {
      await _openCreateLeadWithFollowUp();
    } else {
      await _openCreateFollowUp();
    }
  }

  Future<void> _openCreateLeadWithFollowUp() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'leads',
      action: 'create',
      moduleLabel: 'leads',
    );
    if (!allowed) return;

    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LeadFollowUpFormPage()),
    );
    if (!mounted || payload == null) {
      return;
    }

    final createdId = _readFollowUpId(payload);
    final created = _modelFromPayload(
      payload: payload,
      id: createdId.isNotEmpty
          ? createdId
          : 'FU-${DateTime.now().millisecondsSinceEpoch}',
      assignee: _personFromPayload(
        payload,
        fallbackName: 'You',
      ),
    );

    setState(() {
      _followUps.insert(0, created);
      _currentPage = 1;
      _totalItems += 1;
    });
  }

  Future<void> _openCreateFollowUp() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'create',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const FollowUpFormPage()),
    );
    if (!mounted || payload == null) {
      return;
    }

    final createdId = _readFollowUpId(payload);
    final created = _modelFromPayload(
      payload: payload,
      id: createdId.isNotEmpty
          ? createdId
          : 'FU-${DateTime.now().millisecondsSinceEpoch}',
      assignee: _personFromPayload(payload, fallbackName: 'You'),
    );

    setState(() {
      _followUps.insert(0, created);
      _currentPage = 1;
      _totalItems += 1;
    });
  }

  Future<void> _openEditFollowUp(_FollowUpModel followUp) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'edit',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    final due = _combineDueDateTime(followUp.dueDate, followUp.dueTime);
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => FollowUpFormPage(
          followUpId: followUp.id,
          followUpData: <String, dynamic>{
            'title': followUp.customerName,
            'lead_id': followUp.leadId,
            'due_date': due.toUtc().toIso8601String(),
            'priority': followUp.priority.toLowerCase(),
            'notes': followUp.notes,
          },
        ),
      ),
    );
    if (!mounted || payload == null) {
      return;
    }

    final updated = _modelFromPayload(
      payload: payload,
      id: followUp.id,
      assignee: followUp.assignee,
    );

    final index = _followUps.indexWhere((item) => item.id == followUp.id);
    if (index < 0) {
      return;
    }

    setState(() {
      _followUps[index] = updated;
    });
  }

  Future<void> _openBulkSiteVisitForm() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'site_visits',
      action: 'create',
      moduleLabel: 'site visits',
    );
    if (!allowed) return;

    final selectedFollowUps = _followUps
        .where((followUp) => _selectedFollowUpIds.contains(followUp.id))
        .toList(growable: false);

    if (selectedFollowUps.isEmpty) {
      _showSnackBar('Select at least one follow-up.');
      return;
    }
    if (selectedFollowUps.length != 1) {
      _showSnackBar(
        'Convert to site visit uses the existing single-lead form. Select one follow-up.',
      );
      return;
    }

    final selectedFollowUp = selectedFollowUps.first;
    if (selectedFollowUp.leadId.trim().isEmpty ||
        selectedFollowUp.leadId.trim() == 'N/A') {
      _showSnackBar('Lead information is not available for this follow-up.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SiteVisitFormPage(initialLeadId: selectedFollowUp.leadId.trim()),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadFollowUps(page: _currentPage);
  }

  Future<void> _viewFollowUp(_FollowUpModel followUp) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowUpDetailPage(followUpId: followUp.id),
      ),
    );
  }

  Future<void> _deleteFollowUp(_FollowUpModel followUp) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'delete',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Follow Up'),
          content: Text(
              'Are you sure you want to delete "${followUp.customerName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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

    try {
      await _authProvider.deleteFollowUp(
        id: followUp.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _followUps.removeWhere((item) => item.id == followUp.id);
        if (_totalItems > 0) {
          _totalItems -= 1;
        }
        _selectedFollowUpIds.remove(followUp.id);
        _syncBulkSelectionMode();
      });
      _showSnackBar('Follow-up deleted successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    }
  }

  Future<void> _callFollowUp(_FollowUpModel followUp) async {
    final phone = followUp.leadPhone.trim();
    if (phone.isEmpty) {
      _showSnackBar('Phone number is not available for this follow-up.');
      return;
    }

    final launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    try {
      final launched = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnackBar('No calling app is available on this device.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Unable to open the calling app.');
      }
    }
  }

  void _markFollowUpComplete(_FollowUpModel followUp) {
    _confirmAndCompleteFollowUp(followUp);
  }

  Future<void> _confirmAndCompleteFollowUp(_FollowUpModel followUp) async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'follow_ups',
      action: 'edit',
      moduleLabel: 'follow-ups',
    );
    if (!allowed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mark As Complete'),
          content: Text('Mark "${followUp.customerName}" as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _authProvider.completeFollowUpStatus(
        id: followUp.id,
        isCompleted: true,
        token: _authProvider.currentAuthToken,
      );

      final index = _followUps.indexWhere((item) => item.id == followUp.id);
      if (index < 0 || !mounted) {
        return;
      }

      setState(() {
        _followUps[index] = _followUps[index].copyWith(
          status: 'Completed',
          statusColor: const Color(0xFF2E7D32),
        );
      });
      _showSnackBar('Follow-up marked as complete.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppErrorHandler.friendlyMessage(e));
    }
  }

  _FollowUpModel _modelFromPayload({
    required Map<String, dynamic> payload,
    required String id,
    required _PersonModel assignee,
  }) {
    final dueRaw = _readString(payload['due_date']);
    final due = DateTime.tryParse(dueRaw)?.toLocal() ?? DateTime.now();
    final priority = _readString(payload['priority']).toLowerCase();
    final title = _readString(payload['title']);
    final leadName = _readString(
      payload['lead_name'] ??
          payload['leadName'] ??
          payload['name'] ??
          payload['customer_name'],
    );
    final leadPhone = _readString(
      payload['lead_phone'] ?? payload['leadPhone'] ?? payload['phone'],
    );

    return _FollowUpModel(
      id: id,
      leadId: _readString(payload['lead_id']),
      customerName:
          leadName.isEmpty ? (title.isEmpty ? 'Follow Up' : title) : leadName,
      title: title.isEmpty ? 'Follow Up' : title,
      leadPhone: leadPhone,
      status: 'Pending',
      statusColor: const Color(0xFFFB8C00),
      priority: _labelPriority(priority),
      priorityColor: _priorityColor(priority),
      dueDate: DateFormat('yyyy-MM-dd').format(due),
      dueTime: DateFormat('hh:mm a').format(due),
      channel: 'Call',
      notes: _readString(payload['notes']),
      assignee: assignee,
    );
  }

  String _readFollowUpId(Map<String, dynamic> payload) {
    for (final key in const [
      'task_id',
      'taskId',
      'follow_up_id',
      'followUpId',
      'id',
    ]) {
      final value = _readString(payload[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  _PersonModel _personFromPayload(
    Map<String, dynamic> payload, {
    required String fallbackName,
  }) {
    final assigneeName = _readString(
      payload['assigned_to_name'] ??
          payload['assignedToName'] ??
          payload['assignee_name'] ??
          payload['assigneeName'],
    );
    final assigneePhone = _readString(
      payload['assigned_to_phone'] ??
          payload['assignedToPhone'] ??
          payload['assignee_phone'] ??
          payload['assigneePhone'],
    );
    return _PersonModel(
      name: assigneeName.isEmpty ? fallbackName : assigneeName,
      imageUrl: '',
      phone: assigneePhone,
    );
  }

  DateTime _combineDueDateTime(String dateValue, String timeValue) {
    final datePart = DateTime.tryParse(dateValue) ?? DateTime.now();
    final parsedTime = _parseTimeOfDay(timeValue);
    return DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final formats = <String>['hh:mm a', 'HH:mm', 'h:mm a'];
    for (final format in formats) {
      try {
        final dt = DateFormat(format).parseStrict(value);
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {
        // continue
      }
    }
    return TimeOfDay.now();
  }

  String _labelPriority(String value) {
    switch (value) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  Color _priorityColor(String value) {
    switch (value) {
      case 'high':
        return const Color(0xFFE53935);
      case 'low':
        return const Color(0xFF1E88E5);
      case 'medium':
      default:
        return const Color(0xFFFB8C00);
    }
  }

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    return '';
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'active';
    }
    return false;
  }

  String _readRoleLabel(Map<String, dynamic> user) {
    final rawRole = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
    );
    if (rawRole.isEmpty) {
      return '';
    }
    return rawRole
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  _TeamOption? _teamOptionFromUser(Map<String, dynamic> user) {
    final isActive = _readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    );
    if (!isActive) {
      return null;
    }

    final id = _readString(user['id'] ?? user['user_id'] ?? user['userId']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final fullName = _readString(
      user['full_name'] ?? user['fullName'] ?? user['name'],
    );

    final name = fullName.isNotEmpty
        ? fullName
        : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
    final baseName = name.isEmpty ? id : name;
    final roleLabel = _readRoleLabel(user);
    final label = roleLabel.isEmpty ? baseName : '$baseName ($roleLabel)';

    return _TeamOption(
      id: id,
      label: label,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<_FollowUpModel> get _currentPageFollowUps => _followUps;
  List<_FollowUpModel> get _visibleFollowUps {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _currentPageFollowUps;
    }
    return _currentPageFollowUps.where((followUp) {
      final haystack = <String>[
        followUp.customerName,
        followUp.status,
        followUp.priority,
        followUp.notes,
        followUp.assignee.name,
        followUp.assignee.phone,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  bool get _isAllCurrentPageSelected {
    final followUps = _currentPageFollowUps;
    if (followUps.isEmpty) {
      return false;
    }
    return followUps.every((item) => _selectedFollowUpIds.contains(item.id));
  }

  void _syncBulkSelectionMode() {
    if (_selectedFollowUpIds.isEmpty && _isBulkSelectionMode) {
      _isBulkSelectionMode = false;
    } else if (_selectedFollowUpIds.isNotEmpty && !_isBulkSelectionMode) {
      _isBulkSelectionMode = true;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowUps({int? page}) async {
    final targetPage = page ?? _currentPage;
    setState(() {
      _isLoadingFollowUps = true;
      _loadError = null;
      _currentPage = targetPage;
    });

    try {
      final result = _isMyScope
          ? await _authProvider.myFollowUps(
              token: _authProvider.currentAuthToken,
              page: targetPage,
              perPage: _pageSize,
            )
          : await _authProvider.followUps(
              token: _authProvider.currentAuthToken,
              assignedTo: _selectedTeamId.trim().isEmpty
                  ? null
                  : _selectedTeamId.trim(),
              search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
              page: targetPage,
              perPage: _pageSize,
            );

      final mapped = result.items
          .map(_followUpFromApi)
          .whereType<_FollowUpModel>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _followUps
          ..clear()
          ..addAll(mapped);
        _currentPage = result.currentPage;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _totalItems = result.totalItems;
        _isLoadingFollowUps = false;
        _selectedFollowUpIds.clear();
        _isBulkSelectionMode = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFollowUps = false;
        _loadError = AppErrorHandler.friendlyMessage(e);
      });
    }
  }

  _FollowUpModel? _followUpFromApi(Map<String, dynamic> json) {
    final id = _readString(json['id'] ?? json['task_id'] ?? json['taskId']);
    if (id.isEmpty) {
      return null;
    }

    final title = _readString(json['title']);
    final leadId = _readString(json['lead_id'] ?? json['leadId']);
    final leadName = _readString(json['lead_name'] ?? json['leadName']);
    final leadPhone = _readString(json['lead_phone'] ?? json['leadPhone']);
    final priorityRaw = _readString(json['priority']).toLowerCase();
    final statusRaw = _readString(json['status']).toLowerCase();
    final notes = _readString(json['notes']);
    final dueRaw = _readString(json['due_date'] ?? json['dueDate']);
    final due = DateTime.tryParse(dueRaw)?.toLocal() ?? DateTime.now();

    final assigned = json['assigned_to'];
    String assigneeName =
        _readString(json['assigned_name'] ?? json['assignedName']);
    String assigneeImage = '';
    String assigneePhone =
        _readString(json['assigned_phone'] ?? json['assignedPhone']);
    if (assigned is Map<String, dynamic>) {
      assigneeName = _readString(
        assigned['name'] ??
            assigned['full_name'] ??
            assigned['fullName'] ??
            assigned['first_name'],
      );
      assigneeImage = _readString(
        assigned['image'] ??
            assigned['avatar'] ??
            assigned['profile_image'] ??
            assigned['image_url'],
      );
      assigneePhone = _readString(
        assigned['phone'] ?? assigned['phone_number'] ?? assigned['mobile'],
      );
    } else if (assigned is String && assigned.trim().isNotEmpty) {
      assigneeName = assigned.trim();
    }
    if (assigneeName.isEmpty) {
      assigneeName = 'Unassigned';
    }

    return _FollowUpModel(
      id: id,
      leadId: leadId.isEmpty ? 'N/A' : leadId,
      customerName: leadName.isEmpty ? 'Follow Up' : leadName,
      title: title.isEmpty ? 'Follow Up' : title,
      leadPhone: leadPhone,
      status: _labelStatus(statusRaw),
      statusColor: _statusColor(statusRaw),
      priority: _labelPriority(priorityRaw),
      priorityColor: _priorityColor(priorityRaw),
      dueDate: DateFormat('yyyy-MM-dd').format(due),
      dueTime: DateFormat('hh:mm a').format(due),
      channel: 'Call',
      notes: notes,
      assignee: _PersonModel(
        name: assigneeName,
        imageUrl: assigneeImage,
        phone: assigneePhone,
      ),
    );
  }

  String _labelStatus(String value) {
    if (value.isEmpty) {
      return 'Pending';
    }
    final normalized = value.replaceAll('_', ' ');
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'completed':
      case 'done':
        return const Color(0xFF2E7D32);
      case 'overdue':
      case 'missed':
        return const Color(0xFFD32F2F);
      case 'scheduled':
        return const Color(0xFF1E88E5);
      case 'pending':
      default:
        return const Color(0xFFFB8C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedFollowUpIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Follow Ups'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToolbar(),
            const SizedBox(height: 16),
            if (_isLoadingFollowUps)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _loadFollowUps(page: _currentPage),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else ...[
              if (_isBulkSelectionMode && selectedCount > 0) ...[
                _buildBulkActionBar(selectedCount),
                const SizedBox(height: 16),
              ],
              _buildFollowUpSection(),
              const SizedBox(height: 16),
              _buildPagination(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        final searchField = Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _selectedFollowUpIds.clear();
                _isBulkSelectionMode = false;
              });
              _scheduleFollowUpReload(resetPage: true);
            },
            decoration: const InputDecoration(
              hintText: 'Search by customer, status',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final teamFilter = SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedTeamId.isEmpty ? '' : _selectedTeamId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All Teams'),
              ),
              ..._teamOptions.map(
                (team) => DropdownMenuItem<String>(
                  value: team.id,
                  child: Text(
                    team.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _isLoadingTeams
                ? null
                : (value) {
                    setState(() {
                      _selectedTeamId = value ?? '';
                      _selectedFollowUpIds.clear();
                      _isBulkSelectionMode = false;
                    });
                    _scheduleFollowUpReload(resetPage: true);
                  },
          ),
        );

        final exportButton = null;
        // final exportButton = _canExportData
        //     ? OutlinedButton.icon(
        //         onPressed: _isExporting ? null : _exportFollowUps,
        //         icon: _isExporting
        //             ? const SizedBox(
        //                 width: 16,
        //                 height: 16,
        //                 child: CircularProgressIndicator(strokeWidth: 2),
        //               )
        //             : const Icon(Icons.download_rounded, size: 18),
        //         label: Text(_isExporting ? 'Exporting...' : 'Export'),
        //         style: OutlinedButton.styleFrom(
        //           minimumSize: const Size(0, 48),
        //           padding: const EdgeInsets.symmetric(horizontal: 14),
        //           shape: RoundedRectangleBorder(
        //             borderRadius: BorderRadius.circular(12),
        //           ),
        //         ),
        //       )
        //     : null;

        final addButton = Builder(
          builder: (buttonContext) {
            return FilledButton.icon(
              onPressed: () => _openCreateFollowUpMenu(buttonContext),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Follow Up'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showScopeTabs) ...[
                _buildScopeTabs(),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(flex: 2, child: searchField),
                  if (!_isMyScope) ...[
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: teamFilter),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (exportButton != null) ...[
                    Expanded(child: exportButton),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: addButton),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showScopeTabs) ...[
              _buildScopeTabs(),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(child: searchField),
                if (!_isMyScope) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: 240, child: teamFilter),
                ],
                const SizedBox(width: 12),
                if (exportButton != null) ...[
                  exportButton,
                  const SizedBox(width: 8),
                ],
                addButton,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScopeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _scopeTabItem(
              label: 'My Follow Up',
              isActive: _isMyScope,
              onTap: () {
                if (_isMyScope) return;
                setState(() {
                  _selectedScope = _FollowUpScope.myFollowUp;
                  _selectedTeamId = '';
                  _selectedFollowUpIds.clear();
                  _isBulkSelectionMode = false;
                  _currentPage = 1;
                });
                _loadFollowUps(page: 1);
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scopeTabItem(
              label: 'Team',
              isActive: !_isMyScope,
              onTap: () {
                if (!_isMyScope) return;
                setState(() {
                  _selectedScope = _FollowUpScope.team;
                  _selectedFollowUpIds.clear();
                  _isBulkSelectionMode = false;
                  _currentPage = 1;
                });
                _loadFollowUps(page: 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeTabItem({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(int selectedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4E2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openBulkSiteVisitForm,
                  icon: const Icon(Icons.meeting_room_outlined, size: 16),
                  label: const Text('Convert to Site Visit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Mark Done'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.schedule_outlined, size: 16),
              label: const Text('Reschedule'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _selectedFollowUpIds.clear();
                _isBulkSelectionMode = false;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection() {
    final followUps = _visibleFollowUps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildListHeader(followUps),
          const SizedBox(height: 8),
          if (followUps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'No follow-ups found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...followUps.map(
              (followUp) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DataCard(
                  name: followUp.customerName,
                  leadId: followUp.title,
                  status: followUp.status,
                  priority: followUp.priority,
                  priorityColor: followUp.priorityColor,
                  nextFollowUpDate: '${followUp.dueDate} - ${followUp.dueTime}',
                  budget: followUp.channel,
                  phone:
                      followUp.leadPhone.isEmpty ? 'N/A' : followUp.leadPhone,
                  profileImageUrl: followUp.assignee.imageUrl,
                  assigneeName: followUp.assignee.name,
                  assigneeImageUrl: followUp.assignee.imageUrl,
                  actions: [
                    DataCardAction(
                      icon: Icons.call_outlined,
                      onTap: () => _callFollowUp(followUp),
                    ),
                    DataCardAction(
                      icon: Icons.check_circle_outline,
                      onTap: () => _markFollowUpComplete(followUp),
                    ),
                    DataCardAction(
                      icon: Icons.edit_outlined,
                      onTap: () => _openEditFollowUp(followUp),
                    ),
                    if (_canDeleteFollowUps)
                      DataCardAction(
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        onTap: () => _deleteFollowUp(followUp),
                      ),
                  ],
                  onTap: () => _viewFollowUp(followUp),
                  bulkSelectionMode: _isBulkSelectionMode,
                  isSelected: _selectedFollowUpIds.contains(followUp.id),
                  onLongPress: () {
                    setState(() {
                      _isBulkSelectionMode = true;
                      _selectedFollowUpIds.add(followUp.id);
                    });
                  },
                  onSelectionChanged: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFollowUpIds.add(followUp.id);
                      } else {
                        _selectedFollowUpIds.remove(followUp.id);
                      }
                      _syncBulkSelectionMode();
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader(List<_FollowUpModel> currentPageFollowUps) {
    return Row(
      children: [
        if (_isBulkSelectionMode) ...[
          Checkbox(
            value: _isAllCurrentPageSelected,
            onChanged: (value) {
              final shouldSelect = value ?? false;
              setState(() {
                for (final item in currentPageFollowUps) {
                  if (shouldSelect) {
                    _selectedFollowUpIds.add(item.id);
                  } else {
                    _selectedFollowUpIds.remove(item.id);
                  }
                }
                _syncBulkSelectionMode();
              });
            },
          ),
          const Text(
            'Select all on this page',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const Spacer(),
        Text(
          '$_totalItems total follow-ups',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return PaginationWidget(
      currentPage: _currentPage,
      totalPages: _totalPages,
      totalItems: _totalItems,
      itemLabel: 'records',
      onPageChanged: (page) {
        _selectedFollowUpIds.clear();
        _isBulkSelectionMode = false;
        _loadFollowUps(page: page);
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.name,
    this.radius = 18,
  });

  final String imageUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFFE9EEF7),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            ),
          );
        },
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _FollowUpModel {
  const _FollowUpModel({
    required this.id,
    required this.leadId,
    required this.customerName,
    required this.title,
    required this.leadPhone,
    required this.status,
    required this.statusColor,
    required this.priority,
    required this.priorityColor,
    required this.dueDate,
    required this.dueTime,
    required this.channel,
    required this.notes,
    required this.assignee,
  });

  final String id;
  final String leadId;
  final String customerName;
  final String title;
  final String leadPhone;
  final String status;
  final Color statusColor;
  final String priority;
  final Color priorityColor;
  final String dueDate;
  final String dueTime;
  final String channel;
  final String notes;
  final _PersonModel assignee;

  _FollowUpModel copyWith({
    String? id,
    String? leadId,
    String? customerName,
    String? title,
    String? leadPhone,
    String? status,
    Color? statusColor,
    String? priority,
    Color? priorityColor,
    String? dueDate,
    String? dueTime,
    String? channel,
    String? notes,
    _PersonModel? assignee,
  }) {
    return _FollowUpModel(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      customerName: customerName ?? this.customerName,
      title: title ?? this.title,
      leadPhone: leadPhone ?? this.leadPhone,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      priority: priority ?? this.priority,
      priorityColor: priorityColor ?? this.priorityColor,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      channel: channel ?? this.channel,
      notes: notes ?? this.notes,
      assignee: assignee ?? this.assignee,
    );
  }
}

class _PersonModel {
  const _PersonModel({
    required this.name,
    required this.imageUrl,
    this.phone = '',
  });

  final String name;
  final String imageUrl;
  final String phone;
}

class _TeamOption {
  const _TeamOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}
