import 'package:nextone/providers/auth_provider.dart';

class RoleAccess {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String salesManager = 'sales_manager';
  static const String salesExecutive = 'sales_executive';
  static const String externalCaller = 'external_caller';

  static const List<String> allRoles = <String>[
    superAdmin,
    admin,
    salesManager,
    salesExecutive,
    externalCaller,
  ];

  static const List<String> adminAssignableRoles = <String>[
    salesManager,
    salesExecutive,
    externalCaller,
  ];

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  static String readRole(Map<String, dynamic> data) {
    final value = data['role'] ?? data['user_role'] ?? data['userRole'];
    return value == null ? '' : normalize(value.toString());
  }

  static String label(String role) {
    final normalized = normalize(role);
    if (normalized.isEmpty) {
      return 'Team Member';
    }
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static bool isSuperAdmin(String role) => normalize(role) == superAdmin;
  static bool isAdmin(String role) => normalize(role) == admin;
  static bool isSalesManager(String role) => normalize(role) == salesManager;
  static bool isTierFour(String role) {
    final normalized = normalize(role);
    return normalized == salesExecutive || normalized == externalCaller;
  }

  static bool hasFullAccess(String role) {
    final normalized = normalize(role);
    return normalized == superAdmin || normalized == admin;
  }

  static bool canManageUsers(String role) => hasFullAccess(role);
  static bool canManageProjects(String role) => hasFullAccess(role);
  static bool canExportData(String role) => hasFullAccess(role);
  static bool canViewProjects(String role) => hasFullAccess(role);
  static bool canViewUsers(String role) => hasFullAccess(role);

  static bool canViewTeam(String role) {
    final normalized = normalize(role);
    return hasFullAccess(normalized) || normalized == salesManager;
  }

  static bool canChangeRole(String currentRole, String targetRole) {
    final current = normalize(currentRole);
    final target = normalize(targetRole);
    if (target == superAdmin) {
      return false;
    }
    if (current == superAdmin) {
      return target != superAdmin;
    }
    if (current == admin) {
      return adminAssignableRoles.contains(target);
    }
    return false;
  }

  static bool canDeactivate(String currentRole, String targetRole) {
    return hasFullAccess(currentRole) && normalize(targetRole) != superAdmin;
  }

  static bool canAccessMainTab(String role, int index) {
    switch (index) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 6:
        return true;
      case 4:
        return canViewProjects(role);
      case 5:
        return canViewTeam(role);
      case 7:
        return canViewUsers(role);
      default:
        return false;
    }
  }

  static Future<String> currentRole(AuthProvider authProvider) async {
    final profile = await authProvider.profile(
      token: authProvider.currentAuthToken,
    );
    return readRole(profile.data);
  }
}
