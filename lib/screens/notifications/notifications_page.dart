import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/widgets/crm_app_bar.dart';

enum _NotificationType {
  leadAssignment,
  followUpReminder,
  siteVisitAlert,
  taskNotification,
  statusChange,
}

class _NotificationItem {
  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
  });

  final String id;
  final _NotificationType type;
  final String title;
  final String message;
  final String timeLabel;
  bool isUnread;
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _inAppEnabled = true;
  bool _pushReadyEnabled = true;

  final List<_NotificationItem> _notifications = <_NotificationItem>[
    _NotificationItem(
      id: 'N-1001',
      type: _NotificationType.leadAssignment,
      title: 'New Lead Assigned',
      message: 'Lead L-2026-044 has been assigned to Priya Sharma.',
      timeLabel: '2m ago',
      isUnread: true,
    ),
    _NotificationItem(
      id: 'N-1002',
      type: _NotificationType.followUpReminder,
      title: 'Follow-up Reminder',
      message: 'Follow-up due for Rajesh Khanna at 11:30 AM today.',
      timeLabel: '18m ago',
      isUnread: true,
    ),
    _NotificationItem(
      id: 'N-1003',
      type: _NotificationType.siteVisitAlert,
      title: 'Site Visit in 30 Minutes',
      message: 'Skyloft Penthouse visit is scheduled at 2:00 PM.',
      timeLabel: '31m ago',
      isUnread: true,
    ),
    _NotificationItem(
      id: 'N-1004',
      type: _NotificationType.taskNotification,
      title: 'Task Deadline',
      message: 'Submit booking docs for lead L-2026-012 by EOD.',
      timeLabel: '1h ago',
      isUnread: false,
    ),
    _NotificationItem(
      id: 'N-1005',
      type: _NotificationType.statusChange,
      title: 'Lead Status Updated',
      message: 'Lead L-2026-012 moved from Negotiation to Won.',
      timeLabel: 'Yesterday',
      isUnread: false,
    ),
  ];

  int get _unreadCount {
    return _notifications.where((notification) => notification.isUnread).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CrmAppBar(
        title: 'Notifications',
        showBackButton: true,
        showNotificationDot: false,
        showNotificationIcon: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSummaryCard(),
          // const SizedBox(height: 12),
          // _buildChannelCard(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _unreadCount == 0
                    ? null
                    : () {
                        setState(() {
                          for (final notification in _notifications) {
                            notification.isUnread = false;
                          }
                        });
                      },
                child: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._notifications.map(_buildNotificationTile),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricItem(
              label: 'Unread',
              value: _unreadCount.toString(),
              color: AppColors.error,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _buildMetricItem(
              label: 'Today',
              value: _notifications.length.toString(),
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _buildMetricItem(
              label: 'Channels',
              value: _activeChannelsCount.toString(),
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  int get _activeChannelsCount {
    int count = 0;
    if (_inAppEnabled) count++;
    if (_pushReadyEnabled) count++;
    return count;
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Widget _buildChannelCard() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: AppColors.border),
  //     ),
  //     child: Column(
  //       children: [
  //         SwitchListTile.adaptive(
  //           value: _inAppEnabled,
  //           onChanged: (value) => setState(() => _inAppEnabled = value),
  //           activeColor: AppColors.primary,
  //           title: const Text(
  //             'In-app notifications',
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: AppColors.textPrimary,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           subtitle: const Text(
  //             'Real-time alerts inside the app',
  //             style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
  //           ),
  //         ),
  //         Divider(height: 1, color: AppColors.border.withOpacity(0.8)),
  //         SwitchListTile.adaptive(
  //           value: _pushReadyEnabled,
  //           onChanged: (value) => setState(() => _pushReadyEnabled = value),
  //           activeColor: AppColors.primary,
  //           title: const Text(
  //             'Mobile push-ready system',
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: AppColors.textPrimary,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           subtitle: const Text(
  //             'Enabled for mobile push integration readiness',
  //             style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildNotificationTile(_NotificationItem item) {
    final iconData = _iconForType(item.type);
    final color = _colorForType(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isUnread
              ? color.withOpacity(0.35)
              : AppColors.border.withOpacity(0.8),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () {
          if (item.isUnread) {
            setState(() => item.isUnread = false);
          }
        },
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, size: 19, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (item.isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        trailing: Text(
          item.timeLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  IconData _iconForType(_NotificationType type) {
    switch (type) {
      case _NotificationType.leadAssignment:
        return Icons.person_add_alt_1_outlined;
      case _NotificationType.followUpReminder:
        return Icons.alarm_rounded;
      case _NotificationType.siteVisitAlert:
        return Icons.location_on_outlined;
      case _NotificationType.taskNotification:
        return Icons.task_alt_rounded;
      case _NotificationType.statusChange:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _colorForType(_NotificationType type) {
    switch (type) {
      case _NotificationType.leadAssignment:
        return AppColors.primary;
      case _NotificationType.followUpReminder:
        return AppColors.warning;
      case _NotificationType.siteVisitAlert:
        return AppColors.info;
      case _NotificationType.taskNotification:
        return AppColors.tertiary;
      case _NotificationType.statusChange:
        return AppColors.error;
    }
  }
}
