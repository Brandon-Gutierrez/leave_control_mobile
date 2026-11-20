import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Manrope (y los íconos de Material) en las pruebas de widgets.
///
/// Sin esto las pruebas dibujan todo el texto con una fuente cuadrada y muy
/// ancha, y los desbordes salen mucho peores que en un teléfono real.
Future<void> loadAppFonts() async {
  final manrope = FontLoader('Manrope');
  for (final file in [
    'Manrope_400Regular',
    'Manrope_500Medium',
    'Manrope_600SemiBold',
    'Manrope_700Bold',
    'Manrope_800ExtraBold',
  ]) {
    manrope.addFont(rootBundle.load('rsc/fonts/$file.ttf'));
  }
  await manrope.load();

  // Los íconos viven en el SDK de Flutter; si no se encuentran se sigue sin
  // ellos (el tamaño de un ícono no cambia aunque no se dibuje).
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await icons.load();
      break;
    }
  }
}
