import 'package:control_input_output/core/theme/app_text_styles.dart';
import 'package:control_input_output/core/theme/app_theme.dart';
import 'package:control_input_output/core/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpButton(
  WidgetTester tester, {
  VoidCallback? onPressed,
  bool loading = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: AppPrimaryButton(
          label: 'Ingresar',
          loading: loading,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

void main() {
  test('la tipografía Manrope está declarada y sus archivos existen', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final file in [
      'Manrope_400Regular',
      'Manrope_500Medium',
      'Manrope_600SemiBold',
      'Manrope_700Bold',
      'Manrope_800ExtraBold',
    ]) {
      final data = await rootBundle.load('rsc/fonts/$file.ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: file);
    }
    expect(buildAppTheme().textTheme.bodyMedium?.fontFamily, appFontFamily);
  });

  testWidgets('el texto del botón principal usa Manrope', (tester) async {
    await _pumpButton(tester, onPressed: () {});

    final style = DefaultTextStyle.of(tester.element(find.text('Ingresar')));
    expect(style.style.fontFamily, appFontFamily);
    expect(style.style.fontWeight, FontWeight.w800);
  });

  testWidgets('el botón principal responde al toque', (tester) async {
    var taps = 0;
    await _pumpButton(tester, onPressed: () => taps++);

    await tester.tap(find.text('Ingresar'));
    expect(taps, 1);
  });

  testWidgets('con loading muestra el indicador y no se puede tocar', (
    tester,
  ) async {
    var taps = 0;
    await _pumpButton(tester, loading: true, onPressed: () => taps++);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ingresar'), findsNothing);
    await tester.tap(find.byType(AppPrimaryButton));
    expect(taps, 0);
  });

  testWidgets('sin acción queda deshabilitado', (tester) async {
    await _pumpButton(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
