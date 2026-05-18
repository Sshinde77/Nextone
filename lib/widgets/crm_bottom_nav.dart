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
  final VoidCallback? onPhoneRequests;
  final VoidCallback? onSalary;
  final VoidCallback onMore;
  final VoidCallback onLess;

  final int? leadsBadgeCount;
  final int? followUpsBadgeCount;
  final double height;
  final bool showProjects;
  final bool showTeam;
  final bool showUsers;
  final bool showPhoneRequests;
  final bool showSalary;

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
    this.onPhoneRequests,
    this.onSalary,
    required this.onMore,
    required this.onLess,
    this.leadsBadgeCount,
    this.followUpsBadgeCount,
    this.height = 76,
    this.showProjects = true,
    this.showTeam = true,
    this.showUsers = true,
    this.showPhoneRequests = false,
    this.showSalary = false,
  });

  @override
  State<CRMAppBottomNav> createState() => _CRMAppBottomNavState();
}

class _CRMAppBottomNavState extends State<CRMAppBottomNav> {
  bool _isExpanded = false;

  bool get _isExpandedIndex => widget.currentIndex >= 5;
  bool get _hasOverflow => _allVisibleItems.length > 5;
  List<_NavEntry> get _collapsedItems => _allVisibleItems.take(5).toList();
  List<_NavEntry> get _expandedItems =>
      _allVisibleItems.skip(5).take(5).toList();

  List<_NavEntry> get _allVisibleItems {
    return <_NavEntry>[
      _NavEntry(
        index: 0,
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        onTap: widget.onDashboard,
      ),
      _NavEntry(
        index: 1,
        label: 'Leads',
        icon: Icons.people_alt_outlined,
        onTap: widget.onLeads,
        badgeCount: widget.leadsBadgeCount,
      ),
      _NavEntry(
        index: 2,
        label: 'Follow-ups',
        icon: Icons.check_circle_outline,
        onTap: widget.onFollowUps,
        badgeCount: widget.followUpsBadgeCount,
      ),
      _NavEntry(
        index: 3,
        label: 'Visits',
        icon: Icons.location_on_outlined,
        onTap: widget.onSiteVisits,
      ),
      if (widget.showProjects)
        _NavEntry(
          index: 4,
          label: 'Projects',
          icon: Icons.apartment_outlined,
          onTap: widget.onProjects,
        ),
      if (widget.showTeam)
        _NavEntry(
          index: 5,
          label: 'Team',
          icon: Icons.groups_outlined,
          onTap: widget.onTeam,
        ),
      _NavEntry(
        index: 6,
        label: 'Attendance',
        icon: Icons.fact_check,
        onTap: widget.onReports,
      ),
      if (widget.showUsers)
        _NavEntry(
          index: 7,
          label: 'Users',
          icon: Icons.manage_accounts_outlined,
          onTap: widget.onSettings,
        ),
      if (widget.showPhoneRequests && widget.onPhoneRequests != null)
        _NavEntry(
          index: 8,
          label: 'Phone',
          icon: Icons.phone_callback_outlined,
          onTap: widget.onPhoneRequests!,
        ),
      if (widget.showSalary && widget.onSalary != null)
        _NavEntry(
          index: 9,
          label: 'Salary',
          icon: Icons.payments_outlined,
          onTap: widget.onSalary!,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _isExpanded = _hasOverflow && _isExpandedIndex;
  }

  @override
  void didUpdateWidget(covariant CRMAppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasOverflow && _isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      return;
    }
    if (_isExpanded != _isExpandedIndex) {
      setState(() {
        _isExpanded = _hasOverflow && _isExpandedIndex;
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
                child: !_hasOverflow
                    ? _SingleRowNavBar(
                        key: const ValueKey<String>('single-row-nav'),
                        currentIndex: widget.currentIndex,
                        items: _allVisibleItems,
                      )
                    : _PagedNavBar(
                        key: ValueKey<String>(
                          _isExpanded ? 'expanded-nav' : 'main-nav',
                        ),
                        currentIndex: widget.currentIndex,
                        items: _isExpanded ? _expandedItems : _collapsedItems,
                        isExpanded: _isExpanded,
                        onToggle: _isExpanded ? _handleLess : _handleMore,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleRowNavBar extends StatelessWidget {
  const _SingleRowNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
  });

  final int currentIndex;
  final List<_NavEntry> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: _NavItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: currentIndex == item.index,
                  onTap: item.onTap,
                  badgeCount: item.badgeCount,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PagedNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavEntry> items;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _PagedNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final slots = List<_NavEntry?>.generate(
      5,
      (index) => index < items.length ? items[index] : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: slots
                  .map(
                    (entry) => Expanded(
                      child: entry == null
                          ? const SizedBox.shrink()
                          : _NavItem(
                              icon: entry.icon,
                              label: entry.label,
                              isActive: currentIndex == entry.index,
                              onTap: entry.onTap,
                              badgeCount: entry.badgeCount,
                            ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 6),
          _CenterNavButton(
            icon: isExpanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: isExpanded ? AppColors.primaryDark : AppColors.primary,
            shadowColor: isExpanded
                ? AppColors.primaryDark.withValues(alpha: 0.25)
                : AppColors.primary.withValues(alpha: 0.35),
            onTap: onToggle,
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

class _NavEntry {
  const _NavEntry({
    required this.index,
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  final int index;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;
}
