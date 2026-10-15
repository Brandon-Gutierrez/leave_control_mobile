import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Calendario para elegir un día o un rango. Un toque elige un día; un
/// segundo toque en otro día lo convierte en rango. Devuelve null si se cierra.
Future<DateTimeRange?> showDateRangeSheet(
  BuildContext context, {
  required DateTimeRange initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => DateRangeSheet(
      initial: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class DateRangeSheet extends StatefulWidget {
  final DateTimeRange initial;
  final DateTime firstDate;
  final DateTime lastDate;

  const DateRangeSheet({
    super.key,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<DateRangeSheet> {
  late DateTime _start = widget.initial.start;
  late DateTime _end = widget.initial.end;
  late DateTime _month = DateTime(_start.year, _start.month);

  /// true mientras falta el segundo toque para cerrar el rango.
  bool _picking = false;

  bool get _isSingle => _start == _end;

  bool _canPickMonth(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !target.isBefore(first) && !target.isAfter(last);
  }

  void _moveMonth(int delta) {
    if (!_canPickMonth(delta)) return;
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _tapDay(DateTime day) {
    setState(() {
      if (!_picking) {
        _start = day;
        _end = day;
        _picking = true;
      } else {
        // El primer toque quedó en _start (= _end): se cierra el rango.
        final anchor = _start;
        _start = day.isBefore(anchor) ? day : anchor;
        _end = day.isBefore(anchor) ? anchor : day;
        _picking = false;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _summary {
    if (_picking) return 'Toca otro día para elegir un rango, o aplica este.';
    return _isSingle
        ? 'Día: ${_fmt(_start)}'
        : 'Del ${_fmt(_start)} al ${_fmt(_end)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elige una fecha',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca un día. Para un rango, toca el día inicial y luego el final.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.info),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: _canPickMonth(-1) ? () => _moveMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  color: AppColors.darkText,
                ),
                Expanded(
                  child: Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: _canPickMonth(1) ? () => _moveMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 30),
                  color: AppColors.darkText,
                ),
              ],
            ),
            Row(
              children: [
                for (final w in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _buildGrid(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: AppColors.darkText,
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTimeRange(start: _start, end: _end),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final offset = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = offset + days;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _buildCell(r * 7 + c - offset + 1, days)),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 46);
    }
    final day = DateTime(_month.year, _month.month, dayNumber);
    final enabled =
        !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
    final isEdge = day == _start || day == _end;
    final inRange = day.isAfter(_start) && day.isBefore(_end);
    final isToday =
        day ==
        DateTime(
          widget.lastDate.year,
          widget.lastDate.month,
          widget.lastDate.day,
        );

    final Color textColor = isEdge
        ? Colors.white
        : enabled
        ? AppColors.darkText
        : AppColors.line;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _tapDay(day) : null,
      child: Container(
        height: 46,
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: inRange ? AppColors.dangerBg : Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEdge ? AppColors.primaryRed : Colors.transparent,
            border: isToday && !isEdge
                ? Border.all(color: AppColors.primaryRed)
                : null,
          ),
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isEdge || isToday ? FontWeight.w800 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
