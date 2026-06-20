import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class PaginationWidget extends StatelessWidget {
  const PaginationWidget({
    super.key,
    this.currentPage,
    this.totalPages,
    this.totalItems,
    this.itemLabel = 'items',
    required this.onPageChanged,
  });

  final int? currentPage;
  final int? totalPages;
  final int? totalItems;
  final String itemLabel;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final safeTotal = (totalPages ?? 1) <= 0 ? 1 : (totalPages ?? 1);
    final safeCurrentRaw = currentPage ?? 1;
    final int safeCurrent = safeCurrentRaw.clamp(1, safeTotal).toInt();
    final safeTotalItems = (totalItems ?? 0) < 0 ? 0 : (totalItems ?? 0);

    if (safeTotal <= 1) {
      return const SizedBox.shrink();
    }
    final pages = _buildVisiblePages(safeCurrent, safeTotal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final info = Text(
            'Page $safeCurrent of $safeTotal'
            '${safeTotalItems > 0 ? ' - $safeTotalItems ${safeTotalItems == 1 ? itemLabel.replaceAll(RegExp(r's$'), '') : itemLabel}' : ''}',
            textAlign: stacked ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          );

          final controls = Row(
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
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: controls)),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
            ],
          );
        },
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
            minWidth: page.toString().length >= 3
                ? 32
                : page.toString().length == 2
                    ? 28
                    : 24,
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
    required this.minWidth,
    required this.onTap,
  });

  final int page;
  final bool selected;
  final double minWidth;
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
          width: minWidth,
          height: 24,
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
