import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/leads/lead_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/access_denied_view.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class WebsiteEnquiriesPage extends StatefulWidget {
  const WebsiteEnquiriesPage({super.key});

  @override
  State<WebsiteEnquiriesPage> createState() => _WebsiteEnquiriesPageState();
}

class _WebsiteEnquiriesPageState extends State<WebsiteEnquiriesPage> {
  static const String _websiteSource = 'Website';
  static const List<int> _pageSizeOptions = <int>[10, 20, 50];

  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  Timer? _searchDebounce;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isAdminAllowed = false;
  String _currentRole = '';
  String? _loadError;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedProject;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_WebsiteEnquiry> _enquiries = const <_WebsiteEnquiry>[];
  List<String> _projectOptions = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadProjectOptions();
    _loadEnquiries();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRole = role;
        _isAdminAllowed = RoleAccess.isAdminOrSuperAdmin(role);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdminAllowed = false;
      });
    }
  }

  Future<void> _loadEnquiries({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _loadError = null;
      });
    }

    try {
      final result = await _authProvider.leads(
        token: _authProvider.currentAuthToken,
        source: _websiteSource,
        status: _selectedStatus,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        project: _selectedProject,
        from: _fromDate == null ? null : _apiDateFormat.format(_fromDate!),
        to: _toDate == null ? null : _apiDateFormat.format(_toDate!),
        page: _currentPage,
        perPage: _pageSize,
      );

      final websiteEnquiries = result.items
          .map(_WebsiteEnquiry.fromApi)
          .where((item) => item.source.toLowerCase() == 'website')
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _enquiries = websiteEnquiries;
        _currentPage = result.currentPage <= 0 ? 1 : result.currentPage;
        _pageSize = result.perPage <= 0 ? _pageSize : result.perPage;
        _totalItems = result.totalItems;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enquiries = const <_WebsiteEnquiry>[];
        _totalItems = 0;
        _totalPages = 1;
        _isLoading = false;
        _isRefreshing = false;
        _loadError = AppErrorHandler.friendlyMessage(error);
      });
    }
  }

  Future<void> _loadProjectOptions() async {
    try {
      final result = await _authProvider.publicProjects(perPage: 100);
      final projectNames = result.items
          .map(
            (item) => (item['name'] ??
                    item['project_name'] ??
                    item['projectName'] ??
                    '')
                .toString()
                .trim(),
          )
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) {
        return;
      }
      setState(() {
        _projectOptions = projectNames;
        if (_selectedProject != null &&
            !_projectOptions.contains(_selectedProject)) {
          _selectedProject = null;
        }
      });
    } catch (_) {
      // Keep the page usable even if project filter options cannot be loaded.
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = value;
        _currentPage = 1;
      });
      _loadEnquiries();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
      _currentPage = 1;
    });
    _loadEnquiries();
  }

  void _clearDate({required bool isFrom}) {
    setState(() {
      if (isFrom) {
        _fromDate = null;
      } else {
        _toDate = null;
      }
      _currentPage = 1;
    });
    _loadEnquiries();
  }

  Future<void> _openEditDialog(_WebsiteEnquiry enquiry) async {
    final didUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditWebsiteEnquiryDialog(
        enquiry: enquiry,
        authProvider: _authProvider,
      ),
    );

    if (didUpdate == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Website enquiry updated successfully.'),
          ),
        );
      _loadEnquiries(showLoader: false);
    }
  }

  Future<void> _deleteEnquiry(_WebsiteEnquiry enquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Enquiry'),
          content: Text(
            'Delete the website enquiry for ${enquiry.name}?',
          ),
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

    if (confirmed != true) {
      return;
    }

    try {
      await _authProvider.deleteLead(
        id: enquiry.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Website enquiry deleted successfully.')),
        );
      _loadEnquiries(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppErrorHandler.friendlyMessage(error))),
        );
    }
  }

  Future<void> _openConvertDialog(_WebsiteEnquiry enquiry) async {
    final mode = await showDialog<_ConvertMode>(
      context: context,
      builder: (_) => _ConvertWebsiteEnquiryDialog(enquiry: enquiry),
    );
    if (mode == null || !mounted) {
      return;
    }

    final prefill = enquiry.toLeadPrefill(mode);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadFormPage(leadData: prefill),
        fullscreenDialog: true,
      ),
    );

    if (created == true && mounted) {
      _loadEnquiries(showLoader: false);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Select';
    }
    return _displayDateFormat.format(value);
  }

  Color _statusBackground(String status) {
    switch (status.trim().toLowerCase()) {
      case 'new':
        return const Color(0xFFDCEBFF);
      case 'follow_up':
      case 'follow up':
        return const Color(0xFFFFEDD5);
      case 'site_visit_scheduled':
      case 'site visit scheduled':
        return const Color(0xFFEDE9FE);
      case 'converted':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _statusForeground(String status) {
    switch (status.trim().toLowerCase()) {
      case 'new':
        return const Color(0xFF2563EB);
      case 'follow_up':
      case 'follow up':
        return const Color(0xFFC2410C);
      case 'site_visit_scheduled':
      case 'site visit scheduled':
        return const Color(0xFF7C3AED);
      case 'converted':
        return const Color(0xFF15803D);
      default:
        return AppColors.textSecondary;
    }
  }

  String _prettyStatus(String status) {
    final normalized = status.trim();
    if (normalized.isEmpty) {
      return 'New';
    }
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: const CrmAppBar(title: 'Website Inquiries'),
      body: SafeArea(
        child: _isAdminAllowed || _currentRole.isEmpty
            ? Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => _loadEnquiries(showLoader: false),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 14),
                          _buildFilters(),
                          const SizedBox(height: 14),
                          _buildSummaryRow(),
                          const SizedBox(height: 12),
                          _buildTableCard(),
                          const SizedBox(height: 14),
                          _buildPagination(),
                          const SizedBox(height: 88),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              )
            : const AccessDeniedView(moduleLabel: 'website inquiries'),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.language_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Website Inquiries',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A56),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Contact-form submissions from the website',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isRefreshing ? null : () => _loadEnquiries(showLoader: false),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final statusOptions = <String>[
      'new',
      'follow_up',
      'site_visit_scheduled',
      'converted',
      'lost',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildSearchField(
          width: 230,
          controller: _searchController,
          hintText: 'Search name, phone, email',
          onChanged: _onSearchChanged,
          prefixIcon: Icons.search_rounded,
        ),
        _buildDropdownField(
          width: 170,
          value: _selectedStatus,
          hint: 'All Status',
          items: statusOptions,
          onChanged: (value) {
            setState(() {
              _selectedStatus = value;
              _currentPage = 1;
            });
            _loadEnquiries();
          },
        ),
        _buildDropdownField(
          width: 220,
          value: _selectedProject,
          hint: 'Filter by project...',
          items: _projectOptions,
          onChanged: (value) {
            setState(() {
              _selectedProject = value;
              _currentPage = 1;
            });
            _loadEnquiries();
          },
        ),
        _buildDateField(
          label: _fromDate == null ? 'From' : _formatDate(_fromDate),
          onTap: () => _pickDate(isFrom: true),
          onClear: _fromDate == null ? null : () => _clearDate(isFrom: true),
        ),
        _buildDateField(
          label: _toDate == null ? 'To' : _formatDate(_toDate),
          onTap: () => _pickDate(isFrom: false),
          onClear: _toDate == null ? null : () => _clearDate(isFrom: false),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Showing ${_enquiries.length} of $_totalItems inquiries',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF41526E),
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _pageSizeOptions.contains(_pageSize)
                  ? _pageSize
                  : _pageSizeOptions[1],
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _pageSizeOptions
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size / page'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _pageSize = value;
                  _currentPage = 1;
                });
                _loadEnquiries();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard() {
    if (_loadError != null && !_isLoading) {
      return _buildStateCard(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load website inquiries',
        subtitle: _loadError!,
      );
    }

    if (_enquiries.isEmpty && !_isLoading) {
      return _buildStateCard(
        icon: Icons.inbox_outlined,
        title: 'No website inquiries found',
        subtitle: 'Try changing the search or filter values.',
      );
    }

    return Column(
      children: [
        for (final enquiry in _enquiries) ...[
          _buildEnquiryCard(enquiry),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildEnquiryCard(_WebsiteEnquiry enquiry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
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
              Expanded(child: _buildInquiryCell(enquiry)),
              const SizedBox(width: 10),
              _buildStatusChip(enquiry.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(
                  label: 'Source',
                  value: enquiry.source,
                  icon: Icons.language_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaItem(
                  label: 'Project',
                  value:
                      enquiry.projectName.isEmpty ? '-' : enquiry.projectName,
                  icon: Icons.apartment_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMetaItem(
            label: 'Received',
            value: enquiry.receivedAt == null
                ? '-'
                : _displayDateFormat.format(enquiry.receivedAt!),
            icon: Icons.calendar_today_outlined,
          ),
          if (enquiry.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9EEF6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF556987),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enquiry.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 118,
                child: ElevatedButton.icon(
                  onPressed: () => _openConvertDialog(enquiry),
                  icon: const Icon(Icons.arrow_circle_right_outlined, size: 16),
                  label: const Text('Convert'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openEditDialog(enquiry),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(96, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _deleteEnquiry(enquiry),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(104, 38),
                  side: const BorderSide(color: Color(0xFFF4C7CC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCell(_WebsiteEnquiry enquiry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enquiry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F1E35),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _buildContactPill(
              icon: Icons.call_outlined,
              text: enquiry.phone.isEmpty ? '-' : enquiry.phone,
            ),
            _buildContactPill(
              icon: Icons.mail_outline_rounded,
              text: enquiry.email.isEmpty ? '-' : enquiry.email,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF70839C),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF24364F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9EEF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF8092AA)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60748D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _statusBackground(status),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _prettyStatus(status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _statusForeground(status),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final currentCount = _enquiries.length;
    if (_totalItems == 0) {
      return const Text(
        'Page 0 of 0 · 0 total',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF556987),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Page $_currentPage of $_totalPages · $_totalItems total',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF556987),
            ),
          ),
        ),
        if (_totalPages > 1) ...[
          OutlinedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage -= 1);
                    _loadEnquiries(showLoader: false);
                  }
                : null,
            child: const Text('Previous'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: currentCount > 0 && _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage += 1);
                    _loadEnquiries(showLoader: false);
                  }
                : null,
            child: const Text('Next'),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchField({
    required double width,
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
    required IconData prefixIcon,
  }) {
    return Container(
      width: width,
      height: 42,
      decoration: _filterDecoration(),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required double width,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: width,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _filterDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(_prettyStatus(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required VoidCallback onTap,
    required VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: _filterDecoration(),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: label == 'From' || label == 'To'
                      ? Colors.grey.shade500
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _filterDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100F172A),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConvertMode { leadOnly, leadWithFollowUp, leadWithSiteVisit }

class _WebsiteEnquiry {
  const _WebsiteEnquiry({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.message,
    required this.projectName,
    required this.source,
    required this.status,
    required this.receivedAt,
    required this.rawData,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String message;
  final String projectName;
  final String source;
  final String status;
  final DateTime? receivedAt;
  final Map<String, dynamic> rawData;

  factory _WebsiteEnquiry.fromApi(Map<String, dynamic> json) {
    String readString(dynamic value) {
      if (value == null) {
        return '';
      }
      return value.toString().trim();
    }

    Map<String, dynamic>? readMap(dynamic value) {
      return value is Map<String, dynamic> ? value : null;
    }

    DateTime? readDate(dynamic value) {
      final raw = readString(value);
      if (raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw)?.toLocal();
    }

    final projectMap = readMap(json['project']);
    final rawSource = readString(
      json['source'] ?? json['lead_source'] ?? json['enquiry_source'],
    );

    return _WebsiteEnquiry(
      id: readString(json['id'] ?? json['lead_id'] ?? json['uuid']),
      name: readString(
        json['name'] ??
            json['full_name'] ??
            json['contact_name'] ??
            json['customer_name'],
      ).isEmpty
          ? 'Unknown Inquiry'
          : readString(
              json['name'] ??
                  json['full_name'] ??
                  json['contact_name'] ??
                  json['customer_name'],
            ),
      phone: readString(
        json['phone'] ?? json['phone_number'] ?? json['mobile'],
      ),
      email: readString(json['email']),
      message: readString(
        json['message'] ??
            json['enquiry_message'] ??
            json['description'] ??
            json['notes'] ??
            json['remark'],
      ),
      projectName: readString(
        json['project_name'] ?? projectMap?['name'] ?? json['projectName'],
      ),
      source: rawSource.isEmpty ? 'Website' : rawSource,
      status: readString(json['status'] ?? json['stage']).isEmpty
          ? 'new'
          : readString(json['status'] ?? json['stage']),
      receivedAt: readDate(
        json['received_at'] ??
            json['submitted_at'] ??
            json['created_at'] ??
            json['createdAt'],
      ),
      rawData: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toLeadPrefill(_ConvertMode mode) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final base = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'source': source.isEmpty ? 'Website' : source,
      'project_name': projectName,
      'notes': message,
    };

    switch (mode) {
      case _ConvertMode.leadOnly:
        return <String, dynamic>{
          ...base,
          'status': 'new',
        };
      case _ConvertMode.leadWithFollowUp:
        return <String, dynamic>{
          ...base,
          'status': 'follow_up',
          'title': 'Website inquiry follow-up',
          'due_date': tomorrow.toUtc().toIso8601String(),
          'priority': 'medium',
          'next_followup_time': tomorrow.toUtc().toIso8601String(),
        };
      case _ConvertMode.leadWithSiteVisit:
        return <String, dynamic>{
          ...base,
          'status': 'site_visit_scheduled',
          'visit_date':
              '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}',
          'visit_time': '10:00',
        };
    }
  }
}

class _ConvertWebsiteEnquiryDialog extends StatelessWidget {
  const _ConvertWebsiteEnquiryDialog({required this.enquiry});

  final _WebsiteEnquiry enquiry;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Convert Inquiry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A56),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      enquiry.name.isEmpty
                          ? '?'
                          : enquiry.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enquiry.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          enquiry.phone.isEmpty ? enquiry.email : enquiry.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'This opens the lead creation flow with the enquiry details prefilled. You can optionally prepare a follow-up or site visit at the same time.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            _ConvertActionTile(
              title: 'Lead Only',
              subtitle: 'Just create a lead from this inquiry',
              icon: Icons.person_add_alt_1_rounded,
              iconGradient: const [Color(0xFF1D8CF8), Color(0xFF2563EB)],
              onTap: () => Navigator.of(context).pop(_ConvertMode.leadOnly),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ConvertActionCard(
                    title: 'Lead + Follow-Up',
                    subtitle: 'Also prepare a follow-up task',
                    icon: Icons.call_outlined,
                    gradient: const [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
                    onTap: () => Navigator.of(context)
                        .pop(_ConvertMode.leadWithFollowUp),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ConvertActionCard(
                    title: 'Lead + Site Visit',
                    subtitle: 'Also prepare a site visit',
                    icon: Icons.event_available_outlined,
                    gradient: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
                    onTap: () => Navigator.of(context)
                        .pop(_ConvertMode.leadWithSiteVisit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvertActionTile extends StatelessWidget {
  const _ConvertActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconGradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> iconGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _GradientIconBox(icon: icon, gradient: iconGradient),
            const SizedBox(width: 16),
            Column(
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvertActionCard extends StatelessWidget {
  const _ConvertActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _GradientIconBox(icon: icon, gradient: gradient),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientIconBox extends StatelessWidget {
  const _GradientIconBox({
    required this.icon,
    required this.gradient,
  });

  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220082F3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _EditWebsiteEnquiryDialog extends StatefulWidget {
  const _EditWebsiteEnquiryDialog({
    required this.enquiry,
    required this.authProvider,
  });

  final _WebsiteEnquiry enquiry;
  final AuthProvider authProvider;

  @override
  State<_EditWebsiteEnquiryDialog> createState() =>
      _EditWebsiteEnquiryDialogState();
}

class _EditWebsiteEnquiryDialogState extends State<_EditWebsiteEnquiryDialog> {
  late final TextEditingController _phoneController;
  late final TextEditingController _projectController;
  late final TextEditingController _messageController;
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.enquiry.phone);
    _projectController =
        TextEditingController(text: widget.enquiry.projectName);
    _messageController = TextEditingController(text: widget.enquiry.message);
    _status = widget.enquiry.status;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _projectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.authProvider.editLead(
        id: widget.enquiry.id,
        phone: _phoneController.text.trim(),
        source: widget.enquiry.source,
        status: _status,
        projectName: _projectController.text.trim(),
        budget: _readString(
          widget.enquiry.rawData['budget'] ??
              widget.enquiry.rawData['budget_range'],
        ),
        locationPreference: _readString(
          widget.enquiry.rawData['location_preference'] ??
              widget.enquiry.rawData['locationPreference'],
        ),
        configuration: _readString(widget.enquiry.rawData['configuration']),
        token: widget.authProvider.currentAuthToken,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppErrorHandler.friendlyMessage(error))),
        );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Website Inquiry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102A56),
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.enquiry.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.enquiry.email.isEmpty ? 'No email' : widget.enquiry.email,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: inputDecoration.copyWith(
                      labelText: 'Phone',
                      hintText: 'Enter phone number',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: inputDecoration.copyWith(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(
                        value: 'follow_up',
                        child: Text('Follow Up'),
                      ),
                      DropdownMenuItem(
                        value: 'site_visit_scheduled',
                        child: Text('Site Visit Scheduled'),
                      ),
                      DropdownMenuItem(
                        value: 'converted',
                        child: Text('Converted'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _status = value);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _projectController,
              decoration: inputDecoration.copyWith(
                labelText: 'Project',
                hintText: 'Enter project name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 5,
              readOnly: true,
              decoration: inputDecoration.copyWith(
                labelText: 'Website Message',
                hintText: 'No message',
                helperText:
                    'Message is shown for reference. The current backend edit API does not persist this field.',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
