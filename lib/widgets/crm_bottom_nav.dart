import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class CRMAppBottomNav extends StatefulWidget {
  final int currentIndex;
  final VoidCallback onDashboard;
  final VoidCallback onLeads;
  final VoidCallback onFollowUps;
  final VoidCallback onSiteVisits;
  final VoidCallback onRevisits;
  final VoidCallback onProjects;
  final VoidCallback onTeam;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback? onNotifications;
  final VoidCallback? onSalary;
  final VoidCallback? onClosures;
  final VoidCallback onMore;
  final VoidCallback onLess;
  final int? leadsBadgeCount;
  final int? followUpsBadgeCount;
  final double height;
  final bool showProjects;
  final bool showTeam;
  final bool showUsers;
  final bool showNotifications;
  final bool showSalary;

  const CRMAppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDashboard,
    required this.onLeads,
    required this.onFollowUps,
    required this.onSiteVisits,
    required this.onRevisits,
    required this.onProjects,
    required this.onTeam,
    required this.onReports,
    required this.onSettings,
    this.onNotifications,
    this.onSalary,
    this.onClosures,
    required this.onMore,
    required this.onLess,
    this.leadsBadgeCount,
    this.followUpsBadgeCount,
    this.height = 76,
    this.showProjects = true,
    this.showTeam = true,
    this.showUsers = true,
    this.showNotifications = true,
    this.showSalary = false,
  });

  @override
  State<CRMAppBottomNav> createState() => _CRMAppBottomNavState();
}

class _CRMAppBottomNavState extends State<CRMAppBottomNav> {
  bool _isExpanded = false;
  final GlobalKey _moreButtonKey = GlobalKey();

  bool get _hasOverflow => _allVisibleItems.length > 5;
  List<_NavEntry> get _collapsedItems => _allVisibleItems.take(5).toList();
  List<_NavEntry> get _overflowItems => _allVisibleItems.skip(5).toList();

  List<_NavEntry> get _allVisibleItems {
    return <_NavEntry>[
      _NavEntry(
        index: 0,
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        onTap: widget.onDashboard,
      ),
      if (widget.showProjects)
        _NavEntry(
          index: 5,
          label: 'Projects',
          icon: Icons.apartment_outlined,
          onTap: widget.onProjects,
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
        label: 'Follow-Ups',
        icon: Icons.check_circle_outline,
        onTap: widget.onFollowUps,
        badgeCount: widget.followUpsBadgeCount,
      ),
      _NavEntry(
        index: 3,
        label: 'Site Visits',
        icon: Icons.location_on_outlined,
        onTap: widget.onSiteVisits,
      ),
      _NavEntry(
        index: 4,
        label: 'Re-visits',
        icon: Icons.repeat_rounded,
        onTap: widget.onRevisits,
      ),
      if (widget.onClosures != null)
        _NavEntry(
          index: 10,
          label: 'Closures',
          icon: Icons.verified_outlined,
          onTap: widget.onClosures!,
        ),
      _NavEntry(
        index: 7,
        label: 'Attendance',
        icon: Icons.fact_check,
        onTap: widget.onReports,
      ),
      if (widget.showSalary && widget.onSalary != null)
        _NavEntry(
          index: 9,
          label: 'Salary',
          icon: Icons.payments_outlined,
          onTap: widget.onSalary!,
        ),
      if (widget.showTeam)
        _NavEntry(
          index: 6,
          label: 'Team',
          icon: Icons.groups_outlined,
          onTap: widget.onTeam,
        ),
      if (widget.showUsers)
        _NavEntry(
          index: 8,
          label: 'Users',
          icon: Icons.manage_accounts_outlined,
          onTap: widget.onSettings,
        ),
      if (widget.showNotifications && widget.onNotifications != null)
        _NavEntry(
          index: -1,
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          onTap: widget.onNotifications!,
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant CRMAppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasOverflow && _isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  Future<void> _handleMore() async {
    if (_isExpanded || !_hasOverflow) return;

    setState(() => _isExpanded = true);
    widget.onMore();

    final selected = await _openOverflowMenu();
    if (!mounted) return;

    if (_isExpanded) {
      setState(() => _isExpanded = false);
      widget.onLess();
    }

    selected?.onTap();
  }

  void _handleLess() {
    if (!_isExpanded) return;
    Navigator.of(context).maybePop();
  }

  Future<_NavEntry?> _openOverflowMenu() async {
    final moreContext = _moreButtonKey.currentContext;
    if (moreContext == null) return null;

    final buttonBox = moreContext.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return null;

    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final screenSize = MediaQuery.sizeOf(context);
    final isSmallScreen = screenSize.width < 360;
    final iconSize = isSmallScreen ? 18.0 : 21.0;
    final textSize = isSmallScreen ? 11.0 : 12.5;
    final maxAllowedWidth = (screenSize.width * 0.6).clamp(200.0, 320.0);
    final minPanelWidth = isSmallScreen ? 190.0 : 220.0;
    final baseStyle = TextStyle(
      fontSize: textSize,
      fontWeight: FontWeight.w600,
    );

    var longestLabelWidth = 0.0;
    for (final item in _overflowItems) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: baseStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > longestLabelWidth) {
        longestLabelWidth = painter.width;
      }
    }

    final panelWidth = (longestLabelWidth + iconSize + 70).clamp(
      minPanelWidth,
      maxAllowedWidth,
    );
    final rowHeight = isSmallScreen ? 44.0 : 48.0;
    final menuHeight = (_overflowItems.length * rowHeight + 16).clamp(
      120.0,
      320.0,
    );

    final menuLeft = (buttonTopLeft.dx + buttonBox.size.width - panelWidth).clamp(
      8.0,
      screenSize.width - panelWidth - 8.0,
    );
    final menuTop = (buttonTopLeft.dy - menuHeight - 10.0).clamp(
      8.0,
      screenSize.height - menuHeight - 8.0,
    );

    return showMenu<_NavEntry>(
      context: context,
      elevation: 10,
      color: AppColors.surface,
      position: RelativeRect.fromLTRB(
        menuLeft,
        menuTop,
        screenSize.width - menuLeft - panelWidth,
        screenSize.height - menuTop,
      ),
      constraints: BoxConstraints(
        minWidth: panelWidth,
        maxWidth: panelWidth,
        maxHeight: menuHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      items: _overflowItems
          .map(
            (entry) => PopupMenuItem<_NavEntry>(
              value: entry,
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: _OverflowMenuRow(
                icon: entry.icon,
                label: entry.label,
                isActive: widget.currentIndex == entry.index,
                badgeCount: entry.badgeCount,
                iconSize: iconSize,
                textSize: textSize,
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SizedBox(
          height: widget.height,
          child: Container(
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
                child: !_hasOverflow
                    ? _SingleRowNavBar(
                        currentIndex: widget.currentIndex,
                        items: _allVisibleItems,
                      )
                      : _PrimaryNavBar(
                        currentIndex: widget.currentIndex,
                        items: _collapsedItems,
                        isExpanded: _isExpanded,
                        hasActiveOverflow: _overflowItems.any(
                          (entry) => entry.index == widget.currentIndex,
                        ),
                        moreButtonKey: _moreButtonKey,
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

class _PrimaryNavBar extends StatelessWidget {
  const _PrimaryNavBar({
    required this.currentIndex,
    required this.items,
    required this.isExpanded,
    required this.hasActiveOverflow,
    required this.moreButtonKey,
    required this.onToggle,
  });

  final int currentIndex;
  final List<_NavEntry> items;
  final bool isExpanded;
  final bool hasActiveOverflow;
  final Key moreButtonKey;
  final VoidCallback onToggle;

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
            key: moreButtonKey,
            icon: isExpanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: isExpanded || hasActiveOverflow
                ? AppColors.primaryDark
                : AppColors.primary,
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
  const _CenterNavButton({
    super.key,
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

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

class _OverflowMenuRow extends StatelessWidget {
  const _OverflowMenuRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.badgeCount,
    required this.iconSize,
    required this.textSize,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final int? badgeCount;
  final double iconSize;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final itemColor = isActive ? AppColors.primary : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: iconSize, color: itemColor),
              if ((badgeCount ?? 0) > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: _Badge(count: badgeCount!),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: itemColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final itemColor = isActive ? AppColors.primary : AppColors.textSecondary;

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
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();

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
