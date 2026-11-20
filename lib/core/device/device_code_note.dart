import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'device_code_service.dart';

/// Muestra el código de este teléfono cuando ya está vinculado a una cuenta,
/// para que la persona pueda dictarlo a Recursos Humanos si no logra ingresar.
/// No muestra nada mientras carga, si falla la consulta o si el teléfono aún
/// no está vinculado: nunca estorba.
class DeviceCodeNote extends StatefulWidget {
  /// Texto de ayuda bajo el código.
  final String help;

  /// Permite inyectar la consulta (p. ej. en pruebas).
  final Future<DeviceCodeInfo?> Function()? loader;

  const DeviceCodeNote({
    super.key,
    this.help = 'Si no puedes ingresar, dicta este código a Recursos Humanos.',
    this.loader,
  });

  @override
  State<DeviceCodeNote> createState() => _DeviceCodeNoteState();
}

class _DeviceCodeNoteState extends State<DeviceCodeNote> {
  DeviceCodeInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await (widget.loader ?? DeviceCodeService().fetch)();
    if (!mounted) return;
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || !info.linked) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
      ),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded, size: 28, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Código de este dispositivo',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                SelectableText(
                  info.code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.help,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
