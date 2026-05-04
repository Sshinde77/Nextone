import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/routes/app_routes.dart';

class CrmAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CrmAppBar({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.onProfileTap,
    this.showNotificationDot = true,
    this.showBackButton = false,
    this.onBackTap,
    this.showProfileIcon = true,
    this.showNotificationIcon = true,
  });

  final String title;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final bool showNotificationDot;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final bool showProfileIcon;
  final bool showNotificationIcon;

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<CrmAppBar> createState() => _CrmAppBarState();
}

class _CrmAppBarState extends State<CrmAppBar> {
  final AuthProvider _authProvider = AuthProvider();
  String _profileName = 'User';
  String _profileRole = 'Team Member';
  bool _isLoadingProfile = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_isLoadingProfile) {
      return;
    }
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final result = await _authProvider.profile();
      final data = result.data;

      final firstName = _readString(data['first_name'] ?? data['firstName']);
      final lastName = _readString(data['last_name'] ?? data['lastName']);
      final fallbackName = _readString(data['name']);
      final email = _readString(data['email']);
      final fullName = [
        if (firstName.isNotEmpty) firstName,
        if (lastName.isNotEmpty) lastName,
      ].join(' ').trim();
      final resolvedName = fullName.isNotEmpty
          ? fullName
          : (fallbackName.isNotEmpty ? fallbackName : email);
      final role = _readableRole(
        _readString(data['role'] ?? data['user_role'] ?? data['userRole']),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (resolvedName.isNotEmpty) {
          _profileName = resolvedName;
        }
         if (role.isNotEmpty) {
          _profileRole = role;
        }
      });
    } catch (_) {
      // Keep fallback name/role if profile cannot be fetched.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _readableRole(String role) {
    if (role.isEmpty) {
      return '';
    }
    return role
        .split('_')
        .map((part) {
          if (part.isEmpty) return '';
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      final errorMessage = await _authProvider.logout();
      if (!mounted) {
        return;
      }

      if (errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to logout right now. Please try again.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _handleProfileTap() async {
    if (widget.onProfileTap != null) {
      widget.onProfileTap!.call();
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 78, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 12,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _profileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _profileRole,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          height: 42,
          child: Row(
            children: [
              if (_isLoggingOut)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              else
                const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
              const SizedBox(width: 8),
              const Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'logout') {
      await _handleLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    void handleNotificationTap() {
      if (widget.onNotificationTap != null) {
        widget.onNotificationTap!.call();
        return;
      }

      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == '/notifications') {
        return;
      }
      Navigator.pushNamed(context, '/notifications');
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: widget.showBackButton
          ? IconButton(
              onPressed: widget.onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            )
          : null,
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      titleSpacing: widget.showBackButton ? 4 : 16,
      title: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Color(0xFFB1916C)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset('assets/logo/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.showNotificationIcon)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: handleNotificationTap,
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.showNotificationDot)
                Positioned(
                  right: 12,
                  top: 22,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        if (widget.showNotificationIcon && widget.showProfileIcon)
          const SizedBox(width: 4),
        if (widget.showProfileIcon)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: _handleProfileTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _isLoadingProfile
                      ? '...'
                      : (_profileName.trim().isNotEmpty
                          ? _profileName.trim()[0].toUpperCase()
                          : 'U'),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
