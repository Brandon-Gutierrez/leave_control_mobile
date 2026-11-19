import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Flujo de posiciones compartido por toda la app. Se enciende "en caliente"
/// (al abrir el escáner) para que, al escanear, el GPS ya tenga una lectura
/// precisa, y se apaga solo tras un rato sin uso para no gastar batería.
class PositionFeed {
  /// Abre el flujo de posiciones del sistema (inyectable en pruebas).
  final Stream<Position> Function() open;

  /// Tiempo sin pedir posiciones tras el cual el flujo se apaga.
  final Duration idleTimeout;

  PositionFeed({
    required this.open,
    this.idleTimeout = const Duration(seconds: 90),
  });

  static final PositionFeed shared = PositionFeed(
    open: () => Geolocator.getPositionStream(
      locationSettings: switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        ),
        TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        ),
        _ => const LocationSettings(accuracy: LocationAccuracy.best),
      },
    ),
  );

  final StreamController<Position> _updates = StreamController.broadcast();
  StreamSubscription<Position>? _subscription;
  Timer? _idleTimer;

  /// Última posición recibida (puede ser vieja: quien la use debe revisarla).
  Position? latest;

  Stream<Position> get updates => _updates.stream;

  /// Enciende el flujo si hace falta y reinicia el temporizador de apagado.
  void keepAlive() {
    _subscription ??= open().listen(
      (position) {
        latest = position;
        _updates.add(position);
      },
      // Un fallo (p. ej. GPS apagado) no rompe nada: el flujo se reabre en el
      // siguiente keepAlive.
      onError: (_) {},
      onDone: () => _subscription = null,
    );
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, stop);
  }

  void stop() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _subscription?.cancel();
    _subscription = null;
    latest = null;
  }
}

/// Captura la posición del usuario y detecta ubicación simulada y VPN.
class LocationService {
  /// Precisión con la que se deja de esperar (el servidor rechaza más de 30 m).
  static const goodAccuracyMeters = 30.0;

  final PositionFeed _feed;
  final DateTime Function() _now;

  /// Tiempo máximo esperando una lectura precisa antes de usar la mejor que haya.
  final Duration maxWait;

  /// Una lectura más vieja que esto se descarta: al encender el GPS el teléfono
  /// suele entregar primero la última posición conocida, que puede estar lejos.
  final Duration maxReadingAge;

  LocationService({
    PositionFeed? feed,
    DateTime Function()? now,
    this.maxWait = const Duration(seconds: 15),
    this.maxReadingAge = const Duration(seconds: 15),
  }) : _feed = feed ?? PositionFeed.shared,
       _now = now ?? DateTime.now;

  /// Clave de NSLocationTemporaryUsageDescriptionDictionary (ios/Runner/Info.plist).
  static const _fullAccuracyPurposeKey = 'PremiseValidation';

  /// iOS no informa de VPN a través de connectivity_plus: se consulta al código nativo.
  static const _vpnChannel = MethodChannel('control_input_output/vpn');

  Future<LocationProof> capture() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
        'Activa la ubicación (GPS) de tu teléfono para continuar.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException(
        'Necesitamos el permiso de ubicación para validar que estás en el predio.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes del teléfono.',
      );
    }

    await _ensurePreciseLocation();

    final vpn = await _isVpnActive();
    if (vpn) {
      throw LocationException(
        'Desactiva la VPN para validar tu ubicación e intenta nuevamente.',
      );
    }

    final position = await acquirePosition();

    if (position.isMocked) {
      throw LocationException(
        'Se detectó una ubicación simulada (GPS falso). Desactívala para continuar.',
      );
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

  /// Enciende el GPS en segundo plano (p. ej. al abrir el escáner) para que la
  /// lectura precisa ya esté lista cuando se escanee. No pide permisos ni
  /// muestra nada: si el GPS está apagado o no hay permiso, no hace nada.
  Future<void> warmUp() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _feed.keepAlive();
    } catch (_) {
      // Es solo una optimización: capture() vuelve a validarlo todo.
    }
  }

  /// Espera una lectura reciente y precisa (≤ [goodAccuracyMeters]) hasta
  /// [maxWait]. Pasado ese tiempo usa la mejor lectura reciente que haya, para
  /// que el servidor decida con lo que se tiene. Descarta lecturas viejas.
  Future<Position> acquirePosition() async {
    _feed.keepAlive();

    final done = Completer<void>();
    Position? best; // la más precisa entre las recientes
    Position? lastLive; // la última recibida mientras se esperaba

    bool isFresh(Position p) => _now().difference(p.timestamp) <= maxReadingAge;

    void consider(Position p, {required bool live}) {
      if (live) lastLive = p;
      if (!isFresh(p)) return;
      if (best == null || p.accuracy < best!.accuracy) best = p;
      if (p.accuracy <= goodAccuracyMeters && !done.isCompleted) {
        done.complete();
      }
    }

    final cached = _feed.latest;
    if (cached != null) consider(cached, live: false);
    final subscription = _feed.updates.listen((p) => consider(p, live: true));
    final timer = Timer(maxWait, () {
      if (!done.isCompleted) done.complete();
    });
    try {
      await done.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }

    // Sin lecturas "recientes" (p. ej. reloj del teléfono desfasado) se usa la
    // última que llegó en vivo; la guardada de antes nunca se usa.
    final result = best ?? lastLive;
    if (result == null) {
      throw LocationException(
        'No se pudo obtener tu ubicación. Sal a un lugar abierto e intenta nuevamente.',
      );
    }
    return result;
  }

  /// En iOS la persona puede conceder solo la ubicación aproximada (cientos de
  /// metros), que el servidor rechazaría sin explicar por qué: se pide la
  /// precisa y, si la rechaza, se avisa. En Android siempre es precisa.
  Future<void> _ensurePreciseLocation() async {
    try {
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.precise) {
        return;
      }
      final granted = await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: _fullAccuracyPurposeKey,
      );
      if (granted == LocationAccuracyStatus.precise) return;
    } catch (_) {
      // Si no se puede consultar, se sigue: el servidor valida la precisión.
      return;
    }
    throw LocationException(
      'Activa la ubicación precisa para esta app en los ajustes del teléfono y vuelve a intentar.',
    );
  }

  Future<bool> _isVpnActive() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        return await _vpnChannel.invokeMethod<bool>('isVpnActive') ?? false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.vpn);
    } catch (_) {
      return false;
    }
  }
}
