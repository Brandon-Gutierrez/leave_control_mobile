import 'package:flutter/material.dart';

import '../../../../core/location/location_service.dart';

/// Aviso sobre la cámara del escáner: si la ubicación ya está lista para
/// validar la salida, si todavía la busca o si hay que activarla.
class LocationStatusPill extends StatelessWidget {
  /// Null mientras aún no se sabe (se muestra como «Buscando…»).
  final LocationReadiness? readiness;

  const LocationStatusPill({super.key, required this.readiness});

  @override
  Widget build(BuildContext context) {
    final state = readiness ?? LocationReadiness.searching;
    final (Color bg, String text, Widget icon) = switch (state) {
      LocationReadiness.ready => (
        const Color(0xE63F7D4E),
        'Ubicación lista',
        const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
      LocationReadiness.searching => (
        const Color(0x8C000000),
        'Buscando ubicación…',
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      LocationReadiness.off => (
        const Color(0xE6B71C1C),
        'Activa la ubicación del teléfono',
        const Icon(Icons.location_off_rounded, size: 16, color: Colors.white),
      ),
    };

    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(state),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
