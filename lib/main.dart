import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'screens/user/session_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Espera a que la cookie de sesión guardada en disco esté cargada antes de
  // la primera petición; si no, la primera pantalla no vería una sesión que
  // en realidad sí existe.
  await ApiConfig().ready;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        // Botones y filas más grandes, cómodos para tocar en cualquier edad.
        visualDensity: VisualDensity.comfortable,
        textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.08),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(fontSize: 15),
        ),
      ),
      home: const SessionGate(),
    );
  }
}
