import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/models/auth_models.dart';

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

  static EffectivePermissionsResult _permissions =
      const EffectivePermissionsResult.empty();

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

  static EffectivePermissionsResult get currentPermissions => _permissions;

  static Future<EffectivePermissionsResult> currentPermissionSet(
    AuthProvider authProvider, {
    bool forceRefresh = false,
  }) async {
    final permissions = await authProvider.myPermissions(
      token: authProvider.currentAuthToken,
      forceRefresh: forceRefresh,
    );
    _permissions = permissions;
    return permissions;
  }

  static bool hasFullAccess(String role) => canApprovePhoneRequests(role);

  static bool canViewModule(String module) => _permissions.can(module, 'view');
  static bool canCreateModule(String module) =>
      _permissions.can(module, 'create');
  static bool canEditModule(String module) => _permissions.can(module, 'edit');
  static bool canDeleteModule(String module) =>
      _permissions.can(module, 'delete');
  static bool canApproveModule(String module) =>
      _permissions.can(module, 'approve');
  static bool canExportModule(String module) =>
      _permissions.can(module, 'export');

  static bool canManageUsers(String role) {
    final _ = role;
    return _permissions.canAny(
      'users',
      const <String>['create', 'edit', 'delete', 'approve'],
    );
  }

  static bool canCreateUsers(String role) {
    final _ = role;
    return _permissions.can('users', 'create');
  }

  static bool canEditUsers(String role) {
    final _ = role;
    return _permissions.can('users', 'edit');
  }

  static bool canDeleteUsers(String role) {
    final _ = role;
    return _permissions.can('users', 'delete');
  }

  static bool canAssignManager(String role) {
    final _ = role;
    return _permissions.canAny(
      'users',
      const <String>['edit', 'approve'],
    );
  }

  static bool canManageProjects(String role) {
    final _ = role;
    return _permissions.canAny(
      'projects',
      const <String>['create', 'edit', 'delete'],
    );
  }

  static bool canCreateProjects(String role) {
    final _ = role;
    return _permissions.can('projects', 'create');
  }

  static bool canEditProjects(String role) {
    final _ = role;
    return _permissions.can('projects', 'edit');
  }

  static bool canDeleteProjects(String role) {
    final _ = role;
    return _permissions.can('projects', 'delete');
  }

  static bool canViewProjects(String role) {
    final _ = role;
    return _permissions.can('projects', 'view');
  }

  static bool canViewUsers(String role) {
    final _ = role;
    return _permissions.can('users', 'view');
  }

  static bool canViewTeam(String role) {
    final _ = role;
    return _permissions.can('team', 'view');
  }

  static bool canViewLeadPhones(String role) {
    final _ = role;
    return canApprovePhoneRequests(role);
  }

  static bool canApprovePhoneRequests(String role) {
    final _ = role;
    return _permissions.can('phone_requests', 'approve');
  }

  static bool canViewSalaryManagement(String role) {
    final _ = role;
    return _permissions.can('salary', 'view');
  }

  static bool canManageSalary(String role) {
    final _ = role;
    return _permissions.canAny(
      'salary',
      const <String>['create', 'edit', 'delete', 'approve', 'export'],
    );
  }

  static bool canChangeRole(String currentRole, String targetRole) {
    final target = normalize(targetRole);
    final _ = currentRole;
    return target.isNotEmpty &&
        (canCreateUsers(currentRole) || canEditUsers(currentRole));
  }

  static bool canDeactivate(String currentRole, String targetRole) {
    final _ = targetRole;
    return canDeleteUsers(currentRole);
  }

  static bool canAccessMainTab(String role, int index) {
    final _ = role;
    final module = mainTabModule(index);
    if (module == null) {
      return false;
    }
    return canViewModule(module);
  }

  static Future<String> currentRole(AuthProvider authProvider) async {
    final permissions = await currentPermissionSet(authProvider);
    return permissions.role;
  }

  static String? mainTabModule(int index) {
    switch (index) {
      case 0:
        return 'dashboard';
      case 1:
        return 'leads';
      case 2:
        return 'follow_ups';
      case 3:
        return 'site_visits';
      case 4:
        return 'revisits';
      case 5:
        return 'projects';
      case 6:
        return 'team';
      case 7:
        return 'attendance';
      case 8:
        return 'users';
      case 9:
        return 'salary';
      case 10:
        return 'closures';
      case 11:
        return 'targets';
      default:
        return null;
    }
  }

  static String mainTabLabel(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Leads';
      case 2:
        return 'Follow-Ups';
      case 3:
        return 'Site Visits';
      case 4:
        return 'Re-visits';
      case 5:
        return 'Projects';
      case 6:
        return 'Team';
      case 7:
        return 'Attendance';
      case 8:
        return 'Users';
      case 9:
        return 'Salary';
      case 10:
        return 'Closures';
      case 11:
        return 'Targets';
      default:
        return 'Module';
    }
  }
}
