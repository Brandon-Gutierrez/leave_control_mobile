import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_input_output/screens/user/home_page.dart';
import 'package:control_input_output/screens/user/login_page.dart';
import 'package:control_input_output/screens/user/reasons_page.dart';

/// Tamaños lógicos de teléfonos comunes (ancho x alto).
const _phoneSizes = <String, Size>{
  'iPhone SE (1ra gen)': Size(320, 568),
  'Android compacto': Size(360, 640),
  'iPhone 13 mini': Size(375, 812),
  'Pixel 7': Size(412, 915),
  'iPhone 15 Pro Max': Size(430, 932),
  'Horizontal': Size(800, 360),
};

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

    testWidgets('HomePage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Escanear código QR'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('ReasonPage no desborda en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: ReasonPage(qrData: 'Predio Central+uuid')),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Confirmar Selección'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 31));
    });
  }
}
