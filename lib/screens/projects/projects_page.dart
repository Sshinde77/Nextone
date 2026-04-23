import 'package:flutter/material.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:nextone/constants/app_colors.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<_Project> _projects = const [
    _Project(
      name: 'Skyline Heights',
      location: 'Downtown, Sector 42',
      configuration: '2BHK, 3BHK Luxury Apartments',
      status: 'Ongoing',
      mappedLeads: 45,
    ),
    _Project(
      name: 'Emerald Garden',
      location: 'Green Valley, Phase 2',
      configuration: 'Villas & Row Houses',
      status: 'Completed',
      mappedLeads: 128,
    ),
    _Project(
      name: 'Azure Business Hub',
      location: 'IT Corridor, North Wing',
      configuration: 'Premium Office Spaces',
      status: 'Planning',
      mappedLeads: 12,
    ),
    _Project(
      name: 'The Grand Atrium',
      location: 'Central Plaza',
      configuration: 'Retail Outlets & Showrooms',
      status: 'Ongoing',
      mappedLeads: 34,
    ),
  ];

  List<_Project> get _filteredProjects {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _filteredProjects;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(title: 'Projects'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const SizedBox(height: 18),
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildSearchAndCreateRow(),
          const SizedBox(height: 16),
          Text(
            'Active Projects (${projects.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...projects.map(_buildProjectCard),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Overview',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryStat('Total Projects', '12', AppColors.primary),
              const SizedBox(width: 8),
              _buildSummaryStat('Total Leads', '219', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
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
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                project.location,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),
          _buildInfoRow(Icons.layers_outlined, 'Config', project.configuration),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.link,
            'Leads Mapped',
            '${project.mappedLeads} Leads',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCircleActionButton(
                Icons.visibility_outlined,
                AppColors.info,
                () {},
              ),
              const SizedBox(width: 12),
              _buildCircleActionButton(
                Icons.edit_outlined,
                AppColors.warning,
                () {},
              ),
              const SizedBox(width: 12),
              _buildCircleActionButton(
                Icons.delete_outline,
                AppColors.error,
                () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'ongoing':
        color = AppColors.info;
        break;
      case 'completed':
        color = AppColors.success;
        break;
      case 'planning':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
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

  Widget _buildCircleActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
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
}

class _Project {
  final String name;
  final String location;
  final String configuration;
  final String status;
  final int mappedLeads;

  const _Project({
    required this.name,
    required this.location,
    required this.configuration,
    required this.status,
    required this.mappedLeads,
  });
}
