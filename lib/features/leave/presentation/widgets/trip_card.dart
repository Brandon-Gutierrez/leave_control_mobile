import 'package:flutter/material.dart';

import '../../../../core/format/date_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/leave_status.dart';

/// Una salida: predio, motivo, hora de salida → hora de retorno y cuánto
/// tiempo estuvo fuera. Si aún no volvió, lo dice y qué hacer.
class TripCard extends StatelessWidget {
  final LeaveDetail leave;

  /// Antepone la fecha a las horas (vista de varios días).
  final bool showDates;

  /// Hoy es el día de la salida: aún puede marcar el retorno. Una salida sin
  /// retorno de un día anterior ya no se puede cerrar y no cuenta en los totales.
  final bool canStillReturn;

  const TripCard({
    super.key,
    required this.leave,
    required this.showDates,
    required this.canStillReturn,
  });

  @override
  Widget build(BuildContext context) {
    final left = leave.leftAt;
    final returned = leave.returnedAt;
    final open = returned == null;
    // Si vuelve otro día, las horas llevan su fecha para no confundir.
    final withDates =
        showDates || (returned != null && !DateText.sameDay(left, returned));
    final premise = (leave.premise ?? '').isEmpty
        ? 'Predio no disponible'
        : leave.premise!;
    final reason = leave.reason ?? '';
    final minutes = leave.minutes;

    final Color pillBg = open ? AppColors.dangerBg : AppColors.successBg;
    final Color pillFg = open ? AppColors.danger : AppColors.success;
    final String pill = !open
        ? 'Completada'
        : canStillReturn
        ? 'Sigue fuera'
        : 'Sin retorno';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFFFF9F9) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: open ? const Color(0xFFE9B8B8) : AppColors.cardLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 20, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  premise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pillFg,
                  ),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Motivo: ',
                children: [
                  TextSpan(
                    text: reason,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
            ),
          ],
          const SizedBox(height: 10),
          _Times(
            leftAt: left,
            returnedAt: returned,
            minutes: minutes,
            withDates: withDates,
            open: open,
          ),
          if (open) ...[
            const SizedBox(height: 10),
            Text(
              canStillReturn
                  ? 'Escanea el QR del predio para registrar tu retorno.'
                  : 'No se marcó el retorno de esta salida. '
                        'No se incluye en tus contadores.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recuadro SALIDA → RETORNO y tiempo fuera.
class _Times extends StatelessWidget {
  final DateTime leftAt;
  final DateTime? returnedAt;
  final int? minutes;
  final bool withDates;
  final bool open;

  const _Times({
    required this.leftAt,
    required this.returnedAt,
    required this.minutes,
    required this.withDates,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    final returned = returnedAt;

    final departure = _TimeBlock(
      label: 'SALIDA',
      value: DateText.hm(leftAt),
      date: withDates ? DateText.dayMonth(leftAt) : null,
    );
    final arrival = _TimeBlock(
      label: 'RETORNO',
      value: returned == null ? 'Pendiente' : DateText.hm(returned),
      date: withDates && returned != null ? DateText.dayMonth(returned) : null,
      valueColor: returned == null ? AppColors.danger : null,
      small: returned == null,
    );
    final outside = minutes == null
        ? null
        : _TimeBlock(
            label: 'FUERA',
            value: DateText.duration(minutes!),
            alignEnd: true,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFF6ECEC) : AppColors.softSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En teléfonos angostos el tiempo fuera baja a su propia línea.
          final narrow = constraints.maxWidth < 270;
          final arrow = const Icon(
            Icons.arrow_forward_rounded,
            size: 22,
            color: Color(0xFF999999),
          );
          final row = Row(
            children: [
              Expanded(child: departure),
              arrow,
              const SizedBox(width: 8),
              Expanded(child: arrival),
              if (outside != null && !narrow) ...[
                const SizedBox(width: 8),
                Flexible(child: outside),
              ],
            ],
          );
          if (outside == null || !narrow) return row;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              const SizedBox(height: 8),
              Row(children: [Expanded(child: outside)]),
            ],
          );
        },
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final String value;

  /// Fecha corta bajo la hora (solo cuando hay que distinguir de qué día es).
  final String? date;
  final Color? valueColor;
  final bool alignEnd;

  /// Texto corto en vez de una hora (p. ej. «Pendiente»).
  final bool small;

  const _TimeBlock({
    required this.label,
    required this.value,
    this.date,
    this.valueColor,
    this.alignEnd = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: small ? 18 : 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: valueColor ?? AppColors.darkText,
            ),
          ),
        ),
        if (date != null)
          Text(
            date!,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}
