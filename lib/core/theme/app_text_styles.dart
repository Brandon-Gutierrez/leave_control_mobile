import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Nombre de la tipografía de la app (declarada en pubspec.yaml). Los estilos de
/// botón reemplazan —no mezclan— la fuente del tema: deben indicarla ellos.
const appFontFamily = 'Manrope';

/// Tamaños de texto pensados para leerse cómodamente, incluso para personas
/// mayores o que no usan aplicaciones seguido.
abstract final class AppText {
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.darkText,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppColors.muted,
  );

  /// Título grande de una pantalla (p. ej. «Salidas Temporales»).
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.darkText,
  );
}

/// Medidas mínimas para que los botones sean fáciles de tocar.
abstract final class AppDimens {
  static const double buttonHeight = 56.0;

  /// Botón principal (Ingresar, Reintentar…).
  static const double primaryButtonHeight = 58.0;
  static const double fieldHeight = 56.0;
  static const double iconSize = 26.0;

  static const double radiusField = 14.0;
  static const double radiusButton = 16.0;
  static const double radiusCard = 20.0;
}
