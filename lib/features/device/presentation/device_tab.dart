import 'package:flutter/material.dart';

import '../../../core/device/device_code_note.dart';
import '../../../core/device/device_code_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_logo.dart';

/// Pestaña «Dispositivo». Por ahora solo muestra el código del teléfono; la
/// pantalla completa (copiar, para qué sirve, cuenta vinculada) llega en la
/// siguiente fase.
class DeviceTab extends StatelessWidget {
  /// Permite inyectar la consulta del código de dispositivo (pruebas).
  final Future<DeviceCodeInfo?> Function()? deviceCodeLoader;

  const DeviceTab({super.key, this.deviceCodeLoader});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 22.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pad,
        20,
        pad,
        AppBottomBar.totalHeight(context) + 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  AppLogo(size: 46),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mi dispositivo',
                      style: AppText.display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DeviceCodeNote(
                loader: deviceCodeLoader,
                help:
                    'Recursos Humanos puede pedirte este código para '
                    'ayudarte con el acceso a tu cuenta.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
