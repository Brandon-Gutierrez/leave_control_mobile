import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_logo.dart';
import 'device_view.dart';

/// Pestaña «Dispositivo»: el código de este teléfono, para qué sirve y a qué
/// cuenta está vinculado.
class DeviceTab extends StatelessWidget {
  /// Consultas del código y de la cuenta. Permiten inyectar datos de prueba.
  final DeviceCodeLoader? codeLoader;
  final AccountLoader accountLoader;

  const DeviceTab({super.key, this.codeLoader, required this.accountLoader});

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DeviceView(codeLoader: codeLoader, accountLoader: accountLoader),
            ],
          ),
        ),
      ),
    );
  }
}
