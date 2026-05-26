import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class ClosureDetailPage extends StatefulWidget {
  const ClosureDetailPage({
    super.key,
    required this.lookupId,
  });

  final String lookupId;

  @override
  State<ClosureDetailPage> createState() => _ClosureDetailPageState();
}

class _ClosureDetailPageState extends State<ClosureDetailPage> {
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
      final detail = await _authProvider.closureLeadDetail(
        id: widget.lookupId,
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
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Closure Detail',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
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
              _statusCard(),
              const SizedBox(height: 10),
              _paymentCard(),
              const SizedBox(height: 10),
              _commissionCard(),
              const SizedBox(height: 10),
              _leadCard(),
              const SizedBox(height: 10),
              _closedByCard(),
              const SizedBox(height: 10),
              _notesCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final d = _data!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _readString(d['project_name'], fallback: 'Closure Project'),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_readString(d['id'], fallback: '-')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Booking Date: ${_formatDate(_readString(d['booking_date'], fallback: ''))}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(_readString(d['status'], fallback: 'confirmed')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniTile('Unit', _readString(d['unit_number'], fallback: '-'))),
              const SizedBox(width: 8),
              Expanded(child: _miniTile('Tower', _readString(d['tower_block'], fallback: '-'))),
              const SizedBox(width: 8),
              Expanded(child: _miniTile('Floor', d['floor_number']?.toString() ?? '-')),
              const SizedBox(width: 8),
              Expanded(child: _miniTile('Deal Value', _rupee(_toDouble(d['agreed_price'])))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Status',
      icon: Icons.check_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Current', _readString(d['status'], fallback: '-')),
          _row('Updated', _formatDateTime(_readString(d['updated_at'], fallback: ''))),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Payment Details',
      icon: Icons.credit_card_outlined,
      child: Column(
        children: [
          _row('Booking Amount', _rupee(_toDouble(d['booking_amount']))),
          _row('Payment Plan', _readString(d['payment_plan'], fallback: '-')),
          _row('Home Loan', d['loan_required'] == true ? 'Yes' : 'No'),
          _row('Loan Bank', _readString(d['loan_bank'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _commissionCard() {
    final d = _data!;
    final amount = _toDouble(d['commission_amount']);
    final percent = _toDouble(d['commission_percent']);
    return _sectionCard(
      title: 'Commission',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _row('Amount', '${_rupee(amount)} (${percent.toStringAsFixed(0)}%)'),
          _row('Payment Status', d['commission_paid'] == true ? 'Paid' : 'Pending'),
          _row(
            'Paid Date',
            _formatDate(_readString(d['commission_paid_date'], fallback: '')),
          ),
        ],
      ),
    );
  }

  Widget _leadCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Lead Information',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _row('Name', _readString(d['lead_name'], fallback: '-')),
          _row('Phone', _readString(d['lead_phone'], fallback: '-')),
          _row('Email', _readString(d['lead_email'], fallback: '-')),
          _row('Project', _readString(d['project_name'], fallback: '-')),
          _row('City', _readString(d['project_city'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _closedByCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Closed By',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _row('Name', _readString(d['closed_by_name'], fallback: '-')),
          _row('Manager', _readString(d['closed_by_manager_name'], fallback: '-')),
        ],
      ),
    );
  }

  Widget _notesCard() {
    final d = _data!;
    return _sectionCard(
      title: 'Closure Notes',
      icon: Icons.info_outline,
      child: Text(
        _readString(d['closure_notes'], fallback: '-'),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _errorCard() {
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
          Text(_error ?? 'Unable to load detail', style: const TextStyle(color: AppColors.error)),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No closure detail found.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  String _rupee(double value) {
    if (value <= 0) return '-';
    return 'Rs ${value.toStringAsFixed(0)}';
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

  String _formatDateTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '-';
    final date = _formatDate(parsed.toIso8601String());
    final hh = parsed.toLocal().hour.toString().padLeft(2, '0');
    final mm = parsed.toLocal().minute.toString().padLeft(2, '0');
    return '$date, $hh:$mm';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF0A9A55);
      case 'on_hold':
      case 'on hold':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }
}
