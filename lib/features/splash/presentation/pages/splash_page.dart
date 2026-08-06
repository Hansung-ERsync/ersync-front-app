import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  static const Duration _minimumDisplayDuration = Duration(milliseconds: 1400);

  late final AnimationController _vitalController;

  @override
  void initState() {
    super.initState();
    _vitalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..repeat();
    Future<void>.microtask(_restoreSession);
  }

  Future<void> _restoreSession() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      ref.read(authViewModelProvider.notifier).restoreSession(),
      Future<void>.delayed(_minimumDisplayDuration),
    ]);
    if (!mounted) {
      return;
    }

    final bool restored = results.first == true;
    if (restored) {
      context.goNamed('home');
      return;
    }
    context.goNamed(
      'login',
      extra: ref.read(authViewModelProvider).errorMessage,
    );
  }

  @override
  void dispose() {
    _vitalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splashPage'),
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'ERSync',
                  key: Key('splashBrand'),
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 28),
                RepaintBoundary(
                  key: const Key('splashVitalAnimation'),
                  child: SizedBox(
                    width: 228,
                    height: 66,
                    child: AnimatedBuilder(
                      animation: _vitalController,
                      builder: (BuildContext context, Widget? child) {
                        return CustomPaint(
                          painter: _VitalWavePainter(
                            progress: _vitalController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalWavePainter extends CustomPainter {
  const _VitalWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.12, size.height * 0.55)
      ..lineTo(size.width * 0.18, size.height * 0.51)
      ..lineTo(size.width * 0.23, size.height * 0.66)
      ..lineTo(size.width * 0.29, size.height * 0.13)
      ..lineTo(size.width * 0.35, size.height * 0.88)
      ..lineTo(size.width * 0.41, size.height * 0.55)
      ..lineTo(size.width * 0.58, size.height * 0.55)
      ..lineTo(size.width * 0.63, size.height * 0.49)
      ..lineTo(size.width * 0.68, size.height * 0.64)
      ..lineTo(size.width * 0.73, size.height * 0.27)
      ..lineTo(size.width * 0.79, size.height * 0.78)
      ..lineTo(size.width * 0.85, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.55);

    final Paint guidePaint = Paint()
      ..color = AppColors.textOnDark.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, guidePaint);

    final PathMetric metric = path.computeMetrics().first;
    final double head = metric.length * progress;
    final double tail = math.max(0, head - metric.length * 0.34);
    final Path activePath = metric.extractPath(tail, head);

    final Paint glowPaint = Paint()
      ..color = AppColors.textOnDark.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(activePath, glowPaint);

    final Paint activePaint = Paint()
      ..color = AppColors.textOnDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(activePath, activePaint);

    final Tangent? tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        3.2,
        Paint()..color = AppColors.textOnDark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VitalWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
