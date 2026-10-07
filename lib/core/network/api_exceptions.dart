/// Se lanza cuando el backend responde 401 (sesión vencida o iniciada en otro
/// dispositivo).
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([
    this.message = 'Tu sesión expiró. Inicia sesión nuevamente.',
  ]);

  @override
  String toString() => message;
}

/// Error de una petición al backend: red caída, tiempo de espera agotado, o
/// una respuesta de error con un mensaje ya pensado para mostrarse (p. ej.
/// "Este QR venció..."). Sirve para no mostrar mensajes genéricos que
/// confunden distintos motivos de falla bajo un mismo texto.
class ApiRequestException implements Exception {
  final String message;

  /// Código del backend (p. ej. QR_EXPIRED_OR_INVALID, LEAVE_TICKET_EXPIRED)
  /// cuando la respuesta lo trae. Null si fue un error de red.
  final String? code;

  ApiRequestException(this.message, {this.code});

  @override
  String toString() => message;
}
