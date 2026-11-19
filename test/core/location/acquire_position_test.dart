import 'dart:async';

import 'package:control_input_output/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _position({
  required double accuracy,
  required DateTime at,
  double latitude = -17.39,
}) => Position(
  latitude: latitude,
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

void main() {
  late StreamController<Position> source;
  late PositionFeed feed;

  LocationService service({
    Duration maxWait = const Duration(milliseconds: 300),
  }) => LocationService(feed: feed, maxWait: maxWait);

  setUp(() {
    source = StreamController<Position>.broadcast();
    feed = PositionFeed(open: () => source.stream);
  });

  tearDown(() async {
    feed.stop();
    await source.close();
  });

  test(
    'espera la lectura precisa en vez de usar la primera imprecisa',
    () async {
      final pending = service().acquirePosition();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // El GPS recién encendido da primero una lectura gruesa y luego la buena.
      source.add(_position(accuracy: 80, at: DateTime.now(), latitude: -17.5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.add(_position(accuracy: 12, at: DateTime.now()));

      final position = await pending;
      expect(position.accuracy, 12);
      expect(position.latitude, -17.39);
    },
  );

  test(
    'descarta la última posición conocida (vieja) y espera una nueva',
    () async {
      // Lectura vieja pero "precisa": es la causa del primer intento fallido.
      feed.keepAlive();
      source.add(
        _position(
          accuracy: 5,
          at: DateTime.now().subtract(const Duration(minutes: 5)),
          latitude: -17.9,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final pending = service().acquirePosition();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.add(_position(accuracy: 10, at: DateTime.now()));

      final position = await pending;
      expect(position.latitude, -17.39);
    },
  );

  test(
    'usa de inmediato una lectura reciente y precisa del calentamiento',
    () async {
      feed.keepAlive();
      source.add(_position(accuracy: 8, at: DateTime.now()));
      await Future<void>.delayed(Duration.zero);

      final stopwatch = Stopwatch()..start();
      final position = await service(maxWait: const Duration(seconds: 5))
          .acquirePosition();

      expect(position.accuracy, 8);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );

  test('al agotarse la espera envía la mejor lectura reciente', () async {
    final pending = service().acquirePosition();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    source.add(_position(accuracy: 70, at: DateTime.now()));
    source.add(_position(accuracy: 45, at: DateTime.now()));
    source.add(_position(accuracy: 60, at: DateTime.now()));

    final position = await pending;
    expect(position.accuracy, 45);
  });

  test('sin ninguna lectura lanza un error claro', () async {
    await expectLater(
      service(maxWait: const Duration(milliseconds: 100)).acquirePosition(),
      throwsA(isA<LocationException>()),
    );
  });
}
