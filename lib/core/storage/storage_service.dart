import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro del teléfono. Solo guarda el identificador del
/// dispositivo: la sesión vive en las cookies y el nombre, el rol y el estado
/// de la persona los entrega el servidor en cada pantalla, así que no se
/// guardan copias de datos personales (ni el token de Comteco) en el teléfono.
class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _keyDeviceId = 'device_id';

  /// Claves de versiones anteriores, que guardaban el token de Comteco, el
  /// nombre y el item de la persona.
  static const _legacyKeys = ['token', 'item', 'name'];

  //Eliminar lo que versiones anteriores guardaron de la persona (token de
  //Comteco, nombre e item). Es seguro repetirlo.
  Future<void> purgeLegacyIdentity() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  //Leer el identificador de dispositivo guardado (si ya se generó antes)
  Future<String?> getDeviceId() async {
    return await _storage.read(key: _keyDeviceId);
  }

  //Guardar el identificador de dispositivo generado la primera vez
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _keyDeviceId, value: deviceId);
  }
}