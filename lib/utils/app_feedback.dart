import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/services/notification_navigation_service.dart';

class AppFeedback {
  AppFeedback._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showMessage(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissTimer?.cancel();
    _removeCurrentEntry();

    final overlayState =
        NotificationNavigationService.navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      return;
    }

    _currentEntry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).viewPadding.top + 16;
        final theme = Theme.of(context);
        return IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isError ? AppColors.error : AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_currentEntry!);
    _dismissTimer = Timer(duration, _removeCurrentEntry);
  }

  static void _removeCurrentEntry() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
