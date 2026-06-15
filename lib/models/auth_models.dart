class ForgotPasswordResult {
  const ForgotPasswordResult({required this.message, this.resetToken});

  final String message;
  final String? resetToken;
}

class AuthProfileResult {
  const AuthProfileResult({required this.data, required this.message});

  final Map<String, dynamic> data;
  final String message;
}

class EffectivePermissionsResult {
  const EffectivePermissionsResult({
    required this.role,
    required this.permissions,
    required this.modules,
    required this.permissionKeys,
    required this.message,
  });

  const EffectivePermissionsResult.empty()
      : role = '',
        permissions = const <String, ModulePermissionSet>{},
        modules = const <String>[],
        permissionKeys = const <String>[],
        message = '';

  final String role;
  final Map<String, ModulePermissionSet> permissions;
  final List<String> modules;
  final List<String> permissionKeys;
  final String message;

  bool can(String module, String action) {
    final permissionSet = permissions[module.trim().toLowerCase()];
    if (permissionSet == null) {
      return false;
    }
    return permissionSet.can(action);
  }

  bool canAny(String module, List<String> actions) {
    for (final action in actions) {
      if (can(module, action)) {
        return true;
      }
    }
    return false;
  }

  bool hasModuleAccess(String module) {
    return canAny(module, const <String>['view', 'create', 'edit', 'delete', 'approve', 'export']);
  }
}

class ModulePermissionSet {
  const ModulePermissionSet(this.actions);

  final Map<String, bool> actions;

  bool can(String action) {
    return actions[action.trim().toLowerCase()] ?? false;
  }
}

class AuthTokenResult {
  const AuthTokenResult({
    required this.message,
    required this.data,
    this.accessToken,
    this.refreshToken,
  });

  final String message;
  final Map<String, dynamic> data;
  final String? accessToken;
  final String? refreshToken;
}

class LeadsListResult {
  const LeadsListResult({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int perPage;
  final int totalItems;
  final int totalPages;
}

class ExportFileResult {
  const ExportFileResult({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final List<int> bytes;
  final String contentType;
}
