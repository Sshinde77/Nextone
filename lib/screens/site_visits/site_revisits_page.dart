// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/site_visits/site_revisit_detail_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/permission_guard.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';
import 'package:nextone/widgets/site_revisit_data_card.dart';
import 'package:nextone/widgets/pagination_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteRevisitsPage extends StatefulWidget {
  const SiteRevisitsPage({
    super.key,
    this.showBackButton = false,
  });

  final bool showBackButton;

  @override
  State<SiteRevisitsPage> createState() => _SiteRevisitsPageState();
}

enum _RevisitScope { myItems, team }

class _SiteRevisitsPageState extends State<SiteRevisitsPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  String _currentRole = '';
  _RevisitScope _selectedScope = _RevisitScope.team;
  String _statusFilter = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadRevisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isMyScope => _selectedScope == _RevisitScope.myItems;
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
      // Keep team view visible if role lookup fails.
    }
  }

  Future<void> _loadRevisits({int? page}) async {
    final nextPage = page ?? _currentPage;
    final apiStatus =
        _statusFilter == 'all' ? null : _statusFilter.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = _isMyScope
          ? await _authProvider.myRevisits(
              token: _authProvider.currentAuthToken,
              from: _monthStart,
              to: _monthEnd,
              page: nextPage,
              perPage: _perPage,
            )
          : await _authProvider.siteRevisits(
              token: _authProvider.currentAuthToken,
              status: apiStatus,
              page: nextPage,
              perPage: _perPage,
            );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _currentPage = result.currentPage;
        _totalPages = result.totalPages;
        _totalItems = result.totalItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppErrorHandler.friendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items.where(_matchesFilter).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: 'Re-visits',
        showBackButton: widget.showBackButton,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRevisits,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            // const Text(
            //   'Follow-up visits linked to original site visits',
            //   style: TextStyle(
            //     color: AppColors.textSecondary,
            //     fontWeight: FontWeight.w600,
            //   ),
            // ),
            const SizedBox(height: 12),
            if (_showScopeTabs) ...[
              _buildScopeTabs(),
              const SizedBox(height: 12),
            ],
            _buildKpiRow(),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openScheduleRevisit,
                icon: const Icon(Icons.add),
                label: const Text('Schedule Re-visit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSearchAndFilter(),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (visibleItems.isEmpty)
              _buildEmpty()
            else ...[
              ...visibleItems.map(_buildCard),
              const SizedBox(height: 12),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  String get _monthStart {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return _formatApiDate(start);
  }

  String get _monthEnd {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1, 0);
    return _formatApiDate(end);
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
              label: 'My Revisit',
              isActive: _isMyScope,
              onTap: () {
                if (_isMyScope) return;
                setState(() {
                  _selectedScope = _RevisitScope.myItems;
                  _currentPage = 1;
                });
                _loadRevisits(page: 1);
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
                  _selectedScope = _RevisitScope.team;
                  _currentPage = 1;
                });
                _loadRevisits(page: 1);
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

  Widget _buildKpiRow() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _kpiTile('Scheduled', _countByStatus('scheduled').toString(),
              const Color(0xFF2563EB)),
          _kpiTile('Rescheduled', _countByStatus('rescheduled').toString(),
              const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search lead, project...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'done', child: Text('Done')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(
                    value: 'rescheduled', child: Text('Rescheduled')),
                DropdownMenuItem(value: 'no_show', child: Text('No Show')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _statusFilter = value;
                  _currentPage = 1;
                });
                _loadRevisits(page: 1);
              },
            ),
          ),
        ),
        IconButton(
          onPressed: _loadRevisits,
          icon: const Icon(Icons.refresh),
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
      onPageChanged: (page) => _loadRevisits(page: page),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final leadName = _readString(item['lead_name'], fallback: 'N/A');
    final leadPhone = _readString(item['lead_phone'], fallback: 'N/A');
    final projectName = _readString(item['project_name'], fallback: 'N/A');
    final projectCity = _readString(item['project_city'], fallback: 'N/A');
    final assignedTo = _readString(item['assigned_to_name'], fallback: 'N/A');
    final reason = _readString(item['reason'], fallback: '-');
    final statusRaw = _readString(item['status'], fallback: 'scheduled');
    final transport = item['transport_arranged'] == true ? 'Yes' : 'No';
    final visitDate = _formatDate(
      _readString(item['visit_date'], fallback: ''),
    );
    final visitTime = _readString(item['visit_time'], fallback: '-');
    final feedback = _formatFeedbackValue(item['client_reaction']);
    final nextStep = _formatFeedbackValue(item['next_step']);
    final rating = _readInt(item['rating']);

    return SiteRevisitDataCard(
      leadName: leadName,
      leadPhone: leadPhone,
      projectName: projectName,
      projectCity: projectCity,
      visitDateLabel: visitDate,
      visitTimeLabel: visitTime,
      assignedToName: assignedTo,
      transportLabel: transport,
      statusLabel: statusRaw,
      statusColor: _statusColor(statusRaw),
      reason: reason,
      feedback: feedback,
      nextStep: nextStep,
      rating: rating,
      onView: () => _openRevisitDetail(item),
      onEdit: () => _openEditRevisit(item),
      onStatus: () => _openStatusUpdateDialog(item),
      onCall: () => _launchCaller(leadPhone),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error ?? 'Unable to load re-visits.',
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadRevisits,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No re-visits found for the selected filters.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  String _toYmd(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _formatFeedbackValue(dynamic value) {
    final raw = _readString(value, fallback: '');
    if (raw.isEmpty) return '-';
    final normalized = raw.trim().replaceAll('_', ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  Future<void> _launchCaller(String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty || normalizedPhone.toLowerCase() == 'n/a') {
      return;
    }
    final uri = Uri.parse('tel:$normalizedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '-';
    final local = parsed.toLocal();
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
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return const Color(0xFF0A9A55);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      case 'rescheduled':
        return const Color(0xFFD97706);
      default:
        return AppColors.primary;
    }
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    final status =
        _readString(item['status'], fallback: 'scheduled').toLowerCase().trim();
    final query = _searchController.text.trim().toLowerCase();
    final lead = _readString(item['lead_name'], fallback: '').toLowerCase();
    final project =
        _readString(item['project_name'], fallback: '').toLowerCase();
    final textMatch =
        query.isEmpty || lead.contains(query) || project.contains(query);
    final statusMatch = _statusFilter == 'all' || status == _statusFilter;
    return textMatch && statusMatch;
  }

  int _countByStatus(String status) {
    return _items
        .where(
          (e) =>
              _readString(e['status'], fallback: 'scheduled')
                  .toLowerCase()
                  .trim() ==
              status,
        )
        .length;
  }

  Future<void> _openScheduleRevisit() async {
    final allowed = await PermissionGuard.allowModuleAction(
      context,
      authProvider: _authProvider,
      module: 'revisits',
      action: 'create',
      moduleLabel: 're-visits',
    );
    if (!allowed) return;

    final created = await _showScheduleRevisitDialog();
    if (created != true || !mounted) return;
    await _loadRevisits();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Re-visit scheduled successfully')),
      );
  }

  Future<bool?> _showScheduleRevisitDialog() async {
    final visits = await _loadOriginalVisitsForDropdown();
    if (!mounted) return false;

    if (visits.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No original site visits available')),
        );
      return false;
    }

    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    _OriginalVisitOption? selectedVisit = visits.first;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool transportArranged = false;
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            String dateLabel =
                selectedDate == null ? 'dd-mm-yyyy' : _toYmd(selectedDate!);
            String timeLabel = selectedTime == null
                ? '--:--'
                : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              setLocalState(() => selectedDate = picked);
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    selectedTime ?? const TimeOfDay(hour: 11, minute: 0),
              );
              if (picked == null) return;
              setLocalState(() => selectedTime = picked);
            }

            Future<void> submit() async {
              if (selectedVisit == null ||
                  selectedDate == null ||
                  selectedTime == null ||
                  reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Original visit, date, time and reason are required.',
                      ),
                    ),
                  );
                return;
              }

              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.createSiteRevisit(
                  originalVisitId: selectedVisit!.id,
                  visitDate: _toYmd(selectedDate!),
                  visitTime: timeLabel,
                  reason: reasonController.text.trim(),
                  notes: notesController.text.trim(),
                  transportArranged: transportArranged,
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                  );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 520,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Schedule Re-visit',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text('Original Site Visit *'),
                        const SizedBox(height: 6),
                        SearchableDropdownField<_OriginalVisitOption>(
                          label: 'Original Site Visit *',
                          sheetTitle: 'Original Site Visit',
                          showFieldLabel: false,
                          value: selectedVisit,
                          hintText: 'Select original visit...',
                          items: visits
                              .map(
                                (v) => SearchableDropdownItem<_OriginalVisitOption>(
                                  value: v,
                                  label: v.label,
                                  subtitle: v.assigneeName,
                                ),
                              )
                              .toList(),
                          enabled: !isSubmitting,
                          onChanged: (value) =>
                              setLocalState(() => selectedVisit = value),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Date *',
                                value: dateLabel,
                                icon: Icons.calendar_today_outlined,
                                onTap: isSubmitting ? null : pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Time *',
                                value: timeLabel,
                                icon: Icons.access_time_outlined,
                                onTap: isSubmitting ? null : pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Assign To'),
                        const SizedBox(height: 6),
                        TextFormField(
                          enabled: false,
                          initialValue: selectedVisit?.assigneeName ?? '-',
                          decoration: _fieldDecoration(
                            hint: "Default: original visit's assignee",
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Reason for Re-visit *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: reasonController,
                          enabled: !isSubmitting,
                          decoration: _fieldDecoration(
                            hint: 'Client wanted to see 3BHK units again...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Notes'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          decoration: _fieldDecoration(
                            hint: 'Bring updated price list...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: transportArranged,
                          onChanged: isSubmitting
                              ? null
                              : (value) => setLocalState(
                                    () => transportArranged = value ?? false,
                                  ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Transport arranged for client'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSubmitting ? null : submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Schedule Re-visit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    reasonController.dispose();
    notesController.dispose();
    return result;
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                Icon(icon, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<_OriginalVisitOption>> _loadOriginalVisitsForDropdown() async {
    final result = await _authProvider.siteVisits(
      token: _authProvider.currentAuthToken,
      page: 1,
      perPage: 200,
    );

    return result.items
        .map((item) {
          final id = _readString(item['id'], fallback: '');
          final leadName = _readString(item['lead_name'], fallback: 'Lead');
          final projectName =
              _readString(item['project_name'], fallback: 'Project');
          final assigneeName =
              _readString(item['assigned_to_name'], fallback: 'Unassigned');
          return _OriginalVisitOption(
            id: id,
            assigneeName: assigneeName,
            label: '$leadName - $projectName',
          );
        })
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<void> _openEditRevisit(Map<String, dynamic> item) async {
    final revisitId = _readString(item['id'], fallback: '');
    if (revisitId.isEmpty) return;

    DateTime? selectedDate = DateTime.tryParse(
      _readString(item['visit_date'], fallback: ''),
    )?.toLocal();
    TimeOfDay? selectedTime;
    final rawTime = _readString(item['visit_time'], fallback: '');
    final timeParts = rawTime.split(':');
    if (timeParts.length >= 2) {
      selectedTime = TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 0,
        minute: int.tryParse(timeParts[1]) ?? 0,
      );
    }

    final reasonController = TextEditingController(
      text: _readString(item['reason'], fallback: ''),
    );
    final notesController = TextEditingController(
      text: _readString(item['notes'], fallback: ''),
    );
    final rescheduleReasonController = TextEditingController();
    bool transportArranged = item['transport_arranged'] == true;
    bool isSubmitting = false;

    final usersRaw = await _authProvider.assignmentUsers(
      token: _authProvider.currentAuthToken,
    );
    bool isActiveUser(Map<String, dynamic> user) {
      final value = user['is_active'] ??
          user['isActive'] ??
          user['active'] ??
          user['status'];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final normalized = _readString(value, fallback: '').toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'active';
    }

    String roleLabel(Map<String, dynamic> user) {
      final rawRole = _readString(
        user['role'] ??
            user['user_role'] ??
            user['userRole'] ??
            user['designation'],
        fallback: '',
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

    final membersById = <String, _TeamMemberOption>{};
    for (final raw in usersRaw) {
      if (!isActiveUser(raw)) {
        continue;
      }
      final id = _readString(
        raw['id'] ?? raw['user_id'] ?? raw['userId'] ?? raw['uuid'],
        fallback: '',
      );
      if (id.isEmpty) {
        continue;
      }
      final baseName = _readString(
        raw['full_name'] ??
            raw['name'] ??
            '${raw['first_name'] ?? ''} ${raw['last_name'] ?? ''}',
        fallback: 'Unknown',
      );
      final readableRole = roleLabel(raw);
      membersById[id] = _TeamMemberOption(
        id: id,
        name: readableRole.isEmpty ? baseName : '$baseName ($readableRole)',
      );
    }
    final members = membersById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _TeamMemberOption? selectedMember;
    final assignedToId = _readString(item['assigned_to'], fallback: '');
    if (assignedToId.isNotEmpty) {
      for (final m in members) {
        if (m.id == assignedToId) {
          selectedMember = m;
          break;
        }
      }
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final dateLabel =
                selectedDate == null ? 'dd-mm-yyyy' : _toYmd(selectedDate!);
            final timeLabel = selectedTime == null
                ? '--:--'
                : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) return;
              setLocalState(() => selectedDate = picked);
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
              );
              if (picked == null) return;
              setLocalState(() => selectedTime = picked);
            }

            Future<void> submit() async {
              if (selectedDate == null || selectedTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Visit date and time are required.')),
                );
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.editSiteRevisit(
                  id: revisitId,
                  visitDate: _toYmd(selectedDate!),
                  visitTime: timeLabel,
                  rescheduleReason: rescheduleReasonController.text.trim(),
                  assignedTo: selectedMember?.id,
                  reason: reasonController.text.trim(),
                  notes: notesController.text.trim(),
                  transportArranged: transportArranged,
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 600,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Edit Re-visit',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Date',
                                value: dateLabel,
                                icon: Icons.calendar_today_outlined,
                                onTap: isSubmitting ? null : pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pickerField(
                                label: 'Visit Time',
                                value: timeLabel,
                                icon: Icons.access_time_outlined,
                                onTap: isSubmitting ? null : pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text('Assign To'),
                        const SizedBox(height: 6),
                        SearchableDropdownField<_TeamMemberOption>(
                          label: 'Assign To',
                          sheetTitle: 'Assign To',
                          showFieldLabel: false,
                          value: selectedMember,
                          hintText: 'Select team member',
                          items: members
                              .map(
                                (m) => SearchableDropdownItem<_TeamMemberOption>(
                                  value: m,
                                  label: m.name,
                                ),
                              )
                              .toList(),
                          enabled: !isSubmitting,
                          onChanged: (v) =>
                              setLocalState(() => selectedMember = v),
                        ),
                        const SizedBox(height: 10),
                        const Text('Reason'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: reasonController,
                          enabled: !isSubmitting,
                          decoration:
                              _fieldDecoration(hint: 'Reason for re-visit...'),
                        ),
                        const SizedBox(height: 10),
                        const Text('Notes'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          decoration: _fieldDecoration(),
                        ),
                        const SizedBox(height: 10),
                        const Text('Reschedule Reason (if changing date/time)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: rescheduleReasonController,
                          enabled: !isSubmitting,
                          decoration: _fieldDecoration(
                            hint: 'Client requested morning slot...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: transportArranged,
                          onChanged: isSubmitting
                              ? null
                              : (value) => setLocalState(
                                    () => transportArranged = value ?? false,
                                  ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Transport arranged'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSubmitting ? null : submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Update Re-visit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    reasonController.dispose();
    notesController.dispose();
    rescheduleReasonController.dispose();
    if (updated == true && mounted) {
      await _loadRevisits();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Re-visit updated')));
    }
  }

  Future<void> _openStatusUpdateDialog(Map<String, dynamic> item) async {
    final revisitId = _readString(item['id'], fallback: '');
    if (revisitId.isEmpty) return;

    final noteController = TextEditingController();
    bool isSubmitting = false;
    String selectedStatus =
        _statusToUi(_readString(item['status'], fallback: 'scheduled'));

    final leadName = _readString(item['lead_name'], fallback: 'N/A');
    final projectName = _readString(item['project_name'], fallback: 'N/A');
    final visitDate =
        _formatDate(_readString(item['visit_date'], fallback: ''));
    final visitTime = _readString(item['visit_time'], fallback: '-');

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              if (selectedStatus.trim().isEmpty) return;
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.updateSiteRevisitStatus(
                  id: revisitId,
                  status: _uiToApiStatus(selectedStatus),
                  note: noteController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 560,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Update Re-visit Status',
                              style: TextStyle(
                                  fontSize: 34, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                _initials(leadName),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leadName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                    ),
                                  ),
                                  Text(
                                    '$visitDate · $visitTime · $projectName',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('New Status *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: _fieldDecoration(),
                        items: const [
                          DropdownMenuItem(
                              value: 'Scheduled', child: Text('Scheduled')),
                          DropdownMenuItem(
                              value: 'In Progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'Done', child: Text('Done')),
                          DropdownMenuItem(
                              value: 'Rescheduled', child: Text('Rescheduled')),
                          DropdownMenuItem(
                              value: 'Cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: isSubmitting
                            ? null
                            : (value) => setLocalState(
                                  () => selectedStatus = value ?? 'Scheduled',
                                ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Note (optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        enabled: !isSubmitting,
                        maxLines: 3,
                        decoration: _fieldDecoration(hint: 'Add a note...'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSubmitting ? null : submit,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Update Status'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    if (updated == true && mounted) {
      await _loadRevisits();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Re-visit status updated')));
    }
  }

  String _uiToApiStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'done':
        return 'done';
      case 'in progress':
        return 'in_progress';
      case 'rescheduled':
        return 'rescheduled';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return 'scheduled';
    }
  }

  String _statusToUi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'done':
      case 'completed':
        return 'Done';
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'rescheduled':
        return 'Rescheduled';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return 'Scheduled';
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _openRevisitDetail(Map<String, dynamic> item) async {
    final id = _readString(item['id'], fallback: '');
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteRevisitDetailPage(revisitId: id),
      ),
    );
  }
}

class _OriginalVisitOption {
  const _OriginalVisitOption({
    required this.id,
    required this.label,
    required this.assigneeName,
  });

  final String id;
  final String label;
  final String assigneeName;
}

class _TeamMemberOption {
  const _TeamMemberOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
