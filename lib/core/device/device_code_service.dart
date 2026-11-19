import 'package:dio/dio.dart';

import '../config/api_routes.dart';
import '../network/api_client.dart';
import '../network/api_responses.dart';

/// Código corto de este teléfono (p. ej. «K7M4-Q9XB») y si ya está vinculado a
/// una cuenta. Recursos Humanos lo busca en el panel para ver a quién está
/// vinculado el teléfono y desvincularlo.
class DeviceCodeInfo {
  final String code;
  final bool linked;

  const DeviceCodeInfo({required this.code, required this.linked});
}

/// Consulta el código del dispositivo al servidor. No requiere sesión.
class DeviceCodeService {
  final ApiClient _apiClient = ApiClient();

  Dio get _dio => _apiClient.dio;

  /// Null si no se pudo consultar (sin red, servidor caído): el código es una
  /// ayuda, nunca debe molestar ni bloquear la pantalla donde se muestra.
  Future<DeviceCodeInfo?> fetch() async {
    try {
      final response = await _dio.get(
        ApiRoutes.deviceCode,
        options: ApiResponses.acceptAnyStatus,
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map) return null;
      final code = data['code']?.toString() ?? '';
      if (code.isEmpty) return null;
      return DeviceCodeInfo(code: code, linked: data['linked'] == true);
    } catch (_) {
      return null;
    }
  }
}
