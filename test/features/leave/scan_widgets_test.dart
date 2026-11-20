import 'package:control_input_output/core/location/location_service.dart';
import 'package:control_input_output/features/leave/presentation/widgets/countdown_ring.dart';
import 'package:control_input_output/features/leave/presentation/widgets/location_status_pill.dart';
import 'package:control_input_output/features/leave/presentation/widgets/scan_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(backgroundColor: Colors.black, body: child),
    ),
  );
}

void main() {
  group('LocationStatusPill', () {
    testWidgets('dice cuando la ubicación está lista', (tester) async {
      await _pump(
        tester,
        const Center(
          child: LocationStatusPill(readiness: LocationReadiness.ready),
        ),
      );

      expect(find.text('Ubicación lista'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('mientras busca (o aún no sabe) muestra un indicador', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(
          child: LocationStatusPill(readiness: LocationReadiness.searching),
        ),
      );
      expect(find.text('Buscando ubicación…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _pump(
        tester,
        const Center(child: LocationStatusPill(readiness: null)),
      );
      expect(find.text('Buscando ubicación…'), findsOneWidget);
    });

    testWidgets('pide activar la ubicación si no está disponible', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(
          child: LocationStatusPill(readiness: LocationReadiness.off),
        ),
      );

      expect(find.text('Activa la ubicación del teléfono'), findsOneWidget);
    });

    testWidgets('cambia de estado sin errores', (tester) async {
      Widget pill(LocationReadiness r) =>
          Center(child: LocationStatusPill(readiness: r));

      await _pump(tester, pill(LocationReadiness.searching));
      await _pump(tester, pill(LocationReadiness.ready));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ubicación lista'), findsOneWidget);
      expect(find.text('Buscando ubicación…'), findsNothing);
    });
  });

  group('ScanOverlay', () {
    testWidgets('no intercepta los toques de lo que hay debajo', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
            ),
            const ScanOverlay(frameSize: 260),
          ],
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(ScanOverlay)));
      expect(taps, 1);
    });

    for (final size in const [Size(320, 568), Size(412, 915), Size(800, 360)]) {
      testWidgets('se dibuja sin errores en ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pump(
          tester,
          ScanOverlay(frameSize: (size.shortestSide * 0.7).clamp(200.0, 320.0)),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('CountdownRing', () {
    testWidgets('muestra los segundos que quedan', (tester) async {
      await _pump(
        tester,
        const Center(child: CountdownRing(secondsLeft: 19, totalSeconds: 30)),
      );

      expect(find.text('19'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tiempo para elegir el motivo: 19 segundos'),
        findsOneWidget,
      );
    });

    testWidgets('en los últimos 10 segundos el número se pone rojo', (
      tester,
    ) async {
      Color colorOf(int seconds) {
        final text = tester.widget<Text>(find.text('$seconds'));
        return text.style!.color!;
      }

      await _pump(
        tester,
        const Center(child: CountdownRing(secondsLeft: 25, totalSeconds: 30)),
      );
      final calm = colorOf(25);

      await _pump(
        tester,
        const Center(child: CountdownRing(secondsLeft: 8, totalSeconds: 30)),
      );
      expect(colorOf(8), isNot(calm));
    });

    testWidgets('tolera un total de cero y un tiempo agotado', (tester) async {
      await _pump(
        tester,
        const Center(child: CountdownRing(secondsLeft: 0, totalSeconds: 0)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
