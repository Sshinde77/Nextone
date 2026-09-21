import 'package:flutter/material.dart';
import 'package:nextone/models/auth_models.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/role_access.dart';

class PermissionGuard {
  static Future<bool> allowModuleAction(
    BuildContext context, {
    required AuthProvider authProvider,
    required String module,
    required String action,
    String? moduleLabel,
  }) async {
    EffectivePermissionsResult permissions;
    try {
      permissions = await RoleAccess.currentPermissionSet(
        authProvider,
        forceRefresh: true,
      );
    } catch (_) {
      if (!context.mounted) {
        return false;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to verify permissions right now.'),
          ),
        );
      return false;
    }

    final normalizedModule = module.trim().toLowerCase();
    final allowed = switch (action.trim().toLowerCase()) {
      'view' => RoleAccess.canViewModule(module),
      'create' => RoleAccess.canCreateModule(module),
      'edit' => RoleAccess.canEditModule(module),
      'delete' => RoleAccess.canDeleteModule(module),
      'approve' => RoleAccess.canApproveModule(module),
      'export' => RoleAccess.canExportModule(module),
      'reassign' => normalizedModule == 'leads' &&
          (RoleAccess.canReassignLeads(permissions.role) ||
              RoleAccess.canEditModule(module)),
      _ => false,
    };

    if (allowed || !context.mounted) {
      return allowed;
    }

    final label = moduleLabel ?? _label(module);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "You don't have permission to $action $label.",
          ),
        ),
      );
    return false;
  }

  static String _label(String module) {
    return module
        .trim()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
