/// Cuántas veces salió una persona y cuántos minutos estuvo fuera en un período.
class LeaveStat {
  final int? exits;
  final int? minutes;

  const LeaveStat(this.exits, this.minutes);
}

/// Datos de la persona y si está fuera en este momento, tal como los entrega
/// el backend para la pantalla de inicio.
class LeaveStatus {
  final String? name;
  final bool isLeave;

  /// Fecha de la salida activa (ISO 8601); null si está adentro.
  final String? dateLeave;

  /// Motivo de la salida activa.
  final String? reason;

  /// Rol con nombre legible (p. ej. "Empleado").
  final String? role;

  /// Cargo real de la persona según el sistema de RR.HH.
  final String? jobTitle;
  final String? photoUrl;

  /// Estadísticas por período: `day`, `week` y `month`.
  final Map<String, LeaveStat> stats;

  const LeaveStatus({
    required this.name,
    required this.isLeave,
    required this.dateLeave,
    required this.reason,
    required this.role,
    required this.jobTitle,
    required this.photoUrl,
    required this.stats,
  });

  factory LeaveStatus.fromJson(Map<String, dynamic> json) {
    return LeaveStatus(
      name: json['name'],
      isLeave: json['isLeave'] ?? false,
      dateLeave: json['dateLeave'],
      reason: json['reason'],
      role: _roleLabel(json['role']),
      jobTitle: json['job_title']?.toString(),
      photoUrl: (json['photo_url'] ?? json['photo'] ?? json['avatar'])
          ?.toString(),
      stats: _parseStats(json['stats']),
    );
  }

  /// El rol llega del servidor (texto o { name }); se muestra con nombre legible.
  static String? _roleLabel(dynamic role) {
    final name = (role is Map ? role['name'] : role)?.toString();
    if (name == null || name.isEmpty) return null;
    return switch (name.toUpperCase()) {
      'EMPLOYEE' => 'Empleado',
      'ADMIN' => 'Administrador',
      _ => name,
    };
  }

  static Map<String, LeaveStat> _parseStats(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, LeaveStat>{};
    for (final key in const ['day', 'week', 'month']) {
      final item = raw[key];
      if (item is Map) {
        result[key] = LeaveStat(
          (item['exits'] as num?)?.toInt(),
          (item['minutes'] as num?)?.toInt(),
        );
      }
    }
    return result;
  }
}
