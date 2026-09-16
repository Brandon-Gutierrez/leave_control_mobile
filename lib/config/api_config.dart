import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// Cliente HTTP único de la app. Comparte el mismo [CookieJar] en todas las
/// pantallas para conservar la cookie de sesión de Laravel.
class ApiConfig {
  /// URL del backend. Se puede sobrescribir al compilar:
  /// flutter run -t lib/main_mobile.dart --dart-define=API_BASE_URL=https://mi-api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://duckie-carposporic-nickolas.ngrok-free.dev',
  );

  late final Dio dio;

  final cookieJar = CookieJar();

  static final ApiConfig _instance = ApiConfig._internal();

  factory ApiConfig() => _instance;

  ApiConfig._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    dio.interceptors.add(
      CookieManager(cookieJar),
    );
  }

  /// Elimina la cookie de sesión guardada.
  Future<void> clearSession() => cookieJar.deleteAll();
}
