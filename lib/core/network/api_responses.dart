import 'package:dio/dio.dart';

import 'api_exceptions.dart';

/// Interpreta las respuestas y los fallos del backend.
abstract final class ApiResponses {
  /// Acepta cualquier código de estado: el backend siempre devuelve un JSON
  /// con un mensaje entendible (incluso en 5xx), así que se procesa en vez de
  /// dejar que Dio lo convierta en una excepción genérica.
  static final Options acceptAnyStatus = Options(
    validateStatus: (status) => true,
  );

  /// Lanza [SessionExpiredException] si el backend respondió 401.
  static void throwIfUnauthorized(Response response) {
    if (response.statusCode == 401) {
      final data = response.data;
      final message = data is Map ? data['message'] as String? : null;
      throw message == null || message == 'Unauthenticated.'
          ? SessionExpiredException()
          : SessionExpiredException(message);
    }
  }

  /// Convierte un fallo de red (sin respuesta del servidor) en un mensaje
  /// claro según el motivo, en vez de uno genérico igual para todos los casos.
  static ApiRequestException networkError(DioException e) {
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'La conexión tardó demasiado. Verifica tu internet e intenta nuevamente.',
      DioExceptionType.connectionError =>
        'No hay conexión a internet. Verifica tu red e intenta nuevamente.',
      _ => 'No se pudo completar la solicitud. Intenta nuevamente.',
    };
    return ApiRequestException(message);
  }

  /// Extrae el mensaje que envía el backend en una respuesta de error, si lo
  /// trae; si no, usa [fallback].
  static ApiRequestException responseError(Response response, String fallback) {
    final data = response.data;
    final message = data is Map ? data['message'] as String? : null;
    final code = data is Map ? data['code'] as String? : null;
    return ApiRequestException(message ?? fallback, code: code);
  }
}
