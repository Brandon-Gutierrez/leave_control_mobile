/// Rutas del backend (routes/api.php) usadas por la app móvil.
class ApiRoutes {
  // Sesión
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Empleado
  static const String leaveStatus = '/api/me/leave-status';
  static const String qrScan = '/api/qr/scan';
  static const String leaves = '/api/leaves';

  static String premiseReasons(String premiseName) =>
      '/api/premises/${Uri.encodeComponent(premiseName)}/reasons';
}
