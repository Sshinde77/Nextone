import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/projects/project_detail_page.dart';
import 'package:nextone/screens/projects/project_form_page.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/utils/export_file_helper.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/widgets/data_card.dart';
import 'package:nextone/widgets/pagination_widget.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  static const List<String> _statusOptions = <String>[
    'active',
    'inactive',
    'upcoming',
    'completed',
  ];
  static const List<_ShareFieldOption> _shareFieldOptions = <_ShareFieldOption>[
    _ShareFieldOption(key: 'name', label: 'Project Name'),
    _ShareFieldOption(key: 'developer', label: 'Developer'),
    _ShareFieldOption(key: 'city', label: 'City'),
    _ShareFieldOption(key: 'locality', label: 'Locality'),
    _ShareFieldOption(key: 'price_range', label: 'Price Range'),
    _ShareFieldOption(key: 'total_units', label: 'Total Units'),
    _ShareFieldOption(key: 'rera_number', label: 'RERA Number'),
    _ShareFieldOption(key: 'configurations', label: 'Configurations'),
    _ShareFieldOption(key: 'status', label: 'Status'),
    _ShareFieldOption(key: 'description', label: 'Description'),
  ];

  final TextEditingController _searchController = TextEditingController();
  final AuthProvider _authProvider = AuthProvider();
  final RegExp _emailPattern =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  Timer? _searchDebounce;

  List<_Project> _projects = const <_Project>[];
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _loadError;
  String _currentRole = '';
  String? _selectedStatus;
  int _currentPage = 1;
  int _totalPages = 1;
  int _perPage = 10;
  int _totalItems = 0;

  bool get _canCreateProjects => RoleAccess.canCreateProjects(_currentRole);
  bool get _canEditProjects => RoleAccess.canEditProjects(_currentRole);
  bool get _canDeleteProjects => RoleAccess.canDeleteProjects(_currentRole);

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadProjects();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
      });
    } catch (_) {
      // Keep project management actions hidden if access cannot be resolved.
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects({int? page}) async {
    final requestedPage = page ?? _currentPage;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final filters = _parseSearchFilters(_searchController.text);
      final result = await _authProvider.projects(
        token: _authProvider.currentAuthToken,
        city: filters.city,
        status: _selectedStatus,
        search: filters.search,
        page: requestedPage,
        perPage: _perPage,
      );
      final items = result.items.map(_projectFromApi).toList();
      if (!mounted) return;
      setState(() {
        _projects = items;
        _currentPage =
            result.currentPage <= 0 ? requestedPage : result.currentPage;
        _perPage = result.perPage <= 0 ? _perPage : result.perPage;
        _totalItems = result.totalItems < 0 ? 0 : result.totalItems;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = AppErrorHandler.friendlyMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  _ProjectSearchFilters _parseSearchFilters(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return const _ProjectSearchFilters();
    }

    String? city;
    String remaining = input;

    final cityTagMatch =
        RegExp(r'city\s*:\s*([^\s,]+)', caseSensitive: false).firstMatch(input);
    if (cityTagMatch != null) {
      city = cityTagMatch.group(1)?.trim();
      remaining = input.replaceFirst(cityTagMatch.group(0) ?? '', '').trim();
    } else {
      final csvParts = input.split(RegExp(r'\s*,\s*'));
      if (csvParts.length >= 2) {
        city = csvParts.first.trim();
        remaining = csvParts.skip(1).join(' ').trim();
      }
    }

    return _ProjectSearchFilters(
      city: (city == null || city.isEmpty) ? null : city,
      search: remaining.isEmpty ? null : remaining,
    );
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _loadProjects(page: 1);
    });
  }

  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value;
    });
    _loadProjects(page: 1);
  }

  _Project _projectFromApi(Map<String, dynamic> payload) {
    String readString(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(readString(value)) ?? 0;
    }

    List<String> readList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => readString(e))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    String readDocumentPublicUrl(dynamic value) {
      if (value is Map<String, dynamic>) {
        return readString(
          value['public_url'] ?? value['url'] ?? value['file_path'],
        );
      }
      if (value is Map) {
        return readDocumentPublicUrl(Map<String, dynamic>.from(value));
      }
      return '';
    }

    List<String> readPhotoUrls(dynamic value) {
      if (value is! List) {
        return const <String>[];
      }
      return value
          .map((item) {
            if (item is Map<String, dynamic>) {
              return readDocumentPublicUrl(item);
            }
            if (item is Map) {
              return readDocumentPublicUrl(Map<String, dynamic>.from(item));
            }
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }

    List<_ProjectConfiguration> readConfigurations(dynamic value) {
      if (value is List) {
        return value
            .map((item) {
              if (item is Map<String, dynamic>) {
                return _ProjectConfiguration.fromMap(item);
              }
              if (item is Map) {
                return _ProjectConfiguration.fromMap(
                    Map<String, dynamic>.from(item));
              }
              return _ProjectConfiguration(
                configuration: readString(item),
                carpetArea: '',
                price: '',
              );
            })
            .where((item) => item.hasContent)
            .toList(growable: false);
      }

      final flat = readList(value);
      return flat
          .map(
            (item) => _ProjectConfiguration(
              configuration: item,
              carpetArea: '',
              price: '',
            ),
          )
          .toList(growable: false);
    }

    return _Project(
      id: readString(payload['id']),
      name: readString(payload['name']),
      developer: readString(payload['developer']),
      city: readString(payload['city']),
      locality: readString(payload['locality']),
      address: readString(payload['address']),
      configurations: readConfigurations(payload['configurations']),
      priceRange: readString(payload['price_range']),
      totalUnits: readInt(payload['total_units']),
      possessionDate: readString(payload['possession_date']),
      reraNumber: readString(payload['rera_number']),
      amenities: readList(payload['amenities']),
      status: readString(payload['status']),
      brochureUrl: payload['brochure_url'] == null
          ? null
          : readString(payload['brochure_url']),
      videoUrl: payload['video_url'] == null
          ? null
          : readString(payload['video_url']),
      paymentPlanUrl: payload['payment_plan_url'] == null
          ? null
          : readString(payload['payment_plan_url']),
      homeLoanInfo: payload['home_loan_info'] == null
          ? null
          : readString(payload['home_loan_info']),
      description: readString(payload['description']),
      createdBy: readString(payload['created_by']),
      totalLeads: readString(payload['total_leads']),
      mappedLeads: readInt(payload['total_leads']),
      developerLogoUrl: readDocumentPublicUrl(payload['developer_logo']),
      photoUrls: readPhotoUrls(payload['photos']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Projects'),
      body: RefreshIndicator(
        onRefresh: () => _loadProjects(page: _currentPage),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SizedBox(height: 18),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildSearchAndCreateRow(),
            const SizedBox(height: 16),
            Text(
              'Projects (${_totalItems > 0 ? _totalItems : projects.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              _buildErrorState()
            else if (projects.isEmpty)
              _buildEmptyState()
            else ...[
              ...projects.map(_buildProjectCard),
              const SizedBox(height: 8),
              Center(
                child: PaginationWidget(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  totalItems: _totalItems,
                  itemLabel: 'projects',
                  onPageChanged: (page) => _loadProjects(page: page),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalLeads =
        _projects.fold<int>(0, (sum, item) => sum + item.mappedLeads);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildSummaryStat(
              'Total Projects', '${_projects.length}', AppColors.primary),
          const SizedBox(width: 8),
          _buildSummaryStat('Total Leads', '$totalLeads', AppColors.success),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndCreateRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search (city:Mumbai Skyline) or (Mumbai, Skyline)',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStatus,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
                hint: const Text(
                  'Status',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ..._statusOptions.map(
                    (status) => DropdownMenuItem<String?>(
                      value: status,
                      child: Text(_formatStatusLabel(status)),
                    ),
                  ),
                ],
                onChanged: _onStatusChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // if (_canExportData) ...[
        //   OutlinedButton.icon(
        //     onPressed: _isExporting ? null : _exportProjects,
        //     icon: _isExporting
        //         ? const SizedBox(
        //             width: 16,
        //             height: 16,
        //             child: CircularProgressIndicator(strokeWidth: 2),
        //           )
        //         : const Icon(Icons.download_rounded, size: 18),
        //     label: Text(_isExporting ? 'Exporting...' : 'Export'),
        //     style: OutlinedButton.styleFrom(
        //       minimumSize: const Size(110, 50),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(999),
        //       ),
        //     ),
        //   ),
        //   const SizedBox(width: 8),
        // ],
        if (_canCreateProjects)
          FilledButton(
            onPressed: _openCreateProject,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Add Project'),
          ),
      ],
    );
  }

  String _formatStatusLabel(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Widget _buildProjectCard(_Project project) {
    final normalizedStatus = project.status.toLowerCase();
    final statusColor = normalizedStatus == 'active'
        ? AppColors.success
        : normalizedStatus == 'completed'
            ? AppColors.primary
            : AppColors.warning;
    final coverPhotoUrl =
        project.photoUrls.isNotEmpty ? project.photoUrls.first : '';
    final location = [
      if (project.city.trim().isNotEmpty) project.city.trim(),
      if (project.locality.trim().isNotEmpty) project.locality.trim(),
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DataCardShell(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverPhotoUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProjectPhotoCarousel(photoUrls: project.photoUrls),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x08000000),
                              Color(0xAA102033),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _buildProjectStatusChip(
                          normalizedStatus,
                          statusColor,
                        ),
                      ),
                      if (project.photoUrls.length > 1)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${project.photoUrls.length} Photos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProjectLogo(project),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name.isEmpty
                                  ? 'Unnamed Project'
                                  : project.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.developer.isEmpty
                                  ? 'Developer not added'
                                  : project.developer,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (coverPhotoUrl.isEmpty)
                        _buildProjectStatusChip(normalizedStatus, statusColor),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildProjectMetricRow(
                        left: _buildProjectMetricText(
                          icon: Icons.sell_outlined,
                          label: 'Price Range',
                          value: project.priceRange.isEmpty
                              ? 'N/A'
                              : project.priceRange,
                        ),
                        right: _buildProjectMetricText(
                          icon: Icons.people_alt_outlined,
                          label: 'Total Leads',
                          value: project.totalLeads.isEmpty
                              ? '0'
                              : project.totalLeads,
                        ),
                      ),
                      _buildProjectMetricRow(
                        left: _buildProjectMetricText(
                          icon: Icons.verified_outlined,
                          label: 'RERA',
                          value: project.reraNumber.isEmpty
                              ? 'N/A'
                              : project.reraNumber,
                        ),
                        right: _buildProjectMetricText(
                          icon: Icons.apartment_outlined,
                          label: 'Configuration',
                          value: project.configurationText.isEmpty
                              ? 'N/A'
                              : project.configurationText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total Units: ${project.totalUnits > 0 ? project.totalUnits : '-'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _buildProjectActions([
                        DataCardAction(
                          icon: Icons.visibility_outlined,
                          onTap: () => _openProjectDetails(project),
                        ),
                        DataCardAction(
                          icon: Icons.share_outlined,
                          onTap: () => _shareProject(project),
                        ),
                        DataCardAction(
                          icon: Icons.download_outlined,
                          onTap: () => _openDownloadTypeSheet(project),
                        ),
                        if (_canEditProjects)
                          DataCardAction(
                            icon: Icons.edit_outlined,
                            onTap: () => _openEditProject(project),
                          ),
                        if (_canDeleteProjects)
                          DataCardAction(
                            icon: Icons.delete_outline,
                            color: AppColors.error,
                            onTap: _isDeleting
                                ? () {}
                                : () => _deleteProject(project),
                          ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectLogo(_Project project) {
    final logoUrl = project.developerLogoUrl?.trim() ?? '';
    if (logoUrl.isNotEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildProjectFallbackLogo(project),
        ),
      );
    }
    return _buildProjectFallbackLogo(project);
  }

  Widget _buildProjectFallbackLogo(_Project project) {
    final seed =
        project.developer.isNotEmpty ? project.developer : project.name;
    final initial = seed.trim().isEmpty ? 'P' : seed.trim()[0].toUpperCase();
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E4FF)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildProjectStatusChip(String normalizedStatus, Color statusColor) {
    final label = normalizedStatus.isEmpty
        ? 'N/A'
        : normalizedStatus.replaceAll('_', ' ').toUpperCase();
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildProjectMetricRow({
    required Widget left,
    required Widget right,
  }) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildProjectMetricText({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectActions(List<DataCardAction> actions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions
          .map(
            (action) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: action.onTap,
                icon: Icon(
                  action.icon,
                  size: 18,
                  color: action.color ?? AppColors.textSecondary,
                ),
                constraints:
                    const BoxConstraints.tightFor(width: 38, height: 38),
                padding: EdgeInsets.zero,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(_loadError!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadProjects, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text('No projects found.',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Future<void> _openCreateProject() async {
    if (!_canCreateProjects) {
      _showSnackBar('You do not have permission to create projects.');
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProjectFormPage()),
    );
    if (created == true) {
      await _loadProjects();
    }
  }

  Future<void> _openEditProject(_Project project) async {
    if (!_canEditProjects) {
      _showSnackBar('You do not have permission to edit projects.');
      return;
    }
    Map<String, dynamic> projectData = project.toPayload();
    try {
      final detail = await _authProvider.projectDetail(
        id: project.id,
        token: _authProvider.currentAuthToken,
      );
      projectData = <String, dynamic>{
        ...projectData,
        ...detail,
      };
    } catch (_) {
      // Fall back to the list payload if the detail request fails.
    }
    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectFormPage(projectData: projectData),
      ),
    );
    if (updated == true) {
      await _loadProjects();
    }
  }

  Future<void> _openProjectDetails(_Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailPage(
            projectId: project.id, initialData: project.toPayload()),
      ),
    );
  }

  Future<void> _deleteProject(_Project project) async {
    if (!_canDeleteProjects) {
      _showSnackBar('You do not have permission to delete projects.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${project.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });
    try {
      await _authProvider.deleteProject(
        id: project.id,
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showSnackBar('Project deleted successfully.');
      await _loadProjects();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDownloadTypeSheet(_Project project) async {
    _ProjectDocumentAvailability? availability;
    try {
      availability = await _loadProjectDocumentAvailability(project);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            Future<void> refreshAvailability() async {
              final refreshed = await _loadProjectDocumentAvailability(project);
              if (!mounted) return;
              modalSetState(() {
                availability = refreshed;
              });
            }

            Future<void> handleDownload(
                _ProjectDocumentCategory category) async {
              Navigator.of(context).pop();
              if (category == _ProjectDocumentCategory.all) {
                await _downloadProjectDocumentArchive(project, 'all');
                return;
              }
              if (category == _ProjectDocumentCategory.paymentPlans ||
                  category == _ProjectDocumentCategory.videos) {
                await _downloadProjectDocumentArchive(
                  project,
                  category.apiKey,
                );
                return;
              }
              await _downloadProjectDocumentsByType(project, category.apiKey);
            }

            Future<void> handleUpload(
              _ProjectDocumentCategory category,
            ) async {
              await _uploadProjectDocumentsForCategory(project, category);
              await refreshAvailability();
            }

            final buckets = <_ProjectDocumentBucket>[
              _ProjectDocumentBucket(
                category: _ProjectDocumentCategory.all,
                documents: availability!.allDocuments,
              ),
              _ProjectDocumentBucket(
                category: _ProjectDocumentCategory.unitPlans,
                documents: availability!.unitPlans,
              ),
              _ProjectDocumentBucket(
                category: _ProjectDocumentCategory.creatives,
                documents: availability!.creatives,
              ),
              _ProjectDocumentBucket(
                category: _ProjectDocumentCategory.paymentPlans,
                documents: availability!.paymentPlans,
              ),
              _ProjectDocumentBucket(
                category: _ProjectDocumentCategory.videos,
                documents: availability!.videos,
              ),
            ];

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Download Documents',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final bucket in buckets) ...[
                      _buildDocumentActionCard(
                        bucket: bucket,
                        onDownload: bucket.documents.isEmpty
                            ? null
                            : () => handleDownload(bucket.category),
                        onUpload:
                            bucket.category == _ProjectDocumentCategory.all
                                ? null
                                : () => handleUpload(bucket.category),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_ProjectDocumentAvailability> _loadProjectDocumentAvailability(
    _Project project,
  ) async {
    final payload = await _authProvider.projectDocuments(
      id: project.id,
      token: _authProvider.currentAuthToken,
    );
    final unitPlans = _extractDocuments(payload, 'unit_plans');
    final creatives = _extractDocuments(payload, 'creatives');
    final paymentPlans = _extractDocuments(payload, 'payment_plans');
    final videos = _extractDocuments(payload, 'videos');
    return _ProjectDocumentAvailability(
      unitPlans: unitPlans,
      creatives: creatives,
      paymentPlans: paymentPlans,
      videos: videos,
    );
  }

  Future<void> _uploadProjectDocumentsForCategory(
    _Project project,
    _ProjectDocumentCategory category,
  ) async {
    if (kIsWeb) {
      _showSnackBar('Document upload is not supported on Web in this build.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: category.allowedExtensions,
      allowMultiple: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final filePaths = picked.files
        .map((file) => file.path?.trim() ?? '')
        .where((path) => path.isNotEmpty)
        .toList();
    if (filePaths.isEmpty) {
      _showSnackBar('Could not read the selected file paths.');
      return;
    }

    try {
      final uploadPayload = <String, List<String>>{
        'unit_plans': const <String>[],
        'creatives': const <String>[],
        'payment_plans': const <String>[],
        'videos': const <String>[],
      };
      uploadPayload[category.apiKey] = filePaths;

      await _authProvider.uploadProjectDocuments(
        id: project.id,
        unitPlanFilePaths: uploadPayload['unit_plans'] ?? const <String>[],
        creativeFilePaths: uploadPayload['creatives'] ?? const <String>[],
        paymentPlanFilePaths:
            uploadPayload['payment_plans'] ?? const <String>[],
        videoFilePaths: uploadPayload['videos'] ?? const <String>[],
        token: _authProvider.currentAuthToken,
      );
      if (!mounted) return;
      _showSnackBar('${category.label} uploaded successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Future<void> _downloadProjectDocumentArchive(
    _Project project,
    String archiveType,
  ) async {
    try {
      late final dynamic exported;
      late final String fallbackFileName;
      late final String successMessage;

      switch (archiveType) {
        case 'payment_plans':
          exported = await _authProvider.downloadAllProjectPaymentPlans(
            id: project.id,
            token: _authProvider.currentAuthToken,
          );
          fallbackFileName =
              '${project.name.replaceAll(' ', '_')}_payment_plans.zip';
          successMessage = 'Downloaded all payment plans.';
          break;
        case 'videos':
          exported = await _authProvider.downloadAllProjectVideos(
            id: project.id,
            token: _authProvider.currentAuthToken,
          );
          fallbackFileName = '${project.name.replaceAll(' ', '_')}_videos.zip';
          successMessage = 'Downloaded all videos.';
          break;
        case 'all':
          exported = await _authProvider.downloadAllProjectDocuments(
            id: project.id,
            token: _authProvider.currentAuthToken,
          );
          fallbackFileName =
              '${project.name.replaceAll(' ', '_')}_documents.zip';
          successMessage = 'Downloaded all documents.';
          break;
        default:
          throw Exception('Unsupported download type.');
      }

      final fileName = exported.fileName.trim().isEmpty
          ? fallbackFileName
          : exported.fileName.trim();
      if (kIsWeb) {
        _showSnackBar(
          'Documents ready ($fileName), direct save is not supported on Web in this build.',
        );
        return;
      }
      await ExportFileHelper.saveToDownloadNextone(
        fileName: fileName,
        bytes: exported.bytes,
      );
      if (!mounted) return;
      _showSnackBar(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Future<void> _downloadProjectDocumentsByType(
    _Project project,
    String category,
  ) async {
    try {
      final payload = await _authProvider.projectDocuments(
        id: project.id,
        token: _authProvider.currentAuthToken,
      );
      final docs = _extractDocuments(payload, category);
      if (docs.isEmpty) {
        _showSnackBar(_missingDocumentMessage(category));
        return;
      }

      var downloaded = 0;
      for (final doc in docs) {
        final exported = await _authProvider.downloadProjectDocument(
          projectId: project.id,
          documentId: doc.id,
          token: _authProvider.currentAuthToken,
        );
        final fileName = exported.fileName.trim().isEmpty
            ? doc.name
            : exported.fileName.trim();
        if (kIsWeb) continue;
        await ExportFileHelper.saveToDownloadNextone(
          fileName: fileName,
          bytes: exported.bytes,
        );
        downloaded++;
      }
      if (!mounted) return;
      if (kIsWeb) {
        _showSnackBar(
          'Download ready for ${docs.length} file(s), direct save is not supported on Web in this build.',
        );
      } else {
        _showSnackBar('Downloaded $downloaded file(s).');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  List<_ProjectDocRef> _extractDocuments(
    Map<String, dynamic> payload,
    String category,
  ) {
    dynamic source;
    final data = payload['data'];
    if (payload[category] is List) {
      source = payload[category];
    } else if (data is Map<String, dynamic> && data[category] is List) {
      source = data[category];
    } else {
      final docs = payload['documents'] ??
          (data is Map ? data['documents'] : null) ??
          (data is List ? data : null);
      if (docs is Map<String, dynamic> && docs[category] is List) {
        source = docs[category];
      } else if (docs is List) {
        source = docs.where((item) {
          if (item is! Map) return false;
          final type = _readDocValue(
            item['category'] ?? item['type'] ?? item['document_type'],
          ).toLowerCase();
          if (category == 'unit_plans') {
            return type.contains('unit') || type.contains('plan');
          }
          if (category == 'payment_plans') {
            return type.contains('payment');
          }
          if (category == 'videos') {
            return type.contains('video');
          }
          return type.contains('creative');
        }).toList();
      }
    }
    if (source is! List) return const <_ProjectDocRef>[];
    return source
        .whereType<Map>()
        .map((m) => _ProjectDocRef.fromMap(Map<String, dynamic>.from(m)))
        .where((d) => d.id.isNotEmpty)
        .toList();
  }

  List<_ProjectDocRef> _extractAllDocuments(Map<String, dynamic> payload) {
    final collected = <_ProjectDocRef>[];
    final seenIds = <String>{};
    const categoryKeys = <String>{
      'data',
      'result',
      'results',
      'response',
      'payload',
      'items',
      'unit_plans',
      'creatives',
      'payment_plans',
      'videos',
      'documents',
    };

    void addDoc(dynamic item) {
      if (item is! Map) return;
      final doc = _ProjectDocRef.fromMap(Map<String, dynamic>.from(item));
      if (doc.id.isEmpty || !seenIds.add(doc.id)) {
        return;
      }
      collected.add(doc);
    }

    void visitNode(dynamic node, {String? parentKey}) {
      if (node is List) {
        for (final item in node) {
          if (item is Map || item is List) {
            visitNode(item, parentKey: parentKey);
          }
        }
        return;
      }

      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      if (_ProjectDocRef.fromMap(map).id.isNotEmpty) {
        addDoc(map);
      }

      for (final entry in map.entries) {
        final key = entry.key.trim().toLowerCase();
        final value = entry.value;
        if (categoryKeys.contains(key)) {
          visitNode(value, parentKey: key);
        } else if (parentKey != null && (value is List || value is Map)) {
          visitNode(value, parentKey: parentKey);
        }
      }
    }

    visitNode(payload);
    return collected;
  }

  String _readDocValue(dynamic value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  String _missingDocumentMessage(String category) {
    switch (category) {
      case 'unit_plans':
        return 'No unit plan documents found.';
      case 'creatives':
        return 'No creative documents found.';
      case 'payment_plans':
        return 'No payment plan documents found.';
      case 'videos':
        return 'No video documents found.';
      default:
        return 'No documents found.';
    }
  }

  Future<List<String>?> _openMultiSelectSheet({
    required String title,
    required List<_ShareOptionItem> options,
    required List<String> initialSelectedIds,
  }) async {
    final initial = List<String>.from(initialSelectedIds);
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final selectedIds = List<String>.from(initial);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        options.isEmpty
                            ? 'No options available.'
                            : 'Select one or more options.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: options.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nothing available to select.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox.shrink(),
                                itemBuilder: (context, index) {
                                  final option = options[index];
                                  final selected =
                                      selectedIds.contains(option.id);
                                  return CheckboxListTile(
                                    value: selected,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: AppColors.primary,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      option.label,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          if (!selectedIds
                                              .contains(option.id)) {
                                            selectedIds.add(option.id);
                                          }
                                        } else {
                                          selectedIds.remove(option.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(sheetContext)
                                  .pop(List<String>.from(selectedIds)),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Apply'),
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
  }

  Future<void> _shareProject(_Project project) async {
    List<_ProjectDocRef> availableDocuments = const <_ProjectDocRef>[];
    try {
      final payload = await _authProvider.projectDocuments(
        id: project.id,
        token: _authProvider.currentAuthToken,
      );
      availableDocuments = _extractAllDocuments(payload);
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          'Could not load project documents. You can still share the project details.',
        );
      }
    }
    if (!mounted) {
      return;
    }

    final emailController = TextEditingController();
    final messageController = TextEditingController(
      text: 'Hi, here are the project details!',
    );
    final emails = <String>[];
    final selectedFieldKeys = <String>['name'];
    final selectedDocumentIds = <String>[];
    var isSharing = false;

    bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

    void addEmails(
      String rawValue,
      void Function(void Function()) setDialogState,
    ) {
      final parsed = rawValue
          .split(RegExp(r'[,\n]'))
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isEmpty) return;
      final invalid = parsed.where((item) => !isValidEmail(item)).toList();
      if (invalid.isNotEmpty) {
        _showSnackBar('Invalid email: ${invalid.first}');
        return;
      }
      setDialogState(() {
        for (final email in parsed) {
          if (!emails.contains(email)) {
            emails.add(email);
          }
        }
      });
      emailController.clear();
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (isSharing) return;
              if (emailController.text.trim().isNotEmpty) {
                addEmails(emailController.text, setDialogState);
              }
              if (emails.isEmpty) {
                _showSnackBar('Please add at least one email.');
                return;
              }
              setDialogState(() {
                isSharing = true;
              });
              try {
                final response = await _authProvider.shareProject(
                  id: project.id,
                  emails: emails,
                  message: messageController.text.trim(),
                  fields: selectedFieldKeys,
                  documentIds: selectedDocumentIds,
                  token: _authProvider.currentAuthToken,
                );
                if (!mounted) return;
                final responseMessage =
                    (response['message'] ?? 'Project shared successfully')
                        .toString();
                _showSnackBar(responseMessage);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (!mounted) return;
                _showSnackBar(AppErrorHandler.friendlyMessage(error));
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSharing = false;
                  });
                }
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.share_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Share Project',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                project.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSharing
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          icon: const Icon(Icons.close),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    const Text(
                      'Send to (press Enter or comma to add multiple)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) =>
                                addEmails(emailController.text, setDialogState),
                            onChanged: (value) {
                              if (value.endsWith(',')) {
                                addEmails(value, setDialogState);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'client@example.com',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: isSharing
                                ? null
                                : () => addEmails(
                                      emailController.text,
                                      setDialogState,
                                    ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    if (emails.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: emails
                            .map(
                              (email) => Chip(
                                label: Text(email),
                                onDeleted: isSharing
                                    ? null
                                    : () => setDialogState(
                                          () => emails.remove(email),
                                        ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Personal message (optional)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Hi, please find the project details...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Fields to include',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isSharing
                          ? null
                          : () async {
                              final result = await _openMultiSelectSheet(
                                title: 'Select fields',
                                options: _shareFieldOptions
                                    .map(
                                      (option) => _ShareOptionItem(
                                        id: option.key,
                                        label: option.label,
                                      ),
                                    )
                                    .toList(),
                                initialSelectedIds: selectedFieldKeys,
                              );
                              if (result == null || !dialogContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                selectedFieldKeys
                                  ..clear()
                                  ..addAll(result);
                              });
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedFieldKeys.isEmpty
                                    ? 'Select fields'
                                    : _shareFieldOptions
                                        .where((option) => selectedFieldKeys
                                            .contains(option.key))
                                        .map((option) => option.label)
                                        .join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selectedFieldKeys.isEmpty
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Documents to include',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isSharing
                          ? null
                          : () async {
                              final result = await _openMultiSelectSheet(
                                title: 'Select documents',
                                options: availableDocuments
                                    .map(
                                      (document) => _ShareOptionItem(
                                        id: document.id,
                                        label: document.name,
                                      ),
                                    )
                                    .toList(),
                                initialSelectedIds: selectedDocumentIds,
                              );
                              if (result == null || !dialogContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                selectedDocumentIds
                                  ..clear()
                                  ..addAll(result);
                              });
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedDocumentIds.isEmpty
                                    ? 'Select documents'
                                    : availableDocuments
                                        .where((document) => selectedDocumentIds
                                            .contains(document.id))
                                        .map((document) => document.name)
                                        .join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selectedDocumentIds.isEmpty
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSharing
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSharing ? null : submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.send_outlined, size: 18),
                            label: Text(
                              isSharing ? 'Sharing...' : 'Share Project',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    emailController.dispose();
    messageController.dispose();
  }
}

class _ProjectSearchFilters {
  const _ProjectSearchFilters({
    this.city,
    this.search,
  });

  final String? city;
  final String? search;
}

class _Project {
  final String id;
  final String name;
  final String developer;
  final String city;
  final String locality;
  final String address;
  final List<_ProjectConfiguration> configurations;
  final String priceRange;
  final int totalUnits;
  final String possessionDate;
  final String reraNumber;
  final List<String> amenities;
  final String status;
  final String? brochureUrl;
  final String? videoUrl;
  final String? paymentPlanUrl;
  final String? homeLoanInfo;
  final String description;
  final String createdBy;
  final String totalLeads;
  final int mappedLeads;
  final String? developerLogoUrl;
  final List<String> photoUrls;

  const _Project({
    required this.id,
    required this.name,
    required this.developer,
    required this.city,
    required this.locality,
    required this.address,
    required this.configurations,
    required this.priceRange,
    required this.totalUnits,
    required this.possessionDate,
    required this.reraNumber,
    required this.amenities,
    required this.status,
    required this.brochureUrl,
    required this.videoUrl,
    required this.paymentPlanUrl,
    required this.homeLoanInfo,
    required this.description,
    required this.createdBy,
    required this.totalLeads,
    required this.mappedLeads,
    required this.developerLogoUrl,
    required this.photoUrls,
  });

  String get location => '$locality, $city';
  String get configurationText => configurations
      .map((item) => item.configuration.trim())
      .where((item) => item.isNotEmpty)
      .join(', ');

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'developer': developer,
      'city': city,
      'locality': locality,
      'address': address,
      'configurations':
          configurations.map((item) => item.toMap()).toList(growable: false),
      'price_range': priceRange,
      'total_units': totalUnits,
      'possession_date': possessionDate,
      'rera_number': reraNumber,
      'amenities': amenities,
      'status': status,
      'brochure_url': brochureUrl,
      'video_url': videoUrl,
      'payment_plan_url': paymentPlanUrl,
      'home_loan_info': homeLoanInfo,
      'description': description,
      'created_by': createdBy,
      'total_leads': totalLeads,
      'developer_logo': developerLogoUrl == null
          ? null
          : <String, dynamic>{'public_url': developerLogoUrl},
      'photos': photoUrls
          .map((url) => <String, dynamic>{'public_url': url})
          .toList(growable: false),
    };
  }
}

class _ProjectConfiguration {
  const _ProjectConfiguration({
    required this.configuration,
    required this.carpetArea,
    required this.price,
  });

  final String configuration;
  final String carpetArea;
  final String price;

  bool get hasContent =>
      configuration.trim().isNotEmpty ||
      carpetArea.trim().isNotEmpty ||
      price.trim().isNotEmpty;

  String get summaryLabel {
    final parts = <String>[
      if (configuration.trim().isNotEmpty) configuration.trim(),
      if (carpetArea.trim().isNotEmpty) carpetArea.trim(),
      if (price.trim().isNotEmpty) price.trim(),
    ];
    return parts.join(' • ');
  }

  factory _ProjectConfiguration.fromMap(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString().trim();
      return '';
    }

    return _ProjectConfiguration(
      configuration: read(json['configuration'] ?? json['name']),
      carpetArea: read(json['carpet_area'] ?? json['carpetArea']),
      price: read(json['price']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'configuration': configuration,
      'carpet_area': carpetArea,
      'price': price,
    };
  }
}

class _ProjectPhotoCarousel extends StatefulWidget {
  const _ProjectPhotoCarousel({
    required this.photoUrls,
  });

  final List<String> photoUrls;

  @override
  State<_ProjectPhotoCarousel> createState() => _ProjectPhotoCarouselState();
}

class _ProjectPhotoCarouselState extends State<_ProjectPhotoCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _ProjectPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrls.length != widget.photoUrls.length) {
      _currentIndex = 0;
      _timer?.cancel();
      _startAutoSlide();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  void _startAutoSlide() {
    if (widget.photoUrls.length <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % widget.photoUrls.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
      _currentIndex = nextIndex;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
      return Container(
        color: const Color(0xFFF3F6FB),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
          size: 34,
        ),
      );
    }

    if (widget.photoUrls.length == 1) {
      return Image.network(
        widget.photoUrls.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFF3F6FB),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textSecondary,
            size: 34,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.photoUrls.length,
          onPageChanged: (index) {
            _currentIndex = index;
          },
          itemBuilder: (context, index) {
            return Image.network(
              widget.photoUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF3F6FB),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary,
                  size: 34,
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(
              widget.photoUrls.length,
              (index) => Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectDocRef {
  const _ProjectDocRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory _ProjectDocRef.fromMap(Map<String, dynamic> json) {
    String read(dynamic value) {
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString();
      return '';
    }

    String readFirstValue(
      Map<String, dynamic> source,
      List<String> keys,
    ) {
      for (final key in keys) {
        final value = read(source[key]);
        if (value.isNotEmpty) {
          return value;
        }
      }

      for (final value in source.values) {
        if (value is Map<String, dynamic>) {
          final nested = readFirstValue(value, keys);
          if (nested.isNotEmpty) {
            return nested;
          }
        } else if (value is Map) {
          final nested = readFirstValue(Map<String, dynamic>.from(value), keys);
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }

      return '';
    }

    return _ProjectDocRef(
      id: readFirstValue(json, const <String>[
        'id',
        '_id',
        'doc_id',
        'document_id',
        'documentId',
        'uuid',
        'file_id',
        'fileId',
        'asset_id',
        'assetId',
        'public_id',
        'publicId',
      ]),
      name: readFirstValue(json, const <String>[
        'file_name',
        'filename',
        'original_name',
        'originalName',
        'name',
        'document_name',
        'documentName',
        'title',
        'label',
      ]),
    );
  }
}

class _ProjectDocumentAvailability {
  const _ProjectDocumentAvailability({
    required this.unitPlans,
    required this.creatives,
    required this.paymentPlans,
    required this.videos,
  });

  final List<_ProjectDocRef> unitPlans;
  final List<_ProjectDocRef> creatives;
  final List<_ProjectDocRef> paymentPlans;
  final List<_ProjectDocRef> videos;

  List<_ProjectDocRef> get allDocuments => <_ProjectDocRef>[
        ...unitPlans,
        ...creatives,
        ...paymentPlans,
        ...videos,
      ];
}

class _ProjectDocumentBucket {
  const _ProjectDocumentBucket({
    required this.category,
    required this.documents,
  });

  final _ProjectDocumentCategory category;
  final List<_ProjectDocRef> documents;
}

enum _ProjectDocumentCategory {
  all,
  unitPlans,
  creatives,
  paymentPlans,
  videos,
}

extension on _ProjectDocumentCategory {
  String get apiKey {
    switch (this) {
      case _ProjectDocumentCategory.all:
        return 'all';
      case _ProjectDocumentCategory.unitPlans:
        return 'unit_plans';
      case _ProjectDocumentCategory.creatives:
        return 'creatives';
      case _ProjectDocumentCategory.paymentPlans:
        return 'payment_plans';
      case _ProjectDocumentCategory.videos:
        return 'videos';
    }
  }

  String get label {
    switch (this) {
      case _ProjectDocumentCategory.all:
        return 'All Documents';
      case _ProjectDocumentCategory.unitPlans:
        return 'Unit Plans';
      case _ProjectDocumentCategory.creatives:
        return 'Creatives';
      case _ProjectDocumentCategory.paymentPlans:
        return 'Payment Plans';
      case _ProjectDocumentCategory.videos:
        return 'Videos';
    }
  }

  String get hint {
    switch (this) {
      case _ProjectDocumentCategory.all:
        return 'Download everything uploaded for this project.';
      case _ProjectDocumentCategory.unitPlans:
        return 'Individual unit plan files.';
      case _ProjectDocumentCategory.creatives:
        return 'Individual creative files.';
      case _ProjectDocumentCategory.paymentPlans:
        return 'Download payment plans as an archive.';
      case _ProjectDocumentCategory.videos:
        return 'Download videos as an archive.';
    }
  }

  IconData get icon {
    switch (this) {
      case _ProjectDocumentCategory.all:
        return Icons.folder_zip_outlined;
      case _ProjectDocumentCategory.unitPlans:
        return Icons.home_work_outlined;
      case _ProjectDocumentCategory.creatives:
        return Icons.collections_outlined;
      case _ProjectDocumentCategory.paymentPlans:
        return Icons.payments_outlined;
      case _ProjectDocumentCategory.videos:
        return Icons.video_library_outlined;
    }
  }

  List<String> get allowedExtensions {
    switch (this) {
      case _ProjectDocumentCategory.videos:
        return const <String>[
          'mp4',
          'mov',
          'm4v',
          'webm',
          'avi',
        ];
      case _ProjectDocumentCategory.all:
      case _ProjectDocumentCategory.unitPlans:
      case _ProjectDocumentCategory.creatives:
      case _ProjectDocumentCategory.paymentPlans:
        return const <String>[
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'doc',
          'docx',
        ];
    }
  }
}

Widget _buildDocumentActionCard({
  required _ProjectDocumentBucket bucket,
  required VoidCallback? onDownload,
  required VoidCallback? onUpload,
}) {
  final hasDocuments = bucket.documents.isNotEmpty;
  final documentCount = bucket.documents.length;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hasDocuments
                    ? const Color(0xFFEFF8FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                bucket.category.icon,
                color:
                    hasDocuments ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bucket.category.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDocuments
                        ? '$documentCount file(s) available'
                        : 'No documents uploaded yet',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onDownload,
              style: FilledButton.styleFrom(
                backgroundColor:
                    hasDocuments ? AppColors.primary : AppColors.border,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          bucket.category.hint,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (hasDocuments) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bucket.documents
                .map(
                  (document) => _DocumentPill(name: document.name),
                )
                .toList(),
          ),
        ] else if (onUpload != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(0, 38),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text('Upload ${bucket.category.label}'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _DocumentPill extends StatelessWidget {
  const _DocumentPill({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Text(
        name.isEmpty ? 'Project document' : name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ShareFieldOption {
  const _ShareFieldOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class _ShareOptionItem {
  const _ShareOptionItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}
