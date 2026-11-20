import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo de la app: Comteco con la insignia roja de salida y retorno, sin fondo
/// (el mismo del ícono de la aplicación).
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'rsc/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decorativo: las pantallas ya dicen el nombre de la app en texto.
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(
        Icons.swap_horiz_rounded,
        size: size * 0.5,
        color: AppColors.primaryRed,
      ),
    );
  }
}
