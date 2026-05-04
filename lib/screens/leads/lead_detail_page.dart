import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/lead_detail_model.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/follow_ups/follow_up_form_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailPage extends StatefulWidget {
  final String leadId;

  const LeadDetailPage({super.key, required this.leadId});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _statusNoteController = TextEditingController();
  final TextEditingController _reassignNoteController = TextEditingController();

  static const List<String> _statusFlow = <String>[
    'new',
    'contacted',
    'interested',
    'follow_up',
    'site_visit_scheduled',
    'site_visit_done',
    'negotiation',
    'booked',
    'lost',
  ];

  LeadDetailModel? _lead;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSubmittingStatus = false;
  bool _isSubmittingReassign = false;
  String? _selectedNextStatus;
  String? _selectedAssigneeId;
  List<_AssigneeOption> _assigneeOptions = const <_AssigneeOption>[];

  @override
  void initState() {
    super.initState();
    _fetchLeadDetails();
    _loadAssigneeOptions();
  }

  @override
  void dispose() {
    _statusNoteController.dispose();
    _reassignNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeadDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final data = await _authProvider.leadDetail(id: widget.leadId);
      final lead = LeadDetailModel.fromJson(data);
      final normalizedCurrent = _normalizeStatus(lead.status);

      setState(() {
        _lead = lead;
        _selectedNextStatus ??= _firstStatusAfter(normalizedCurrent);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadAssigneeOptions() async {
    try {
      final users =
          await _authProvider.users(token: _authProvider.currentAuthToken);
      final options = users
          .map(_assigneeFromApi)
          .where((u) => u != null)
          .cast<_AssigneeOption>()
          .toList();

      final uniqueById = <String, _AssigneeOption>{};
      for (final option in options) {
        uniqueById[option.id] = option;
      }
      final uniqueOptions = uniqueById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }
      setState(() {
        _assigneeOptions = uniqueOptions;
      });
    } catch (_) {
      // Keep UI usable even if users endpoint fails.
    }
  }

  _AssigneeOption? _assigneeFromApi(Map<String, dynamic> user) {
    final isActive = _readBool(
      user['is_active'] ?? user['isActive'] ?? user['active'] ?? user['status'],
    );
    if (!isActive) {
      return null;
    }

    final roleRaw = _readString(
      user['role'] ??
          user['user_role'] ??
          user['userRole'] ??
          user['designation'],
    );
    final normalizedRole = _normalizeRole(roleRaw);
    if (normalizedRole != 'sale_executive' &&
        normalizedRole != 'sales_manager') {
      return null;
    }

    final id = _readString(
        user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final combinedName = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName
    ].join(' ').trim();

    final displayName = combinedName.isNotEmpty
        ? combinedName
        : _readString(user['name'] ??
            user['full_name'] ??
            user['fullName'] ??
            user['email']);

    return _AssigneeOption(
        id: id, name: displayName.isEmpty ? 'User $id' : displayName);
  }

  Future<void> _makeCall(String phoneNumber) async {
    final launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail(String email) async {
    final launchUri = Uri(
      scheme: 'mailto',
      path: email.trim(),
    );
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitStatusChange() async {
    if (_selectedNextStatus == null || _selectedNextStatus!.isEmpty) {
      _showSnackBar('Please select the next status.');
      return;
    }
    setState(() {
      _isSubmittingStatus = true;
    });

    try {
      await _authProvider.updateLeadStatus(
        id: widget.leadId,
        status: _selectedNextStatus!,
        note: _statusNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _fetchLeadDetails();
      if (!mounted) {
        return;
      }
      _showSnackBar('Lead status updated successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingStatus = false;
        });
      }
    }
  }

  Future<void> _submitReassignment() async {
    if (_selectedAssigneeId == null || _selectedAssigneeId!.isEmpty) {
      _showSnackBar('Please select an assignee.');
      return;
    }
    setState(() {
      _isSubmittingReassign = true;
    });

    try {
      await _authProvider.reassignLead(
        id: widget.leadId,
        assignedTo: _selectedAssigneeId!,
        note: _reassignNoteController.text.trim(),
        token: _authProvider.currentAuthToken,
      );
      await _fetchLeadDetails();
      if (!mounted) {
        return;
      }
      _showSnackBar('Lead reassigned successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReassign = false;
        });
      }
    }
  }

  Future<void> _openStatusSheet() async {
    final current = _normalizeStatus(_lead?.status ?? '');
    final nextStatuses = _allowedTransitions(current);
    if (nextStatuses.isEmpty) {
      _showSnackBar('No further status transition available.');
      return;
    }

    if (_selectedNextStatus == null ||
        !nextStatuses.contains(_selectedNextStatus)) {
      _selectedNextStatus = nextStatuses.first;
    }
    _statusNoteController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildSheetContainer(
          title: 'Change Status',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedNextStatus,
                isExpanded: true,
                decoration: _fieldDecoration('Select status'),
                items: nextStatuses
                    .map((status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(_prettyStatus(status)),
                        ))
                    .toList(),
                onChanged: _isSubmittingStatus
                    ? null
                    : (value) => setState(() => _selectedNextStatus = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _statusNoteController,
                minLines: 2,
                maxLines: 3,
                decoration: _fieldDecoration('Add note (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmittingStatus
                      ? null
                      : () async {
                          await _submitStatusChange();
                          if (mounted) Navigator.of(context).pop();
                        },
                  child: Text(
                      _isSubmittingStatus ? 'Updating...' : 'Update Status'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openReassignSheet() async {
    if (_assigneeOptions.isEmpty) {
      _showSnackBar('No active assignee available.');
      return;
    }
    _reassignNoteController.clear();
    _selectedAssigneeId ??= _assigneeOptions.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildSheetContainer(
          title: 'Reassign Lead',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedAssigneeId,
                isExpanded: true,
                decoration: _fieldDecoration('Select assignee'),
                items: _assigneeOptions
                    .map((user) => DropdownMenuItem<String>(
                          value: user.id,
                          child: Text(user.name),
                        ))
                    .toList(),
                onChanged: _isSubmittingReassign
                    ? null
                    : (value) => setState(() => _selectedAssigneeId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reassignNoteController,
                minLines: 2,
                maxLines: 3,
                decoration: _fieldDecoration('Add note (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmittingReassign
                      ? null
                      : () async {
                          await _submitReassignment();
                          if (mounted) Navigator.of(context).pop();
                        },
                  child: Text(_isSubmittingReassign
                      ? 'Reassigning...'
                      : 'Reassign Lead'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onConvertLead() async {
    if (_lead == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Convert Lead',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textSecondary,
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConvertLeadInfoCard(),
                        const SizedBox(height: 14),
                        const Text(
                          'Choose what you want to convert this lead into:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 420;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  _buildConvertOptionCard(
                                    icon: Icons.call_outlined,
                                    iconBackground: const Color(0xFF2ECF8D),
                                    title: 'Follow-Up',
                                    subtitle: 'Create a task with due date & priority',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => FollowUpFormPage(
                                            initialLeadId: widget.leadId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildConvertOptionCard(
                                    icon: Icons.calendar_month_outlined,
                                    iconBackground: const Color(0xFF8C4BFF),
                                    title: 'Site Visit',
                                    subtitle: 'Schedule a project visit',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SiteVisitFormPage(
                                            initialLeadId: widget.leadId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: _buildConvertOptionCard(
                                    icon: Icons.call_outlined,
                                    iconBackground: const Color(0xFF2ECF8D),
                                    title: 'Follow-Up',
                                    subtitle: 'Create a task with due date & priority',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => FollowUpFormPage(
                                            initialLeadId: widget.leadId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildConvertOptionCard(
                                    icon: Icons.calendar_month_outlined,
                                    iconBackground: const Color(0xFF8C4BFF),
                                    title: 'Site Visit',
                                    subtitle: 'Schedule a project visit',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SiteVisitFormPage(
                                            initialLeadId: widget.leadId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConvertLeadInfoCard() {
    final lead = _lead!;
    final leadStatus = _prettyStatus(_normalizeStatus(lead.status));
    final initials =
        lead.name.trim().isNotEmpty ? lead.name.trim()[0].toLowerCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lead.phone} - $leadStatus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertOptionCard({
    required IconData icon,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Lead Details',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLeadDetails,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _lead == null
                  ? const Center(child: Text('No data found'))
                  : RefreshIndicator(
                      onRefresh: _fetchLeadDetails,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 14),
                            _buildActionButtonsRow(),
                            const SizedBox(height: 24),
                            _buildInfoSection('Lead Information', [
                              _buildInfoTile(
                                Icons.phone_outlined,
                                'Phone',
                                _lead!.phone,
                                onTap: () => _makeCall(_lead!.phone),
                              ),
                              _buildInfoTile(
                                Icons.email_outlined,
                                'Email',
                                _lead!.email,
                                onTap: () => _sendEmail(_lead!.email),
                              ),
                              _buildInfoTile(Icons.source_outlined, 'Source',
                                  _lead!.source),
                              _buildInfoTile(
                                Icons.location_on_outlined,
                                'Location Preference',
                                _lead!.locationPreference,
                              ),
                              _buildInfoTile(
                                Icons.account_balance_wallet_outlined,
                                'Budget',
                                _lead!.budget,
                              ),
                            ]),
                            const SizedBox(height: 24),
                            if (_lead!.assignedTo != null)
                              _buildInfoSection('Assigned To', [
                                _buildInfoTile(
                                  Icons.person_outline,
                                  'Name',
                                  _lead!.assignedTo!.fullName,
                                ),
                                _buildInfoTile(
                                  Icons.phone_outlined,
                                  'Phone',
                                  _lead!.assignedTo!.phone,
                                  onTap: () =>
                                      _makeCall(_lead!.assignedTo!.phone),
                                ),
                              ]),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final itemWidth = wide ? (constraints.maxWidth - 16) / 3 : null;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPremiumActionButton(
                width: itemWidth,
                label: 'Change Status',
                subtitle: 'Update lead stage',
                icon: Icons.timeline_rounded,
                onTap: _openStatusSheet,
                highlighted: true,
              ),
              _buildPremiumActionButton(
                width: itemWidth,
                label: 'Reassign Lead',
                subtitle: 'Transfer ownership',
                icon: Icons.swap_horiz_rounded,
                onTap: _openReassignSheet,
              ),
              _buildPremiumActionButton(
                width: itemWidth,
                label: 'Convert Lead',
                subtitle: 'Move to customer',
                icon: Icons.sync_alt_rounded,
                onTap: _onConvertLead,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumActionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [Color(0xFF2F6BFF), Color(0xFF5A8BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: highlighted ? null : const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted ? Colors.transparent : AppColors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: highlighted ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: highlighted ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: highlighted
                              ? Colors.white.withOpacity(0.88)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color:
                      highlighted ? Colors.white.withOpacity(0.92) : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              _lead!.name.isNotEmpty ? _lead!.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lead!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Text(
                //   'Lead #${widget.leadId}',
                //   style: const TextStyle(
                //     fontSize: 12,
                //     color: AppColors.textSecondary,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _prettyStatus(_normalizeStatus(_lead!.status)),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContainer({required String title, required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onTap != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  color: AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  String _normalizeRole(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'sales_executive') {
      return 'sale_executive';
    }
    return normalized;
  }

  String _normalizeStatus(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  String _prettyStatus(String value) {
    final normalized = _normalizeStatus(value);
    if (normalized.isEmpty) {
      return 'UNKNOWN';
    }
    return normalized
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _firstStatusAfter(String current) {
    final next = _allowedTransitions(current);
    if (next.isEmpty) {
      return null;
    }
    return next.first;
  }

  List<String> _allowedTransitions(String current) {
    if (current.isEmpty || !_statusFlow.contains(current)) {
      return _statusFlow;
    }
    if (current == 'booked' || current == 'lost') {
      return const <String>[];
    }
    final index = _statusFlow.indexOf(current);
    if (index < 0 || index + 1 >= _statusFlow.length) {
      return const <String>[];
    }
    final forward = _statusFlow.sublist(index + 1);
    return forward;
  }

  String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    return '';
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AssigneeOption {
  const _AssigneeOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
