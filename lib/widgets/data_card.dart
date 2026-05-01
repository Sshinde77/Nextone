import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class DataCardAction {
  const DataCardAction({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
}

class DataCard extends StatelessWidget {
  const DataCard({
    super.key,
    required this.name,
    required this.leadId,
    required this.status,
    required this.priority,
    required this.priorityColor,
    required this.nextFollowUpDate,
    required this.budget,
    required this.phone,
    required this.profileImageUrl,
    required this.assigneeName,
    required this.assigneeImageUrl,
    required this.actions,
    this.bulkSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectionChanged,
  });

  final String name;
  final String leadId;
  final String status;
  final String priority;
  final Color priorityColor;
  final String nextFollowUpDate;
  final String budget;
  final String phone;
  final String profileImageUrl;
  final String assigneeName;
  final String assigneeImageUrl;
  final List<DataCardAction> actions;

  final bool bulkSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: onLongPress,
        onTap: bulkSelectionMode && onSelectionChanged != null
            ? () => onSelectionChanged!(!isSelected)
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF7FAFF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFFBDD3FF) : AppColors.border,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 380;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bulkSelectionMode) ...[
                        Checkbox(
                          value: isSelected,
                          onChanged: onSelectionChanged == null
                              ? null
                              : (value) => onSelectionChanged!(value ?? false),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _ProfileAvatar(
                        imageUrl: profileImageUrl,
                        name: name,
                        radius: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (leadId.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                leadId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: _buildStatusChip(
                            maxWidth: isVeryCompact ? 120 : 170,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoPair(
                    left: _metaItem(
                      'Priority',
                      priority,
                      dotColor: priorityColor,
                    ),
                    right: _metaItem(
                      'Next Follow-up',
                      nextFollowUpDate,
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoPair(
                    left: _metaItem(
                      'Budget',
                      budget,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    right: _metaItem(
                      'Phone',
                      phone,
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _ProfileAvatar(
                              imageUrl: assigneeImageUrl,
                              name: assigneeName,
                              radius: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                assigneeName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildActionIcons(
                        isVeryCompact: isVeryCompact,
                        actions: actions,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EAF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC2185B),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoPair({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    );
  }

  Widget _metaItem(
    String label,
    String value, {
    Color? valueColor,
    Color? dotColor,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIcons({
    required bool isVeryCompact,
    required List<DataCardAction> actions,
  }) {
    final iconSize = isVeryCompact ? 16.0 : 18.0;
    final buttonSize = isVeryCompact ? 30.0 : 34.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map(
            (action) => _actionIcon(
              action.icon,
              onTap: action.onTap,
              iconSize: iconSize,
              buttonSize: buttonSize,
              color: action.color,
            ),
          )
          .toList(),
    );
  }

  Widget _actionIcon(
    IconData icon, {
    required VoidCallback onTap,
    required double iconSize,
    required double buttonSize,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: iconSize,
          color: color ?? AppColors.textSecondary,
        ),
        constraints: BoxConstraints.tightFor(
          width: buttonSize,
          height: buttonSize,
        ),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.name,
    this.radius = 18,
  });

  final String imageUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFFE9EEF7),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            ),
          );
        },
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
