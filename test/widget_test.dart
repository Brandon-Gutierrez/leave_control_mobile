import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_input_output/screens/user/home_page.dart';
import 'package:control_input_output/screens/user/login_page.dart';
import 'package:control_input_output/screens/user/reasons_page.dart';
import 'package:control_input_output/services/api_service.dart';

/// Tamaños lógicos de teléfonos comunes (ancho x alto).
const _phoneSizes = <String, Size>{
  'iPhone SE (1ra gen)': Size(320, 568),
  'Android compacto': Size(360, 640),
  'iPhone 13 mini': Size(375, 812),
  'Pixel 7': Size(412, 915),
  'iPhone 15 Pro Max': Size(430, 932),
  'Horizontal': Size(800, 360),
};

/// [ApiService] de prueba: no toca la red ni el almacenamiento seguro,
/// así las pantallas se pueden probar de forma instantánea y determinista.
class _FakeApiService implements ApiService {
  Map<String, dynamic>? leaveStatusResponse;
  List<String>? reasonsResponse;

  _FakeApiService({this.leaveStatusResponse, this.reasonsResponse});

  @override
  Future<Map<String, dynamic>?> checkData() async => leaveStatusResponse;

  @override
  Future<List<String>?> getReasons(String namePremise) async => reasonsResponse;

  @override
  Future<void> confirmLeave(String namePremise, String nameReason, String qrData) async {}

  @override
  Future<String?> login(String username, String password) async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasActiveSession() async => true;

  @override
  Future<Map<String, dynamic>> userStatus(String qrData) async => {};
}

/// Deja que la Future falsa (instantánea) se resuelva y la UI se actualice.
/// No usa pumpAndSettle: HomePage puede dejar un Timer.periodic corriendo
/// (el contador de tiempo transcurrido), con el que pumpAndSettle nunca termina.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Desmonta el widget para que cualquier Timer.periodic pendiente se cancele
/// de forma segura en dispose().
Future<void> _tearDownTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  for (final entry in _phoneSizes.entries) {
    testWidgets('LoginPage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('HomePage sin salida activa no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeApiService(leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false});
      await tester.pumpWidget(MaterialApp(home: HomePage(apiService: api)));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Registrar mi salida'), findsOneWidget);

      await _tearDownTimers(tester);
    });

    testWidgets('HomePage con salida activa y motivo no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeApiService(leaveStatusResponse: {
        'name': 'Juan Pérez',
        'isLeave': true,
        'dateLeave': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'reason': 'Trámite bancario',
      });
      await tester.pumpWidget(MaterialApp(home: HomePage(apiService: api)));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Registrar mi retorno'), findsOneWidget);
      expect(find.textContaining('Trámite bancario'), findsOneWidget);
      expect(find.text('Tiempo transcurrido'), findsOneWidget);

      await _tearDownTimers(tester);
    });

    testWidgets('ReasonPage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeApiService(reasonsResponse: ['Trámite bancario', 'Cita médica']);
      await tester.pumpWidget(
        MaterialApp(
          home: ReasonPage(
            qrData: 'Predio Central+uuid',
            leaveTicket: 'ticket-uuid',
            apiService: api,
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Confirmar Selección'), findsOneWidget);
      expect(find.text('Trámite bancario'), findsOneWidget);

      await _tearDownTimers(tester);
    });
  }

  testWidgets('HomePage nunca muestra una pantalla en blanco mientras carga', (tester) async {
    // Nunca se resuelve hasta que el test lo decida: simula la espera de la red.
    final neverCompletes = Completer<Map<String, dynamic>?>();
    final slowApi = _SlowFakeApiService(neverCompletes.future);

    await tester.pumpWidget(MaterialApp(home: HomePage(apiService: slowApi)));
    // Un solo pump: se inspecciona el primer frame, antes de que la petición
    // (que nunca termina) pueda resolverse.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cargando tu información...'), findsOneWidget);

    neverCompletes.complete({'name': 'Juan Pérez', 'isLeave': false});
    await _settle(tester);
    await _tearDownTimers(tester);
  });

  testWidgets('HomePage muestra un mensaje claro y reintentar si falla la carga', (tester) async {
    final api = _FakeApiService(leaveStatusResponse: null); // fuerza el error simulado

    await tester.pumpWidget(MaterialApp(home: HomePage(apiService: api)));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo cargar tu información'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    // Al reintentar con datos disponibles, se debe mostrar el contenido normal.
    api.leaveStatusResponse = {'name': 'Juan Pérez', 'isLeave': false};
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Registrar mi salida'), findsOneWidget);

    await _tearDownTimers(tester);
  });
}

/// [ApiService] falso cuya respuesta se resuelve solo cuando el test lo pide
/// explícitamente, para poder inspeccionar el estado de carga intermedio.
class _SlowFakeApiService implements ApiService {
  final Future<Map<String, dynamic>?> _pending;
  _SlowFakeApiService(this._pending);

  @override
  Future<Map<String, dynamic>?> checkData() => _pending;

  @override
  Future<List<String>?> getReasons(String namePremise) async => null;

  @override
  Future<void> confirmLeave(String namePremise, String nameReason, String qrData) async {
    throw ApiRequestException('No se pudo registrar la salida. Intenta nuevamente.');
  }

  @override
  Future<String?> login(String username, String password) async => 'Credenciales incorrectas';

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasActiveSession() async => true;

  @override
  Future<Map<String, dynamic>> userStatus(String qrData) async {
    throw ApiRequestException('Código QR inválido o vencido.');
  }
}
