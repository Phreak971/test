import 'geo.dart';

/// Parsed `geo:` URI (RFC 5870 plus the common Android `?q=` extension).
class GeoUri {
  const GeoUri({this.point, this.label, this.query});

  final Geo? point;
  final String? label;

  /// Free-text search when no coordinates are given (`geo:0,0?q=pizza`).
  final String? query;

  static GeoUri? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'geo') return null;
    Geo? point;
    final path = uri.path.split(';').first;
    final parts = path.split(',');
    if (parts.length >= 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null && !(lat == 0 && lng == 0) && lat.abs() <= 90 && lng.abs() <= 180) {
        point = Geo(lat, lng);
      }
    }
    String? q;
    try {
      q = uri.queryParameters['q']?.trim();
    } on FormatException {
      return null; // malformed percent-encoding
    }
    if (q != null && q.isNotEmpty) {
      // "q=lat,lng(Label)"
      final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*(?:\((.*)\))?\s*$').firstMatch(q);
      if (m != null) {
        final lat = double.parse(m[1]!), lng = double.parse(m[2]!);
        if (lat.abs() <= 90 && lng.abs() <= 180) {
          return GeoUri(point: Geo(lat, lng), label: m[3]?.trim().isEmpty ?? true ? null : m[3]!.trim());
        }
      }
      if (point == null) return GeoUri(query: q);
    }
    if (point == null) return null;
    return GeoUri(point: point);
  }
}
