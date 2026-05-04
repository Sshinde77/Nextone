import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class CRMAppBottomNav extends StatefulWidget {
  final int currentIndex;

  final VoidCallback onDashboard;
  final VoidCallback onLeads;
  final VoidCallback onFollowUps;
  final VoidCallback onSiteVisits;
  final VoidCallback onProjects;
  final VoidCallback onTeam;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onMore;
  final VoidCallback onLess;

  final int? leadsBadgeCount;
  final int? followUpsBadgeCount;
  final double height;

  const CRMAppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDashboard,
    required this.onLeads,
    required this.onFollowUps,
    required this.onSiteVisits,
    required this.onProjects,
    required this.onTeam,
    required this.onReports,
    required this.onSettings,
    required this.onMore,
    required this.onLess,
    this.leadsBadgeCount,
    this.followUpsBadgeCount,
    this.height = 76,
  });

  @override
  State<CRMAppBottomNav> createState() => _CRMAppBottomNavState();
}

class _CRMAppBottomNavState extends State<CRMAppBottomNav> {
  bool _isExpanded = false;

  bool get _isExpandedIndex => widget.currentIndex >= 4;

  @override
  void initState() {
    super.initState();
    _isExpanded = _isExpandedIndex;
  }

  @override
  void didUpdateWidget(covariant CRMAppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isExpanded != _isExpandedIndex) {
      setState(() {
        _isExpanded = _isExpandedIndex;
      });
    }
  }

  void _handleMore() {
    if (_isExpanded) return;
    setState(() => _isExpanded = true);
    widget.onMore();
  }

  void _handleLess() {
    if (!_isExpanded) return;
    setState(() => _isExpanded = false);
    widget.onLess();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: AppColors.surface,
            child: SizedBox(
              height: widget.height,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _isExpanded
                    ? _ExpandedNavBar(
                        key: const ValueKey<String>('expanded-nav'),
                        currentIndex: widget.currentIndex,
                        onProjects: widget.onProjects,
                        onTeam: widget.onTeam,
                        onReports: widget.onReports,
                        onSettings: widget.onSettings,
                        onLess: _handleLess,
                      )
                    : _MainNavBar(
                        key: const ValueKey<String>('main-nav'),
                        currentIndex: widget.currentIndex,
                        onDashboard: widget.onDashboard,
                        onLeads: widget.onLeads,
                        onFollowUps: widget.onFollowUps,
                        onSiteVisits: widget.onSiteVisits,
                        onMore: _handleMore,
                        leadsBadgeCount: widget.leadsBadgeCount,
                        followUpsBadgeCount: widget.followUpsBadgeCount,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onLeads;
  final VoidCallback onFollowUps;
  final VoidCallback onSiteVisits;
  final VoidCallback onMore;
  final int? leadsBadgeCount;
  final int? followUpsBadgeCount;

  const _MainNavBar({
    super.key,
    required this.currentIndex,
    required this.onDashboard,
    required this.onLeads,
    required this.onFollowUps,
    required this.onSiteVisits,
    required this.onMore,
    this.leadsBadgeCount,
    this.followUpsBadgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: currentIndex == 0,
                    onTap: onDashboard,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.people_alt_outlined,
                    label: 'Leads',
                    isActive: currentIndex == 1,
                    onTap: onLeads,
                    badgeCount: leadsBadgeCount,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _CenterNavButton(
            icon: Icons.keyboard_arrow_up_rounded,
            color: AppColors.primary,
            shadowColor: AppColors.primary.withValues(alpha: 0.35),
            onTap: onMore,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.check_circle_outline,
                    label: 'Follow-ups',
                    isActive: currentIndex == 2,
                    onTap: onFollowUps,
                    badgeCount: followUpsBadgeCount,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.location_on_outlined,
                    label: 'Visits',
                    isActive: currentIndex == 3,
                    onTap: onSiteVisits,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onProjects;
  final VoidCallback onTeam;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onLess;

  const _ExpandedNavBar({
    super.key,
    required this.currentIndex,
    required this.onProjects,
    required this.onTeam,
    required this.onReports,
    required this.onSettings,
    required this.onLess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.apartment_outlined,
              label: 'Projects',
              isActive: currentIndex == 4,
              onTap: onProjects,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.groups_outlined,
              label: 'Team',
              isActive: currentIndex == 5,
              onTap: onTeam,
            ),
          ),
          const SizedBox(width: 4),
          _CenterNavButton(
            icon: Icons.keyboard_arrow_down_rounded,
            color: AppColors.primaryDark,
            shadowColor: AppColors.primaryDark.withValues(alpha: 0.25),
            onTap: onLess,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _NavItem(
              icon: Icons.fact_check,
              label: 'Attendance',
              isActive: currentIndex == 6,
              onTap: onReports,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              isActive: currentIndex == 7,
              onTap: onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterNavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

  const _CenterNavButton({
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: true,
        customBorder: const CircleBorder(),
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor =
        isActive ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: itemColor),
                  if ((badgeCount ?? 0) > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: _Badge(count: badgeCount!),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: itemColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final String text = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
