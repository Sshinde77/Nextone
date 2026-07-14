import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/services/auth_service.dart';
import 'package:nextone/services/notification_navigation_service.dart';
import 'package:nextone/services/push_notification_service.dart';
import 'package:nextone/utils/app_error_handler.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isBootstrapping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping) {
      return;
    }
    _isBootstrapping = true;

    final startedAt = DateTime.now();
    var isLoggedIn = false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await PushNotificationService.initialize();
    } catch (error, stackTrace) {
      AppErrorHandler.logDebug(
        'Startup initialization completed with a recoverable error.',
        name: 'StartupPage',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      isLoggedIn = await AuthService.hasPersistedSession();
    } catch (error, stackTrace) {
      AppErrorHandler.logDebug(
        'Session lookup failed during startup; falling back to login.',
        name: 'StartupPage',
        error: error,
        stackTrace: stackTrace,
      );
    }

    const minSplashDuration = Duration(milliseconds: 2200);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }

    if (!mounted) {
      return;
    }

    final targetRoute = isLoggedIn ? AppRoutes.home : AppRoutes.login;
    Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationNavigationService.flushPendingNavigation());
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8FBFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFF3F8FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.08,
            left: -size.width * 0.12,
            child: _GlowBlob(
              size: size.width * 0.38,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: size.height * 0.18,
            right: -size.width * 0.1,
            child: _GlowBlob(
              size: size.width * 0.3,
              color: AppColors.secondary.withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.08,
            left: size.width * 0.2,
            child: _GlowBlob(
              size: size.width * 0.45,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = _controller.value;
                    final pulse =
                        0.5 + (math.sin(progress * math.pi * 2) * 0.5);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(220, 220),
                                painter: _StartupRingsPainter(
                                  progress: progress,
                                  pulse: pulse,
                                ),
                              ),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      blurRadius: 28,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Image.asset(
                                    'assets/logo/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'INITIALIZING WORKSPACE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 246,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Preparing your dashboard and secure session',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: 0.35 + (pulse * 0.2),
                          child: Container(
                            width: 250,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.0),
                                  AppColors.primary.withValues(alpha: 0.18),
                                  AppColors.primaryLight
                                      .withValues(alpha: 0.28),
                                  AppColors.primary.withValues(alpha: 0.0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 60,
                                  spreadRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.45,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}

class _StartupRingsPainter extends CustomPainter {
  _StartupRingsPainter({
    required this.progress,
    required this.pulse,
  });

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide * 0.31;
    final middleRadius = size.shortestSide * 0.25;
    final innerRadius = size.shortestSide * 0.18;

    final outerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.primary.withValues(alpha: 0.08);
    final innerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.primary.withValues(alpha: 0.06);

    canvas.drawCircle(center, outerRadius, outerTrack);
    canvas.drawCircle(center, middleRadius, innerTrack);

    void drawArc({
      required double radius,
      required double startAngle,
      required double sweepAngle,
      required Color color,
      required double strokeWidth,
    }) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    final start = -math.pi / 2 + (progress * math.pi * 2);
    drawArc(
      radius: outerRadius,
      startAngle: start,
      sweepAngle: math.pi * 0.58,
      color: AppColors.primary.withValues(alpha: 0.95),
      strokeWidth: 2.4,
    );
    drawArc(
      radius: middleRadius,
      startAngle: start - (math.pi * 0.35),
      sweepAngle: math.pi * 0.5,
      color: AppColors.primaryLight.withValues(alpha: 0.85),
      strokeWidth: 2.0,
    );
    drawArc(
      radius: innerRadius,
      startAngle: start + (math.pi * 0.2),
      sweepAngle: math.pi * (0.3 + (pulse * 0.18)),
      color: AppColors.primary.withValues(alpha: 0.28),
      strokeWidth: 1.8,
    );

    final highlightPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.18 + (pulse * 0.08))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, innerRadius * 0.55, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _StartupRingsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
