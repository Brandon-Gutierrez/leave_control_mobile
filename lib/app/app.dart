import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/session_gate.dart';

/// Aplicación móvil de registro de salidas temporales.
class ControlLeavesApp extends StatelessWidget {
  const ControlLeavesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile app',
      theme: buildAppTheme(),
      home: const SessionGate(),
    );
  }
}
