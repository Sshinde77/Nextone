import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedLeadIds = <String>{};

  int _currentPage = 1;
  final int _pageSize = 5;
  String _searchQuery = '';

  final List<_LeadModel> _allLeads = <_LeadModel>[
    _LeadModel(
      id: 'L-2026-0001',
      name: 'Rajesh Khanna',
      status: 'Site Visit Scheduled',
      priority: 'Hot',
      priorityColor: const Color(0xFFE53935),
      nextFollowUpDate: '2026-04-25',
      budget: 'INR 8.0 Cr',
      phone: '+91 98765 11111',
      profileImageUrl: 'https://i.pravatar.cc/160?img=11',
      assignee: _PersonModel(
        name: 'Amit Kumar',
        imageUrl: 'https://i.pravatar.cc/160?img=21',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0002',
      name: 'Meera Reddy',
      status: 'Qualified',
      priority: 'Warm',
      priorityColor: const Color(0xFFFB8C00),
      nextFollowUpDate: '2026-04-24',
      budget: 'INR 50 L',
      phone: '+91 98765 33333',
      profileImageUrl: 'https://i.pravatar.cc/160?img=12',
      assignee: _PersonModel(
        name: 'Sneha Gupta',
        imageUrl: 'https://i.pravatar.cc/160?img=22',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0003',
      name: 'Suresh Iyer',
      status: 'Negotiation',
      priority: 'Hot',
      priorityColor: const Color(0xFFE53935),
      nextFollowUpDate: '2026-04-23',
      budget: 'INR 15.0 Cr',
      phone: '+91 98765 44444',
      profileImageUrl: 'https://i.pravatar.cc/160?img=13',
      assignee: _PersonModel(
        name: 'Priya Menon',
        imageUrl: 'https://i.pravatar.cc/160?img=23',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0004',
      name: 'Ananya Sharma',
      status: 'New',
      priority: 'Cold',
      priorityColor: const Color(0xFF1E88E5),
      nextFollowUpDate: '2026-04-28',
      budget: 'INR 1.0 Cr',
      phone: '+91 98765 55555',
      profileImageUrl: 'https://i.pravatar.cc/160?img=14',
      assignee: _PersonModel(
        name: 'Rohan Das',
        imageUrl: 'https://i.pravatar.cc/160?img=24',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0005',
      name: 'Vikram Rao',
      status: 'Follow-up Pending',
      priority: 'Warm',
      priorityColor: const Color(0xFFFB8C00),
      nextFollowUpDate: '2026-04-27',
      budget: 'INR 2.2 Cr',
      phone: '+91 98670 11122',
      profileImageUrl: 'https://i.pravatar.cc/160?img=15',
      assignee: _PersonModel(
        name: 'Neha Joshi',
        imageUrl: 'https://i.pravatar.cc/160?img=25',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0006',
      name: 'Arjun Malhotra',
      status: 'Proposal Shared',
      priority: 'Warm',
      priorityColor: const Color(0xFFFB8C00),
      nextFollowUpDate: '2026-04-29',
      budget: 'INR 3.4 Cr',
      phone: '+91 98111 90210',
      profileImageUrl: 'https://i.pravatar.cc/160?img=16',
      assignee: _PersonModel(
        name: 'Amit Kumar',
        imageUrl: 'https://i.pravatar.cc/160?img=21',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0007',
      name: 'Kavya Nair',
      status: 'Demo Scheduled',
      priority: 'Hot',
      priorityColor: const Color(0xFFE53935),
      nextFollowUpDate: '2026-04-26',
      budget: 'INR 95 L',
      phone: '+91 99220 77123',
      profileImageUrl: 'https://i.pravatar.cc/160?img=17',
      assignee: _PersonModel(
        name: 'Sneha Gupta',
        imageUrl: 'https://i.pravatar.cc/160?img=22',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0008',
      name: 'Nitin Verma',
      status: 'Closed Won',
      priority: 'Hot',
      priorityColor: const Color(0xFFE53935),
      nextFollowUpDate: '2026-05-02',
      budget: 'INR 6.8 Cr',
      phone: '+91 99887 66110',
      profileImageUrl: 'https://i.pravatar.cc/160?img=18',
      assignee: _PersonModel(
        name: 'Rohan Das',
        imageUrl: 'https://i.pravatar.cc/160?img=24',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0009',
      name: 'Pooja Kapoor',
      status: 'Contacted',
      priority: 'Cold',
      priorityColor: const Color(0xFF1E88E5),
      nextFollowUpDate: '2026-04-30',
      budget: 'INR 42 L',
      phone: '+91 98701 88221',
      profileImageUrl: 'https://i.pravatar.cc/160?img=19',
      assignee: _PersonModel(
        name: 'Priya Menon',
        imageUrl: 'https://i.pravatar.cc/160?img=23',
      ),
    ),
    _LeadModel(
      id: 'L-2026-0010',
      name: 'Dev Patel',
      status: 'Re-engagement',
      priority: 'Warm',
      priorityColor: const Color(0xFFFB8C00),
      nextFollowUpDate: '2026-05-01',
      budget: 'INR 1.8 Cr',
      phone: '+91 98100 77331',
      profileImageUrl: 'https://i.pravatar.cc/160?img=20',
      assignee: _PersonModel(
        name: 'Neha Joshi',
        imageUrl: 'https://i.pravatar.cc/160?img=25',
      ),
    ),
  ];

  List<_LeadModel> get _filteredLeads {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _allLeads;
    }
    return _allLeads.where((lead) {
      return lead.name.toLowerCase().contains(query) ||
          lead.id.toLowerCase().contains(query) ||
          lead.status.toLowerCase().contains(query) ||
          lead.assignee.name.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPages {
    if (_filteredLeads.isEmpty) {
      return 1;
    }
    return (_filteredLeads.length / _pageSize).ceil();
  }

  List<_LeadModel> get _currentPageLeads {
    final leads = _filteredLeads;
    if (leads.isEmpty) {
      return const <_LeadModel>[];
    }

    final safePage = _currentPage.clamp(1, _totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = math.min(start + _pageSize, leads.length);
    return leads.sublist(start, end);
  }

  bool get _isAllCurrentPageSelected {
    final leads = _currentPageLeads;
    if (leads.isEmpty) {
      return false;
    }
    return leads.every((lead) => _selectedLeadIds.contains(lead.id));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedLeadIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lead Management',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
            _buildLeadsSection(),
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 1;
                _selectedLeadIds.clear();
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search by name, lead id, status, assignee',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Lead'),
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
        crossAxisAlignment: WrapCrossAlignment.center,
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
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
            label: const Text('Assign'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('Update Status'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(_selectedLeadIds.clear);
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsSection() {
    final leads = _currentPageLeads;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListHeader(leads),
          const SizedBox(height: 8),
          if (leads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'No leads found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...leads.map(
              (lead) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LeadCard(
                  lead: lead,
                  isSelected: _selectedLeadIds.contains(lead.id),
                  onSelectionChanged: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLeadIds.add(lead.id);
                      } else {
                        _selectedLeadIds.remove(lead.id);
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

  Widget _buildListHeader(List<_LeadModel> currentPageLeads) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: _isAllCurrentPageSelected,
            onChanged: (value) {
              final shouldSelect = value ?? false;
              setState(() {
                for (final lead in currentPageLeads) {
                  if (shouldSelect) {
                    _selectedLeadIds.add(lead.id);
                  } else {
                    _selectedLeadIds.remove(lead.id);
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
            '${_filteredLeads.length} total leads',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalItems = _filteredLeads.length;
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
        crossAxisAlignment: WrapCrossAlignment.center,
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
                          _selectedLeadIds.clear();
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
                          _selectedLeadIds.clear();
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

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final _LeadModel lead;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryCompact = constraints.maxWidth < 380;

          return Column(
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
                    imageUrl: lead.profileImageUrl,
                    name: lead.name,
                    radius: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          lead.id,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _buildStatusChip(
                        maxWidth: isVeryCompact ? 120 : 170,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoPair(
                left: _metaItem(
                  'Priority',
                  lead.priority,
                  dotColor: lead.priorityColor,
                ),
                right: _metaItem(
                  'Next Follow-up',
                  lead.nextFollowUpDate,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(height: 10),
              _buildInfoPair(
                left: _metaItem(
                  'Budget',
                  lead.budget,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                right: _metaItem(
                  'Phone',
                  lead.phone,
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _ProfileAvatar(
                          imageUrl: lead.assignee.imageUrl,
                          name: lead.assignee.name,
                          radius: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lead.assignee.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionIcons(isVeryCompact: isVeryCompact),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EAF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        lead.status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC2185B),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoPair({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    );
  }

  Widget _metaItem(
    String label,
    String value, {
    Color? valueColor,
    Color? dotColor,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIcons({required bool isVeryCompact}) {
    final iconSize = isVeryCompact ? 16.0 : 18.0;
    final buttonSize = isVeryCompact ? 30.0 : 34.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionIcon(
          Icons.call_outlined,
          onTap: () {},
          iconSize: iconSize,
          buttonSize: buttonSize,
        ),
        _actionIcon(
          Icons.visibility_outlined,
          onTap: () {},
          iconSize: iconSize,
          buttonSize: buttonSize,
        ),
        _actionIcon(
          Icons.edit_outlined,
          onTap: () {},
          iconSize: iconSize,
          buttonSize: buttonSize,
        ),
        _actionIcon(
          Icons.delete_outline,
          onTap: () {},
          color: const Color(0xFFD32F2F),
          iconSize: iconSize,
          buttonSize: buttonSize,
        ),
      ],
    );
  }

  Widget _actionIcon(
    IconData icon, {
    required VoidCallback onTap,
    required double iconSize,
    required double buttonSize,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: iconSize,
          color: color ?? AppColors.textSecondary,
        ),
        constraints: BoxConstraints.tightFor(
          width: buttonSize,
          height: buttonSize,
        ),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
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

class _LeadModel {
  const _LeadModel({
    required this.id,
    required this.name,
    required this.status,
    required this.priority,
    required this.priorityColor,
    required this.nextFollowUpDate,
    required this.budget,
    required this.phone,
    required this.profileImageUrl,
    required this.assignee,
  });

  final String id;
  final String name;
  final String status;
  final String priority;
  final Color priorityColor;
  final String nextFollowUpDate;
  final String budget;
  final String phone;
  final String profileImageUrl;
  final _PersonModel assignee;
}

class _PersonModel {
  const _PersonModel({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;
}
