import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/screens/closures/closure_detail_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_detail_page.dart';
import 'package:nextone/screens/leads/lead_detail_page.dart';
import 'package:nextone/screens/notifications/notifications_page.dart';
import 'package:nextone/screens/projects/project_detail_page.dart';
import 'package:nextone/screens/site_visits/site_revisit_detail_page.dart';
import 'package:nextone/screens/site_visits/site_visit_details_page.dart';
import 'package:nextone/screens/team/team_member_details_page.dart';
import 'package:nextone/services/auth_service.dart';
import 'package:nextone/utils/app_error_handler.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final List<_QueuedNotificationPayload> _pendingPayloads =
      <_QueuedNotificationPayload>[];
  static final Set<String> _handledPayloadKeys = <String>{};
  static final Set<String> _pendingPayloadKeys = <String>{};

  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    final payload = <String, dynamic>{
      ...message.data,
      if (message.messageId != null) 'message_id': message.messageId,
      if (message.notification?.title != null) 'title': message.notification?.title,
      if (message.notification?.body != null) 'body': message.notification?.body,
    };
    await handlePayload(
      payload,
      sourceLabel: 'remote_message',
      sourceKey: message.messageId,
    );
  }

  static Future<void> handlePayload(
    Map<String, dynamic> payload, {
    String? sourceKey,
    String? sourceLabel,
  }) async {
    final payloadKey = _notificationKey(payload, fallbackKey: sourceKey);
    final normalized = _flattenPayload(payload);
    if (_handledPayloadKeys.contains(payloadKey) ||
        _pendingPayloadKeys.contains(payloadKey)) {
      return;
    }

    final instruction = _resolveInstruction(normalized);
    if (instruction == null) {
      _handledPayloadKeys.add(payloadKey);
      await _navigateToNotifications();
      return;
    }

    if (!_isReadyForNavigation()) {
      _queuePayload(
        _QueuedNotificationPayload(
          key: payloadKey,
          payload: normalized,
          instruction: instruction,
          sourceLabel: sourceLabel,
        ),
      );
      return;
    }

    if (!await _canNavigateToInstruction(instruction)) {
      _queuePayload(
        _QueuedNotificationPayload(
          key: payloadKey,
          payload: normalized,
          instruction: instruction,
          sourceLabel: sourceLabel,
        ),
      );
      return;
    }

    try {
      await _navigate(instruction);
      _handledPayloadKeys.add(payloadKey);
    } catch (error, stackTrace) {
      AppErrorHandler.logDebug(
        'Failed to navigate from notification tap.',
        name: 'NotificationNavigationService',
        error: error,
        stackTrace: stackTrace,
      );
      _handledPayloadKeys.add(payloadKey);
      await _navigateToNotifications();
    }
  }

  static Future<void> flushPendingNavigation() async {
    if (_pendingPayloads.isEmpty || !_isReadyForNavigation()) {
      return;
    }

    final queued = List<_QueuedNotificationPayload>.from(_pendingPayloads);
    for (final item in queued) {
      if (_handledPayloadKeys.contains(item.key)) {
        _removePendingKey(item.key);
        continue;
      }

      if (!await _canNavigateToInstruction(item.instruction)) {
        continue;
      }

      try {
        await _navigate(item.instruction);
        _handledPayloadKeys.add(item.key);
      } catch (error, stackTrace) {
        AppErrorHandler.logDebug(
          'Failed to flush pending notification navigation.',
          name: 'NotificationNavigationService',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _removePendingKey(item.key);
      }
    }
  }

  static bool _isReadyForNavigation() {
    return navigatorKey.currentState != null &&
        navigatorKey.currentContext != null;
  }

  static void _queuePayload(_QueuedNotificationPayload payload) {
    if (_pendingPayloadKeys.add(payload.key)) {
      _pendingPayloads.add(payload);
    }
  }

  static void _removePendingKey(String key) {
    _pendingPayloadKeys.remove(key);
    _pendingPayloads.removeWhere((item) => item.key == key);
  }

  static Future<bool> _canNavigateToInstruction(
    _NotificationInstruction instruction,
  ) async {
    if (instruction.requiresAuth) {
      final token = AuthService.currentAuthToken;
      if (token == null || token.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static Future<void> _navigate(_NotificationInstruction instruction) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    switch (instruction.kind) {
      case _NotificationTargetKind.leadDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => LeadDetailPage(leadId: instruction.entityId!),
          ),
        );
        return;
      case _NotificationTargetKind.projectDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailPage(
              projectId: instruction.entityId!,
              initialData: instruction.initialData,
            ),
          ),
        );
        return;
      case _NotificationTargetKind.followUpDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                FollowUpDetailPage(followUpId: instruction.entityId!),
          ),
        );
        return;
      case _NotificationTargetKind.siteVisitDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SiteVisitDetailsPage(
              visitId: instruction.entityId!,
              visitData: instruction.initialData,
            ),
          ),
        );
        return;
      case _NotificationTargetKind.siteRevisitDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SiteRevisitDetailPage(revisitId: instruction.entityId!),
          ),
        );
        return;
      case _NotificationTargetKind.closureDetail:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ClosureDetailPage(lookupId: instruction.entityId!),
          ),
        );
        return;
      case _NotificationTargetKind.teamMemberDetail:
        final details = await AuthProvider().usersDetail(
          id: instruction.entityId!,
          token: AuthService.currentAuthToken,
        );
        if (navigatorKey.currentState == null) {
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => TeamMemberDetailsPage(memberData: details),
          ),
        );
        return;
      case _NotificationTargetKind.notifications:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsPage(),
          ),
        );
        return;
    }
  }

  static Future<void> _navigateToNotifications() async {
    if (!_isReadyForNavigation()) {
      return;
    }
    await _navigate(const _NotificationInstruction.notifications());
  }

  static _NotificationInstruction? _resolveInstruction(
    Map<String, dynamic> payload,
  ) {
    final explicitTarget = _firstString(payload, const <String>[
      'route',
      'route_name',
      'screen',
      'screen_name',
      'target',
      'target_screen',
      'destination',
      'module',
      'entity',
      'entity_type',
      'type',
    ]);
    final normalizedTarget = _normalizeTarget(explicitTarget);

    final leadId = _firstString(payload, const <String>[
      'lead_id',
      'leadId',
      'lead',
    ]);
    final projectId = _firstString(payload, const <String>[
      'project_id',
      'projectId',
    ]);
    final followUpId = _firstString(payload, const <String>[
      'follow_up_id',
      'followUpId',
      'followup_id',
      'followupId',
      'task_id',
      'taskId',
    ]);
    final visitId = _firstString(payload, const <String>[
      'visit_id',
      'visitId',
      'site_visit_id',
      'siteVisitId',
    ]);
    final revisitId = _firstString(payload, const <String>[
      'revisit_id',
      'revisitId',
      'site_revisit_id',
      'siteRevisitId',
    ]);
    final closureId = _firstString(payload, const <String>[
      'closure_id',
      'closureId',
      'lookup_id',
      'lookupId',
    ]);
    final userId = _firstString(payload, const <String>[
      'user_id',
      'userId',
      'employee_id',
      'employeeId',
      'team_member_id',
      'teamMemberId',
    ]);

    final projectData = _extractNestedMap(payload, const <String>[
      'project',
      'project_data',
      'projectData',
    ]);
    final leadData = _extractNestedMap(payload, const <String>[
      'lead',
      'lead_data',
      'leadData',
    ]);
    final followUpData = _extractNestedMap(payload, const <String>[
      'follow_up',
      'followUp',
      'follow_up_data',
      'followUpData',
      'task',
      'task_data',
      'taskData',
    ]);
    final visitData = _extractNestedMap(payload, const <String>[
      'visit',
      'visit_data',
      'visitData',
      'site_visit',
      'siteVisit',
    ]);
    final revisitData = _extractNestedMap(payload, const <String>[
      'revisit',
      'revisit_data',
      'revisitData',
      'site_revisit',
      'siteRevisit',
    ]);
    final closureData = _extractNestedMap(payload, const <String>[
      'closure',
      'closure_data',
      'closureData',
    ]);
    final userData = _extractNestedMap(payload, const <String>[
      'user',
      'user_data',
      'userData',
      'employee',
      'employee_data',
      'employeeData',
      'team_member',
      'teamMember',
      'team_member_data',
      'teamMemberData',
    ]);
    final hasProjectData = projectData?.isNotEmpty == true;
    final hasVisitData = visitData?.isNotEmpty == true;

    final resolvedLeadId = leadId.isNotEmpty
        ? leadId
        : _firstString(leadData ?? const <String, dynamic>{}, const <String>[
            'lead_id',
            'leadId',
            'id',
            'entity_id',
            'entityId',
            'target_id',
            'targetId',
            'record_id',
            'recordId',
          ]);
    final resolvedProjectId = projectId.isNotEmpty
        ? projectId
        : _firstString(projectData ?? const <String, dynamic>{}, const <String>[
            'project_id',
            'projectId',
            'id',
            'entity_id',
            'entityId',
            'target_id',
            'targetId',
            'record_id',
            'recordId',
          ]);
    final resolvedFollowUpId = followUpId.isNotEmpty
        ? followUpId
        : _firstString(
            followUpData ?? const <String, dynamic>{},
            const <String>[
              'follow_up_id',
              'followUpId',
              'id',
              'entity_id',
              'entityId',
              'target_id',
              'targetId',
              'record_id',
              'recordId',
              'task_id',
              'taskId',
            ],
          );
    final resolvedVisitId = visitId.isNotEmpty
        ? visitId
        : _firstString(visitData ?? const <String, dynamic>{}, const <String>[
            'visit_id',
            'visitId',
            'id',
            'entity_id',
            'entityId',
            'target_id',
            'targetId',
            'record_id',
            'recordId',
          ]);
    final resolvedRevisitId = revisitId.isNotEmpty
        ? revisitId
        : _firstString(
            revisitData ?? const <String, dynamic>{},
            const <String>[
              'revisit_id',
              'revisitId',
              'id',
              'entity_id',
              'entityId',
              'target_id',
              'targetId',
              'record_id',
              'recordId',
            ],
          );
    final resolvedClosureId = closureId.isNotEmpty
        ? closureId
        : _firstString(
            closureData ?? const <String, dynamic>{},
            const <String>[
              'closure_id',
              'closureId',
              'lead_id',
              'leadId',
              'id',
              'entity_id',
              'entityId',
              'target_id',
              'targetId',
              'record_id',
              'recordId',
            ],
          );
    final resolvedUserId = userId.isNotEmpty
        ? userId
        : _firstString(userData ?? const <String, dynamic>{}, const <String>[
            'user_id',
            'userId',
            'employee_id',
            'employeeId',
            'team_member_id',
            'teamMemberId',
            'id',
            'entity_id',
            'entityId',
            'target_id',
            'targetId',
            'record_id',
            'recordId',
          ]);

    if (_matchesAny(normalizedTarget, const <String>[
          'lead',
          'lead_detail',
          'lead_detail_page',
          'lead_assigned',
          'lead_new',
          'lead_updated',
        ]) &&
        resolvedLeadId.isNotEmpty) {
      return _NotificationInstruction.lead(resolvedLeadId);
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'follow_up',
          'followup',
          'follow_up_detail',
          'follow_up_created',
          'follow_up_due',
          'follow_up_overdue',
          'follow_up_completed',
          'task',
          'task_detail',
          'task_created',
          'task_reminder',
          'task_completed',
        ]) &&
        resolvedFollowUpId.isNotEmpty) {
      return _NotificationInstruction.followUp(resolvedFollowUpId);
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'visit',
          'site_visit',
          'visit_detail',
          'visit_scheduled',
          'visit_reminder',
          'visit_done',
          'visit_cancelled',
          'visit_rescheduled',
        ]) &&
        resolvedVisitId.isNotEmpty) {
      return _NotificationInstruction.siteVisit(
        resolvedVisitId,
        initialData: hasVisitData ? visitData : null,
      );
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'revisit',
          'site_revisit',
          'revisit_detail',
          'revisit_scheduled',
        ]) &&
        resolvedRevisitId.isNotEmpty) {
      return _NotificationInstruction.siteRevisit(resolvedRevisitId);
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'project',
          'project_detail',
          'project_new',
          'project_updated',
        ]) &&
        resolvedProjectId.isNotEmpty) {
      return _NotificationInstruction.project(
        resolvedProjectId,
        initialData: hasProjectData ? projectData : null,
      );
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'closure',
          'closure_detail',
          'closure_created',
          'closure_booked',
          'booking',
        ]) &&
        (resolvedLeadId.isNotEmpty || resolvedClosureId.isNotEmpty)) {
      return _NotificationInstruction.closure(
        resolvedLeadId.isNotEmpty ? resolvedLeadId : resolvedClosureId,
      );
    }

    if (_matchesAny(normalizedTarget, const <String>[
          'user',
          'team',
          'team_member',
          'team_member_detail',
          'employee',
          'attendance',
          'salary',
        ]) &&
        resolvedUserId.isNotEmpty) {
      return _NotificationInstruction.teamMember(resolvedUserId);
    }

    final singleResolvedInstruction = <_NotificationInstruction>[
      if (resolvedLeadId.isNotEmpty) _NotificationInstruction.lead(resolvedLeadId),
      if (resolvedProjectId.isNotEmpty)
        _NotificationInstruction.project(
          resolvedProjectId,
          initialData: hasProjectData ? projectData : null,
        ),
      if (resolvedFollowUpId.isNotEmpty)
        _NotificationInstruction.followUp(resolvedFollowUpId),
      if (resolvedVisitId.isNotEmpty)
        _NotificationInstruction.siteVisit(
          resolvedVisitId,
          initialData: hasVisitData ? visitData : null,
        ),
      if (resolvedRevisitId.isNotEmpty)
        _NotificationInstruction.siteRevisit(resolvedRevisitId),
      if (resolvedClosureId.isNotEmpty)
        _NotificationInstruction.closure(resolvedClosureId),
      if (resolvedUserId.isNotEmpty)
        _NotificationInstruction.teamMember(resolvedUserId),
    ];
    if (normalizedTarget.isEmpty && singleResolvedInstruction.length == 1) {
      return singleResolvedInstruction.first;
    }

    return null;
  }

  static Map<String, dynamic> _flattenPayload(Map<String, dynamic> payload) {
    final flattened = <String, dynamic>{};

    void merge(Map<String, dynamic> source) {
      for (final entry in source.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        flattened[key] = entry.value;
      }
    }

    merge(payload);

    for (final key in const <String>[
      'data',
      'payload',
      'meta',
      'extra',
      'notification_data',
      'notificationData',
    ]) {
      final value = flattened[key];
      final nested = _asMap(value);
      if (nested != null) {
        merge(nested);
        continue;
      }
      if (value is String) {
        final decoded = _decodeMap(value);
        if (decoded != null) {
          merge(decoded);
        }
      }
    }

    return flattened;
  }

  static Map<String, dynamic>? _extractNestedMap(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      final mapValue = _asMap(value);
      if (mapValue != null) {
        return mapValue;
      }
      if (value is String) {
        final decoded = _decodeMap(value);
        if (decoded != null) {
          return decoded;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, dynamic entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }

  static Map<String, dynamic>? _decodeMap(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map(
          (key, dynamic entryValue) =>
              MapEntry(key.toString(), entryValue),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _firstString(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value == null) {
        continue;
      }
      final resolved = value.toString().trim();
      if (resolved.isNotEmpty && resolved.toLowerCase() != 'null') {
        return resolved;
      }
    }
    return '';
  }

  static String _notificationKey(
    Map<String, dynamic> payload, {
    String? fallbackKey,
  }) {
    final messageId = _firstString(payload, const <String>[
      'message_id',
      'messageId',
      'notification_id',
      'notificationId',
      'id',
    ]);
    if (messageId.isNotEmpty) {
      return messageId;
    }
    if (fallbackKey != null && fallbackKey.trim().isNotEmpty) {
      return fallbackKey.trim();
    }

    final digest = <String>[
      _firstString(payload, const <String>[
        'type',
        'module',
        'entity_type',
        'entity',
        'screen',
        'route',
      ]),
      _firstString(payload, const <String>[
        'lead_id',
        'project_id',
        'follow_up_id',
        'visit_id',
        'revisit_id',
        'closure_id',
        'user_id',
      ]),
      _firstString(payload, const <String>[
        'title',
        'body',
        'message',
        'description',
      ]),
    ].where((part) => part.isNotEmpty).join('|');

    return digest.isEmpty ? payload.hashCode.toString() : digest;
  }

  static String _normalizeTarget(String? target) {
    return target?.trim().toLowerCase().replaceAll('-', '_').replaceAll(
              ' ',
              '_',
            ) ??
        '';
  }

  static bool _matchesAny(String value, List<String> expected) {
    if (value.isEmpty) {
      return false;
    }
    for (final target in expected) {
      if (value == target || value.contains(target) || target.contains(value)) {
        return true;
      }
    }
    return false;
  }
}

enum _NotificationTargetKind {
  leadDetail,
  projectDetail,
  followUpDetail,
  siteVisitDetail,
  siteRevisitDetail,
  closureDetail,
  teamMemberDetail,
  notifications,
}

class _NotificationInstruction {
  const _NotificationInstruction._({
    required this.kind,
    required this.requiresAuth,
    this.entityId,
    this.initialData,
  });

  const _NotificationInstruction.lead(String leadId)
      : this._(
          kind: _NotificationTargetKind.leadDetail,
          requiresAuth: true,
          entityId: leadId,
        );

  const _NotificationInstruction.project(
    String projectId, {
    Map<String, dynamic>? initialData,
  }) : this._(
          kind: _NotificationTargetKind.projectDetail,
          requiresAuth: true,
          entityId: projectId,
          initialData: initialData,
        );

  const _NotificationInstruction.followUp(String followUpId)
      : this._(
          kind: _NotificationTargetKind.followUpDetail,
          requiresAuth: true,
          entityId: followUpId,
        );

  const _NotificationInstruction.siteVisit(
    String visitId, {
    Map<String, dynamic>? initialData,
  }) : this._(
          kind: _NotificationTargetKind.siteVisitDetail,
          requiresAuth: true,
          entityId: visitId,
          initialData: initialData,
        );

  const _NotificationInstruction.siteRevisit(String revisitId)
      : this._(
          kind: _NotificationTargetKind.siteRevisitDetail,
          requiresAuth: true,
          entityId: revisitId,
        );

  const _NotificationInstruction.closure(String lookupId)
      : this._(
          kind: _NotificationTargetKind.closureDetail,
          requiresAuth: true,
          entityId: lookupId,
        );

  const _NotificationInstruction.teamMember(String userId)
      : this._(
          kind: _NotificationTargetKind.teamMemberDetail,
          requiresAuth: true,
          entityId: userId,
        );

  const _NotificationInstruction.notifications()
      : this._(
          kind: _NotificationTargetKind.notifications,
          requiresAuth: false,
        );

  final _NotificationTargetKind kind;
  final bool requiresAuth;
  final String? entityId;
  final Map<String, dynamic>? initialData;
}

class _QueuedNotificationPayload {
  const _QueuedNotificationPayload({
    required this.key,
    required this.payload,
    required this.instruction,
    this.sourceLabel,
  });

  final String key;
  final Map<String, dynamic> payload;
  final _NotificationInstruction instruction;
  final String? sourceLabel;
}
