import 'package:dio/dio.dart';

import 'location_service.dart';
import 'storage_service.dart';
import '../config/api_config.dart';
import '../config/api_routes.dart';

/// Se lanza cuando el backend responde 401 (sesión vencida o iniciada en otro
/// dispositivo).
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'Tu sesión expiró. Inicia sesión nuevamente.']);

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

class ApiService {
  final StorageService _storageService = StorageService();
  final LocationService _locationService;

  ApiService({LocationService? locationService})
    : _locationService = locationService ?? LocationService();
  final ApiConfig _apiConfig = ApiConfig();

  Dio get _dio => _apiConfig.dio;

  // Acepta cualquier código de estado: el backend siempre devuelve un JSON
  // con un mensaje entendible (incluso en 5xx), así que se procesa aquí en
  // vez de dejar que Dio lo convierta en una excepción genérica.
  static final Options _acceptAnyStatus = Options(
    validateStatus: (status) => true,
  );

  void _throwIfUnauthorized(Response response) {
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
  ApiRequestException _networkError(DioException e) {
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
  ApiRequestException _responseError(Response response, String fallback) {
    final data = response.data;
    final message = data is Map ? data['message'] as String? : null;
    final code = data is Map ? data['code'] as String? : null;
    return ApiRequestException(message ?? fallback, code: code);
  }

  //realiza la peticion, comprueba que el usuario existe y guarda los datos localmente
  //Devuelve null si inició sesión correctamente, o el mensaje a mostrar. Solo
  //un 401 del servidor significa usuario o contraseña incorrectos: cualquier
  //otra falla (servidor caído, túnel apagado, dispositivo no autorizado) se
  //informa con su propio mensaje.
  Future<String?> login(String username, String password) async {
    final Response response;
    try {
      // DeviceId y X-Client-Platform los agrega ApiConfig a cada petición.
      response = await _dio.post(
        ApiRoutes.login,
        data: {
          'username': username,
          'password': password,
        },
        options: _acceptAnyStatus,
      );
    } on DioException catch (e) {
      return _networkError(e).message;
    }

    final data = response.data;
    final serverMessage = data is Map ? data['message'] as String? : null;

    if (response.statusCode == 200 && data is Map && data['user'] is Map) {
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] as Map);
      await _storageService.saveData(
        (user['name'] ?? '').toString().trim(),
        (user['item'] ?? '').toString(),
        (user['external_identifier'] ?? '').toString(),
      );
      return null;
    }

    // Una respuesta sin JSON no viene del sistema (p. ej. el túnel está
    // apagado o apunta a otro servidor): no es un problema de credenciales.
    if (data is! Map) {
      return 'No se pudo conectar con el servidor. Intenta de nuevo en unos minutos.';
    }
    if (response.statusCode == 401) {
      return serverMessage ?? 'Usuario o contraseña incorrectos.';
    }
    return serverMessage ?? 'No se pudo iniciar sesión. Intenta de nuevo.';
  }

  //Comprueba si la sesión guardada sigue siendo válida en este dispositivo.
  //true: sesión válida. false: hay que iniciar sesión. Lanza
  //ApiRequestException si no se pudo comprobar (sin red, servidor caído).
  Future<bool> hasActiveSession() async {
    final Response response;
    try {
      response = await _dio.get(ApiRoutes.me, options: _acceptAnyStatus);
    } on DioException catch (e) {
      throw _networkError(e);
    }
    if (response.statusCode == 200 && response.data is Map) return true;
    if (response.statusCode == 401 || response.statusCode == 403) return false;
    throw _responseError(response, 'No se pudo comprobar tu sesión. Intenta de nuevo.');
  }

  //Cierra la sesion en el servidor y elimina los datos locales
  Future<void> logout() async {
    try {
      await _dio.post(ApiRoutes.logout, options: _acceptAnyStatus);
    } catch (_) {
      // Aunque falle la red, la sesión local se elimina igualmente
    }
    try {
      await _apiConfig.clearSession();
      await _storageService.deleteData();
    } catch (_) {
      // No debe impedir volver al login aunque falle el borrado local.
    }
  }

  //Obtiene los datos y el estado de salida del usuario autenticado
  //(el item se identifica por la sesión, no hace falta enviarlo)
  Future<Map<String, dynamic>?> checkData() async {
    final Response response;
    try {
      response = await _dio.get(ApiRoutes.leaveStatus, options: _acceptAnyStatus);
    } catch (e) {
      return null;
    }
    _throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> responseData = response.data;

    // Sincroniza el nombre/token guardados localmente si cambiaron. Esto es
    // solo caché local: si el almacenamiento seguro falla por cualquier
    // motivo, no debe impedir que se muestre el estado de salida del usuario.
    try {
      final String? token = responseData['token'];
      final String? name = responseData['name'];
      final String? localToken = await _storageService.getToken();
      final String? localName = await _storageService.getName();
      if (token != null && name != null && (token != localToken || name != localName)) {
        await _storageService.updateData(token, name);
      }
    } catch (e) {
      // Se ignora: la información principal (isLeave, dateLeave, reason)
      // ya está disponible en responseData.
    }

    return responseData;
  }

  //Envia el QR escaneado y devuelve la accion a realizar (mostrar motivos o retorno)
  //Lanza ApiRequestException con un mensaje claro si el servidor rechaza la
  //solicitud (QR vencido, sin cupo, etc.) o si falla la red.
  Future<Map<String, dynamic>> userStatus(String qrData) async {
    // Lanza LocationException si no hay una ubicación confiable.
    final location = await _locationService.capture();
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.qrScan,
        data: {'qrData': qrData, ...location.toJson()},
        options: _acceptAnyStatus,
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }
    _throwIfUnauthorized(response);
    if (response.data is! Map<String, dynamic>) {
      throw ApiRequestException('El servidor respondió de forma inesperada. Intenta nuevamente.');
    }
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode != 200 || data['status'] == 1) {
      throw _responseError(response, 'No se pudo procesar el código QR.');
    }
    return data;
  }

  //Obtiene las razones de salida de un predio especifico
  Future<List<String>?> getReasons(String namePremise) async {
    final Response response;
    try {
      response = await _dio.get(
        ApiRoutes.premiseReasons(namePremise),
        options: _acceptAnyStatus,
      );
    } catch (e) {
      return null;
    }
    _throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;
    return List<String>.from(response.data['reasons'] ?? []);
  }

  //Realiza la solicitud de salida del usuario. [leaveTicket] es el
  //comprobante que devuelve userStatus() al escanear (no el texto del QR).
  //Lanza ApiRequestException con el motivo exacto si falla (comprobante
  //vencido, límite de salidas alcanzado, error de red, etc.).
  Future<void> confirmLeave(String namePremise, String nameReason, String leaveTicket) async {
    final location = await _locationService.capture();
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.leaves,
        data: {
          'leaveTicket': leaveTicket,
          'namePremise': namePremise,
          'nameReason': nameReason,
          ...location.toJson(),
        },
        options: _acceptAnyStatus,
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }
    _throwIfUnauthorized(response);
    if (response.statusCode != 200) {
      throw _responseError(response, 'No se pudo registrar la salida. Intenta nuevamente.');
    }
  }
}
