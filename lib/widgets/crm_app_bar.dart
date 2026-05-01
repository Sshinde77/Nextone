import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class CrmAppBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    void handleNotificationTap() {
      if (onNotificationTap != null) {
        onNotificationTap!.call();
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
      leading: showBackButton
          ? IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
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
      titleSpacing: showBackButton ? 4 : 16,
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
              title,
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
        if (showNotificationIcon)
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
              if (showNotificationDot)
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
        if (showNotificationIcon && showProfileIcon) const SizedBox(width: 4),
        if (showProfileIcon)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
