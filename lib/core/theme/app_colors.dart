import 'package:flutter/material.dart';

/// Paleta del sistema: rojo como color de marca sobre neutros. Los colores de
/// estado son versiones apagadas (poca saturación) para que no compitan con el
/// rojo: el estado se distingue por el matiz sutil, el ícono y el texto.
abstract final class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);
  static const lightBg = Color(0xFFFAFAFA);
  static const loginBg = Color(0xFFF5F5F5);

  // Estados
  static const success = Color(0xFF3F7D4E);
  static const successBg = Color(0xFFEEF5EF);
  static const danger = Color(0xFFB71C1C);
  static const dangerBg = Color(0xFFFBEBEB);
  static const warning = Color(0xFF9A6A1F);
  static const warningBg = Color(0xFFFAF3E6);

  /// Información y acciones neutras: gris, no azul.
  static const info = Color(0xFF4A4A4A);
  static const infoBg = Color(0xFFF0F0F0);
  static const line = Color(0xFFDDDDDD);
}
