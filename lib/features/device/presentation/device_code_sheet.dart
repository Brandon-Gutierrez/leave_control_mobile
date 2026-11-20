import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'device_view.dart';

/// Hoja con el código del teléfono para quien no puede iniciar sesión: lo
/// dicta a Recursos Humanos para que liberen o vinculen el teléfono.
Future<void> showDeviceCodeSheet(
  BuildContext context, {
  DeviceCodeLoader? codeLoader,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.lightBg,
    builder: (_) => _DeviceCodeSheet(codeLoader: codeLoader),
  );
}

class _DeviceCodeSheet extends StatelessWidget {
  final DeviceCodeLoader? codeLoader;

  const _DeviceCodeSheet({this.codeLoader});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Código de este teléfono',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Si no puedes ingresar, dicta este código a Recursos Humanos.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              DeviceView(codeLoader: codeLoader),
            ],
          ),
        ),
      ),
    );
  }
}
