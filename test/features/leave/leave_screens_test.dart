import 'dart:async';

import 'package:control_input_output/core/device/device_code_service.dart';
import 'package:control_input_output/core/network/api_exceptions.dart';
import 'package:control_input_output/features/auth/models/account_info.dart';
import 'package:control_input_output/features/auth/presentation/login_page.dart';
import 'package:control_input_output/features/leave/data/leave_service.dart';
import 'package:control_input_output/features/leave/models/leave_reason.dart';
import 'package:control_input_output/features/leave/models/leave_status.dart';
import 'package:control_input_output/features/leave/models/qr_scan_result.dart';
import 'package:control_input_output/features/leave/presentation/date_range_sheet.dart';
import 'package:control_input_output/features/leave/presentation/home_page.dart';
import 'package:control_input_output/features/leave/presentation/reasons_page.dart';
import 'package:control_input_output/features/leave/presentation/scan_page.dart';
import 'package:control_input_output/features/leave/presentation/widgets/trip_card.dart';
import 'package:control_input_output/features/leave/presentation/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sin consulta real del código de dispositivo (no hay red en las pruebas).
Future<DeviceCodeInfo?> _noDeviceCode() async => null;

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
  List<LeaveReasonOption>? reasonsResponse;

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

  /// Detalle de salidas que devuelve el fake (por defecto, ninguna).
  List<LeaveDetail>? detailsResponse = const [];

  @override
  Future<List<LeaveDetail>?> fetchLeaveDetails(
    DateTime from,
    DateTime to,
  ) async => detailsResponse;

  @override
  Future<List<LeaveReasonOption>?> getReasons(String namePremise) async =>
      reasonsResponse;

  /// Motivo con el que se pidió registrar la salida, y error a simular.
  String? confirmedReason;
  ApiRequestException? confirmError;

  @override
  Future<void> confirmLeave(
    String namePremise,
    String nameReason,
    String qrData,
  ) async {
    confirmedReason = nameReason;
    if (confirmError != null) throw confirmError!;
  }

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

      await tester.pumpWidget(
        MaterialApp(home: LoginPage(deviceCodeLoader: _noDeviceCode)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Salidas Temporales'), findsOneWidget);
      expect(find.text('Registra tus salidas y retornos'), findsOneWidget);
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
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(leaveService: api, deviceCodeLoader: _noDeviceCode),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Hola, Juan Pérez'), findsOneWidget);
      expect(find.text('Estás dentro'), findsOneWidget);
      expect(find.text('Registrar salida'), findsOneWidget);
      expect(find.text('Dispositivo'), findsOneWidget);

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
        await tester.pumpWidget(
          MaterialApp(
            home: HomePage(leaveService: api, deviceCodeLoader: _noDeviceCode),
          ),
        );
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Registrar retorno'), findsOneWidget);
        expect(find.text('Estás fuera'), findsOneWidget);
        expect(find.textContaining('Trámite bancario'), findsOneWidget);
        expect(find.text('transcurrido'), findsOneWidget);

        await _tearDownTimers(tester);
      },
    );

    testWidgets('ReasonsPage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeLeaveService(
        reasonsResponse: const [
          LeaveReasonOption('Trámite bancario'),
          LeaveReasonOption('Cita médica'),
        ],
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
      expect(find.text('Trámite bancario'), findsOneWidget);
      expect(find.text('Cita médica'), findsOneWidget);
      // Ya no hay botón de confirmar: tocar el motivo registra la salida.
      expect(find.text('Confirmar Selección'), findsNothing);

      await _tearDownTimers(tester);
    });
  }

  testWidgets('ReasonsPage: tocar un motivo registra la salida directamente', (
    tester,
  ) async {
    final api =
        _FakeLeaveService(
            reasonsResponse: const [
              LeaveReasonOption('Trámite bancario'),
              LeaveReasonOption('Cita médica'),
            ],
          )
          ..confirmError = ApiRequestException(
            'Sin conexión',
          ); // se queda en la pantalla
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

    await tester.tap(find.text('Cita médica'));
    await tester.pump();
    await tester.pump();

    expect(api.confirmedReason, 'Cita médica');
    // Si falla, se puede volver a tocar un motivo.
    expect(find.text('Cita médica'), findsOneWidget);

    await _tearDownTimers(tester);
  });

  testWidgets('ReasonsPage no deja elegir un motivo que llegó a su límite', (
    tester,
  ) async {
    final api = _FakeLeaveService(
      reasonsResponse: LeaveReasonOption.listFromJson({
        'reasons': ['Almuerzo', 'Cita médica'],
        'blocked_reasons': [
          {'name': 'Almuerzo', 'limit': 1, 'used': 1, 'period': 'day'},
        ],
      }),
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

    expect(find.text('Límite alcanzado: 1 vez por día'), findsOneWidget);

    // Tocar el motivo agotado no registra nada; el otro sí.
    api.confirmError = ApiRequestException('Sin conexión');
    await tester.tap(find.text('Almuerzo'));
    await tester.pump();
    await tester.pump();
    expect(api.confirmedReason, isNull);

    await tester.tap(find.text('Cita médica'));
    await tester.pump();
    await tester.pump();
    expect(api.confirmedReason, 'Cita médica');

    await _tearDownTimers(tester);
  });

  test('LeaveReasonOption lee los motivos y los límites por período', () {
    final options = LeaveReasonOption.listFromJson({
      'reasons': ['A', 'B', 'C'],
      'blocked_reasons': [
        {'name': 'B', 'limit': 2, 'used': 2, 'period': 'week'},
        {'name': 'C', 'limit': 1, 'used': 1, 'period': 'month'},
      ],
    });

    expect(options.map((o) => o.name), ['A', 'B', 'C']);
    expect(options[0].isBlocked, isFalse);
    expect(options[1].blockedNote, 'Límite alcanzado: 2 veces por semana');
    expect(options[2].blockedNote, 'Límite alcanzado: 1 vez por mes');
    // Respuesta antigua sin límites: todo disponible.
    expect(
      LeaveReasonOption.listFromJson({
        'reasons': ['A'],
      }).single.isBlocked,
      isFalse,
    );
  });

  testWidgets('HomePage nunca muestra una pantalla en blanco mientras carga', (
    tester,
  ) async {
    // Nunca se resuelve hasta que el test lo decida: simula la espera de la red.
    final neverCompletes = Completer<LeaveStatus?>();
    final slowApi = _SlowFakeLeaveService(neverCompletes.future);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(leaveService: slowApi, deviceCodeLoader: _noDeviceCode),
      ),
    );
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

  // Jueves 19/11/2026, 12:00: con un reloj fijo los días de la semana y los
  // textos «Hoy» / «Ayer» no dependen del día en que se corran las pruebas.
  DateTime fixedNow() => DateTime(2026, 11, 19, 12);

  Future<void> pumpHome(
    WidgetTester tester,
    LeaveService api, {
    Future<DeviceCodeInfo?> Function()? deviceCodeLoader,
    Future<AccountInfo?> Function()? accountLoader,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomePage(
          leaveService: api,
          deviceCodeLoader: deviceCodeLoader ?? _noDeviceCode,
          accountLoader: accountLoader ?? (() async => null),
          clock: fixedNow,
        ),
      ),
    );
    await _settle(tester);
    await tester.pump();
  }

  void phone(WidgetTester tester, [String name = 'iPhone 13 mini']) {
    tester.view.physicalSize = _phoneSizes[name]!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('HomePage muestra cada salida con sus horas y su duración', (
    tester,
  ) async {
    phone(tester);
    final api =
        _FakeLeaveService(
            leaveStatusResponse: {
              'name': 'Juan Pérez',
              'isLeave': false,
              'stats': {
                'day': {'exits': 2, 'minutes': 75},
              },
            },
          )
          ..detailsResponse = [
            LeaveDetail(
              leftAt: DateTime(2026, 11, 19, 11, 30),
              returnedAt: DateTime(2026, 11, 19, 12, 15),
              premise: 'Central',
              reason: 'Trámite bancario',
              minutes: 45,
            ),
            LeaveDetail(
              leftAt: DateTime(2026, 11, 19, 8, 10),
              returnedAt: DateTime(2026, 11, 19, 8, 40),
              premise: 'Prado',
              reason: 'Cita médica',
              minutes: 30,
            ),
          ];
    await pumpHome(tester, api);

    expect(find.text('Detalle de tus salidas'), findsOneWidget);
    expect(
      find.text('Hoy saliste 2 veces · 1 h 15 min fuera en total'),
      findsOneWidget,
    );
    // Salida completa: predio, motivo, de qué hora a qué hora y duración.
    expect(find.text('Central'), findsOneWidget);
    expect(find.text('Motivo: Trámite bancario'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
    expect(find.text('12:15'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Completada'), findsNWidgets(2));
    expect(find.text('Prado'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    // Hoy no hay estado de salida ni último retorno inventado.
    expect(find.text('Último retorno a las 12:15'), findsOneWidget);

    await _tearDownTimers(tester);
  });

  testWidgets('HomePage: una salida sin retorno de hoy pide escanear el QR', (
    tester,
  ) async {
    phone(tester);
    final api =
        _FakeLeaveService(
            leaveStatusResponse: {
              'name': 'Juan Pérez',
              'isLeave': true,
              'dateLeave': DateTime(2026, 11, 19, 10, 30).toIso8601String(),
              'reason': 'Trámite bancario',
              'stats': {
                'day': {'exits': 1, 'minutes': 90},
              },
            },
          )
          ..detailsResponse = [
            LeaveDetail(
              leftAt: DateTime(2026, 11, 19, 10, 30),
              premise: 'Prado',
              reason: 'Trámite bancario',
            ),
          ];
    await pumpHome(tester, api);

    // Tarjeta de estado: desde cuándo, de qué predio y por qué motivo.
    expect(find.text('Estás fuera'), findsOneWidget);
    expect(find.text('Desde las 10:30 · Prado'), findsOneWidget);
    expect(find.text('01:30:00'), findsOneWidget);
    expect(
      find.text('Hoy saliste 1 vez · 1 h 30 min fuera hasta ahora'),
      findsOneWidget,
    );
    // Tarjeta de la salida: sigue fuera y qué hacer.
    expect(find.text('Sigue fuera'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(
      find.text('Escanea el QR del predio para registrar tu retorno.'),
      findsOneWidget,
    );

    await _tearDownTimers(tester);
  });

  testWidgets('HomePage dentro sin salidas avisa cómo registrar la próxima', (
    tester,
  ) async {
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {
        'name': 'Juan Pérez',
        'isLeave': false,
        'stats': {
          'day': {'exits': 0, 'minutes': 0},
        },
      },
    );
    await pumpHome(tester, api);

    expect(find.text('Estás dentro'), findsOneWidget);
    expect(
      find.text('Cuando salgas, escanea el QR del predio.'),
      findsOneWidget,
    );
    expect(find.text('Hoy aún no has salido'), findsOneWidget);
    expect(find.byType(TripCard), findsNothing);

    await _tearDownTimers(tester);
  });

  testWidgets('HomePage filtra tus salidas por un rango del calendario', (
    tester,
  ) async {
    // El calendario es una hoja inferior alta: en la superficie por defecto
    // (800x600) el botón "Aplicar" queda fuera de la pantalla.
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {
        'name': 'Juan Pérez',
        'isLeave': false,
        'stats': {
          'day': {'exits': 1, 'minutes': 10},
        },
      },
    );
    await pumpHome(tester, api);
    // Por defecto muestra hoy, con los contadores del día.
    expect(find.text('Jueves 19 de noviembre'), findsOneWidget);
    expect(
      find.text('Hoy saliste 1 vez · 10 min fuera en total'),
      findsOneWidget,
    );
    expect(find.text('Volver a hoy'), findsNothing);

    await tester.tap(find.byTooltip('Elegir fecha'));
    await tester.pumpAndSettle();
    expect(find.text('Elige una fecha'), findsOneWidget);

    // Un solo día: se toca el día 1 y se aplica.
    final firstOfMonth = find.descendant(
      of: find.byType(DateRangeSheet),
      matching: find.text('1'),
    );
    await tester.tap(firstOfMonth.first);
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(api.requestedRange, isNotNull);
    expect(api.requestedRange!.start, DateTime(2026, 11, 1));
    expect(api.requestedRange!.end, DateTime(2026, 11, 1));
    expect(find.text('Domingo 1 de noviembre'), findsOneWidget);
    expect(
      find.text('El 01/11/2026 saliste 3 veces · 45 min fuera en total'),
      findsOneWidget,
    );

    await tester.tap(find.text('Volver a hoy'));
    await tester.pump();
    expect(find.text('Jueves 19 de noviembre'), findsOneWidget);
    expect(
      find.text('Hoy saliste 1 vez · 10 min fuera en total'),
      findsOneWidget,
    );

    await _tearDownTimers(tester);
  });

  testWidgets('La tira de la semana elige un día y no deja elegir el futuro', (
    tester,
  ) async {
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false},
    );
    await pumpHome(tester, api);

    // Lunes a domingo de la semana de hoy (jueves 19).
    for (final day in [16, 17, 18, 19, 20, 21, 22]) {
      expect(
        find.byKey(WeekStrip.dayKey(DateTime(2026, 11, day))),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 18))));
    await tester.pump();
    await tester.pump();
    expect(api.requestedRange!.start, DateTime(2026, 11, 18));
    expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);
    expect(
      find.text('Ayer saliste 3 veces · 45 min fuera en total'),
      findsOneWidget,
    );

    // Un día futuro no se puede elegir.
    api.requestedRange = null;
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 20))));
    await tester.pump();
    expect(api.requestedRange, isNull);
    expect(find.text('Miércoles 18 de noviembre'), findsOneWidget);

    // Tocar hoy vuelve a la vista de hoy.
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 19))));
    await tester.pump();
    expect(find.text('Volver a hoy'), findsNothing);
    expect(find.text('Jueves 19 de noviembre'), findsOneWidget);

    await _tearDownTimers(tester);
  });

  testWidgets('Una salida sin retorno de otro día se marca «Sin retorno»', (
    tester,
  ) async {
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false},
    );
    await pumpHome(tester, api);

    api.detailsResponse = [
      LeaveDetail(
        leftAt: DateTime(2026, 11, 18, 15, 0),
        premise: 'Prado',
        reason: 'Cita médica',
      ),
    ];
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 18))));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Sin retorno'), findsOneWidget);
    expect(find.text('Sigue fuera'), findsNothing);
    expect(
      find.textContaining('No se incluye en tus contadores'),
      findsOneWidget,
    );

    await _tearDownTimers(tester);
  });

  testWidgets('Las salidas sin retorno siguen el rango elegido', (
    tester,
  ) async {
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {
        'name': 'Juan Pérez',
        'isLeave': false,
        // Aunque el servidor enviara salidas viejas, hoy no se advierte nada.
        'unreturned_leaves': [
          {'date': '2026-09-10T09:00:00', 'reason': 'Trámite bancario'},
        ],
      },
    )..detailsResponse = null; // sin detalle: se usan los avisos del rango
    await pumpHome(tester, api);

    // Vista de hoy: sin advertencias de otras fechas.
    expect(find.text('Salida sin retorno'), findsNothing);
    expect(find.textContaining('Trámite bancario'), findsNothing);

    // Un rango sin salidas sin retorno: no se muestra ninguna advertencia.
    api.rangeResponse = const LeaveStat(2, 30);
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 17))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Salida sin retorno'), findsNothing);

    // Un rango que sí incluye una: aparece solo esa.
    api.rangeResponse = LeaveStat(1, 20, [
      UnreturnedLeave(DateTime(2026, 11, 18, 8, 30), 'Cita médica'),
    ]);
    await tester.tap(find.byKey(WeekStrip.dayKey(DateTime(2026, 11, 18))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Salida sin retorno'), findsOneWidget);
    expect(find.textContaining('Cita médica'), findsOneWidget);
    expect(find.textContaining('Trámite bancario'), findsNothing);

    await _tearDownTimers(tester);
  });

  for (final entry in _phoneSizes.entries) {
    testWidgets('HomePage con textos largos y varias salidas no desborda en '
        '${entry.key}', (tester) async {
      phone(tester, entry.key);
      final api =
          _FakeLeaveService(
              leaveStatusResponse: {
                'name': 'María Fernanda Rodríguez de la Quintana',
                'role': 'EMPLOYEE',
                'job_title': 'Técnico de Redes y Telecomunicaciones',
                'isLeave': true,
                'dateLeave': DateTime(2026, 11, 18, 22, 5).toIso8601String(),
                'reason': 'Reunión externa con proveedores del servicio',
                'stats': {
                  'day': {'exits': 3, 'minutes': 205},
                },
              },
            )
            ..detailsResponse = [
              LeaveDetail(
                leftAt: DateTime(2026, 11, 19, 10, 30),
                premise: 'Predio Central Norte del Departamento de La Paz',
                reason: 'Reunión externa con proveedores del servicio',
              ),
              LeaveDetail(
                leftAt: DateTime(2026, 11, 19, 8, 5),
                returnedAt: DateTime(2026, 11, 19, 9, 30),
                premise: 'Prado',
                reason: 'Cita médica',
                minutes: 85,
              ),
              LeaveDetail(
                leftAt: DateTime(2026, 11, 18, 23, 50),
                returnedAt: DateTime(2026, 11, 19, 0, 20),
                premise: 'Central',
                reason: 'Trámite bancario',
                minutes: 30,
              ),
            ];
      await pumpHome(tester, api);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(TripCard), findsNWidgets(3));

      await _tearDownTimers(tester);
    });
  }

  testWidgets('La barra inferior cambia a Dispositivo y vuelve a Inicio', (
    tester,
  ) async {
    phone(tester);
    final api = _FakeLeaveService(
      leaveStatusResponse: {'name': 'Juan Pérez', 'isLeave': false},
    );
    await pumpHome(
      tester,
      api,
      deviceCodeLoader: () async => DeviceCodeInfo(
        code: 'K7M4-Q9XB',
        linked: true,
        linkedAt: DateTime(2026, 11, 18, 8, 15),
      ),
      accountLoader: () async =>
          const AccountInfo(name: 'Juan Pérez', item: '2057'),
    );

    // El código del teléfono ya no aparece en Inicio.
    expect(find.text('Mi dispositivo'), findsNothing);
    expect(find.text('K7M4-Q9XB'), findsNothing);

    await tester.tap(find.text('Dispositivo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Mi dispositivo'), findsOneWidget);
    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Vinculado a tu cuenta'), findsOneWidget);
    expect(find.text('Juan Pérez · Item 2057'), findsOneWidget);
    expect(find.text('Vinculado el 18/11/2026 a las 08:15'), findsOneWidget);
    expect(find.text('Hola, Juan Pérez'), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pump();
    expect(find.text('Hola, Juan Pérez'), findsOneWidget);
    expect(find.text('Mi dispositivo'), findsNothing);

    await _tearDownTimers(tester);
  });

  testWidgets('El login ofrece ver el código del teléfono en una hoja', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          deviceCodeLoader: () async =>
              const DeviceCodeInfo(code: 'K7M4-Q9XB', linked: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El código no está a la vista hasta que se pide.
    expect(find.text('K7M4-Q9XB'), findsNothing);
    await tester.tap(find.textContaining('¿No puedes ingresar?'));
    await tester.pumpAndSettle();

    expect(find.text('Código de este teléfono'), findsOneWidget);
    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Vinculado a una cuenta'), findsOneWidget);
    expect(find.text('Copiar código'), findsOneWidget);
  });

  testWidgets('El botón de escanear no responde mientras carga', (
    tester,
  ) async {
    phone(tester);
    final pending = Completer<LeaveStatus?>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          leaveService: _SlowFakeLeaveService(pending.future),
          deviceCodeLoader: _noDeviceCode,
          clock: fixedNow,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Registrar salida'));
    await tester.pump();
    expect(find.byType(ScanPage), findsNothing);

    pending.complete(LeaveStatus.fromJson({'name': 'Juan', 'isLeave': false}));
    await _settle(tester);
    await _tearDownTimers(tester);
  });

  testWidgets(
    'HomePage muestra un mensaje claro y reintentar si falla la carga',
    (tester) async {
      final api = _FakeLeaveService(
        leaveStatusResponse: null,
      ); // fuerza el error simulado

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(leaveService: api, deviceCodeLoader: _noDeviceCode),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('No se pudo cargar tu información'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Al reintentar con datos disponibles, se debe mostrar el contenido normal.
      api.leaveStatusResponse = {'name': 'Juan Pérez', 'isLeave': false};
      await tester.tap(find.text('Reintentar'));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Registrar salida'), findsOneWidget);
      expect(find.text('Estás dentro'), findsOneWidget);

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
  Future<List<LeaveDetail>?> fetchLeaveDetails(
    DateTime from,
    DateTime to,
  ) async => null;

  @override
  Future<List<LeaveReasonOption>?> getReasons(String namePremise) async => null;

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
