/// Fechas, horas y duraciones escritas en español para las pantallas.
/// No usa `intl`: son pocas frases y así no depende de la configuración regional.
abstract final class DateText {
  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// La fecha sin la hora.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// «miércoles»
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// Inicial del día para la tira de la semana: L M M J V S D.
  static String weekdayLetter(DateTime d) => 'LMMJVSD'[d.weekday - 1];

  /// «Jueves 19 de noviembre»
  static String longDate(DateTime d) {
    final day = weekday(d);
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day} de '
        '${_months[d.month - 1]}';
  }

  /// «19/11»
  static String dayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

  /// «19/11/2026»
  static String dayMonthYear(DateTime d) => '${dayMonth(d)}/${d.year}';

  /// «08:05»
  static String hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// «40 min», «2 h», «1 h 25 min»
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
