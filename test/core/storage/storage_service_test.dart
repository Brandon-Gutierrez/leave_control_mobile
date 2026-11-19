import 'package:control_input_output/core/storage/storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'borra el token de Comteco, el nombre y el item de versiones anteriores',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'token': 'token-de-comteco',
        'item': '2057',
        'name': 'Juan Pérez',
        'device_id': 'dispositivo-123',
      });
      final storage = StorageService();

      await storage.purgeLegacyIdentity();

      const raw = FlutterSecureStorage();
      expect(await raw.read(key: 'token'), isNull);
      expect(await raw.read(key: 'item'), isNull);
      expect(await raw.read(key: 'name'), isNull);
      // El identificador del dispositivo sí se conserva: la vinculación depende de él.
      expect(await storage.getDeviceId(), 'dispositivo-123');
    },
  );

  test('repetirlo no falla aunque no haya nada guardado', () async {
    FlutterSecureStorage.setMockInitialValues({});

    await StorageService().purgeLegacyIdentity();
    await StorageService().purgeLegacyIdentity();

    expect(await StorageService().getDeviceId(), isNull);
  });
}
