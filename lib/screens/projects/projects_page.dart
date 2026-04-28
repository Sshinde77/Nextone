import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/projects/project_detail_page.dart';
import 'package:nextone/screens/projects/project_form_page.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final TextEditingController _searchController = TextEditingController();
  final AuthProvider _authProvider = AuthProvider();

  List<_Project> _projects = const <_Project>[];
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _loadError;

  List<_Project> get _filteredProjects {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final result = await _authProvider.projects(
        token: _authProvider.currentAuthToken,
        page: 1,
        perPage: 200,
      );
      final items = result.items.map(_projectFromApi).toList();
      if (!mounted) return;
      setState(() {
        _projects = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        return value.map((e) => readString(e)).where((e) => e.isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const <String>[];
    }

    return _Project(
      id: readString(payload['id']),
      name: readString(payload['name']),
      developer: readString(payload['developer']),
      city: readString(payload['city']),
      locality: readString(payload['locality']),
      address: readString(payload['address']),
      configurations: readList(payload['configurations']),
      priceRange: readString(payload['price_range']),
      totalUnits: readInt(payload['total_units']),
      possessionDate: readString(payload['possession_date']),
      reraNumber: readString(payload['rera_number']),
      amenities: readList(payload['amenities']),
      status: readString(payload['status']),
      brochureUrl: payload['brochure_url'] == null ? null : readString(payload['brochure_url']),
      description: readString(payload['description']),
      createdBy: readString(payload['created_by']),
      totalLeads: readString(payload['total_leads']),
      mappedLeads: readInt(payload['total_leads']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = _filteredProjects;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Projects'),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SizedBox(height: 18),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildSearchAndCreateRow(),
            const SizedBox(height: 16),
            Text(
              'Projects (${projects.length})',
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
            else
              ...projects.map(_buildProjectCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalLeads = _projects.fold<int>(0, (sum, item) => sum + item.mappedLeads);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildSummaryStat('Total Projects', '${_projects.length}', AppColors.primary),
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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
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
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search projects',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _openCreateProject,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: const Text('Add Project'),
        ),
      ],
    );
  }

  Widget _buildProjectCard(_Project project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              _buildStatusBadge(project.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  project.location,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),
          _buildInfoRow(Icons.layers_outlined, 'Config', project.configurationText),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.link, 'Leads', '${project.mappedLeads}'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCircleActionButton(
                Icons.visibility_outlined,
                AppColors.info,
                () => _openProjectDetails(project),
              ),
              const SizedBox(width: 12),
              _buildCircleActionButton(
                Icons.edit_outlined,
                AppColors.warning,
                () => _openEditProject(project),
              ),
              const SizedBox(width: 12),
              _buildCircleActionButton(
                Icons.delete_outline,
                AppColors.error,
                _isDeleting ? () {} : () => _deleteProject(project),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = normalized == 'active' ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        normalized.isEmpty ? 'N/A' : normalized.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: color),
        onPressed: onPressed,
      ),
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
        child: Text('No projects found.', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Future<void> _openCreateProject() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProjectFormPage()),
    );
    if (created == true) {
      await _loadProjects();
    }
  }

  Future<void> _openEditProject(_Project project) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectFormPage(projectData: project.toPayload()),
      ),
    );
    if (updated == true) {
      await _loadProjects();
    }
  }

  Future<void> _openProjectDetails(_Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailPage(projectId: project.id, initialData: project.toPayload()),
      ),
    );
  }

  Future<void> _deleteProject(_Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${project.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
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
}

class _Project {
  final String id;
  final String name;
  final String developer;
  final String city;
  final String locality;
  final String address;
  final List<String> configurations;
  final String priceRange;
  final int totalUnits;
  final String possessionDate;
  final String reraNumber;
  final List<String> amenities;
  final String status;
  final String? brochureUrl;
  final String description;
  final String createdBy;
  final String totalLeads;
  final int mappedLeads;

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
    required this.description,
    required this.createdBy,
    required this.totalLeads,
    required this.mappedLeads,
  });

  String get location => '$locality, $city';
  String get configurationText => configurations.join(', ');

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'developer': developer,
      'city': city,
      'locality': locality,
      'address': address,
      'configurations': configurations,
      'price_range': priceRange,
      'total_units': totalUnits,
      'possession_date': possessionDate,
      'rera_number': reraNumber,
      'amenities': amenities,
      'status': status,
      'brochure_url': brochureUrl,
      'description': description,
      'created_by': createdBy,
      'total_leads': totalLeads,
    };
  }
}
