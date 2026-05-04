import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_detail_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/utils/csv_export_helper.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:url_launcher/url_launcher.dart';

class FollowUpPage extends StatefulWidget {
  const FollowUpPage({super.key});

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFollowUpIds = <String>{};
  final AuthProvider _authProvider = AuthProvider();
  bool _isBulkSelectionMode = false;

  int _currentPage = 1;
  final int _pageSize = 5;
  String _searchQuery = '';
  bool _isLoadingFollowUps = false;
  String? _loadError;

  final List<_FollowUpModel> _allFollowUps = <_FollowUpModel>[
    _FollowUpModel(
      id: 'FU-2026-001',
      leadId: 'L-2026-0001',
      customerName: 'Rajesh Khanna',
      status: 'Scheduled',
      statusColor: const Color(0xFF1E88E5),
      priority: 'High',
      priorityColor: const Color(0xFFE53935),
      dueDate: '2026-04-25',
      dueTime: '10:30 AM',
      channel: 'Call',
      notes: 'Discuss unit options and payment plan.',
      assignee: _PersonModel(
        name: 'Amit Kumar',
        imageUrl: 'https://i.pravatar.cc/160?img=21',
      ),
    ),
    _FollowUpModel(
      id: 'FU-2026-002',
      leadId: 'L-2026-0002',
      customerName: 'Meera Reddy',
      status: 'Pending',
      statusColor: const Color(0xFFFB8C00),
      priority: 'Medium',
      priorityColor: const Color(0xFFFB8C00),
      dueDate: '2026-04-24',
      dueTime: '02:15 PM',
      channel: 'WhatsApp',
      notes: 'Share project brochure and floor plans.',
      assignee: _PersonModel(
        name: 'Sneha Gupta',
        imageUrl: 'https://i.pravatar.cc/160?img=22',
      ),
    ),
    _FollowUpModel(
      id: 'FU-2026-003',
      leadId: 'L-2026-0003',
      customerName: 'Suresh Iyer',
      status: 'Overdue',
      statusColor: const Color(0xFFD32F2F),
      priority: 'High',
      priorityColor: const Color(0xFFE53935),
      dueDate: '2026-04-22',
      dueTime: '11:00 AM',
      channel: 'Meeting',
      notes: 'Negotiation follow-up pending final approval.',
      assignee: _PersonModel(
        name: 'Priya Menon',
        imageUrl: 'https://i.pravatar.cc/160?img=23',
      ),
    ),
    _FollowUpModel(
      id: 'FU-2026-004',
      leadId: 'L-2026-0005',
      customerName: 'Vikram Rao',
      status: 'Scheduled',
      statusColor: const Color(0xFF1E88E5),
      priority: 'Medium',
      priorityColor: const Color(0xFFFB8C00),
      dueDate: '2026-04-27',
      dueTime: '04:00 PM',
      channel: 'Call',
      notes: 'Reconfirm site visit for Sunday.',
      assignee: _PersonModel(
        name: 'Neha Joshi',
        imageUrl: 'https://i.pravatar.cc/160?img=25',
      ),
    ),
    _FollowUpModel(
      id: 'FU-2026-005',
      leadId: 'L-2026-0007',
      customerName: 'Kavya Nair',
      status: 'Completed',
      statusColor: const Color(0xFF2E7D32),
      priority: 'High',
      priorityColor: const Color(0xFFE53935),
      dueDate: '2026-04-23',
      dueTime: '09:00 AM',
      channel: 'Demo',
      notes: 'Demo done. Awaiting feedback by tomorrow.',
      assignee: _PersonModel(
        name: 'Sneha Gupta',
        imageUrl: 'https://i.pravatar.cc/160?img=22',
      ),
    ),
    _FollowUpModel(
      id: 'FU-2026-006',
      leadId: 'L-2026-0009',
      customerName: 'Pooja Kapoor',
      status: 'Pending',
      statusColor: const Color(0xFFFB8C00),
      priority: 'Low',
      priorityColor: const Color(0xFF1E88E5),
      dueDate: '2026-04-30',
      dueTime: '01:30 PM',
      channel: 'Email',
      notes: 'Send revised costing sheet.',
      assignee: _PersonModel(
        name: 'Priya Menon',
        imageUrl: 'https://i.pravatar.cc/160?img=23',
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  Future<void> _openCreateFollowUp() async {
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const FollowUpFormPage()),
    );
    if (!mounted || payload == null) {
      return;
    }

    final created = _modelFromPayload(
      payload: payload,
      id: 'FU-${DateTime.now().millisecondsSinceEpoch}',
      assignee: const _PersonModel(name: 'You', imageUrl: ''),
    );

    setState(() {
      _allFollowUps.insert(0, created);
      _currentPage = 1;
    });
  }

  Future<void> _openEditFollowUp(_FollowUpModel followUp) async {
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

    final index = _allFollowUps.indexWhere((item) => item.id == followUp.id);
    if (index < 0) {
      return;
    }

    setState(() {
      _allFollowUps[index] = updated;
    });
  }

  Future<void> _viewFollowUp(_FollowUpModel followUp) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowUpDetailPage(followUpId: followUp.id),
      ),
    );
  }

  Future<void> _deleteFollowUp(_FollowUpModel followUp) async {
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
        _allFollowUps.removeWhere((item) => item.id == followUp.id);
        _selectedFollowUpIds.remove(followUp.id);
        _syncBulkSelectionMode();
      });
      _showSnackBar('Follow-up deleted successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _callFollowUp(_FollowUpModel followUp) async {
    final phone = followUp.assignee.phone.trim();
    if (phone.isEmpty) {
      _showSnackBar('Phone number is not available for this follow-up.');
      return;
    }

    final launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  void _markFollowUpComplete(_FollowUpModel followUp) {
    _confirmAndCompleteFollowUp(followUp);
  }

  Future<void> _confirmAndCompleteFollowUp(_FollowUpModel followUp) async {
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

      final index = _allFollowUps.indexWhere((item) => item.id == followUp.id);
      if (index < 0 || !mounted) {
        return;
      }

      setState(() {
        _allFollowUps[index] = _allFollowUps[index].copyWith(
          status: 'Completed',
          statusColor: const Color(0xFF2E7D32),
        );
      });
      _showSnackBar('Follow-up marked as complete.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
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

    return _FollowUpModel(
      id: id,
      leadId: _readString(payload['lead_id']),
      customerName: title.isEmpty ? 'Follow Up' : title,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportFollowUps() async {
    await CsvExportHelper.exportRowsToClipboard(
      context: context,
      fileLabel: 'Follow Ups',
      headers: const <String>[
        'ID',
        'Lead ID',
        'Customer',
        'Status',
        'Priority',
        'Due Date',
        'Due Time',
        'Channel',
        'Assignee',
        'Phone',
      ],
      rows: _currentPageFollowUps
          .map(
            (item) => <String>[
              item.id,
              item.leadId,
              item.customerName,
              item.status,
              item.priority,
              item.dueDate,
              item.dueTime,
              item.channel,
              item.assignee.name,
              item.assignee.phone,
            ],
          )
          .toList(),
    );
  }

  List<_FollowUpModel> get _filteredFollowUps {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _allFollowUps;
    }

    return _allFollowUps.where((followUp) {
      return followUp.customerName.toLowerCase().contains(query) ||
          followUp.id.toLowerCase().contains(query) ||
          followUp.leadId.toLowerCase().contains(query) ||
          followUp.status.toLowerCase().contains(query) ||
          followUp.assignee.name.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPages {
    if (_filteredFollowUps.isEmpty) {
      return 1;
    }
    return (_filteredFollowUps.length / _pageSize).ceil();
  }

  List<_FollowUpModel> get _currentPageFollowUps {
    final followUps = _filteredFollowUps;
    if (followUps.isEmpty) {
      return const <_FollowUpModel>[];
    }

    final safePage = _currentPage.clamp(1, _totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = math.min(start + _pageSize, followUps.length);
    return followUps.sublist(start, end);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowUps() async {
    setState(() {
      _isLoadingFollowUps = true;
      _loadError = null;
    });

    try {
      final result = await _authProvider.followUps(
        token: _authProvider.currentAuthToken,
      );

      final mapped = result.items
          .map(_followUpFromApi)
          .whereType<_FollowUpModel>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _allFollowUps
          ..clear()
          ..addAll(mapped);
        _isLoadingFollowUps = false;
        _currentPage = 1;
        _selectedFollowUpIds.clear();
        _isBulkSelectionMode = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFollowUps = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
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
      customerName: title.isEmpty ? 'Follow Up' : title,
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
                      onPressed: _loadFollowUps,
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
                _currentPage = 1;
                _selectedFollowUpIds.clear();
                _isBulkSelectionMode = false;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search by customer, status',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final exportButton = OutlinedButton.icon(
          onPressed: _exportFollowUps,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: _openCreateFollowUp,
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

        if (isCompact) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: exportButton),
                  const SizedBox(width: 8),
                  Expanded(child: addButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            exportButton,
            const SizedBox(width: 8),
            addButton,
          ],
        );
      },
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
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Mark Done'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  label: const Text('Reschedule'),
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
    final followUps = _currentPageFollowUps;

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
                  leadId: '',
                  status: followUp.status,
                  priority: followUp.priority,
                  priorityColor: followUp.priorityColor,
                  nextFollowUpDate: '${followUp.dueDate} - ${followUp.dueTime}',
                  budget: followUp.channel,
                  phone: followUp.assignee.phone.isEmpty
                      ? 'N/A'
                      : followUp.assignee.phone,
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
                    DataCardAction(
                      icon: Icons.visibility_outlined,
                      onTap: () => _viewFollowUp(followUp),
                    ),
                    DataCardAction(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => _deleteFollowUp(followUp),
                    ),
                  ],
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
          '${_filteredFollowUps.length} total follow-ups',
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
    final totalItems = _filteredFollowUps.length;
    final totalPages = _totalPages;
    final currentPage = _currentPage.clamp(1, totalPages);
    final start = totalItems == 0 ? 0 : ((currentPage - 1) * _pageSize) + 1;
    final end =
        totalItems == 0 ? 0 : math.min(currentPage * _pageSize, totalItems);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Text(
            'Showing $start-$end of $totalItems',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage -= 1;
                          _selectedFollowUpIds.clear();
                          _isBulkSelectionMode = false;
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage += 1;
                          _selectedFollowUpIds.clear();
                          _isBulkSelectionMode = false;
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    required this.followUp,
    required this.isSelected,
    required this.onView,
    required this.onDelete,
    required this.onEdit,
    required this.onCall,
    required this.onComplete,
    required this.onSelectionChanged,
  });

  final _FollowUpModel followUp;
  final bool isSelected;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onCall;
  final VoidCallback onComplete;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF7FAFF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFFBDD3FF) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),
              const SizedBox(width: 4),
              _ProfileAvatar(
                imageUrl: followUp.assignee.imageUrl,
                name: followUp.customerName,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      followUp.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigned To: ${followUp.assignee.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(followUp.priority, followUp.priorityColor),
            ],
          ),
          const SizedBox(height: 10),
          _metaRow(
            'Assigned To',
            followUp.assignee.name,
            AppColors.textPrimary,
            Icons.person_outline,
          ),
          const SizedBox(height: 8),
          _metaRow(
            'Due',
            '${followUp.dueDate} • ${followUp.dueTime}',
            AppColors.textPrimary,
            Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 8),
          _metaRow(
            'Channel',
            followUp.channel,
            AppColors.textPrimary,
            Icons.call_outlined,
          ),
          const SizedBox(height: 8),
          _metaRow(
            'Notes',
            followUp.notes,
            AppColors.textSecondary,
            Icons.notes_outlined,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ProfileAvatar(
                imageUrl: followUp.assignee.imageUrl,
                name: followUp.assignee.name,
                radius: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  followUp.assignee.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined),
              ),
              IconButton(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, Color valueColor, IconData icon) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
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
