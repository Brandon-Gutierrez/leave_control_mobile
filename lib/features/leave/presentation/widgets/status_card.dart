import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/format/date_text.dart';
import '../../../../core/theme/app_colors.dart';

/// Estado actual de la persona en un vistazo.
///
/// Dentro: tarjeta verde con un anillo completo y una marca de verificación.
/// Fuera: tarjeta oscura con un anillo que avanza y el tiempo transcurrido,
/// que se actualiza cada segundo sin reconstruir el resto de la pantalla.
class StatusCard extends StatefulWidget {
  final bool isLeave;

  /// Cuándo salió (solo si está fuera).
  final DateTime? leftAt;

  /// Predio y motivo de la salida activa, si se conocen.
  final String? premise;
  final String? reason;

  /// Hora del último retorno de hoy (solo si está dentro y ya volvió alguna vez).
  final DateTime? lastReturnAt;

  /// Reloj (pruebas); por defecto la hora real.
  final DateTime Function()? clock;

  const StatusCard({
    super.key,
    required this.isLeave,
    this.leftAt,
    this.premise,
    this.reason,
    this.lastReturnAt,
    this.clock,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLeave != widget.isLeave ||
        oldWidget.leftAt != widget.leftAt) {
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    final leftAt = widget.leftAt;
    if (!widget.isLeave || leftAt == null) {
      _elapsed = Duration.zero;
      return;
    }
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_tick);
    });
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  void _tick() {
    final diff = _now().difference(widget.leftAt!);
    _elapsed = diff.isNegative ? Duration.zero : diff;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String get _elapsedText {
    final h = _elapsed.inHours;
    return '${_two(h)}:${_two(_elapsed.inMinutes.remainder(60))}:'
        '${_two(_elapsed.inSeconds.remainder(60))}';
  }

  String get _sinceText {
    final leftAt = widget.leftAt;
    if (leftAt == null) return '';
    final today = DateText.sameDay(leftAt, _now());
    final when = today
        ? 'Desde las ${DateText.hm(leftAt)}'
        : 'Desde el ${DateText.dayMonth(leftAt)} a las ${DateText.hm(leftAt)}';
    final premise = widget.premise;
    return premise == null || premise.isEmpty ? when : '$when · $premise';
  }

  @override
  Widget build(BuildContext context) {
    final out = widget.isLeave;
    final bg = out ? const Color(0xFF1A1A1A) : AppColors.successBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // El anillo se adapta al ancho para que el texto de al lado no se
          // aplaste en teléfonos angostos.
          final ring = (constraints.maxWidth * 0.42).clamp(96.0, 128.0);
          return Row(
            children: [
              _Ring(
                size: ring,
                out: out,
                progress: out ? (_elapsed.inSeconds % 3600) / 3600 : 1,
                elapsedText: _elapsedText,
              ),
              const SizedBox(width: 18),
              Expanded(child: out ? _outText() : _inText()),
            ],
          );
        },
      ),
    );
  }

  Widget _title(String text, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: color,
        ),
      ),
    );
  }

  Widget _inText() {
    final last = widget.lastReturnAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ESTADO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 5),
        _title('Estás dentro', AppColors.darkText),
        const SizedBox(height: 5),
        Text(
          last != null
              ? 'Último retorno a las ${DateText.hm(last)}'
              : 'Cuando salgas, escanea el QR del predio.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
        ),
      ],
    );
  }

  Widget _outText() {
    final reason = widget.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ESTADO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: Color(0xFFF2A5A5),
          ),
        ),
        const SizedBox(height: 5),
        _title('Estás fuera', Colors.white),
        const SizedBox(height: 5),
        Text(
          _sinceText,
          style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
        ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Anillo con la marca de verificación (dentro) o el tiempo transcurrido (fuera).
class _Ring extends StatelessWidget {
  final double size;
  final bool out;
  final double progress;
  final String elapsedText;

  const _Ring({
    required this.size,
    required this.out,
    required this.progress,
    required this.elapsedText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: progress,
                track: out ? const Color(0xFF333333) : const Color(0xFFD3E4D6),
                color: out ? const Color(0xFFE04B4B) : AppColors.success,
                stroke: size * 0.078,
              ),
            ),
          ),
          if (out)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.17),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      elapsedText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Text(
                    'transcurrido',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            )
          else
            Icon(
              Icons.check_rounded,
              size: size * 0.4,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;
  final double stroke;

  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}
