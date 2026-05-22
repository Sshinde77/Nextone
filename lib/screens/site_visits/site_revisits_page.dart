import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/site_revisit_data_card.dart';

class SiteRevisitsPage extends StatefulWidget {
  const SiteRevisitsPage({
    super.key,
    this.showBackButton = false,
  });

  final bool showBackButton;

  @override
  State<SiteRevisitsPage> createState() => _SiteRevisitsPageState();
}

class _SiteRevisitsPageState extends State<SiteRevisitsPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadRevisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRevisits() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _authProvider.siteRevisits(
        from: _toYmd(from),
        to: _toYmd(to),
        token: _authProvider.currentAuthToken,
        page: 1,
        perPage: 50,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
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
            else
              ...visibleItems.map(_buildCard),
          ],
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
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(
                    value: 'rescheduled', child: Text('Rescheduled')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _statusFilter = value);
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
    final feedback = _readString(item['client_reaction'], fallback: '-');

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
        'No re-visits found for current month.',
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
    final status = _readString(item['status'], fallback: 'scheduled')
        .toLowerCase()
        .trim();
    final query = _searchController.text.trim().toLowerCase();
    final lead = _readString(item['lead_name'], fallback: '').toLowerCase();
    final project =
        _readString(item['project_name'], fallback: '').toLowerCase();
    final textMatch = query.isEmpty || lead.contains(query) || project.contains(query);
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SiteVisitFormPage()),
    );
    if (!mounted) return;
    await _loadRevisits();
  }
}
