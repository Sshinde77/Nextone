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
    final lead = data['lead'] ?? {};
    final project = data['project'] ?? {};
    final assignedTo = data['assigned_to'] ?? {};
    final status = data['status']?.toString() ?? 'N/A';
    final visitDate = _formatDate(data['visit_date']);
    final visitTime = data['visit_time']?.toString() ?? 'N/A';
    final transportArranged = data['transport_arranged'] == true;
    final notes = data['notes']?.toString() ?? 'No notes provided.';
    final feedback = data['feedback'];

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
                      _buildHeader(status),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildScheduleCard(
                                visitDate, visitTime, transportArranged),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Lead Information',
                              icon: Icons.person_outline,
                              children: [
                                _buildInfoRow('Name', lead['name'] ?? 'N/A'),
                                _buildInfoRow('Phone', lead['phone'] ?? 'N/A',
                                    isLink: true,
                                    onTap: () => _launchCaller(lead['phone'])),
                                _buildInfoRow('Email', lead['email'] ?? 'N/A',
                                    isLink: true,
                                    onTap: () => _launchEmail(lead['email'])),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Project Information',
                              icon: Icons.apartment_outlined,
                              children: [
                                _buildInfoRow(
                                    'Project', project['name'] ?? 'N/A'),
                                _buildInfoRow('City', project['city'] ?? 'N/A'),
                                _buildInfoRow(
                                    'Address', project['address'] ?? 'N/A'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Assignment',
                              icon: Icons.assignment_ind_outlined,
                              children: [
                                _buildInfoRow('Assigned To',
                                    assignedTo['full_name'] ?? 'Unassigned'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Visit Notes',
                              icon: Icons.note_outlined,
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
                                children: _buildFeedbackWidgets(feedback),
                              ),
                            ],
                            const SizedBox(height: 16),
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

  Widget _buildHeader(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _getStatusColor(status).withOpacity(0.2)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Site Visit Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String date, String time, bool transport) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildScheduleItem(Icons.calendar_today_outlined, 'Date', date),
          _buildDivider(),
          _buildScheduleItem(Icons.access_time, 'Time', time),
          _buildDivider(),
          _buildScheduleItem(
            transport ? Icons.directions_car : Icons.directions_walk,
            'Transport',
            transport ? 'Arranged' : 'Self',
            iconColor: transport ? AppColors.success : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildScheduleItem(IconData icon, String label, String value,
      {Color? iconColor}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
          const SizedBox(height: 8),
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
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
    if (feedback == null) return false;
    if (feedback is String) return feedback.trim().isNotEmpty;
    if (feedback is Map) return feedback.isNotEmpty;
    return true;
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
    final feedback = _visitData['feedback'];
    final feedbackMap = feedback is Map<String, dynamic>
        ? feedback
        : const <String, dynamic>{};

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
                      decoration: const InputDecoration(labelText: 'Client Reaction'),
                      items: const [
                        DropdownMenuItem(value: 'positive', child: Text('Positive')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                        DropdownMenuItem(value: 'negative', child: Text('Negative')),
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
