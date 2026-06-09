import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:nextone/widgets/crm_app_bar.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final AuthProvider _authProvider = AuthProvider();
  final List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  final List<String> _notificationTypes = <String>['all'];

  io.Socket? _socket;
  bool _isLoading = true;
  bool _isSocketConnected = false;
  bool _onlyUnread = false;
  String _selectedType = 'all';
  int _unreadCount = 0;
  String? _errorText;

  static const List<String> _socketEvents = <String>[
    'notification:new',
    'task:created',
    'task:updated',
    'task:completed',
    'task:reminder',
    'lead:assigned',
    'lead:status_changed',
    'visit:scheduled',
    'visit:reminder',
    'visit:done',
    'visit:cancelled',
    'project:new',
  ];

  @override
  void initState() {
    super.initState();
    _refreshData(showLoader: true);
    _connectSocket();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _refreshData({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final notificationsFuture = _safeNotificationsFetch();
      final unreadCountFuture = _safeUnreadCountFetch();
      final typeListFuture = _safeTypeListFetch();

      final notifications = (await notificationsFuture)
          .map(_normalizeNotification)
          .toList();
      final unreadCount = await unreadCountFuture;
      final typeList = (await typeListFuture).toSet().toList()..sort();

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(notifications);
        _unreadCount = unreadCount;
        _notificationTypes
          ..clear()
          ..add('all')
          ..addAll(typeList);
        _isLoading = false;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _friendlyError(error);
      });
    }
  }

  Future<List<Map<String, dynamic>>> _safeNotificationsFetch() async {
    try {
      return await _authProvider.notifications(
        type: _selectedType == 'all' ? null : _selectedType,
        unreadOnly: _onlyUnread ? true : null,
        page: 1,
        perPage: 50,
      );
    } catch (error) {
      if (_isTimeoutError(error)) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          return await _authProvider.notifications(
            type: _selectedType == 'all' ? null : _selectedType,
            unreadOnly: _onlyUnread ? true : null,
            page: 1,
            perPage: 50,
          );
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }
      return const <Map<String, dynamic>>[];
    }
  }

  Future<int> _safeUnreadCountFetch() async {
    try {
      return await _authProvider.unreadNotificationsCount();
    } catch (_) {
      return 0;
    }
  }

  Future<List<String>> _safeTypeListFetch() async {
    try {
      return await _authProvider.notificationTypes();
    } catch (_) {
      return const <String>[];
    }
  }

  void _connectSocket() {
    final token = _authProvider.currentAuthToken;
    if (token == null || token.trim().isEmpty) return;

    _socket = io.io(
      'wss://nextoneapi-production.up.railway.app',
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .setAuth(<String, dynamic>{'token': token})
          .enableForceNew()
          .build(),
    );

    _socket?.onConnect((_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = true);
    });
    _socket?.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = false);
    });

    for (final eventName in _socketEvents) {
      _socket?.on(eventName, (_) async {
        await _refreshData(showLoader: false);
      });
    }
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> item) {
    final isReadRaw = item['is_read'] ?? item['isRead'] ?? item['read'];
    final isRead = isReadRaw == true || isReadRaw?.toString() == 'true';
    return <String, dynamic>{
      ...item,
      'id': item['id']?.toString() ??
          item['_id']?.toString() ??
          item['notification_id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      'type': item['type']?.toString() ?? 'general',
      'title': item['title']?.toString() ?? 'Notification',
      'message': item['message']?.toString() ??
          item['description']?.toString() ??
          item['body']?.toString() ??
          '',
      'is_read': isRead,
      'created_at': item['created_at']?.toString() ??
          item['createdAt']?.toString() ??
          item['timestamp']?.toString(),
    };
  }

  Future<void> _markAllRead() async {
    try {
      await _authProvider.markAllNotificationsRead();
      await _refreshData(showLoader: false);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _deleteAll() async {
    try {
      await _authProvider.deleteAllNotifications();
      await _refreshData(showLoader: false);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _markOneRead(String id) async {
    try {
      await _authProvider.markSingleNotificationRead(id: id);
      await _refreshData(showLoader: false);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _deleteOne(String id) async {
    try {
      await _authProvider.deleteSingleNotification(id: id);
      await _refreshData(showLoader: false);
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyError(error))),
    );
  }

  String _friendlyError(Object error) {
    return AppErrorHandler.friendlyMessage(error);
  }

  bool _isTimeoutError(Object error) {
    return AppErrorHandler.friendlyMessage(error) ==
        AppErrorHandler.timeoutMessage;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 420;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CrmAppBar(
        title: 'Notifications',
        showBackButton: true,
        showNotificationDot: false,
        showNotificationIcon: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshData(showLoader: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _heroHeader(compact)),
                  SliverToBoxAdapter(child: _filterPanel(compact)),
                  if (_errorText != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_notifications.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (_, index) =>
                            _notificationCard(_notifications[index], compact),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _heroHeader(bool compact) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2447D5), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSocketConnected
                          ? 'Realtime sync active'
                          : 'Realtime sync offline',
                      style: TextStyle(
                        color: const Color(0xFFDBEAFE).withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _heroButton(
                icon: Icons.refresh_rounded,
                onTap: _isLoading ? null : () => _refreshData(showLoader: true),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                onSelected: (value) {
                  if (value == 'read_all') _markAllRead();
                  if (value == 'delete_all') _deleteAll();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'read_all', child: Text('Mark all as read')),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Text('Delete all notifications'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  label: 'Unread',
                  value: _unreadCount.toString(),
                  icon: Icons.mark_email_unread_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  label: 'Total',
                  value: _notifications.length.toString(),
                  icon: Icons.notifications_active_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  label: 'Live',
                  value: _isSocketConnected ? 'ON' : 'OFF',
                  icon: _isSocketConnected
                      ? Icons.sensors_rounded
                      : Icons.sensors_off_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE2E8F0), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel(bool compact) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.95)),
      ),
      child: compact
          ? Column(
              children: [
                _typeDropdown(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _unreadChip(),
                    const Spacer(),
                    _statusPill(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _typeDropdown()),
                const SizedBox(width: 10),
                _unreadChip(),
                const SizedBox(width: 10),
                _statusPill(),
              ],
            ),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _notificationTypes.contains(_selectedType) ? _selectedType : 'all',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: _notificationTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            _formatTypeLabel(type),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedType = value);
        _refreshData(showLoader: false);
      },
    );
  }

  Widget _unreadChip() {
    return FilterChip(
      selected: _onlyUnread,
      onSelected: (selected) {
        setState(() => _onlyUnread = selected);
        _refreshData(showLoader: false);
      },
      showCheckmark: false,
      selectedColor: const Color(0xFFEEF2FF),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
        color: _onlyUnread ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
      ),
      label: Text(
        'Unread only',
        style: TextStyle(
          color: _onlyUnread ? const Color(0xFF4F46E5) : const Color(0xFF475569),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _isSocketConnected
            ? const Color(0xFFE7F8EE)
            : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: _isSocketConnected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE11D48),
          ),
          const SizedBox(width: 6),
          Text(
            _isSocketConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: _isSocketConnected
                  ? const Color(0xFF166534)
                  : const Color(0xFFBE123C),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 34,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'New alerts will appear here in realtime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item, bool compact) {
    final id = item['id'].toString();
    final type = item['type']?.toString() ?? 'general';
    final isRead = item['is_read'] == true;

    return Dismissible(
      key: ValueKey<String>('notification_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteOne(id);
        return false;
      },
      child: InkWell(
        onTap: isRead ? null : () => _markOneRead(id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? AppColors.border.withValues(alpha: 0.8)
                  : _typeColor(type).withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_typeIcon(type), color: _typeColor(type), size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? 'Notification',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTypeLabel(type),
                          style: TextStyle(
                            color: _typeColor(type),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _timeLabel(item['created_at']?.toString()),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item['message']?.toString() ?? '',
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTypeLabel(String type) {
    if (type == 'all') return 'All types';
    return type
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _timeLabel(String? source) {
    if (source == null || source.trim().isEmpty) return 'now';
    final parsed = DateTime.tryParse(source)?.toLocal();
    if (parsed == null) return source;
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'lead_assigned':
      case 'lead_new':
        return Icons.person_add_alt_1_outlined;
      case 'follow_up_created':
      case 'follow_up_due':
      case 'follow_up_overdue':
      case 'follow_up_completed':
        return Icons.alarm_rounded;
      case 'visit_scheduled':
      case 'visit_reminder':
      case 'visit_done':
      case 'visit_cancelled':
      case 'visit_rescheduled':
        return Icons.location_on_outlined;
      case 'project_new':
      case 'project_updated':
        return Icons.apartment_rounded;
      case 'task_created':
      case 'task_reminder':
      case 'task_completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'lead_assigned':
      case 'lead_new':
        return AppColors.primary;
      case 'follow_up_created':
      case 'follow_up_due':
      case 'follow_up_overdue':
      case 'follow_up_completed':
        return AppColors.warning;
      case 'visit_scheduled':
      case 'visit_reminder':
      case 'visit_done':
      case 'visit_cancelled':
      case 'visit_rescheduled':
        return AppColors.info;
      case 'project_new':
      case 'project_updated':
        return AppColors.tertiary;
      case 'task_created':
      case 'task_reminder':
      case 'task_completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

