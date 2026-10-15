import 'dart:async';

import 'package:control_input_output/core/network/api_exceptions.dart';
import 'package:control_input_output/features/auth/presentation/login_page.dart';
import 'package:control_input_output/features/leave/data/leave_service.dart';
import 'package:control_input_output/features/leave/models/leave_status.dart';
import 'package:control_input_output/features/leave/models/qr_scan_result.dart';
import 'package:control_input_output/features/leave/presentation/date_range_sheet.dart';
import 'package:control_input_output/features/leave/presentation/home_page.dart';
import 'package:control_input_output/features/leave/presentation/reasons_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tamaños lógicos de teléfonos comunes (ancho x alto).
const _phoneSizes = <String, Size>{
  'iPhone SE (1ra gen)': Size(320, 568),
  'Android compacto': Size(360, 640),
  'iPhone 13 mini': Size(375, 812),
  'Pixel 7': Size(412, 915),
  'iPhone 15 Pro Max': Size(430, 932),
  'Horizontal': Size(800, 360),
};

/// [LeaveService] de prueba: no toca la red ni el almacenamiento seguro,
/// así las pantallas se pueden probar de forma instantánea y determinista.
class _FakeLeaveService implements LeaveService {
  Map<String, dynamic>? leaveStatusResponse;
  List<String>? reasonsResponse;

  _FakeLeaveService({this.leaveStatusResponse, this.reasonsResponse});

  @override
  Future<LeaveStatus?> fetchLeaveStatus() async => leaveStatusResponse == null
      ? null
      : LeaveStatus.fromJson(leaveStatusResponse!);

  /// Último rango consultado y resultado que devuelve el fake.
  DateTimeRange? requestedRange;
  LeaveStat? rangeResponse = const LeaveStat(3, 45);

  @override
  Future<LeaveStat?> fetchRangeStats(DateTime from, DateTime to) async {
    requestedRange = DateTimeRange(start: from, end: to);
    return rangeResponse;
  }

  @override
  Future<List<String>?> getReasons(String namePremise) async => reasonsResponse;

  @override
  Future<void> confirmLeave(
    String namePremise,
    String nameReason,
    String qrData,
  ) async {}

  @override
  Future<QrScanResult> scanQr(String qrData) async => const QrScanResult(
    message: '',
    action: null,
    leaveTicket: null,
    leaveTicketExpiresAt: null,
  );
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

    testWidgets('HomePage sin salida activa no desborda en ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeLeaveService(
        leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false},
      );
      await tester.pumpWidget(MaterialApp(home: HomePage(leaveService: api)));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Registrar mi salida'), findsOneWidget);

      await _tearDownTimers(tester);
    });

    testWidgets(
      'HomePage con salida activa y motivo no desborda en ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final api = _FakeLeaveService(
          leaveStatusResponse: {
            'name': 'Juan Pérez',
            'isLeave': true,
            'dateLeave': DateTime.now()
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
            'reason': 'Trámite bancario',
          },
        );
        await tester.pumpWidget(MaterialApp(home: HomePage(leaveService: api)));
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Registrar mi retorno'), findsOneWidget);
        expect(find.textContaining('Trámite bancario'), findsOneWidget);
        expect(find.text('Tiempo transcurrido'), findsOneWidget);

        await _tearDownTimers(tester);
      },
    );

    testWidgets('ReasonsPage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeLeaveService(
        reasonsResponse: ['Trámite bancario', 'Cita médica'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReasonsPage(
            qrData: 'Predio Central+uuid',
            leaveTicket: 'ticket-uuid',
            leaveService: api,
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

  testWidgets('HomePage nunca muestra una pantalla en blanco mientras carga', (
    tester,
  ) async {
    // Nunca se resuelve hasta que el test lo decida: simula la espera de la red.
    final neverCompletes = Completer<LeaveStatus?>();
    final slowApi = _SlowFakeLeaveService(neverCompletes.future);

    await tester.pumpWidget(MaterialApp(home: HomePage(leaveService: slowApi)));
    // Un solo pump: se inspecciona el primer frame, antes de que la petición
    // (que nunca termina) pueda resolverse.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cargando tu información...'), findsOneWidget);

    neverCompletes.complete(
      LeaveStatus.fromJson({'name': 'Juan Pérez', 'isLeave': false}),
    );
    await _settle(tester);
    await _tearDownTimers(tester);
  });

  testWidgets('HomePage filtra tus salidas por un rango del calendario', (
    tester,
  ) async {
    final api = _FakeLeaveService(
      leaveStatusResponse: {
        'name': 'Juan Pérez',
        'isLeave': false,
        'stats': {
          'day': {'exits': 1, 'minutes': 10},
        },
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomePage(leaveService: api),
      ),
    );
    await _settle(tester);
    // Por defecto muestra hoy, con los contadores del día.
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('Día siguiente'), findsNothing);

    await tester.tap(find.byTooltip('Elegir fecha'));
    await tester.pumpAndSettle();
    expect(find.text('Elige una fecha'), findsOneWidget);

    // Un solo día: se toca dos veces el mismo día y se aplica.
    final firstOfMonth = find.descendant(
      of: find.byType(DateRangeSheet),
      matching: find.text('1'),
    );
    await tester.tap(firstOfMonth.first);
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await _settle(tester);

    if (DateTime.now().day != 1) {
      expect(api.requestedRange, isNotNull);
      expect(api.requestedRange!.start, api.requestedRange!.end);
      expect(find.text('45 min'), findsOneWidget); // tiempo del día elegido
      expect(find.text('Hoy'), findsNothing);
    }

    await tester.tap(find.text('Volver a hoy'));
    await tester.pump();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);

    await _tearDownTimers(tester);
  });

  testWidgets('HomePage navega día a día con las flechas', (tester) async {
    final api = _FakeLeaveService(
      leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false},
    );
    await tester.pumpWidget(MaterialApp(home: HomePage(leaveService: api)));
    await _settle(tester);

    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // salidas del fake

    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pump();
    expect(find.text('Hoy'), findsOneWidget);

    await _tearDownTimers(tester);
  });

  testWidgets(
    'HomePage muestra un mensaje claro y reintentar si falla la carga',
    (tester) async {
      final api = _FakeLeaveService(
        leaveStatusResponse: null,
      ); // fuerza el error simulado

      await tester.pumpWidget(MaterialApp(home: HomePage(leaveService: api)));
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
    },
  );
}

/// [LeaveService] falso cuya respuesta se resuelve solo cuando el test lo pide
/// explícitamente, para poder inspeccionar el estado de carga intermedio.
class _SlowFakeLeaveService implements LeaveService {
  final Future<LeaveStatus?> _pending;
  _SlowFakeLeaveService(this._pending);

  @override
  Future<LeaveStatus?> fetchLeaveStatus() => _pending;

  @override
  Future<LeaveStat?> fetchRangeStats(DateTime from, DateTime to) async => null;

  @override
  Future<List<String>?> getReasons(String namePremise) async => null;

  @override
  Future<void> confirmLeave(
    String namePremise,
    String nameReason,
    String qrData,
  ) async {
    throw ApiRequestException(
      'No se pudo registrar la salida. Intenta nuevamente.',
    );
  }

  @override
  Future<QrScanResult> scanQr(String qrData) async {
    throw ApiRequestException('Código QR inválido o vencido.');
  }
}
