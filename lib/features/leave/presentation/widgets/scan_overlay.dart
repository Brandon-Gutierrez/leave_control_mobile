import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Lo que se dibuja sobre la cámara: la pantalla se oscurece un poco fuera del
/// marco para que se note dónde apuntar, y el marco lleva cuatro esquinas rojas
/// y una línea de lectura al centro. No intercepta toques.
class ScanOverlay extends StatelessWidget {
  final double frameSize;

  const ScanOverlay({super.key, required this.frameSize});

  static const double _corner = 56;
  static const double _stroke = 6;
  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MaskPainter(frameSize: frameSize, radius: _radius),
            ),
            Center(
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CornersPainter(
                          length: _corner,
                          stroke: _stroke,
                          radius: _radius,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: frameSize / 2 - 1.5,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE04B4B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oscurece todo menos el interior del marco.
class _MaskPainter extends CustomPainter {
  final double frameSize;
  final double radius;

  const _MaskPainter({required this.frameSize, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: size.center(Offset.zero),
            width: frameSize,
            height: frameSize,
          ),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.frameSize != frameSize || old.radius != radius;
}

/// Cuatro esquinas en «L» con la esquina exterior redondeada.
class _CornersPainter extends CustomPainter {
  final double length;
  final double stroke;
  final double radius;

  const _CornersPainter({
    required this.length,
    required this.stroke,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.primaryRed;

    // La esquina superior izquierda, con el trazo hacia adentro del marco.
    final inset = stroke / 2;
    final corner = Path()
      ..moveTo(inset, length)
      ..lineTo(inset, radius)
      ..arcToPoint(
        Offset(radius, inset),
        radius: Radius.circular(radius - inset),
      )
      ..lineTo(length, inset);

    // Las otras tres son la misma esquina girada alrededor del centro.
    final center = size.center(Offset.zero);
    for (var quarter = 0; quarter < 4; quarter++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(quarter * math.pi / 2);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) =>
      old.length != length || old.stroke != stroke || old.radius != radius;
}
