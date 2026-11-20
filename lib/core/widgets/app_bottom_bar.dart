import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra inferior: Inicio, el botón central para escanear el QR y Dispositivo.
///
/// El botón central sobresale de la barra, así que la barra mide más que su
/// parte blanca. Úsala con `Scaffold(extendBody: true)` y deja al contenido un
/// margen inferior de [totalHeight] para que nada quede tapado.
class AppBottomBar extends StatelessWidget {
  /// 0 = Inicio, 1 = Dispositivo.
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Texto bajo el botón central («Registrar salida» o «Registrar retorno»).
  final String scanLabel;

  /// Null deshabilita el botón central (p. ej. mientras carga el estado).
  final VoidCallback? onScan;

  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.scanLabel,
    required this.onScan,
  });

  /// Alto de la parte blanca de la barra.
  static const double barHeight = 96;

  /// Cuánto sobresale el botón central por encima de la barra.
  static const double fabOverflow = 42;

  static const double _fabSize = 92;
  static const double _fabSlotWidth = 132;

  /// Alto total que ocupa la barra (con la parte que sobresale y la zona segura).
  static double totalHeight(BuildContext context) =>
      barHeight + fabOverflow + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: barHeight + fabOverflow + inset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Parte blanca de la barra (llega hasta el borde, bajo la zona segura).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight + inset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            height: barHeight,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_outlined,
                    label: 'Inicio',
                    selected: selectedIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                ),
                const SizedBox(width: _fabSlotWidth),
                Expanded(
                  child: _NavItem(
                    icon: Icons.smartphone_rounded,
                    label: 'Dispositivo',
                    selected: selectedIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                ),
              ],
            ),
          ),
          // Botón central: círculo rojo que sobresale y su etiqueta.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(
              child: SizedBox(
                width: _fabSlotWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScanButton(onTap: onScan, label: scanLabel),
                    const SizedBox(height: 4),
                    Text(
                      scanLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryRed : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;

  const _ScanButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: enabled
              ? AppColors.primaryRed
              : AppColors.primaryRed.withValues(alpha: 0.4),
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white, width: 6),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: AppBottomBar._fabSize,
              height: AppBottomBar._fabSize,
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
