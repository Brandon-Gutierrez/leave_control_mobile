import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../storage/device_service.dart';

/// Cliente HTTP único de la app. Guarda la cookie de sesión de Laravel en
/// disco (no solo en memoria): si no se persiste, cada reinicio de la app
/// pierde la cookie y obliga a iniciar sesión de nuevo aunque el usuario no
/// haya cerrado sesión.
class ApiClient {
  late final Dio dio;

  /// Se resuelve cuando la cookie de sesión guardada en disco ya está
  /// cargada y lista para usarse. `main()` la espera antes de decidir la
  /// pantalla inicial, para no disparar la primera petición sin cookie.
  late final Future<void> ready;

  PersistCookieJar? _cookieJar;
  CookieManager? _cookieManager;
  final DeviceService _deviceService = DeviceService();

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          // El backend decide qué roles entran según la aplicación: en la
          // móvil, ADMIN y EMPLOYEE.
          'X-Client-Platform': 'mobile',
        },
      ),
    );

    // El backend exige el encabezado DeviceId en TODAS las peticiones (no
    // solo en el login): cada cuenta queda vinculada a un único teléfono.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['DeviceId'] = await _deviceService.getDeviceId();
          handler.next(options);
        },
      ),
    );

    // Las cookies se gestionan siempre, pero esperando a que el disco esté
    // leído: si la primera petición (el login) saliera antes, la cookie de
    // sesión no se guardaría y la primera pantalla fallaría con 401.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await ready;
          unawaited(_cookieManager!.onRequest(options, handler));
        },
        onResponse: (response, handler) async {
          await ready;
          unawaited(_cookieManager!.onResponse(response, handler));
        },
        onError: (error, handler) async {
          await ready;
          unawaited(_cookieManager!.onError(error, handler));
        },
      ),
    );

    ready = _initCookieJar();
  }

  Future<void> _initCookieJar() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${dir.path}/.cookies/'),
    );
    _cookieJar = cookieJar;
    _cookieManager = CookieManager(cookieJar);
  }

  /// Elimina la cookie de sesión guardada.
  Future<void> clearSession() async {
    await ready;
    await _cookieJar?.deleteAll();
  }
}
