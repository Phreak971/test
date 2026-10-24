// Runs on both the VM and the browser (`flutter test --platform chrome`),
// where Dart's bitwise operators are unsigned 32-bit.
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';

import 'polyline_encoder.dart';

void main() {
  test('polyline6 with negative coordinates decodes identically on every platform', () {
    const pts = [Geo(40.758, -73.9855), Geo(40.7612, -73.9776), Geo(-33.8688, 151.2093), Geo(-0.000001, -179.999999)];
    final back = decodePolyline(encodePolylineForTest(pts, 6), precision: 6);
    for (var i = 0; i < pts.length; i++) {
      expect(back[i].lat, closeTo(pts[i].lat, 1e-6));
      expect(back[i].lng, closeTo(pts[i].lng, 1e-6));
    }
  });
}
