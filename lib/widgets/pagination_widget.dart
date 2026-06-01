import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class PaginationWidget extends StatelessWidget {
  const PaginationWidget({
    super.key,
    this.currentPage,
    this.totalPages,
    required this.onPageChanged,
  });

  final int? currentPage;
  final int? totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final safeTotal = (totalPages ?? 1) <= 0 ? 1 : (totalPages ?? 1);
    final safeCurrentRaw = currentPage ?? 1;
    final int safeCurrent = safeCurrentRaw.clamp(1, safeTotal).toInt();

    if (safeTotal <= 1) {
      return const SizedBox.shrink();
    }
    final pages = _buildVisiblePages(safeCurrent, safeTotal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            enabled: safeCurrent > 1,
            onTap: () => onPageChanged(safeCurrent - 1),
          ),
          const SizedBox(width: 8),
          ..._buildPageItems(context, pages, safeCurrent),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.chevron_right,
            enabled: safeCurrent < safeTotal,
            onTap: () => onPageChanged(safeCurrent + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageItems(
    BuildContext context,
    List<int> pages,
    int safeCurrent,
  ) {
    final items = <Widget>[];

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (i > 0 && page - pages[i - 1] > 1) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }

      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _PageChip(
            page: page,
            selected: page == safeCurrent,
            onTap: () => onPageChanged(page),
          ),
        ),
      );
    }

    return items;
  }

  List<int> _buildVisiblePages(int current, int total) {
    final Set<int> pageSet = {1, total, current - 1, current, current + 1};
    return pageSet.where((p) => p >= 1 && p <= total).toList()..sort();
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
