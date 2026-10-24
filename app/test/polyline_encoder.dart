import 'package:overworld/core/geo.dart';

/// Reference encoder (arithmetic only) used to cross-check the decoder.
String encodePolylineForTest(List<Geo> pts, int precision) {
  final f = precision == 6 ? 1e6 : 1e5;
  final sb = StringBuffer();
  var pLat = 0, pLng = 0;
  void enc(int v) {
    var z = v < 0 ? -2 * v - 1 : 2 * v;
    while (z >= 32) {
      sb.writeCharCode((z % 32 + 32) + 63);
      z ~/= 32;
    }
    sb.writeCharCode(z + 63);
  }

  for (final p in pts) {
    final lat = (p.lat * f).round(), lng = (p.lng * f).round();
    enc(lat - pLat);
    enc(lng - pLng);
    pLat = lat;
    pLng = lng;
  }
  return sb.toString();
}
