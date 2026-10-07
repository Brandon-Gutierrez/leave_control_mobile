import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tamaños de texto pensados para leerse cómodamente, incluso para personas
/// mayores o que no usan aplicaciones seguido.
abstract final class AppText {
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.darkText,
  );

  static final TextStyle caption = TextStyle(
    fontSize: 14,
    color: Colors.grey.shade600,
  );
}

/// Medidas mínimas para que los botones sean fáciles de tocar.
abstract final class AppDimens {
  static const double buttonHeight = 56.0;
  static const double iconSize = 26.0;
}
