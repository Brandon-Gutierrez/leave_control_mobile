/// Motivo de salida de un predio. Si la persona ya lo usó tantas veces como
/// permite el límite del período, llega con una nota y no se puede elegir.
class LeaveReasonOption {
  final String name;

  /// Por qué no está permitido (p. ej. "Límite alcanzado: 1 vez por día"),
  /// o null si se puede elegir.
  final String? blockedNote;

  const LeaveReasonOption(this.name, {this.blockedNote});

  bool get isBlocked => blockedNote != null;

  /// Lee la respuesta de `GET /premises/{predio}/reasons`: los nombres de
  /// `reasons` y, en `blocked_reasons`, los que ya llegaron a su límite.
  static List<LeaveReasonOption> listFromJson(Map<String, dynamic> json) {
    final notes = <String, String>{};
    for (final blocked in json['blocked_reasons'] as List? ?? const []) {
      if (blocked is! Map) continue;
      final limit = (blocked['limit'] as num?)?.toInt() ?? 0;
      notes[blocked['name'].toString()] = _note(
        limit,
        blocked['period']?.toString(),
      );
    }
    return [
      for (final name in json['reasons'] as List? ?? const [])
        LeaveReasonOption(name.toString(), blockedNote: notes[name.toString()]),
    ];
  }

  static String _note(int limit, String? period) {
    final unit = switch (period) {
      'week' => 'semana',
      'month' => 'mes',
      _ => 'día',
    };
    return 'Límite alcanzado: $limit ${limit == 1 ? 'vez' : 'veces'} por $unit';
  }
}
