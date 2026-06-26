import 'package:flutter_test/flutter_test.dart';
import 'package:nextone/services/notification_navigation_service.dart';

void main() {
  test('resolves camelCase lead detail screens', () {
    final routeKey = NotificationNavigationService.debugResolveRouteKey(
      <String, dynamic>{
        'screen_name': 'LeadDetailPage',
        'lead_id': 'lead-123',
      },
    );

    expect(routeKey, 'lead_detail:lead-123');
  });

  test('falls back to the leads list when only the lead screen is present', () {
    final routeKey = NotificationNavigationService.debugResolveRouteKey(
      <String, dynamic>{
        'target_screen': 'LeadsPage',
        'title': 'Lead assigned',
      },
    );

    expect(routeKey, 'lead_list');
  });

  test('resolves task-style follow-up payloads', () {
    final routeKey = NotificationNavigationService.debugResolveRouteKey(
      <String, dynamic>{
        'reference_type': 'tasks',
        'reference_id': 'task-42',
      },
    );

    expect(routeKey, 'follow_up_detail:task-42');
  });

  test('resolves appraisal notifications to salary management', () {
    final routeKey = NotificationNavigationService.debugResolveRouteKey(
      <String, dynamic>{
        'reference_type': 'appraisal',
        'reference_id': '79d12b9d-dea4-4ace-a9d9-4de9ffca912a',
      },
    );

    expect(routeKey, 'salary_management');
  });
}
