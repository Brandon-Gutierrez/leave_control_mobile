import 'package:control_input_output/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocationProof serializa lo que el servidor valida', () {
    final proof = LocationProof(
      latitude: -17.3935,
      longitude: -66.157,
      accuracyMeters: 0,
      capturedAt: DateTime.utc(2026, 9, 25, 12),
      isMocked: false,
      vpnDetected: true,
    );
    final json = proof.toJson();
    expect(json['latitude'], -17.3935);
    expect(json['longitude'], -66.157);
    expect(json['accuracy_m'], greaterThan(0)); // el servidor exige > 0
    expect(json['location_timestamp'], '2026-09-25T12:00:00.000Z');
    expect(json['is_mocked'], false);
    expect(json['vpn_detected'], true);
  });
}
