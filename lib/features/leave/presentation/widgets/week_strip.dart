import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/format/date_text.dart';
import '../../../../core/theme/app_colors.dart';

/// Tira con los siete días (lunes a domingo) de la semana de la fecha elegida.
/// Los días elegidos van en negro y los futuros se ven apagados y no se tocan.
class WeekStrip extends StatelessWidget {
  /// Primer y último día elegidos (el mismo si es un solo día).
  final DateTime selectedStart;
  final DateTime selectedEnd;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  const WeekStrip({
    super.key,
    required this.selectedStart,
    required this.selectedEnd,
    required this.today,
    required this.onSelect,
  });

  /// Clave de la celda de un día (para pruebas).
  static Key dayKey(DateTime d) =>
      ValueKey('week-day-${d.year}-${d.month}-${d.day}');

  @override
  Widget build(BuildContext context) {
    final first = DateText.dateOnly(selectedStart);
    final monday = DateTime(
      first.year,
      first.month,
      first.day - (first.weekday - 1),
    );
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 44 px por día; en teléfonos angostos se reparte el ancho disponible.
        final width = math.min(44.0, constraints.maxWidth / 7);
        // Las celdas tienen un alto fijo: con la letra del teléfono al máximo
        // el texto se agranda hasta x1.3 y no más, para que siempre quepa.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayCell(
                  key: dayKey(day),
                  day: day,
                  width: width,
                  selected:
                      !day.isBefore(DateText.dateOnly(selectedStart)) &&
                      !day.isAfter(DateText.dateOnly(selectedEnd)),
                  isToday: DateText.sameDay(day, today),
                  future: day.isAfter(DateText.dateOnly(today)),
                  onTap: () => onSelect(day),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final double width;
  final bool selected;
  final bool isToday;
  final bool future;
  final VoidCallback onTap;

  const _DayCell({
    super.key,
    required this.day,
    required this.width,
    required this.selected,
    required this.isToday,
    required this.future,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final letterColor = selected ? const Color(0xFFBDBDBD) : AppColors.muted;
    final numberColor = selected ? Colors.white : AppColors.darkText;

    return Semantics(
      button: !future,
      enabled: !future,
      selected: selected,
      label: DateText.longDate(day),
      excludeSemantics: true,
      child: Opacity(
        opacity: future ? 0.35 : 1,
        child: Material(
          color: selected ? AppColors.darkText : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: future ? null : onTap,
            child: SizedBox(
              width: width,
              height: 58,
              // Si por algún motivo no cabe, se reduce en vez de partirse.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateText.weekdayLetter(day),
                      style: TextStyle(fontSize: 12, color: letterColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: numberColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
