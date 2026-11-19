import 'package:control_input_output/core/device/device_code_note.dart';
import 'package:control_input_output/core/device/device_code_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<DeviceCodeInfo?> Function() loader,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DeviceCodeNote(loader: loader)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra el código cuando el teléfono está vinculado', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => const DeviceCodeInfo(code: 'K7M4-Q9XB', linked: true),
    );

    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Código de este dispositivo'), findsOneWidget);
    expect(find.textContaining('Recursos Humanos'), findsOneWidget);
  });

  testWidgets('no muestra nada si el teléfono aún no está vinculado', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => const DeviceCodeInfo(code: 'K7M4-Q9XB', linked: false),
    );

    expect(find.text('K7M4-Q9XB'), findsNothing);
    expect(find.text('Código de este dispositivo'), findsNothing);
  });

  testWidgets('no molesta si la consulta falla', (tester) async {
    await _pump(tester, () async => null);

    expect(find.text('Código de este dispositivo'), findsNothing);
  });
}
