import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/closures/closure_detail_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/widgets/closure_data_card.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class ClosuresPage extends StatefulWidget {
  const ClosuresPage({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<ClosuresPage> createState() => _ClosuresPageState();
}

class _ClosuresPageState extends State<ClosuresPage> {
  final AuthProvider _authProvider = AuthProvider();
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _loadClosures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClosures({int? page}) async {
    final nextPage = page ?? _currentPage;
    final apiStatus =
        _statusFilter == 'all' ? null : _statusFilter.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _authProvider.closures(
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
    final visibleItems = _items.where(_matchesSearch).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          CrmAppBar(title: 'Closures', showBackButton: widget.showBackButton),
      body: RefreshIndicator(
        onRefresh: () => _loadClosures(page: _currentPage),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Booking records when leads are converted',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openCreateClosureDialog,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.add),
                  label: const Text('Book Lead'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKpiRow(),
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

  Future<void> _openCreateClosureDialog() async {
    final leadResult = await _authProvider.leads(
      token: _authProvider.currentAuthToken,
      perPage: 100,
    );
    final projectResult = await _authProvider.projects(
      token: _authProvider.currentAuthToken,
      perPage: 100,
    );
    final users =
        await _authProvider.users(token: _authProvider.currentAuthToken);

    if (!mounted) return;
    final leads = leadResult.items;
    final projects = projectResult.items;
    if (leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No leads available for closure booking.')),
      );
      return;
    }

    String step = 'booking';
    bool isSubmitting = false;

    String? selectedLeadId;
    String? selectedProjectId;
    DateTime bookingDate = DateTime.now();

    final unitNumberController = TextEditingController();
    final towerController = TextEditingController();
    final floorController = TextEditingController();
    final unitTypeController = TextEditingController();
    final carpetAreaController = TextEditingController();
    final superAreaController = TextEditingController();
    final agreedPriceController = TextEditingController();
    final bookingAmountController = TextEditingController();
    final paymentPlanController = TextEditingController();
    String? selectedPaymentPlan;
    const paymentPlans = <String>[
      'Construction Linked Plan',
      'Down Payment Plan',
      'Flexi Payment Plan',
      'Subvention Plan',
    ];
    bool loanRequired = false;
    final loanBankController = TextEditingController();
    final commissionPercentController = TextEditingController();
    commissionPercentController.text = '2';
    bool commissionPaid = false;
    String? selectedManagerId;
    final notesController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: bookingDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) return;
              setLocalState(() => bookingDate = picked);
            }

            Future<void> submit() async {
              if ((selectedLeadId ?? '').isEmpty ||
                  (selectedProjectId ?? '').isEmpty ||
                  unitNumberController.text.trim().isEmpty ||
                  floorController.text.trim().isEmpty ||
                  unitTypeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all required fields.')),
                );
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.createClosure(
                  leadId: selectedLeadId!,
                  projectId: selectedProjectId!,
                  siteVisitId: null,
                  bookingDate: _toYmd(bookingDate),
                  unitNumber: unitNumberController.text.trim(),
                  towerBlock: towerController.text.trim(),
                  floorNumber: int.tryParse(floorController.text.trim()) ?? 0,
                  unitType: unitTypeController.text.trim(),
                  carpetAreaSqft:
                      double.tryParse(carpetAreaController.text.trim()) ?? 0,
                  superAreaSqft:
                      double.tryParse(superAreaController.text.trim()) ?? 0,
                  agreedPrice:
                      double.tryParse(agreedPriceController.text.trim()) ?? 0,
                  bookingAmount:
                      double.tryParse(bookingAmountController.text.trim()) ?? 0,
                  paymentPlan: paymentPlanController.text.trim(),
                  loanRequired: loanRequired,
                  loanBank: loanBankController.text.trim(),
                  commissionPercent: double.tryParse(
                          commissionPercentController.text.trim()) ??
                      0,
                  commissionPaid: commissionPaid,
                  closedByManager: selectedManagerId,
                  closureNotes: notesController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() => isSubmitting = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Create Closure - Book Lead',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700),
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
                      const SizedBox(height: 8),
                      _stepTabs(step, (v) => setLocalState(() => step = v)),
                      const SizedBox(height: 14),
                      if (step == 'booking') ...[
                        _dropdownField(
                          label: 'Lead *',
                          value: selectedLeadId,
                          hint: 'Select lead to book...',
                          items: leads
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: _readString(e['id'], fallback: ''),
                                  child: Text(
                                    _readString(e['name'], fallback: 'Lead'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedLeadId = v),
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: 'Project *',
                          value: selectedProjectId,
                          hint: 'Select project...',
                          items: projects
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: _readString(e['id'], fallback: ''),
                                  child: Text(
                                    _readString(e['name'], fallback: 'Project'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedProjectId = v),
                        ),
                        const SizedBox(height: 10),
                        _dateField('Booking Date *', bookingDate, pickDate),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _textField(
                                    'Unit Number *', unitNumberController)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _textField(
                                    'Tower / Block', towerController)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Floor *',
                                floorController,
                                keyboardType: TextInputType.number,
                                hintText: 'Floor',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _textField(
                                'Unit Type *',
                                unitTypeController,
                                hintText: 'Unit Type',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _textField(
                                'Carpet Area (sqft)',
                                carpetAreaController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: 'Carpet',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          'Super Area (sqft)',
                          superAreaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 10),
                        _textField('Closure Notes', notesController,
                            maxLines: 3),
                      ] else if (step == 'financials') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Agreed Price (Rs) *',
                                agreedPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '9500000',
                                prefixText: 'Rs ',
                                onChanged: (_) => setLocalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _textField(
                                'Booking Amount (Rs)',
                                bookingAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '500000',
                                prefixText: 'Rs ',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: 'Payment Plan',
                          value: selectedPaymentPlan,
                          hint: 'Select payment plan...',
                          items: paymentPlans
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child:
                                      Text(e, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setLocalState(() {
                              selectedPaymentPlan = v;
                              paymentPlanController.text = v ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: loanRequired,
                          onChanged: (v) =>
                              setLocalState(() => loanRequired = v ?? false),
                          title: const Text(
                            'Home loan required',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _textField('Loan Bank', loanBankController),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Commission % (auto-calcs amount)',
                                commissionPercentController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '2',
                                prefixText: '% ',
                                onChanged: (_) => setLocalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _readOnlyField(
                                'Commission Amount (Rs)',
                                _rupee(
                                  (double.tryParse(agreedPriceController.text
                                              .trim()) ??
                                          0) *
                                      (double.tryParse(
                                            commissionPercentController.text
                                                .trim(),
                                          ) ??
                                          0) /
                                      100,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: 'Reporting Manager',
                          value: selectedManagerId,
                          hint: 'Select manager...',
                          items: users
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: _readString(e['id'], fallback: ''),
                                  child: Text(
                                    '${_readString(e['first_name'], fallback: '').trim()} ${_readString(e['last_name'], fallback: '').trim()}'
                                        .trim(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .where((e) => (e.value ?? '').isNotEmpty)
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedManagerId = v),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: commissionPaid,
                          onChanged: (v) =>
                              setLocalState(() => commissionPaid = v ?? false),
                          title: const Text(
                            'Commission already paid',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Book Lead'),
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

    unitNumberController.dispose();
    towerController.dispose();
    floorController.dispose();
    unitTypeController.dispose();
    carpetAreaController.dispose();
    superAreaController.dispose();
    agreedPriceController.dispose();
    bookingAmountController.dispose();
    paymentPlanController.dispose();
    loanBankController.dispose();
    commissionPercentController.dispose();
    notesController.dispose();

    if (created == true && mounted) {
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Closure created successfully.')),
      );
    }
  }

  Widget _stepTabs(String step, ValueChanged<String> onChanged) {
    Widget tab(String value, String label) {
      final selected = value == step;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tab('booking', 'Booking Details'),
          const SizedBox(width: 4),
          tab('financials', 'Financials'),
          const SizedBox(width: 4),
          tab('commission', 'Commission'),
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (value ?? '').isEmpty ? null : value,
          decoration: _fieldDecoration(hint: hint),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: _fieldDecoration(hint: ''),
            child: Text(_toYmd(date)),
          ),
        ),
      ],
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? prefixText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration:
              _fieldDecoration(hint: hintText ?? label, prefixText: prefixText),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        InputDecorator(
          decoration:
              _fieldDecoration(hint: 'Auto-calculated', prefixText: 'Rs '),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint, String? prefixText}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefixText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildKpiRow() {
    final total = _items.length;
    final totalDealValue =
        _items.fold<double>(0, (sum, e) => sum + _toDouble(e['agreed_price']));
    final totalCommission = _items.fold<double>(
        0, (sum, e) => sum + _toDouble(e['commission_amount']));
    final commissionPaid =
        _items.where((e) => e['commission_paid'] == true).length;
    final commissionPending = total - commissionPaid;

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _kpiTile('Total Closures', total.toString(), const Color(0xFF2563EB)),
          _kpiTile('Total Deal Value', _rupee(totalDealValue),
              const Color(0xFF0A9A55)),
          _kpiTile('Commission Paid', _rupee(totalCommission),
              const Color(0xFF16A34A)),
          _kpiTile('Comm. Pending', commissionPending.toString(),
              const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
              hintText: 'Search lead, project, unit...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 180, child: _buildStatusDropdown()),
        IconButton(
          onPressed: _refreshClosures,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All')),
        DropdownMenuItem(value: 'confirmed', child: Text('confirmed')),
        DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
        DropdownMenuItem(value: 'on_hold', child: Text('on_hold')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _statusFilter = value;
          _currentPage = 1;
        });
        _loadClosures(page: 1);
      },
    );
  }

  void _refreshClosures() {
    _loadClosures(page: _currentPage);
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = _readString(item['status'], fallback: 'pending');
    return ClosureDataCard(
      leadName: _readString(item['lead_name'], fallback: 'N/A'),
      leadPhone: _readString(item['lead_phone'], fallback: 'N/A'),
      projectName: _readString(item['project_name'], fallback: 'N/A'),
      projectCity: _readString(item['project_city'], fallback: 'N/A'),
      unitNumber: _readString(item['unit_number'], fallback: '-'),
      unitType: _readString(item['unit_type'], fallback: '-'),
      towerBlock: _readString(item['tower_block'], fallback: '-').toUpperCase(),
      floorNumber: item['floor_number']?.toString() ?? '-',
      bookingDate: _formatDate(_readString(item['booking_date'], fallback: '')),
      dealValueLabel: _rupee(_toDouble(item['agreed_price'])),
      commissionLabel: _rupee(_toDouble(item['commission_amount'])),
      commissionPaidLabel: item['commission_paid'] == true ? 'Yes' : 'No',
      closedByName: _readString(item['closed_by_name'], fallback: '-'),
      statusLabel: status,
      statusColor: _statusColor(status),
      onView: () => _openClosureDetail(item),
      onEdit: () => _openEditClosureDialog(item),
      onStatus: () => _openStatusUpdateDialog(item),
    );
  }

  Future<void> _openClosureDetail(Map<String, dynamic> item) async {
    final leadId = _readString(item['lead_id'], fallback: '');
    final closureId = _readString(item['id'], fallback: '');
    final lookupId = leadId.isNotEmpty ? leadId : closureId;
    if (lookupId.isEmpty) {
      _showInfo('Unable to open detail. Missing id.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClosureDetailPage(lookupId: lookupId),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditClosureDialog(Map<String, dynamic> item) async {
    final id = _readString(item['id'], fallback: '');
    if (id.isEmpty) return;
    final users =
        await _authProvider.users(token: _authProvider.currentAuthToken);
    if (!mounted) return;

    String step = 'booking';
    bool isSubmitting = false;
    DateTime bookingDate =
        DateTime.tryParse(_readString(item['booking_date'], fallback: '')) ??
            DateTime.now();

    final unitNumberController = TextEditingController(
        text: _readString(item['unit_number'], fallback: ''));
    final towerController = TextEditingController(
        text: _readString(item['tower_block'], fallback: ''));
    final floorController = TextEditingController(
      text: item['floor_number']?.toString() ?? '',
    );
    final unitTypeController = TextEditingController(
        text: _readString(item['unit_type'], fallback: ''));
    final carpetAreaController = TextEditingController(
      text: _readString(item['carpet_area_sqft'], fallback: ''),
    );
    final superAreaController = TextEditingController(
      text: _readString(item['super_area_sqft'], fallback: ''),
    );
    final agreedPriceController = TextEditingController(
      text: _readString(item['agreed_price'], fallback: ''),
    );
    final bookingAmountController = TextEditingController(
      text: _readString(item['booking_amount'], fallback: ''),
    );
    String? selectedPaymentPlan =
        _readString(item['payment_plan'], fallback: '');
    const paymentPlans = <String>[
      'Construction Linked Plan',
      'Down Payment Plan',
      'Flexi Payment Plan',
      'Subvention Plan',
    ];
    bool loanRequired = item['loan_required'] == true;
    final loanBankController = TextEditingController(
        text: _readString(item['loan_bank'], fallback: ''));
    final commissionPercentController = TextEditingController(
      text: _readString(item['commission_percent'], fallback: '2'),
    );
    bool commissionPaid = item['commission_paid'] == true;
    DateTime? commissionPaidDate = DateTime.tryParse(
        _readString(item['commission_paid_date'], fallback: ''));
    String? selectedManagerId =
        _readString(item['closed_by_manager'], fallback: '').isEmpty
            ? null
            : _readString(item['closed_by_manager'], fallback: '');
    final notesController = TextEditingController(
      text: _readString(item['closure_notes'], fallback: ''),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: bookingDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) return;
              setLocalState(() => bookingDate = picked);
            }

            Future<void> submit() async {
              if (unitNumberController.text.trim().isEmpty ||
                  floorController.text.trim().isEmpty ||
                  unitTypeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all required fields.')),
                );
                return;
              }
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.editClosure(
                  id: id,
                  bookingDate: _toYmd(bookingDate),
                  unitNumber: unitNumberController.text.trim(),
                  towerBlock: towerController.text.trim(),
                  floorNumber: int.tryParse(floorController.text.trim()) ?? 0,
                  unitType: unitTypeController.text.trim(),
                  carpetAreaSqft:
                      double.tryParse(carpetAreaController.text.trim()) ?? 0,
                  superAreaSqft:
                      double.tryParse(superAreaController.text.trim()) ?? 0,
                  agreedPrice:
                      double.tryParse(agreedPriceController.text.trim()) ?? 0,
                  bookingAmount:
                      double.tryParse(bookingAmountController.text.trim()) ?? 0,
                  paymentPlan: selectedPaymentPlan ?? '',
                  loanRequired: loanRequired,
                  loanBank: loanBankController.text.trim(),
                  commissionPercent: double.tryParse(
                          commissionPercentController.text.trim()) ??
                      0,
                  commissionPaid: commissionPaid,
                  commissionPaidDate:
                      commissionPaid && commissionPaidDate != null
                          ? _toYmd(commissionPaidDate!)
                          : null,
                  closedByManager: selectedManagerId,
                  closureNotes: notesController.text.trim(),
                  token: _authProvider.currentAuthToken,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() => isSubmitting = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(AppErrorHandler.friendlyMessage(e))),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit Closure',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700),
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
                      const SizedBox(height: 8),
                      _stepTabs(step, (v) => setLocalState(() => step = v)),
                      const SizedBox(height: 14),
                      if (step == 'booking') ...[
                        _dateField('Booking Date *', bookingDate, pickDate),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _textField(
                                    'Unit Number', unitNumberController)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _textField(
                                    'Tower / Block', towerController)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Floor',
                                floorController,
                                keyboardType: TextInputType.number,
                                hintText: 'Floor',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _textField(
                                'Unit Type',
                                unitTypeController,
                                hintText: 'Unit Type',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _textField(
                                'Carpet Area (sqft)',
                                carpetAreaController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: 'Carpet',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          'Super Area (sqft)',
                          superAreaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 10),
                        _textField('Closure Notes', notesController,
                            maxLines: 3),
                      ] else if (step == 'financials') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Agreed Price (Rs) *',
                                agreedPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '9500000',
                                prefixText: 'Rs ',
                                onChanged: (_) => setLocalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _textField(
                                'Booking Amount (Rs)',
                                bookingAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '500000',
                                prefixText: 'Rs ',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: 'Payment Plan',
                          value: (selectedPaymentPlan ?? '').isEmpty
                              ? null
                              : selectedPaymentPlan,
                          hint: 'Select payment plan...',
                          items: paymentPlans
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child:
                                      Text(e, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedPaymentPlan = v),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: loanRequired,
                          onChanged: (v) =>
                              setLocalState(() => loanRequired = v ?? false),
                          title: const Text(
                            'Home loan required',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                'Commission % (auto-calcs amount)',
                                commissionPercentController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                hintText: '2',
                                prefixText: '% ',
                                onChanged: (_) => setLocalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _readOnlyField(
                                'Commission Amount (Rs)',
                                _rupee(
                                  (double.tryParse(agreedPriceController.text
                                              .trim()) ??
                                          0) *
                                      (double.tryParse(
                                            commissionPercentController.text
                                                .trim(),
                                          ) ??
                                          0) /
                                      100,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: 'Reporting Manager',
                          value: selectedManagerId,
                          hint: 'Select manager...',
                          items: users
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: _readString(e['id'], fallback: ''),
                                  child: Text(
                                    '${_readString(e['first_name'], fallback: '').trim()} ${_readString(e['last_name'], fallback: '').trim()}'
                                        .trim(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .where((e) => (e.value ?? '').isNotEmpty)
                              .toList(),
                          onChanged: (v) =>
                              setLocalState(() => selectedManagerId = v),
                        ),
                        const SizedBox(height: 10),
                        if (commissionPaid) ...[
                          _dateField(
                            'Commission Paid Date',
                            commissionPaidDate ?? DateTime.now(),
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    commissionPaidDate ?? DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 3650)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 3650)),
                              );
                              if (picked == null) return;
                              setLocalState(() => commissionPaidDate = picked);
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        CheckboxListTile(
                          value: commissionPaid,
                          onChanged: (v) => setLocalState(() {
                            commissionPaid = v ?? false;
                            if (commissionPaid && commissionPaidDate == null) {
                              commissionPaidDate = DateTime.now();
                            }
                          }),
                          title: const Text(
                            'Commission already paid',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Update Closure'),
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

    unitNumberController.dispose();
    towerController.dispose();
    floorController.dispose();
    unitTypeController.dispose();
    carpetAreaController.dispose();
    superAreaController.dispose();
    agreedPriceController.dispose();
    bookingAmountController.dispose();
    loanBankController.dispose();
    commissionPercentController.dispose();
    notesController.dispose();

    if (updated == true && mounted) {
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Closure updated successfully.')));
    }
  }

  Future<void> _openStatusUpdateDialog(Map<String, dynamic> item) async {
    final closureId = _readString(item['id'], fallback: '');
    if (closureId.isEmpty) return;

    final noteController = TextEditingController();
    bool isSubmitting = false;
    final currentStatus =
        _readString(item['status'], fallback: 'confirmed').toLowerCase();
    String selectedStatus = _statusToUi(currentStatus);

    final leadName = _readString(item['lead_name'], fallback: 'N/A');
    final projectName = _readString(item['project_name'], fallback: 'N/A');
    final bookingDate =
        _formatDate(_readString(item['booking_date'], fallback: ''));

    List<String> allowedStatuses;
    if (currentStatus == 'confirmed') {
      allowedStatuses = <String>['Confirmed', 'On Hold', 'Cancelled'];
    } else {
      allowedStatuses = <String>[selectedStatus];
    }
    if (!allowedStatuses.contains(selectedStatus)) {
      selectedStatus = allowedStatuses.first;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              setLocalState(() => isSubmitting = true);
              try {
                await _authProvider.updateClosureStatus(
                  id: closureId,
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
                  SnackBar(
                      content:
                          Text(AppErrorHandler.friendlyMessage(e))),
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
                              'Change Closure Status',
                              style: TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w700),
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
                                    '$projectName · $bookingDate',
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
                      const Text('New Status'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: _fieldDecoration(hint: 'Select status'),
                        items: allowedStatuses
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) => setLocalState(
                                  () =>
                                      selectedStatus = value ?? selectedStatus,
                                ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Note (optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        enabled: !isSubmitting,
                        maxLines: 3,
                        decoration: _fieldDecoration(
                            hint: 'Reason for status change...'),
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
      await _loadClosures();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Closure status updated')));
    }
  }

  String _uiToApiStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'on hold':
        return 'on_hold';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return 'confirmed';
    }
  }

  String _statusToUi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'on_hold':
      case 'on hold':
        return 'On Hold';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return 'Confirmed';
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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
          Text(_error ?? 'Unable to load closures.',
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadClosures,
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
      child: const Text('No closures found.',
          style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _isLoading || _currentPage <= 1
                ? null
                : () => _loadClosures(page: _currentPage - 1),
            child: const Text('Previous'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Page $_currentPage of $_totalPages - $_totalItems total',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _isLoading || _currentPage >= _totalPages
                ? null
                : () => _loadClosures(page: _currentPage + 1),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final query = _searchController.text.trim().toLowerCase();
    final lead = _readString(item['lead_name'], fallback: '').toLowerCase();
    final project =
        _readString(item['project_name'], fallback: '').toLowerCase();
    final unit = _readString(item['unit_number'], fallback: '').toLowerCase();
    return query.isEmpty ||
        lead.contains(query) ||
        project.contains(query) ||
        unit.contains(query);
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
    if (value <= 0) return 'Rs 0';
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  String _toYmd(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
      'Dec'
    ];
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'done':
        return const Color(0xFF0A9A55);
      case 'pending':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }
}

