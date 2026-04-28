import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialData,
  });

  final String projectId;
  final Map<String, dynamic>? initialData;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final _authProvider = AuthProvider();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _authProvider.projectDetail(
        id: widget.projectId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      setState(() {
        _data = detail;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? const <String, dynamic>{};
    final status = _readString(data['status']).toLowerCase();
    final statusColor = status == 'active' ? AppColors.success : AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Project Details', showBackButton: true),
      body: _isLoading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _loadDetail, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildHeroCard(data, status, statusColor),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Overview',
                        children: [
                          _kv('Project ID', _readString(data['id']), icon: Icons.fingerprint),
                          _kv('Developer', _readString(data['developer']), icon: Icons.business_outlined),
                          _kv('City', _readString(data['city']), icon: Icons.location_city_outlined),
                          _kv('Locality', _readString(data['locality']), icon: Icons.map_outlined),
                          _kv('Address', _readString(data['address']), icon: Icons.place_outlined),
                          _kv('Price Range', _readString(data['price_range']), icon: Icons.currency_rupee_outlined),
                          _kv('Total Units', _readString(data['total_units']), icon: Icons.apartment_outlined),
                          _kv('Possession Date', _formatDate(_readString(data['possession_date'])), icon: Icons.event_outlined),
                          _kv('RERA Number', _readString(data['rera_number']), icon: Icons.verified_user_outlined),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Configurations',
                        children: [_chipWrap(_readList(data['configurations']))],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Amenities',
                        children: [_chipWrap(_readList(data['amenities']))],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Meta',
                        children: [
                          _kv('Total Leads', _readString(data['total_leads']), icon: Icons.groups_outlined),
                          _kv('Created By', _readString(data['created_by']), icon: Icons.person_outline),
                          _kv(
                            'Brochure URL',
                            _readString(data['brochure_url']).isEmpty ? 'Not available' : _readString(data['brochure_url']),
                            icon: Icons.picture_as_pdf_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: 'Description',
                        children: [
                          Text(
                            _readString(data['description']).isEmpty
                                ? 'No description provided.'
                                : _readString(data['description']),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroCard(Map<String, dynamic> data, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFB1916C), Color(0xFF8A6E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _readString(data['name']).isEmpty ? 'Project' : _readString(data['name']),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.isEmpty ? 'N/A' : status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_readString(data['locality'])}, ${_readString(data['city'])}',
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('Leads', _readString(data['total_leads'])),
              const SizedBox(width: 10),
              _heroStat('Units', _readString(data['total_units'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipWrap(List<String> items) {
    final values = items.isEmpty ? <String>['Not specified'] : items;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                item,
                style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
    );
  }

  List<String> _readList(dynamic value) {
    if (value is List) {
      return value.map((e) => _readString(e)).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }
}
