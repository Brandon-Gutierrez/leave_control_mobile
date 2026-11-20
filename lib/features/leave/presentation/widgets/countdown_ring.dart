import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Anillo con los segundos que quedan para elegir el motivo. El arco rojo se
/// va vaciando con el tiempo; en los últimos 10 segundos el número se pone rojo.
class CountdownRing extends StatelessWidget {
  final int secondsLeft;

  /// Segundos con los que empezó la cuenta atrás (el anillo parte lleno).
  final int totalSeconds;

  final double size;

  const CountdownRing({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalSeconds < 1 ? 1 : totalSeconds;
    final progress = (secondsLeft / total).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 10;

    return Semantics(
      label: 'Tiempo para elegir el motivo: $secondsLeft segundos',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(progress: progress, stroke: size * 0.09),
            ),
            Text(
              '$secondsLeft',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: urgent ? AppColors.primaryRed : AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;

  const _RingPainter({required this.progress, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFE8E8E8),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primaryRed,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.stroke != stroke;
}
