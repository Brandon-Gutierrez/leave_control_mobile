import 'dart:io';

import 'package:control_input_output/core/network/api_client.dart';
import 'package:control_input_output/core/network/api_exceptions.dart';
import 'package:control_input_output/features/auth/data/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo y guarda la última petición enviada.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body, {this.contentType = 'application/json'});

  final int status;
  final String body;
  final String contentType;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService api;

  setUpAll(() {
    // En pruebas no hay plugin nativo: la cookie de sesión se guarda en temp.
    final dir = Directory.systemTemp.createTempSync('cookies_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = AuthService();
  });

  _FakeAdapter respond(int status, String body, {String contentType = 'application/json'}) {
    final adapter = _FakeAdapter(status, body, contentType: contentType);
    ApiClient().dio.httpClientAdapter = adapter;
    return adapter;
  }

  group('login', () {
    test('solo un 401 del servidor se muestra como credenciales incorrectas', () async {
      respond(401, '{"status":"ERROR","message":"Credenciales inválidas."}');

      expect(await api.login('juan', 'mala'), 'Credenciales inválidas.');
    });

    test('una respuesta que no es del sistema (túnel apagado) no culpa a las credenciales', () async {
      respond(404, 'The endpoint x.ngrok-free.dev is offline.', contentType: 'text/plain');

      final message = await api.login('juan', 'ok');

      expect(message, contains('No se pudo conectar con el servidor'));
      expect(message, isNot(contains('Credenciales')));
    });

    test('otro teléfono muestra el aviso de Recursos Humanos del servidor', () async {
      respond(403, '{"code":"DEVICE_NOT_AUTHORIZED","message":"Esta cuenta ya está vinculada a otro teléfono. Contacte a Recursos Humanos."}');

      expect(await api.login('juan', 'ok'), contains('Recursos Humanos'));
    });

    test('un error 5xx con mensaje del servidor se muestra tal cual', () async {
      respond(502, '{"message":"Un servicio necesario no está disponible temporalmente."}');

      expect(await api.login('juan', 'ok'), contains('no está disponible'));
    });

    test('login correcto envía la aplicación y un identificador estable del teléfono', () async {
      final adapter = respond(200, '{"user":{"name":"Juan","item":1,"external_identifier":"t"}}');

      expect(await api.login('juan', 'ok'), isNull);

      final headers = adapter.lastRequest!.headers;
      expect(headers['X-Client-Platform'], 'mobile');
      final deviceId = headers['DeviceId'] as String;
      expect(deviceId.length, greaterThanOrEqualTo(16));

      await api.login('juan', 'ok');
      expect(adapter.lastRequest!.headers['DeviceId'], deviceId);
    });
  });

  group('sesión guardada', () {
    test('200 en /auth/me es sesión válida', () async {
      respond(200, '{"user":{"name":"Juan"}}');
      expect(await api.hasActiveSession(), isTrue);
    });

    test('401 (sesión cerrada o dispositivo desvinculado) pide iniciar sesión', () async {
      respond(401, '{"code":"DEVICE_NOT_AUTHORIZED","message":"..."}');
      expect(await api.hasActiveSession(), isFalse);
    });

    test('un servidor caído no se confunde con una sesión inválida', () async {
      respond(503, 'Service Unavailable', contentType: 'text/plain');
      expect(api.hasActiveSession(), throwsA(isA<ApiRequestException>()));
    });
  });
}
