import 'dart:async';

import 'package:control_input_output/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _position({required double accuracy, required DateTime at}) =>
    Position(
      latitude: -17.39,
      longitude: -66.15,
      timestamp: at,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Future<void> _tick([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late StreamController<Position> source;
  late PositionFeed feed;
  late bool available;
  late List<LocationReadiness> events;
  StreamSubscription<LocationReadiness>? subscription;

  void watch({Duration every = const Duration(milliseconds: 40)}) {
    final service = LocationService(
      feed: feed,
      canUseLocation: () async => available,
    );
    subscription = service.readiness(every: every).listen(events.add);
  }

  setUp(() {
    source = StreamController<Position>.broadcast();
    feed = PositionFeed(open: () => source.stream);
    available = true;
    events = [];
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    feed.stop();
    await source.close();
  });

  test('busca la ubicación y avisa cuando hay una lectura precisa', () async {
    watch();
    await _tick();
    expect(events, [LocationReadiness.searching]);

    // Una lectura gruesa todavía no sirve para validar la salida.
    source.add(_position(accuracy: 80, at: DateTime.now()));
    await _tick();
    expect(events, [LocationReadiness.searching]);

    source.add(_position(accuracy: 12, at: DateTime.now()));
    await _tick();
    expect(events, [LocationReadiness.searching, LocationReadiness.ready]);
  });

  test('una lectura vieja, aunque precisa, no cuenta como lista', () async {
    watch();
    await _tick();

    source.add(
      _position(
        accuracy: 5,
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    await _tick();

    expect(events, [LocationReadiness.searching]);
  });

  test('vuelve a buscar si la precisión empeora', () async {
    watch();
    await _tick();
    source.add(_position(accuracy: 10, at: DateTime.now()));
    await _tick();
    source.add(_position(accuracy: 90, at: DateTime.now()));
    await _tick();

    expect(events, [
      LocationReadiness.searching,
      LocationReadiness.ready,
      LocationReadiness.searching,
    ]);
  });

  test('sin ubicación disponible avisa y se recupera al activarla', () async {
    available = false;
    watch();
    await _tick();
    expect(events, [LocationReadiness.off]);

    available = true;
    await _tick(120);
    expect(events, [LocationReadiness.off, LocationReadiness.searching]);
  });

  test('al dejar de escuchar no sigue consultando', () async {
    var checks = 0;
    final service = LocationService(
      feed: feed,
      canUseLocation: () async {
        checks++;
        return true;
      },
    );
    final sub = service
        .readiness(every: const Duration(milliseconds: 30))
        .listen(events.add);
    await _tick(100);
    await sub.cancel();
    final after = checks;
    await _tick(150);

    expect(checks, after);
  });
}
