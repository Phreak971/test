import 'geo.dart';
import 'geo_uri.dart';

/// Builds and parses place links.
///
/// Overworld shares its own https link (see [shareLink]); the landing page at
/// that address hands the place to the app when it's installed and shows a
/// map otherwise. Incoming links from other map services are understood too,
/// so "Open with Overworld" and pasting a link both work.
class MapLinks {
  const MapLinks(this.shareBase);

  /// Landing page base, e.g. `https://example.github.io/overworld/p/`.
  final Uri shareBase;

  static const scheme = 'overworld';

  Uri shareLink(Geo at, {String? name}) => shareBase.replace(
    queryParameters: {
      'lat': at.lat.toStringAsFixed(5),
      'lng': at.lng.toStringAsFixed(5),
      if (name != null && name.trim().isNotEmpty) 'n': name.trim(),
    },
  );

  /// `overworld://place?...`, what the landing page opens.
  static Uri appLink(Geo at, {String? name}) => Uri(
    scheme: scheme,
    host: 'place',
    queryParameters: {
      'lat': at.lat.toStringAsFixed(5),
      'lng': at.lng.toStringAsFixed(5),
      if (name != null && name.trim().isNotEmpty) 'n': name.trim(),
    },
  );

  /// Parses any supported link (or a bare URL pasted as text). Null when the
  /// text isn't a place link.
  static GeoUri? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('geo:')) return GeoUri.parse(text);
    final uri = Uri.tryParse(lower.startsWith('http') || lower.contains('://') ? text : 'https://$text');
    if (uri == null) return null;
    try {
      if (uri.scheme == scheme) return _overworld(uri);
      if (uri.scheme != 'https' && uri.scheme != 'http') return null;
      final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      if (host == 'openstreetmap.org' || host == 'osm.org') return _osm(uri);
      if (host == 'maps.apple.com') return _apple(uri);
      if (host == 'maps.google.com' || ((host == 'google.com' || host.startsWith('google.')) && uri.path.startsWith('/maps'))) {
        return _google(uri);
      }
      // Our landing page (any host: the share domain is configurable).
      if (uri.pathSegments.contains('p') && uri.queryParameters.containsKey('lat')) return _overworld(uri);
    } on FormatException {
      return null;
    }
    return null;
  }

  static Geo? _point(String? lat, String? lng) {
    final a = double.tryParse(lat?.trim() ?? ''), b = double.tryParse(lng?.trim() ?? '');
    if (a == null || b == null || !a.isFinite || !b.isFinite || a.abs() > 90 || b.abs() > 180) return null;
    return Geo(a, b);
  }

  static String? _label(String? s) {
    final t = s?.replaceAll('+', ' ').trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 120 ? t.substring(0, 120) : t;
  }

  /// "lat,lng" in one parameter.
  static Geo? _pair(String? s) {
    final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(s ?? '');
    return m == null ? null : _point(m[1], m[2]);
  }

  static GeoUri? _overworld(Uri u) {
    final q = u.queryParameters;
    final p = _point(q['lat'], q['lng']);
    if (p == null) return null;
    return GeoUri(point: p, label: _label(q['n']));
  }

  static GeoUri? _osm(Uri u) {
    final q = u.queryParameters;
    final marker = _point(q['mlat'], q['mlon']);
    if (marker != null) return GeoUri(point: marker);
    // #map=17/40.75800/-73.98550
    final m = RegExp(r'map=\d+(?:\.\d+)?/(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)').firstMatch(u.fragment);
    if (m != null) {
      final p = _point(m[1], m[2]);
      if (p != null) return GeoUri(point: p);
    }
    final query = _label(q['query']);
    return query == null ? null : GeoUri(query: query);
  }

  static GeoUri? _google(Uri u) {
    final q = u.queryParameters;
    // ?q=lat,lng / ?query=lat,lng / ?ll=lat,lng / ?destination=lat,lng
    for (final k in ['q', 'query', 'll', 'destination', 'daddr', 'center']) {
      final p = _pair(q[k]);
      if (p != null) return GeoUri(point: p);
    }
    // /maps/place/Name/@lat,lng,17z  and  /maps/@lat,lng,15z
    final segs = u.pathSegments;
    final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(u.path);
    // A place's own pin (!3dLAT!4dLNG) beats the camera position.
    final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(u.path);
    final placeIdx = segs.indexOf('place');
    final name = placeIdx >= 0 && placeIdx + 1 < segs.length && !segs[placeIdx + 1].startsWith('@') ? _label(segs[placeIdx + 1]) : null;
    final p = (pin == null ? null : _point(pin[1], pin[2])) ?? (at == null ? null : _point(at[1], at[2]));
    if (p != null) return GeoUri(point: p, label: name);
    final text = _label(q['q'] ?? q['query']) ?? name;
    final searchIdx = segs.indexOf('search');
    final searched = searchIdx >= 0 && searchIdx + 1 < segs.length ? _label(segs[searchIdx + 1]) : null;
    final query = text ?? searched;
    return query == null ? null : GeoUri(query: query);
  }

  static GeoUri? _apple(Uri u) {
    final q = u.queryParameters;
    final name = _label(q['q'] ?? q['name']);
    for (final k in ['ll', 'coordinate', 'sll', 'daddr']) {
      final p = _pair(q[k]);
      if (p != null) return GeoUri(point: p, label: name);
    }
    final query = name ?? _label(q['address']) ?? _label(q['daddr']);
    return query == null ? null : GeoUri(query: query);
  }
}
