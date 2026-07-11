import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class SiteRevisitDataCard extends StatelessWidget {
  const SiteRevisitDataCard({
    super.key,
    required this.leadName,
    required this.leadPhone,
    required this.projectName,
    required this.projectCity,
    required this.visitDateLabel,
    required this.visitTimeLabel,
    required this.assignedToName,
    required this.closingPersonName,
    required this.transportLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.reason,
    required this.feedback,
    this.nextStep,
    this.rating,
    this.onView,
    this.onEdit,
    this.onStatus,
    this.onCall,
    this.onDelete,
  });

  final String leadName;
  final String leadPhone;
  final String projectName;
  final String projectCity;
  final String visitDateLabel;
  final String visitTimeLabel;
  final String assignedToName;
  final String closingPersonName;
  final String transportLabel;
  final String statusLabel;
  final Color statusColor;
  final String reason;
  final String feedback;
  final String? nextStep;
  final int? rating;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onStatus;
  final VoidCallback? onCall;
  final VoidCallback? onDelete;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          _infoRow('Date', visitDateLabel),
          _infoRow('Time', visitTimeLabel),
          _infoRow('Assigned To', assignedToName),
          _infoRow('Closing Person', closingPersonName),
          _infoRow('Transport', transportLabel),
          if (rating != null && rating! > 0) _infoRow('Rating', '$rating/5'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _action(Icons.phone_outlined, onCall, color: AppColors.primary),
              _action(Icons.remove_red_eye_outlined, onView),
              _action(Icons.edit_outlined, onEdit),
              if (!_isDoneStatus) _action(Icons.check_circle_outline, onStatus),
              if (onDelete != null) _action(Icons.delete_outline, onDelete),
            ],
          ),
        ],
      ),
    );
  }

  bool get _isDoneStatus {
    final normalized = statusLabel.trim().toLowerCase();
    return normalized == 'done' || normalized == 'completed';
  }

  Widget _action(
    IconData icon,
    VoidCallback? onTap, {
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
          size: 18,
          color: onTap == null
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : (color ?? AppColors.textSecondary),
        ),
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
            width: 90,
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
