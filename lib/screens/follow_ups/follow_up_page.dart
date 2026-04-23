import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class FollowUpPage extends StatefulWidget {
  const FollowUpPage({super.key});

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFollowUpIds = <String>{};

  int _currentPage = 1;
  final int _pageSize = 5;
  String _searchQuery = '';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            if (selectedCount > 0) ...[
              _buildBulkActionBar(selectedCount),
              const SizedBox(height: 16),
            ],
            _buildFollowUpSection(),
            const SizedBox(height: 16),
            _buildPagination(),
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
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search by customer, follow-up id, lead id, status',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: () {},
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
              Row(children: [Expanded(child: addButton)]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildBulkActionBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4E2FF)),
      ),
      child: Wrap(
        runSpacing: 8,
        spacing: 8,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Mark Done'),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.schedule_outlined, size: 16),
            label: const Text('Reschedule'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(_selectedFollowUpIds.clear),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
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
                child: _FollowUpCard(
                  followUp: followUp,
                  isSelected: _selectedFollowUpIds.contains(followUp.id),
                  onSelectionChanged: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFollowUpIds.add(followUp.id);
                      } else {
                        _selectedFollowUpIds.remove(followUp.id);
                      }
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
    final end = totalItems == 0
        ? 0
        : math.min(currentPage * _pageSize, totalItems);

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
    required this.onSelectionChanged,
  });

  final _FollowUpModel followUp;
  final bool isSelected;
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
                      '${followUp.id} • ${followUp.leadId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(followUp.status, followUp.statusColor),
            ],
          ),
          const SizedBox(height: 10),
          _metaRow(
            'Priority',
            followUp.priority,
            followUp.priorityColor,
            Icons.flag_outlined,
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
                onPressed: () {},
                icon: const Icon(Icons.call_outlined),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.check_circle_outline),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
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
}

class _PersonModel {
  const _PersonModel({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;
}
