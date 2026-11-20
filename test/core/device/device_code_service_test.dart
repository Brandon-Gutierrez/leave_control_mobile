import 'dart:convert';
import 'dart:io';

import 'package:control_input_output/core/device/device_code_service.dart';
import 'package:control_input_output/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // En pruebas no hay plugin nativo: la cookie de sesión se guarda en temp.
    final dir = Directory.systemTemp.createTempSync('cookies_device_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  void respond(int status, Object body) {
    ApiClient().dio.httpClientAdapter = _FakeAdapter(status, body);
  }

  test(
    'lee el código, si está vinculado y desde cuándo (hora local)',
    () async {
      respond(200, {
        'status': 0,
        'code': 'K7M4-Q9XB',
        'linked': true,
        'linked_at': '2026-11-18T08:15:00-04:00',
      });

      final info = await DeviceCodeService().fetch();

      expect(info!.code, 'K7M4-Q9XB');
      expect(info.linked, isTrue);
      expect(info.linkedAt!.toUtc(), DateTime.utc(2026, 11, 18, 12, 15));
    },
  );

  test('un teléfono sin vincular no trae fecha', () async {
    respond(200, {
      'status': 0,
      'code': 'K7M4-Q9XB',
      'linked': false,
      'linked_at': null,
    });

    final info = await DeviceCodeService().fetch();

    expect(info!.linked, isFalse);
    expect(info.linkedAt, isNull);
  });

  test('un servidor antiguo sin linked_at sigue funcionando', () async {
    respond(200, {'status': 0, 'code': 'K7M4-Q9XB', 'linked': true});

    final info = await DeviceCodeService().fetch();

    expect(info!.linked, isTrue);
    expect(info.linkedAt, isNull);
  });

  test('si el servidor falla o responde algo raro devuelve null', () async {
    respond(500, {'message': 'Error'});
    expect(await DeviceCodeService().fetch(), isNull);

    respond(200, {'status': 0, 'code': ''});
    expect(await DeviceCodeService().fetch(), isNull);

    respond(200, '"texto"');
    expect(await DeviceCodeService().fetch(), isNull);
  });
}
