/// Configuración de conexión con el backend.
abstract final class ApiConfig {
  /// URL del backend. Se puede sobrescribir al compilar:
  /// flutter run --dart-define=API_BASE_URL=https://mi-api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://duckie-carposporic-nickolas.ngrok-free.dev',
  );
}
