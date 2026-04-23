import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class CRMAppBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CRMAppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CRMAppBottomNav> createState() => _CRMAppBottomNavState();
}

class _CRMAppBottomNavState extends State<CRMAppBottomNav> {
  static const int _loopCycles = 10000;
  late final PageController _pageController;
  late int _currentPage;

  final List<_NavData> items = [
    _NavData(Icons.dashboard_outlined, "Dashboard"),
    _NavData(Icons.people_alt_outlined, "Leads"),
    _NavData(Icons.check_circle_outline, "Follow-ups"),
    _NavData(Icons.location_on_outlined, "Visits"),
    _NavData(Icons.apartment_outlined, "Projects"),
    _NavData(Icons.groups_outlined, "Team"),
    _NavData(Icons.person, "Profile"),
    _NavData(Icons.settings, "Settings"),
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = _loopStartPage + widget.currentIndex;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.27,
    );
  }

  @override
  void didUpdateWidget(covariant CRMAppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _activeIndex != widget.currentIndex) {
      _animateToIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _loopStartPage => items.length * _loopCycles;

  int get _activeIndex => _normaliseIndex(_currentPage);

  int _normaliseIndex(int page) => page % items.length;

  int _nearestPageForIndex(int index) {
    final current = _pageController.hasClients
        ? (_pageController.page ?? _currentPage.toDouble()).round()
        : _currentPage;
    final currentIndex = _normaliseIndex(current);
    var pageOffset = index - currentIndex;

    if (pageOffset.abs() > items.length / 2) {
      pageOffset += pageOffset.isNegative ? items.length : -items.length;
    }

    return current + pageOffset;
  }

  void _animateToIndex(int index) {
    final targetPage = _nearestPageForIndex(index);
    _currentPage = targetPage;

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onTap(int index) {
    widget.onTap(index);
    _animateToIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        physics: const _NavPagePhysics(),
        onPageChanged: (page) {
          _currentPage = page;
          final index = _normaliseIndex(page);

          if (index != widget.currentIndex) {
            widget.onTap(index);
          }

          if (!mounted) return;
          setState(() {});
        },
        itemBuilder: (context, page) {
          final index = _normaliseIndex(page);
          final isActive = widget.currentIndex == index;

          return GestureDetector(
            onTap: () => _onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      items[index].icon,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    items[index].label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavData {
  final IconData icon;
  final String label;

  _NavData(this.icon, this.label);
}

class _NavPagePhysics extends PageScrollPhysics {
  const _NavPagePhysics({ScrollPhysics? parent})
    : super(parent: parent ?? const ClampingScrollPhysics());

  @override
  _NavPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _NavPagePhysics(parent: buildParent(ancestor));
  }

  // Increase thresholds so a light touch doesn't switch tabs.
  @override
  double get dragStartDistanceMotionThreshold => 20.0;

  @override
  double get minFlingDistance => 80.0;

  @override
  double get minFlingVelocity => 1200.0;
}
