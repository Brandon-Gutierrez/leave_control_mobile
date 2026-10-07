import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Espera a que la cookie de sesión guardada en disco esté cargada antes de
  // la primera petición; si no, la primera pantalla no vería una sesión que
  // en realidad sí existe.
  await ApiClient().ready;
  runApp(const ControlLeavesApp());
}
