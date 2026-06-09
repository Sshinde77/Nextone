import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class ClosureDataCard extends StatelessWidget {
  const ClosureDataCard({
    super.key,
    required this.leadName,
    required this.leadPhone,
    required this.projectName,
    required this.projectCity,
    required this.unitNumber,
    required this.unitType,
    required this.towerBlock,
    required this.floorNumber,
    required this.bookingDate,
    required this.dealValueLabel,
    required this.commissionLabel,
    required this.commissionPaidLabel,
    required this.closedByName,
    required this.statusLabel,
    required this.statusColor,
    this.onView,
    this.onEdit,
    this.onStatus,
  });

  final String leadName;
  final String leadPhone;
  final String projectName;
  final String projectCity;
  final String unitNumber;
  final String unitType;
  final String towerBlock;
  final String floorNumber;
  final String bookingDate;
  final String dealValueLabel;
  final String commissionLabel;
  final String commissionPaidLabel;
  final String closedByName;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialAvatar(name: leadName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      leadPhone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Project', '$projectName, $projectCity'),
          _infoRow('Unit', '$unitNumber • $unitType • $towerBlock • $floorNumber'),
          _infoRow('Booking Date', bookingDate),
          _infoRow('Deal Value', dealValueLabel),
          _infoRow('Commission', commissionLabel),
          _infoRow('Commission Paid', commissionPaidLabel),
          _infoRow('Closed By', closedByName),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _action(Icons.remove_red_eye_outlined, onView),
              _action(Icons.edit_outlined, onEdit),
              _action(Icons.info_outline, onStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.textSecondary),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 21,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

