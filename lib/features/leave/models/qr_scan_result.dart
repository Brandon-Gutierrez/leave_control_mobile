/// Qué debe hacer la app tras escanear un QR.
class QrScanResult {
  static const String _showReasonsAction = 'showReasons';

  /// Mensaje del servidor para mostrar a la persona.
  final String message;

  /// `showReasons` (hay que elegir el motivo de la salida) o `showHome`
  /// (el retorno ya quedó registrado).
  final String? action;

  /// Comprobante del escaneo: es lo que se envía al confirmar el motivo, no
  /// el texto del QR original.
  final String? leaveTicket;
  final DateTime? leaveTicketExpiresAt;

  const QrScanResult({
    required this.message,
    required this.action,
    required this.leaveTicket,
    required this.leaveTicketExpiresAt,
  });

  factory QrScanResult.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['leaveTicketExpiresAt'];
    return QrScanResult(
      message: json['message'] ?? 'Acción completada.',
      action: json['action'],
      leaveTicket: (json['leaveTicket'] ?? json['qrData'])?.toString(),
      leaveTicketExpiresAt: expiresAt != null
          ? DateTime.tryParse(expiresAt.toString())
          : null,
    );
  }

  /// Hay que elegir el motivo de la salida.
  bool get showsReasons => action == _showReasonsAction;
}
