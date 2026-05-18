import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/auth_models.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class PhoneRequestsPage extends StatefulWidget {
  const PhoneRequestsPage({super.key});

  @override
  State<PhoneRequestsPage> createState() => _PhoneRequestsPageState();
}

class _PhoneRequestsPageState extends State<PhoneRequestsPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _updatingRequestIds = <String>{};

  String _currentRole = '';
  bool _isLoadingAccess = true;
  bool _isLoadingRequests = true;
  String? _errorMessage;
  String _selectedStatus = 'Pending';
  String _selectedScope = 'Pending';

  List<_PhoneRequest> _requests = <_PhoneRequest>[];

  bool get _isAdminReviewer =>
      RoleAccess.isAdmin(_currentRole) || RoleAccess.isSuperAdmin(_currentRole);

  bool get _isSalesManager => RoleAccess.isSalesManager(_currentRole);

  @override
  void initState() {
    super.initState();
    _loadAccessAndRequests();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessAndRequests() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        _isLoadingAccess = false;
        _selectedScope = _isAdminReviewer ? 'Pending' : 'My Requests';
      });
      await _loadRequests();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccess = false;
        _isLoadingRequests = false;
        _errorMessage = 'Unable to load phone request access.';
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _errorMessage = null;
    });

    try {
      LeadsListResult result;
      if (_isAdminReviewer) {
        result = _selectedScope == 'All Requests'
            ? await _authProvider.phoneRevealAll(
                page: 1,
                perPage: 20,
                token: _authProvider.currentAuthToken,
              )
            : await _authProvider.phoneRevealPending(
                page: 1,
                perPage: 20,
                token: _authProvider.currentAuthToken,
              );
      } else {
        result = await _authProvider.phoneRevealMyRequests(
          page: 1,
          perPage: 20,
          token: _authProvider.currentAuthToken,
        );
      }

      final mapped = result.items.map(_mapRequest).toList();
      if (!mounted) return;
      setState(() {
        _requests = mapped;
        _isLoadingRequests = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRequests = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  _PhoneRequest _mapRequest(Map<String, dynamic> json) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is num || value is bool) return value.toString().trim();
      }
      return '';
    }

    Map<String, dynamic>? readMap(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is Map<String, dynamic>) return value;
      }
      return null;
    }

    final lead = readMap(const ['lead', 'lead_data', 'leadData']);
    final requester = readMap(const ['requester', 'requested_by_user', 'user']);
    final reviewer = readMap(const ['reviewer', 'reviewed_by_user']);
    final leadName = read(const ['lead_name', 'leadName', 'name']) != ''
        ? read(const ['lead_name', 'leadName', 'name'])
        : _readNested(lead, const ['name', 'full_name']);
    final requesterName =
        read(const ['requester_name', 'requested_by_name', 'requestedByName']) != ''
        ? read(const ['requester_name', 'requested_by_name', 'requestedByName'])
        : _readNested(requester, const ['name', 'full_name', 'first_name']);
    final requesterRole =
        read(const ['requester_role', 'requested_by_role', 'requestedByRole']) != ''
            ? read(const ['requester_role', 'requested_by_role', 'requestedByRole'])
            : _readNested(requester, const ['role', 'designation']);
    final reviewerName = read(const ['reviewed_by_name', 'reviewedByName']) != ''
        ? read(const ['reviewed_by_name', 'reviewedByName']).trim()
        : _readNested(reviewer, const ['name', 'full_name']);
    final mineRaw = json['mine'] ?? json['is_mine'] ?? json['my_request'];
    final mine = mineRaw is bool
        ? mineRaw
        : mineRaw is num
            ? mineRaw != 0
            : mineRaw is String
                ? mineRaw.toLowerCase() == 'true'
                : false;

    return _PhoneRequest(
      id: read(const ['id', 'request_id', 'requestId']),
      leadName: leadName.isEmpty ? 'Lead' : leadName,
      requestedBy: requesterName.isEmpty ? 'Unknown' : requesterName,
      requesterRole: RoleAccess.label(requesterRole),
      reason: read(const ['reason', 'note', 'request_note', 'message']),
      requestedAt: _formatDateTime(read(const ['requested_at', 'created_at', 'createdAt'])),
      reviewedAt: _formatDateTime(read(const ['reviewed_at', 'updated_at', 'updatedAt'])),
      reviewedBy: reviewerName,
      status: _normalizeStatus(read(const ['status', 'request_status'])),
      phone: read(const ['lead_phone', 'phone', 'phone_number', 'mobile']) != ''
          ? read(const ['lead_phone', 'phone', 'phone_number', 'mobile'])
          : _readNested(lead, const ['phone', 'phone_number', 'mobile']),
      mine: mine,
    );
  }

  String _readNested(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return '';
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
    }
    return '';
  }

  String _normalizeStatus(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized == 'approved') return 'Approved';
    if (normalized == 'rejected' || normalized == 'declined') return 'Rejected';
    if (normalized == 'pending') return 'Pending';
    return raw.trim().isEmpty ? 'Pending' : raw.trim();
  }

  String _formatDateTime(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final parsed = DateTime.parse(raw).toLocal();
      final month = _monthName(parsed.month);
      final hour = parsed.hour == 0 ? 12 : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
      final minute = parsed.minute.toString().padLeft(2, '0');
      final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
      return '${parsed.day} $month ${parsed.year}, ${hour.toString().padLeft(2, '0')}:$minute $suffix';
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  List<_PhoneRequest> get _filteredRequests {
    final query = _searchController.text.trim().toLowerCase();
    return _requests.where((request) {
      final statusMatch =
          _selectedStatus == 'All' || request.status == _selectedStatus;
      if (!statusMatch) return false;
      if (query.isEmpty) return true;
      return request.leadName.toLowerCase().contains(query) ||
          request.requestedBy.toLowerCase().contains(query) ||
          request.reason.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _approveRequest(_PhoneRequest request) async {
    if (request.id.isEmpty) {
      _showSnackBar('Missing request id.');
      return;
    }
    setState(() => _updatingRequestIds.add(request.id));
    try {
      await _authProvider.approvePhoneReveal(
        id: request.id,
        note: 'Approved for follow-up',
        token: _authProvider.currentAuthToken,
      );
      await _loadRequests();
      _showSnackBar('Request approved.');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _updatingRequestIds.remove(request.id));
      }
    }
  }

  Future<void> _rejectRequest(_PhoneRequest request) async {
    if (request.id.isEmpty) {
      _showSnackBar('Missing request id.');
      return;
    }
    setState(() => _updatingRequestIds.add(request.id));
    try {
      await _authProvider.declinePhoneReveal(
        id: request.id,
        note: 'Not required at this stage',
        token: _authProvider.currentAuthToken,
      );
      await _loadRequests();
      _showSnackBar('Request declined.');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _updatingRequestIds.remove(request.id));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: const CrmAppBar(title: 'Phone Requests'),
      body: SafeArea(
        top: false,
        child: _isLoadingAccess
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadRequests,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildScopeTabs(),
                    const SizedBox(height: 12),
                    _buildFilters(),
                    const SizedBox(height: 14),
                    if (_isLoadingRequests)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null)
                      _buildErrorState()
                    else ...[
                      ..._filteredRequests.map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PhoneRequestCard(
                            request: request,
                            isAdminReviewer: _isAdminReviewer,
                            isSalesManager: _isSalesManager,
                            isBusy: _updatingRequestIds.contains(request.id),
                            onApprove: () => _approveRequest(request),
                            onReject: () => _rejectRequest(request),
                          ),
                        ),
                      ),
                      if (_filteredRequests.isEmpty) _buildEmptyState(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _isAdminReviewer
        ? 'Phone Number Access Control'
        : 'Phone Number Requests';
    final subtitle = _isAdminReviewer
        ? 'Review and manage requests to reveal lead phone numbers'
        : 'Request access to lead phone numbers for follow-ups';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isAdminReviewer
                  ? Icons.verified_user_outlined
                  : Icons.phone_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTabs() {
    final tabs = _isAdminReviewer
        ? const <String>['Pending', 'All Requests']
        : const <String>['My Requests'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = _selectedScope == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab),
              selected: selected,
              onSelected: (_) async {
                setState(() => _selectedScope = tab);
                await _loadRequests();
              },
              selectedColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by lead or requester',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (value) => setState(() => _selectedStatus = value),
          itemBuilder: (context) {
            const values = <String>['All', 'Pending', 'Approved', 'Rejected'];
            return values
                .map((status) => PopupMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ))
                .toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            _errorMessage ?? 'Unable to load requests.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadRequests,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'No requests found',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Try changing filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PhoneRequestCard extends StatelessWidget {
  const _PhoneRequestCard({
    required this.request,
    required this.isAdminReviewer,
    required this.isSalesManager,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final _PhoneRequest request;
  final bool isAdminReviewer;
  final bool isSalesManager;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusStyle(request.status);
    final initials = _initials(request.requestedBy);
    final canShowFullPhone = isAdminReviewer || request.status == 'Approved';
    final phoneValue = request.status == 'Approved'
        ? (canShowFullPhone ? request.phone : _maskedPhone(request.phone))
        : (request.phone.isEmpty
            ? 'Awaiting approval'
            : _maskedPhone(request.phone));

    if (!isAdminReviewer) {
      return _buildMyRequestCard(statusMeta.color, phoneValue);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE9EEF7),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.leadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.requestedBy,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusMeta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  request.status,
                  style: TextStyle(
                    color: statusMeta.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoPair(
            leftLabel: 'Requester Role',
            leftValue: request.requesterRole,
            rightLabel: 'Requested At',
            rightValue: request.requestedAt,
          ),
          const SizedBox(height: 8),
          _infoPair(
            leftLabel: 'Reason',
            leftValue: request.reason.isEmpty ? '-' : request.reason,
            rightLabel: 'Reviewed By',
            rightValue: request.reviewedBy.isEmpty ? '-' : request.reviewedBy,
          ),
          const SizedBox(height: 8),
          _infoPair(
            leftLabel: 'Phone (if approved)',
            leftValue: phoneValue,
            rightLabel: 'Reviewed At',
            rightValue: request.reviewedAt.isEmpty ? '-' : request.reviewedAt,
            rightIsDim: request.reviewedAt.isEmpty,
            leftAsLink: request.status == 'Approved' && canShowFullPhone,
          ),
          const SizedBox(height: 12),
          if (isAdminReviewer && request.status == 'Pending')
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE9F8EF),
                      foregroundColor: const Color(0xFF198754),
                    ),
                    onPressed: isBusy ? null : onApprove,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(isBusy ? 'Updating...' : 'Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC3545),
                      side: const BorderSide(color: Color(0xFFF2C9CF)),
                    ),
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                request.status == 'Pending'
                    ? 'Pending admin approval'
                    : request.status == 'Rejected'
                        ? 'Request declined'
                        : (isSalesManager
                            ? 'Number available above'
                            : 'Status updated'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyRequestCard(Color statusColor, String phoneValue) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metaItem(label: 'Lead', value: request.leadName),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaItem(
                  label: 'Your Reason',
                  value: request.reason.isEmpty ? '-' : request.reason,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        request.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaItem(
                  label: 'Phone (if approved)',
                  value: phoneValue,
                  asLink: request.status == 'Approved' && phoneValue.isNotEmpty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metaItem(
                  label: 'Requested At',
                  value: request.requestedAt.isEmpty ? '-' : request.requestedAt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaItem(
                  label: 'Reviewed At',
                  value: request.reviewedAt.isEmpty ? '-' : request.reviewedAt,
                  dim: request.reviewedAt.isEmpty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPair({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    bool rightIsDim = false,
    bool leftAsLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _metaItem(
            label: leftLabel,
            value: leftValue,
            asLink: leftAsLink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metaItem(
            label: rightLabel,
            value: rightValue,
            dim: rightIsDim,
          ),
        ),
      ],
    );
  }

  Widget _metaItem({
    required String label,
    required String value,
    bool dim = false,
    bool asLink = false,
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
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: asLink
                ? AppColors.primary
                : (dim ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  ({Color color}) _statusStyle(String status) {
    switch (status) {
      case 'Approved':
        return (color: const Color(0xFF198754));
      case 'Rejected':
        return (color: const Color(0xFFDC3545));
      default:
        return (color: const Color(0xFFC47A00));
    }
  }

  String _maskedPhone(String phone) {
    final value = phone.trim();
    if (value.isEmpty) return 'Not available';
    final keepCount = (value.length / 2).ceil();
    final hiddenCount = value.length - keepCount;
    if (hiddenCount <= 0) return value;
    return '${value.substring(0, keepCount)}${'x' * hiddenCount}';
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _PhoneRequest {
  const _PhoneRequest({
    required this.id,
    required this.leadName,
    required this.requestedBy,
    required this.requesterRole,
    required this.reason,
    required this.requestedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.status,
    required this.phone,
    required this.mine,
  });

  final String id;
  final String leadName;
  final String requestedBy;
  final String requesterRole;
  final String reason;
  final String requestedAt;
  final String reviewedAt;
  final String reviewedBy;
  final String status;
  final String phone;
  final bool mine;
}
