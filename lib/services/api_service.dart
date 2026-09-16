import 'package:dio/dio.dart';

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

class ApiService {
  final StorageService _storageService = StorageService();
  final ApiConfig _apiConfig = ApiConfig();

  Dio get _dio => _apiConfig.dio;

  // Acepta respuestas 4xx para poder leer el mensaje del backend
  static final Options _acceptClientErrors = Options(
    validateStatus: (status) => status != null && status < 500,
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

  //realiza la peticion, comprueba que el usuario existe y guarda los datos localmente
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiRoutes.login,
        data: {
          'username': username,
          'password': password,
        },
      );
      final Map<String, dynamic> user = response.data['user'];
      await _storageService.saveData(
        (user['name'] ?? '').toString().trim(),
        (user['item'] ?? '').toString(),
        (user['external_identifier'] ?? '').toString(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  //Cierra la sesion en el servidor y elimina los datos locales
  Future<void> logout() async {
    try {
      await _dio.post(ApiRoutes.logout, options: _acceptClientErrors);
    } catch (_) {
      // Aunque falle la red, la sesión local se elimina igualmente
    }
    await _apiConfig.clearSession();
    await _storageService.deleteData();
  }

  //Obtiene los datos y el estado de salida del usuario autenticado
  Future<Map<String, dynamic>?> checkData() async {
    final Response response;
    try {
      response = await _dio.get(ApiRoutes.leaveStatus, options: _acceptClientErrors);
    } catch (e) {
      return null;
    }
    _throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> responseData = response.data;
    final String? token = responseData['token'];
    final String? name = responseData['name'];
    final String? localToken = await _storageService.getToken();
    final String? localName = await _storageService.getName();

    //Si los datos cambiaron, los actualiza
    if (token != null && name != null && (token != localToken || name != localName)) {
      await _storageService.updateData(token, name);
    }
    return responseData;
  }

  //Envia el QR escaneado y devuelve la accion a realizar (mostrar motivos o retorno)
  Future<Map<String, dynamic>?> userStatus(String qrData) async {
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.qrScan,
        data: {'qrData': qrData},
        options: _acceptClientErrors,
      );
    } catch (e) {
      return null;
    }
    _throwIfUnauthorized(response);
    return response.data is Map<String, dynamic> ? response.data : null;
  }

  //Obtiene las razones de salida de un predio especifico
  Future<List<String>?> getReasons(String namePremise) async {
    final Response response;
    try {
      response = await _dio.get(
        ApiRoutes.premiseReasons(namePremise),
        options: _acceptClientErrors,
      );
    } catch (e) {
      return null;
    }
    _throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;
    return List<String>.from(response.data['reasons'] ?? []);
  }

  //Realiza la solicitud de salida del usuario
  Future<bool> confirmLeave(String namePremise, String nameReason, String qrData) async {
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.leaves,
        data: {
          'qrData': qrData,
          'namePremise': namePremise,
          'nameReason': nameReason,
        },
        options: _acceptClientErrors,
      );
    } catch (e) {
      return false;
    }
    _throwIfUnauthorized(response);
    return response.statusCode == 200;
  }
}
