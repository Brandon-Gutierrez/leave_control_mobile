import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _keyToken = 'token';
  static const _keyItem = 'item';
  static const _keyName = 'name';
  static const _keyDeviceId = 'device_id';

  //Guardar data de forma local
  Future<void> saveData (String name,String item, String token) async { 
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyItem, value: item);  
    await _storage.write(key: _keyName, value: name);
  }

  //Leer el token de forma local
  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  //Leer el item de forma local
  Future<String?> getItem() async {
    return await _storage.read(key: _keyItem);
  }

  //Leer el nombre de forma local
  Future<String?> getName() async {
    return await _storage.read(key: _keyName);
  }

  //Actualizar data de forma local
  Future<void> updateData (String token, String name) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyName, value: name);
  }

  //Eliminar data de forma local
  Future<void> deleteData() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyItem);
    await _storage.delete(key: _keyName);
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