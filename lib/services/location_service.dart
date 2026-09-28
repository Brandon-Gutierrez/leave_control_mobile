import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Ubicación capturada con las señales que el servidor usa para validarla.
class LocationProof {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  /// El sistema marcó la posición como simulada (GPS falso).
  final bool isMocked;

  /// El dispositivo tiene una conexión VPN activa.
  final bool vpnDetected;

  const LocationProof({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.isMocked,
    required this.vpnDetected,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyMeters < 0.1 ? 0.1 : accuracyMeters,
    'location_timestamp': capturedAt.toUtc().toIso8601String(),
    'is_mocked': isMocked,
    'vpn_detected': vpnDetected,
  };
}

/// Se lanza cuando no se puede obtener una ubicación confiable.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

/// Captura la posición del usuario y detecta ubicación simulada y VPN.
class LocationService {
  static const _timeout = Duration(seconds: 20);

  Future<LocationProof> capture() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Activa la ubicación (GPS) de tu teléfono para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Necesitamos el permiso de ubicación para validar que estás en el predio.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('El permiso de ubicación está bloqueado. Actívalo en los ajustes del teléfono.');
    }

    final vpn = await _isVpnActive();
    if (vpn) {
      throw LocationException('Desactiva la VPN para validar tu ubicación e intenta nuevamente.');
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _timeout,
        ),
      );
    } catch (_) {
      throw LocationException('No se pudo obtener tu ubicación. Sal a un lugar abierto e intenta nuevamente.');
    }

    if (position.isMocked) {
      throw LocationException('Se detectó una ubicación simulada (GPS falso). Desactívala para continuar.');
    }

    return LocationProof(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
      isMocked: position.isMocked,
      vpnDetected: vpn,
    );
  }

  Future<bool> _isVpnActive() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.vpn);
    } catch (_) {
      return false;
    }
  }
}
