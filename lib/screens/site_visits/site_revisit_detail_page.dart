import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/site_visits/feedback_form_dialog.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class SiteRevisitDetailPage extends StatefulWidget {
  const SiteRevisitDetailPage({
    super.key,
    required this.revisitId,
  });

  final String revisitId;

  @override
  State<SiteRevisitDetailPage> createState() => _SiteRevisitDetailPageState();
}

class _SiteRevisitDetailPageState extends State<SiteRevisitDetailPage> {
  final AuthProvider _authProvider = AuthProvider();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _authProvider.siteRevisitDetail(
        id: widget.revisitId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _data = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: const CrmAppBar(
        title: 'Re-visit Details',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard()
            else if (_data == null)
              _emptyCard()
            else ...[
              _headerCard(),
              const SizedBox(height: 10),
              _infoSection(
                'Reason',
                _readString(_data!['reason'], fallback: '-'),
              ),
              const SizedBox(height: 10),
              _infoSection(
                'Notes',
                _readString(_data!['notes'], fallback: '-'),
              ),
              const SizedBox(height: 10),
              _leadCard(),
              const SizedBox(height: 10),
              _projectCard(),
              const SizedBox(height: 10),
              _assigneeCard(),
              if (_isCompletedStatus(
                  _readString(_data!['status'], fallback: ''))) ...[
                const SizedBox(height: 10),
                _feedbackCard(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final status = _readString(_data!['status'], fallback: 'scheduled');
    final date = _formatDate(_readString(_data!['visit_date'], fallback: ''));
    final time = _readString(_data!['visit_time'], fallback: '-');
    final transport =
        _data!['transport_arranged'] == true ? 'Arranged' : 'Not Arranged';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.repeat_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Re-visit',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_readString(_data!['id'], fallback: '-')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniTile('Date', date)),
              const SizedBox(width: 8),
              Expanded(child: _miniTile('Time', time)),
              const SizedBox(width: 8),
              Expanded(child: _miniTile('Transport', transport)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadCard() {
    return _entityCard(
      title: 'Lead Information',
      primary: _nestedString('lead', 'name', fallback: 'N/A'),
      secondary: _nestedString('lead', 'phone', fallback: '-'),
      tertiary: _nestedString('lead', 'email', fallback: '-'),
      icon: Icons.person_outline,
    );
  }

  Widget _projectCard() {
    return _entityCard(
      title: 'Project',
      primary: _nestedString('project', 'name', fallback: 'N/A'),
      secondary: _nestedString('project', 'city', fallback: '-'),
      tertiary: _nestedString('project', 'address', fallback: '-'),
      icon: Icons.apartment_outlined,
    );
  }

  Widget _assigneeCard() {
    return _entityCard(
      title: 'Coordinator',
      primary: _nestedString('assigned_to', 'full_name', fallback: 'N/A'),
      secondary: _nestedString('assigned_to', 'id', fallback: '-'),
      tertiary: '',
      icon: Icons.groups_outlined,
    );
  }

  Widget _feedbackCard() {
    final feedback = _feedbackData();
    final hasFeedback = _hasFeedback(feedback);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.rate_review_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Feedback',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Open the feedback form for this completed re-visit.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasFeedback ? null : _openFeedbackForm,
              icon: const Icon(Icons.star_border_rounded),
              label: Text(
                hasFeedback ? 'Feedback Submitted' : 'Submit Feedback',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (hasFeedback) ...[
            const SizedBox(height: 10),
            const Text(
              'Feedback can be submitted only one time for a re-visit.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nestedString(
    String parentKey,
    String childKey, {
    required String fallback,
  }) {
    final nested = _asMap(_data![parentKey]);
    return _readString(nested[childKey], fallback: fallback);
  }

  Widget _entityCard({
    required String title,
    required String primary,
    required String secondary,
    required String tertiary,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(primary,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tertiary.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tertiary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status.toLowerCase()) {
      'done' || 'completed' => const Color(0xFF16A34A),
      'rescheduled' => const Color(0xFFD97706),
      'cancelled' || 'canceled' => const Color(0xFFDC2626),
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  bool _isCompletedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' || normalized == 'done';
  }

  Map<String, dynamic> _feedbackData() {
    final source = _data ?? const <String, dynamic>{};
    final nested = _asMap(source['feedback']);

    return <String, dynamic>{
      'rating': source['rating'] ?? nested['rating'],
      'client_reaction': source['client_reaction'] ?? nested['client_reaction'],
      'interested_in': source['interested_in'] ?? nested['interested_in'],
      'next_step': source['next_step'] ?? nested['next_step'],
      'remarks':
          source['feedback_remarks'] ?? source['remarks'] ?? nested['remarks'],
    }..removeWhere(
        (key, value) => value == null || value.toString().trim().isEmpty);
  }

  bool _hasFeedback(Map<String, dynamic> feedback) {
    return feedback.isNotEmpty;
  }

  Future<void> _openFeedbackForm() async {
    final feedback = _feedbackData();
    final hasFeedback = _hasFeedback(feedback);
    if (hasFeedback) {
      _showSnackBar('Feedback has already been submitted for this re-visit.');
      return;
    }
    final result = await showFeedbackFormDialog(
      context: context,
      title: 'Submit Feedback',
      submitLabel: 'Submit Feedback',
      initialData: FeedbackFormData.fromMap(feedback),
    );

    if (result == null) {
      return;
    }

    try {
      await _authProvider.submitSiteRevisitFeedback(
        id: widget.revisitId,
        rating: result.rating,
        clientReaction: result.apiClientReaction,
        interestedIn: result.interestedIn,
        nextStep: result.apiNextStep,
        remarks: result.remarks,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Feedback submitted successfully.');
      await _loadDetail();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error ?? 'Unable to load details',
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadDetail,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No details found.',
        style: TextStyle(
            color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
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
}

