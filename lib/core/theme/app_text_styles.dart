import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tamaños de texto pensados para leerse cómodamente, incluso para personas
/// mayores o que no usan aplicaciones seguido.
class AppText {
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.darkText,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.darkText,
  );

  static final TextStyle caption = TextStyle(
    fontSize: 14,
    color: Colors.grey.shade600,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}

/// Medidas mínimas para que los botones sean fáciles de tocar.
class AppDimens {
  static const double buttonHeight = 56.0;
  static const double cardRadius = 8.0;
  static const double fieldRadius = 8.0;
  static const double iconSize = 26.0;
}
