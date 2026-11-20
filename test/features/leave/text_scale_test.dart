import 'package:control_input_output/core/device/device_code_service.dart';
import 'package:control_input_output/core/theme/app_theme.dart';
import 'package:control_input_output/features/auth/models/account_info.dart';
import 'package:control_input_output/features/auth/presentation/login_page.dart';
import 'package:control_input_output/features/leave/models/leave_reason.dart';
import 'package:control_input_output/features/leave/models/leave_status.dart';
import 'package:control_input_output/features/leave/presentation/home_page.dart';
import 'package:control_input_output/features/leave/presentation/reasons_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_leave_service.dart';
import '../../support/load_app_fonts.dart';

/// Personas con la letra del teléfono muy grande (accesibilidad) no deben ver
/// textos cortados ni pantallas desbordadas.
const _scales = [1.3, 1.6, 2.0];
const _sizes = <String, Size>{
  'teléfono chico 320x568': Size(320, 568),
  'teléfono normal 390x844': Size(390, 844),
};

Widget _app(Widget home, double scale) => MaterialApp(
  theme: buildAppTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<DeviceCodeInfo?> _code() async => DeviceCodeInfo(
  code: 'K7M4-Q9XB',
  linked: true,
  linkedAt: DateTime(2026, 11, 18, 8, 15),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

FakeLeaveService _busyDay() =>
    FakeLeaveService(
        leaveStatusResponse: {
          'name': 'María Fernanda Rodríguez de la Quintana',
          'role': 'EMPLOYEE',
          'job_title': 'Técnico de Redes y Telecomunicaciones',
          'isLeave': true,
          'dateLeave': DateTime(2026, 11, 19, 10, 30).toIso8601String(),
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
      ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final size in _sizes.entries) {
    for (final scale in _scales) {
      final where = '${size.key}, letra x$scale';

      void useSize(WidgetTester tester) {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
      }

      testWidgets('Login no desborda ($where)', (tester) async {
        useSize(tester);
        await tester.pumpWidget(
          _app(LoginPage(deviceCodeLoader: _code), scale),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Ingresar'), findsOneWidget);
      });

      testWidgets('La hoja del código del teléfono no desborda ($where)', (
        tester,
      ) async {
        useSize(tester);
        await tester.pumpWidget(
          _app(LoginPage(deviceCodeLoader: _code), scale),
        );
        await tester.pumpAndSettle();
        final link = find.textContaining('¿No puedes ingresar?');
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('K7M4-Q9XB'), findsOneWidget);
      });

      testWidgets('Inicio con una salida en curso no desborda ($where)', (
        tester,
      ) async {
        useSize(tester);
        await tester.pumpWidget(
          _app(
            HomePage(
              leaveService: _busyDay(),
              deviceCodeLoader: _code,
              accountLoader: () async => null,
              clock: () => DateTime(2026, 11, 19, 12, 30),
            ),
            scale,
          ),
        );
        await _settle(tester);
        // Se recorre toda la pantalla para construir todo lo que hay debajo.
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Estás fuera'), findsOneWidget);

        await _unmount(tester);
      });

      testWidgets('Dispositivo con cuenta larga no desborda ($where)', (
        tester,
      ) async {
        useSize(tester);
        await tester.pumpWidget(
          _app(
            HomePage(
              leaveService: _busyDay(),
              deviceCodeLoader: _code,
              accountLoader: () async => const AccountInfo(
                name: 'María Fernanda Rodríguez de la Quintana',
                item: '20571',
              ),
              clock: () => DateTime(2026, 11, 19, 12, 30),
            ),
            scale,
          ),
        );
        await _settle(tester);
        await tester.tap(find.text('Dispositivo'));
        await _settle(tester);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('K7M4-Q9XB'), findsOneWidget);

        await _unmount(tester);
      });

      testWidgets('Motivos de salida no desbordan ($where)', (tester) async {
        useSize(tester);
        final api = FakeLeaveService(
          reasonsResponse: LeaveReasonOption.listFromJson({
            'reasons': [
              for (var i = 1; i <= 8; i++)
                'Reunión externa con proveedores del servicio número $i',
            ],
            'blocked_reasons': [
              {
                'name': 'Reunión externa con proveedores del servicio número 2',
                'limit': 1,
                'used': 1,
                'period': 'day',
              },
            ],
          }),
        );
        await tester.pumpWidget(
          _app(
            ReasonsPage(
              qrData: 'Predio Central Norte del Departamento+uuid',
              leaveTicket: 't',
              ticketExpiresAt: DateTime.now().add(const Duration(seconds: 40)),
              leaveService: api,
            ),
            scale,
          ),
        );
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Elige tu motivo de salida'), findsOneWidget);

        await _unmount(tester);
      });
    }
  }
}
