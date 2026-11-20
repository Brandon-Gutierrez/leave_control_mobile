import 'dart:async';

import 'package:control_input_output/core/device/device_code_service.dart';
import 'package:control_input_output/core/theme/app_theme.dart';
import 'package:control_input_output/features/auth/models/account_info.dart';
import 'package:control_input_output/features/device/presentation/device_code_sheet.dart';
import 'package:control_input_output/features/device/presentation/device_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _linkedAt = DateTime(2026, 11, 18, 8, 15);

DeviceCodeInfo _info({bool linked = true}) => DeviceCodeInfo(
  code: 'K7M4-Q9XB',
  linked: linked,
  linkedAt: linked ? _linkedAt : null,
);

Future<AccountInfo?> _account() async =>
    const AccountInfo(name: 'Juan Pérez', item: '2057');

Future<void> _pump(
  WidgetTester tester, {
  required DeviceCodeLoader codeLoader,
  AccountLoader? accountLoader,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DeviceView(
            codeLoader: codeLoader,
            accountLoader: accountLoader,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('con sesión muestra el código, para qué sirve y la cuenta', (
    tester,
  ) async {
    await _pump(
      tester,
      codeLoader: () async => _info(),
      accountLoader: _account,
    );

    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Vinculado a tu cuenta'), findsOneWidget);
    expect(find.text('¿Para qué sirve este código?'), findsOneWidget);
    expect(find.textContaining('Identifica este teléfono'), findsOneWidget);
    expect(find.textContaining('¿Cambiarás de teléfono?'), findsOneWidget);
    expect(find.textContaining('Si otra persona usó'), findsOneWidget);
    expect(find.text('Cuenta vinculada'), findsOneWidget);
    expect(find.text('Juan Pérez · Item 2057'), findsOneWidget);
    expect(find.text('Vinculado el 18/11/2026 a las 08:15'), findsOneWidget);
  });

  testWidgets('sin sesión no muestra la cuenta ni dice «tu cuenta»', (
    tester,
  ) async {
    await _pump(tester, codeLoader: () async => _info());

    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Vinculado a una cuenta'), findsOneWidget);
    expect(find.text('Cuenta vinculada'), findsNothing);
    expect(find.textContaining('Item'), findsNothing);
  });

  testWidgets('un teléfono sin vincular lo dice', (tester) async {
    await _pump(tester, codeLoader: () async => _info(linked: false));

    expect(find.text('Aún sin vincular'), findsOneWidget);
    expect(find.textContaining('Vinculado el'), findsNothing);
  });

  testWidgets('si la cuenta no se puede consultar igual muestra el código', (
    tester,
  ) async {
    await _pump(
      tester,
      codeLoader: () async => _info(),
      accountLoader: () async => null,
    );

    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Cuenta vinculada'), findsNothing);
  });

  testWidgets('Copiar código lo copia y lo confirma un momento', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(
      tester,
      codeLoader: () async => _info(),
      accountLoader: _account,
    );

    await tester.tap(find.text('Copiar código'));
    await tester.pump();
    await tester.pump();

    expect(copied, ['K7M4-Q9XB']);
    expect(find.text('Código copiado'), findsOneWidget);
    expect(find.text('Copiar código'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copiar código'), findsOneWidget);
  });

  testWidgets('mientras carga muestra un indicador', (tester) async {
    final pending = Completer<DeviceCodeInfo?>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: DeviceView(codeLoader: () => pending.future)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('K7M4-Q9XB'), findsNothing);

    pending.complete(_info());
    await tester.pump();
    await tester.pump();
    expect(find.text('K7M4-Q9XB'), findsOneWidget);
  });

  testWidgets('si falla la consulta avisa y permite reintentar', (
    tester,
  ) async {
    var fails = true;
    await _pump(tester, codeLoader: () async => fails ? null : _info());

    expect(
      find.text('No se pudo obtener el código de este teléfono'),
      findsOneWidget,
    );

    fails = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('el código y las tarjetas no desbordan en $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        codeLoader: () async => _info(),
        accountLoader: () async => const AccountInfo(
          name: 'María Fernanda Rodríguez de la Quintana',
          item: '20571',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('K7M4-Q9XB'), findsOneWidget);
    });
  }

  testWidgets('la hoja del login muestra el código del teléfono', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDeviceCodeSheet(context, codeLoader: () async => _info()),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Código de este teléfono'), findsOneWidget);
    expect(find.text('K7M4-Q9XB'), findsOneWidget);
    expect(find.text('Cuenta vinculada'), findsNothing);
  });
}
