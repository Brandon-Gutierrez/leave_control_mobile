import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema global: botones y filas más grandes, cómodos para tocar en cualquier
/// edad.
ThemeData buildAppTheme() {
  return ThemeData(
    // Esquema explícito: todo componente de Material (calendario, diálogos,
    // campos) usa solo la paleta de la app, sin tonos derivados del seed.
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryRed,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryRed,
          onPrimary: Colors.white,
          primaryContainer: AppColors.dangerBg,
          onPrimaryContainer: AppColors.danger,
          secondary: AppColors.info,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.infoBg,
          onSecondaryContainer: AppColors.darkText,
          surface: Colors.white,
          onSurface: AppColors.darkText,
          onSurfaceVariant: AppColors.info,
          surfaceTint: Colors.transparent,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          error: AppColors.danger,
        ),
    useMaterial3: true,
    visualDensity: VisualDensity.comfortable,
    textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.08),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      contentTextStyle: TextStyle(fontSize: 15),
    ),
  );
}
