import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteVisitDetailsPage extends StatefulWidget {
  final String visitId;
  final Map<String, dynamic>? visitData;

  const SiteVisitDetailsPage({
    super.key,
    required this.visitId,
    this.visitData,
  });

  @override
  State<SiteVisitDetailsPage> createState() => _SiteVisitDetailsPageState();
}

class _SiteVisitDetailsPageState extends State<SiteVisitDetailsPage> {
  final AuthProvider _authProvider = AuthProvider();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _visitData = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _visitData = widget.visitData ?? const <String, dynamic>{};
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _authProvider.siteVisitDetail(
        id: widget.visitId,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _visitData = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _visitData;
    final status = data['status']?.toString() ?? 'N/A';
    final visitDate = _formatDate(data['visit_date']);
    final visitTime = data['visit_time']?.toString() ?? 'N/A';
    final transportArranged = data['transport_arranged'] == true;
    final notes = data['notes']?.toString() ?? 'No notes provided.';
    final leadName = _readField(
      data,
      flatKey: 'lead_name',
      nestedParentKey: 'lead',
      nestedFieldKey: 'name',
      fallback: 'N/A',
    );
    final leadPhone = _readField(
      data,
      flatKey: 'lead_phone',
      nestedParentKey: 'lead',
      nestedFieldKey: 'phone',
      fallback: '',
    );
    final leadEmail = _readField(
      data,
      flatKey: 'lead_email',
      nestedParentKey: 'lead',
      nestedFieldKey: 'email',
      fallback: '',
    );
    final projectName = _readField(
      data,
      flatKey: 'project_name',
      nestedParentKey: 'project',
      nestedFieldKey: 'name',
      fallback: 'N/A',
    );
    final projectCity = _readField(
      data,
      flatKey: 'project_city',
      nestedParentKey: 'project',
      nestedFieldKey: 'city',
      fallback: '-',
    );
    final projectAddress = _readField(
      data,
      flatKey: 'project_address',
      nestedParentKey: 'project',
      nestedFieldKey: 'address',
      fallback: '-',
    );
    final assigneeName = _readField(
      data,
      flatKey: 'assigned_to_name',
      nestedParentKey: 'assigned_to',
      nestedFieldKey: 'full_name',
      fallback: 'Unassigned',
    );
    final feedback = _feedbackData(data);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Visit Details',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _loadDetails,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeroCard(
                        status: status,
                        visitDate: visitDate,
                        visitTime: visitTime,
                        transportArranged: transportArranged,
                        leadName: leadName,
                        projectName: projectName,
                        assigneeName: assigneeName,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: 'Lead Information',
                              icon: Icons.person_outline,
                              accent: AppColors.primary,
                              children: [
                                _buildInfoRow('Name', leadName),
                                _buildInfoRow('Phone', leadPhone,
                                    isLink: true,
                                    onTap: () => _launchCaller(leadPhone)),
                                _buildInfoRow('Email', leadEmail,
                                    isLink: true,
                                    onTap: () => _launchEmail(leadEmail)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Project Information',
                              icon: Icons.apartment_outlined,
                              accent: const Color(0xFF0F766E),
                              children: [
                                _buildInfoRow('Project', projectName),
                                _buildInfoRow('City', projectCity),
                                _buildInfoRow('Address', projectAddress),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Assignment',
                              icon: Icons.assignment_ind_outlined,
                              accent: const Color(0xFF8B5CF6),
                              children: [
                                _buildInfoRow('Assigned To', assigneeName),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Visit Notes',
                              icon: Icons.note_outlined,
                              accent: const Color(0xFFD97706),
                              children: [
                                Text(
                                  notes,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            if (_hasFeedback(feedback)) ...[
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Feedback',
                                icon: Icons.feedback_outlined,
                                accent: const Color(0xFFDC2626),
                                children: _buildFeedbackWidgets(feedback),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: leadPhone.trim().isEmpty
                                        ? null
                                        : () => _launchCaller(leadPhone),
                                    icon: const Icon(Icons.call_outlined),
                                    label: const Text('Call Lead'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: leadEmail.trim().isEmpty
                                        ? null
                                        : () => _launchEmail(leadEmail),
                                    icon: const Icon(Icons.email_outlined),
                                    label: const Text('Email'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _submitFeedback,
                                icon: const Icon(Icons.rate_review_outlined),
                                label: Text(
                                  _hasFeedback(feedback)
                                      ? 'Update Feedback'
                                      : 'Submit Feedback',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroCard({
    required String status,
    required String visitDate,
    required String visitTime,
    required bool transportArranged,
    required String leadName,
    required String projectName,
    required String assigneeName,
  }) {
    final statusColor = _getStatusColor(status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  color: statusColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Site Visit Details',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      leadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: visitDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroMetric(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: visitTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroMetric(
                  icon: transportArranged
                      ? Icons.directions_car_rounded
                      : Icons.directions_walk_rounded,
                  label: 'Transport',
                  value: transportArranged ? 'Arranged' : 'Self',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _softChip('Lead: $leadName'),
              _softChip('Coordinator: $assigneeName'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isLink = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  color: isLink ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date.toString());
      final months = [
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
        'Dec'
      ];
      return '${parsed.day} ${months[parsed.month - 1]}, ${parsed.year}';
    } catch (_) {
      return date.toString();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'rescheduled':
        return const Color(0xFFF59E0B);
      case 'scheduled':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  bool _hasFeedback(dynamic feedback) {
    final map = _readMap(feedback);
    if (map.isNotEmpty) return true;
    if (feedback is String) return feedback.trim().isNotEmpty;
    return false;
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic entry) => MapEntry(key.toString(), entry),
      );
    }
    return const <String, dynamic>{};
  }

  String _readString(dynamic value, {String fallback = 'N/A'}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  String _nestedString(
    Map<String, dynamic> source,
    String nestedKey,
    String valueKey, {
    String fallback = 'N/A',
  }) {
    final nested = _readMap(source[nestedKey]);
    return _readString(nested[valueKey], fallback: fallback);
  }

  String _readField(
    Map<String, dynamic> source, {
    required String flatKey,
    required String nestedParentKey,
    required String nestedFieldKey,
    String fallback = 'N/A',
  }) {
    final flatValue = _readString(source[flatKey], fallback: '');
    if (flatValue.isNotEmpty) {
      return flatValue;
    }
    return _nestedString(
      source,
      nestedParentKey,
      nestedFieldKey,
      fallback: fallback,
    );
  }

  Map<String, dynamic> _feedbackData(Map<String, dynamic> source) {
    final nested = _readMap(source['feedback']);
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

  List<Widget> _buildFeedbackWidgets(dynamic feedback) {
    if (feedback is Map<String, dynamic>) {
      final rating = feedback['rating']?.toString() ?? '';
      final reaction = feedback['client_reaction']?.toString() ?? '';
      final interestedIn = feedback['interested_in']?.toString() ?? '';
      final nextStep = feedback['next_step']?.toString() ?? '';
      final remarks = feedback['remarks']?.toString() ?? '';

      final widgets = <Widget>[];
      if (rating.trim().isNotEmpty) {
        widgets.add(_buildInfoRow('Rating', rating));
      }
      if (reaction.trim().isNotEmpty) {
        widgets.add(_buildInfoRow('Reaction', reaction));
      }
      if (interestedIn.trim().isNotEmpty) {
        widgets.add(_buildInfoRow('Interested In', interestedIn));
      }
      if (nextStep.trim().isNotEmpty) {
        widgets.add(_buildInfoRow('Next Step', nextStep));
      }
      if (remarks.trim().isNotEmpty) {
        widgets.add(_buildInfoRow('Remarks', remarks));
      }
      if (widgets.isNotEmpty) {
        return widgets;
      }
    }

    return <Widget>[
      Text(
        feedback.toString(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    ];
  }

  Future<void> _submitFeedback() async {
    final feedbackMap = _feedbackData(_visitData);

    final remarksController = TextEditingController(
      text: feedbackMap['remarks']?.toString() ?? '',
    );
    final interestedController = TextEditingController(
      text: feedbackMap['interested_in']?.toString() ?? '',
    );
    final nextStepController = TextEditingController(
      text: feedbackMap['next_step']?.toString() ?? '',
    );
    String reaction = feedbackMap['client_reaction']?.toString() ?? 'positive';
    int rating = int.tryParse(feedbackMap['rating']?.toString() ?? '') ?? 4;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Submit Feedback'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          onPressed: () => setLocalState(() => rating = star),
                          icon: Icon(
                            star <= rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.warning,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: reaction,
                      decoration:
                          const InputDecoration(labelText: 'Client Reaction'),
                      items: const [
                        DropdownMenuItem(
                            value: 'positive', child: Text('Positive')),
                        DropdownMenuItem(
                            value: 'neutral', child: Text('Neutral')),
                        DropdownMenuItem(
                            value: 'negative', child: Text('Negative')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocalState(() => reaction = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: interestedController,
                      decoration: const InputDecoration(
                        labelText: 'Interested In',
                        hintText: '3BHK - Floor 12',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nextStepController,
                      decoration: const InputDecoration(
                        labelText: 'Next Step',
                        hintText: 'negotiation',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: remarksController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        hintText: 'Client feedback remarks',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      remarksController.dispose();
      interestedController.dispose();
      nextStepController.dispose();
      return;
    }

    try {
      await _authProvider.submitSiteVisitFeedback(
        id: widget.visitId,
        rating: rating,
        clientReaction: reaction,
        interestedIn: interestedController.text.trim(),
        nextStep: nextStepController.text.trim(),
        remarks: remarksController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Feedback submitted successfully.');
      await _loadDetails();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      remarksController.dispose();
      interestedController.dispose();
      nextStepController.dispose();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _launchCaller(String? phone) async {
    if (phone == null) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchEmail(String? email) async {
    if (email == null) return;
    final Uri url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
