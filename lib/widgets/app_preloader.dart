import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class AppPreloader extends StatelessWidget {
  const AppPreloader({
    super.key,
    this.message,
    this.compact = false,
  });

  final String? message;
  final bool compact;

  const AppPreloader.screen({
    super.key,
    this.message,
  }) : compact = false;

  const AppPreloader.compact({
    super.key,
    this.message,
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final spinnerSize = compact ? 18.0 : 24.0;
    final strokeWidth = compact ? 2.0 : 2.6;
    final verticalPadding = compact ? 14.0 : 22.0;

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: spinnerSize,
              height: spinnerSize,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              SizedBox(height: compact ? 10 : 12),
              Text(
                message!.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
