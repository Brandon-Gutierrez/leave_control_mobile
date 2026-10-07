import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_responses.dart';
import '../../../core/storage/storage_service.dart';

/// Inicio y cierre de sesión, y comprobación de la sesión guardada.
class AuthService {
  final StorageService _storageService = StorageService();
  final ApiClient _apiClient = ApiClient();

  Dio get _dio => _apiClient.dio;

  //realiza la peticion, comprueba que el usuario existe y guarda los datos localmente
  //Devuelve null si inició sesión correctamente, o el mensaje a mostrar. Solo
  //un 401 del servidor significa usuario o contraseña incorrectos: cualquier
  //otra falla (servidor caído, túnel apagado, dispositivo no autorizado) se
  //informa con su propio mensaje.
  Future<String?> login(String username, String password) async {
    final Response response;
    try {
      // DeviceId y X-Client-Platform los agrega ApiClient a cada petición.
      response = await _dio.post(
        ApiRoutes.login,
        data: {'username': username, 'password': password},
        options: ApiResponses.acceptAnyStatus,
      );
    } on DioException catch (e) {
      return ApiResponses.networkError(e).message;
    }

    final data = response.data;
    final serverMessage = data is Map ? data['message'] as String? : null;

    if (response.statusCode == 200 && data is Map && data['user'] is Map) {
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        data['user'] as Map,
      );
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
      response = await _dio.get(
        ApiRoutes.me,
        options: ApiResponses.acceptAnyStatus,
      );
    } on DioException catch (e) {
      throw ApiResponses.networkError(e);
    }
    if (response.statusCode == 200 && response.data is Map) return true;
    if (response.statusCode == 401 || response.statusCode == 403) return false;
    throw ApiResponses.responseError(
      response,
      'No se pudo comprobar tu sesión. Intenta de nuevo.',
    );
  }

  //Cierra la sesion en el servidor y elimina los datos locales
  Future<void> logout() async {
    try {
      await _dio.post(ApiRoutes.logout, options: ApiResponses.acceptAnyStatus);
    } catch (_) {
      // Aunque falle la red, la sesión local se elimina igualmente
    }
    try {
      await _apiClient.clearSession();
      await _storageService.deleteData();
    } catch (_) {
      // No debe impedir volver al login aunque falle el borrado local.
    }
  }
}
