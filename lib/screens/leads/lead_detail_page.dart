import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/lead_detail_model.dart';
import 'package:nextone/providers/auth_provider.dart';
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
      final users = await _authProvider.users(token: _authProvider.currentAuthToken);
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
      user['role'] ?? user['user_role'] ?? user['userRole'] ?? user['designation'],
    );
    final normalizedRole = _normalizeRole(roleRaw);
    if (normalizedRole != 'sale_executive' && normalizedRole != 'sales_manager') {
      return null;
    }

    final id = _readString(user['id'] ?? user['user_id'] ?? user['userId'] ?? user['uuid']);
    if (id.isEmpty) {
      return null;
    }

    final firstName = _readString(user['first_name'] ?? user['firstName']);
    final lastName = _readString(user['last_name'] ?? user['lastName']);
    final combinedName = [if (firstName.isNotEmpty) firstName, if (lastName.isNotEmpty) lastName]
        .join(' ')
        .trim();

    final displayName = combinedName.isNotEmpty
        ? combinedName
        : _readString(user['name'] ?? user['full_name'] ?? user['fullName'] ?? user['email']);

    return _AssigneeOption(id: id, name: displayName.isEmpty ? 'User $id' : displayName);
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

    if (_selectedNextStatus == null || !nextStatuses.contains(_selectedNextStatus)) {
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
                  child: Text(_isSubmittingStatus ? 'Updating...' : 'Update Status'),
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
                  child: Text(_isSubmittingReassign ? 'Reassigning...' : 'Reassign Lead'),
                ),
              ),
            ],
          ),
        );
      },
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLeadDetails,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                              _buildInfoTile(Icons.source_outlined, 'Source', _lead!.source),
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
                                  onTap: () => _makeCall(_lead!.assignedTo!.phone),
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
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _openStatusSheet,
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Change Status'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openReassignSheet,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Reassign Lead'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
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

  Widget _buildInfoTile(IconData icon, String label, String value, {VoidCallback? onTap}) {
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
                      color: onTap != null ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.border, size: 20),
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
    final normalized = value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
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
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
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
