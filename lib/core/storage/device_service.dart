import 'dart:math';

import 'storage_service.dart';

/// Identificador único del dispositivo, generado una sola vez y guardado en
/// el almacenamiento seguro. El backend lo usa para vincular la cuenta del
/// empleado a este dispositivo (ver AuthController::login).
class DeviceService {
  final StorageService _storageService;

  DeviceService({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  /// Devuelve el identificador guardado o genera uno nuevo la primera vez.
  Future<String> getDeviceId() async {
    final existing = await _storageService.getDeviceId();
    if (existing != null && existing.length >= 16) return existing;

    final generated = _generate();
    await _storageService.saveDeviceId(generated);
    return generated;
  }

  /// 32 bytes aleatorios en hexadecimal (64 caracteres): suficiente entropía
  /// y dentro del rango de 16-255 que exige el backend.
  String _generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
