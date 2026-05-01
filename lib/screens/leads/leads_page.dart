import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/screens/leads/lead_form_page.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedLeadIds = <String>{};
  final AuthProvider _authProvider = AuthProvider();
  bool _isBulkSelectionMode = false;

  Timer? _searchDebounce;
  bool _isLoadingLeads = true;
  String? _loadError;

  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  List<_LeadModel> _currentPageLeads = <_LeadModel>[];

  bool get _isAllCurrentPageSelected {
    final leads = _currentPageLeads;
    if (leads.isEmpty) {
      return false;
    }
    return leads.every((lead) => _selectedLeadIds.contains(lead.id));
  }

  void _syncBulkSelectionMode() {
    if (_selectedLeadIds.isEmpty && _isBulkSelectionMode) {
      _isBulkSelectionMode = false;
    } else if (_selectedLeadIds.isNotEmpty && !_isBulkSelectionMode) {
      _isBulkSelectionMode = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    setState(() {
      _isLoadingLeads = true;
      _loadError = null;
    });

    try {
      final result = await _authProvider.leads(
        token: _authProvider.currentAuthToken,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: _currentPage,
        perPage: _pageSize,
      );

      if (!mounted) {
        return;
      }

      final pageLeads = result.items.map(_LeadModel.fromApi).toList();
      final pageLeadIds = pageLeads.map((lead) => lead.id).toSet();

      setState(() {
        _currentPageLeads = pageLeads;
        _currentPage = result.currentPage <= 0 ? 1 : result.currentPage;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _totalItems = result.totalItems;
        _selectedLeadIds.removeWhere((id) => !pageLeadIds.contains(id));
        _isLoadingLeads = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPageLeads = <_LeadModel>[];
        _totalItems = 0;
        _totalPages = 1;
        _isLoadingLeads = false;
        _selectedLeadIds.clear();
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = value;
        _currentPage = 1;
        _selectedLeadIds.clear();
        _isBulkSelectionMode = false;
      });
      _loadLeads();
    });
  }

  Future<void> _openCreateLead() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );

    if (created == true && mounted) {
      _loadLeads();
    }
  }

  Future<void> _openEditLead(_LeadModel lead) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadFormPage(
          leadId: lead.id,
          leadData: lead.rawData,
        ),
      ),
    );

    if (updated == true && mounted) {
      _loadLeads();
    }
  }

  Future<void> _callLead(String phoneNumber) async {
    final launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _viewLeadDetail(String leadId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailPage(leadId: leadId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedLeadIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Lead Management'),
      body: RefreshIndicator(
        onRefresh: _loadLeads,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by name, status, assignee',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: _openCreateLead,
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
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Assign'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Update Status'),
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
              onPressed: () {
                setState(() {
                  _selectedLeadIds.clear();
                  _isBulkSelectionMode = false;
                });
              },
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
          if (_isLoadingLeads)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadLeads,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (leads.isEmpty)
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
                child: DataCard(
                  name: lead.name,
                  leadId: '',
                  status: lead.status,
                  priority: lead.priority,
                  priorityColor: lead.priorityColor,
                  nextFollowUpDate: lead.nextFollowUpDate,
                  budget: lead.budget,
                  phone: lead.phone,
                  profileImageUrl: lead.profileImageUrl,
                  assigneeName: lead.assignee.name,
                  assigneeImageUrl: lead.assignee.imageUrl,
                  actions: [
                    DataCardAction(
                      icon: Icons.call_outlined,
                      onTap: () => _callLead(lead.phone),
                    ),
                    DataCardAction(
                      icon: Icons.visibility_outlined,
                      onTap: () => _viewLeadDetail(lead.id),
                    ),
                    DataCardAction(
                      icon: Icons.edit_outlined,
                      onTap: () => _openEditLead(lead),
                    ),
                    DataCardAction(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFD32F2F),
                      onTap: () {},
                    ),
                  ],
                  bulkSelectionMode: _isBulkSelectionMode,
                  isSelected: _selectedLeadIds.contains(lead.id),
                  onLongPress: () {
                    setState(() {
                      _isBulkSelectionMode = true;
                      _selectedLeadIds.add(lead.id);
                    });
                  },
                  onSelectionChanged: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLeadIds.add(lead.id);
                      } else {
                        _selectedLeadIds.remove(lead.id);
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

  Widget _buildListHeader(List<_LeadModel> currentPageLeads) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          if (_isBulkSelectionMode) ...[
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
            '$_totalItems total leads',
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
    final totalItems = _totalItems;
    final totalPages = _totalPages <= 0 ? 1 : _totalPages;
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
                onPressed: !_isLoadingLeads && currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage -= 1;
                          _selectedLeadIds.clear();
                          _isBulkSelectionMode = false;
                        });
                        _loadLeads();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: !_isLoadingLeads && currentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage += 1;
                          _selectedLeadIds.clear();
                          _isBulkSelectionMode = false;
                        });
                        _loadLeads();
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
    required this.email,
    required this.source,
    required this.assignedToId,
    required this.locationPreference,
    required this.notes,
    required this.rawData,
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
  final String email;
  final String source;
  final String assignedToId;
  final String locationPreference;
  final String notes;
  final Map<String, dynamic> rawData;

  factory _LeadModel.fromApi(Map<String, dynamic> json) {
    final id = _readString(
      json['id'] ?? json['lead_id'] ?? json['leadId'],
      fallback: 'N/A',
    );
    final firstName = _readString(
      json['first_name'] ?? json['firstName'],
    );
    final lastName = _readString(
      json['last_name'] ?? json['lastName'],
    );
    final fullName = _readString(
      json['name'] ??
          json['full_name'] ??
          json['fullName'] ??
          json['contact_name'] ??
          json['customer_name'],
    );
    final resolvedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    final status = _readString(
      json['status'] ?? json['stage'] ?? json['current_status'],
      fallback: 'Unknown',
    );
    final priorityRaw = _readString(
      json['priority'] ?? json['temperature'],
      fallback: 'Warm',
    );
    final nextFollowUpDate = _readDate(
      json['next_follow_up_date'] ??
          json['nextFollowUpDate'] ??
          json['follow_up_date'],
    );
    final budget = _readBudget(
      json['budget'] ?? json['budget_value'] ?? json['budget_range'],
    );
    final phone = _readString(
      json['phone_number'] ?? json['phone'] ?? json['mobile'],
      fallback: 'N/A',
    );
    final profileImageUrl = _readString(
      json['profile_image'] ??
          json['profileImage'] ??
          json['avatar'] ??
          json['image_url'],
    );

    final assigned = json['assigned_to'] ?? json['assignee'];
    final assignedToId = assigned is Map<String, dynamic>
        ? _readString(
            assigned['id'] ??
                assigned['user_id'] ??
                assigned['userId'] ??
                assigned['uuid'],
          )
        : _readString(assigned);
    final assignedNameFromRoot = _readString(
      json['assigned_name'] ??
          json['assignedName'] ??
          json['assignee_name'] ??
          json['assigneeName'],
    );
    final assigneeName = assigned is Map<String, dynamic>
        ? _readString(
            assigned['name'] ??
                assigned['full_name'] ??
                assigned['fullName'] ??
                assigned['first_name'],
            fallback: 'Unassigned',
          )
        : (assignedNameFromRoot.isNotEmpty
            ? assignedNameFromRoot
            : 'Unassigned');
    final assigneeImage = assigned is Map<String, dynamic>
        ? _readString(
            assigned['image'] ??
                assigned['avatar'] ??
                assigned['profile_image'] ??
                assigned['image_url'],
          )
        : '';

    final email = _readString(json['email']);
    final source = _readString(json['source']);
    final locationPreference = _readString(
      json['location_preference'] ?? json['locationPreference'],
    );
    final notes = _readString(json['notes']);

    final priorityLabel = _readPriorityLabel(priorityRaw);
    return _LeadModel(
      id: id,
      name: resolvedName.isNotEmpty
          ? resolvedName
          : (fullName.isNotEmpty ? fullName : 'Unknown Lead'),
      status: status,
      priority: priorityLabel,
      priorityColor: _priorityColor(priorityLabel),
      nextFollowUpDate: nextFollowUpDate,
      budget: budget,
      phone: phone,
      profileImageUrl: profileImageUrl,
      assignee: _PersonModel(name: assigneeName, imageUrl: assigneeImage),
      email: email,
      source: source,
      assignedToId: assignedToId,
      locationPreference: locationPreference,
      notes: notes,
      rawData: Map<String, dynamic>.from(json),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String _readDate(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) {
      return 'N/A';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  static String _readBudget(dynamic value) {
    if (value is num) {
      return 'INR ${value.toString()}';
    }
    final asString = _readString(value);
    return asString.isEmpty ? 'N/A' : asString;
  }

  static String _readPriorityLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'high' || normalized == 'hot') {
      return 'Hot';
    }
    if (normalized == 'low' || normalized == 'cold') {
      return 'Cold';
    }
    return 'Warm';
  }

  static Color _priorityColor(String label) {
    switch (label.toLowerCase()) {
      case 'hot':
        return const Color(0xFFE53935);
      case 'cold':
        return const Color(0xFF1E88E5);
      default:
        return const Color(0xFFFB8C00);
    }
  }
}

class _PersonModel {
  const _PersonModel({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;
}
