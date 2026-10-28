import 'geo.dart';
import 'geo_uri.dart';

/// Builds and parses place links.
///
/// Overworld shares its own https link (see [shareLink]); the landing page at
/// that address hands the place to the app when it's installed and shows a
/// map otherwise. Links from other map apps are understood too (Google Maps,
/// Apple Maps, Waze, OpenStreetMap, `geo:`, `google.navigation:`,
/// `geo-navigation:`), so "Open with", the share sheet and pasting all work.
/// Short links that hide the place (`maps.app.goo.gl/...`) come back with
/// [GeoUri.unresolved] set; `LinkResolver` fetches them.
class MapLinks {
  const MapLinks(this.shareBase);

  /// Landing page base, e.g. `https://example.github.io/overworld/p/`.
  final Uri shareBase;

  static const scheme = 'overworld';

  static Map<String, String> _params(Geo at, String? name) => {
    'lat': at.lat.toStringAsFixed(5),
    'lng': at.lng.toStringAsFixed(5),
    if (name != null && name.trim().isNotEmpty) 'n': name.trim(),
  };

  Uri shareLink(Geo at, {String? name}) => shareBase.replace(queryParameters: _params(at, name));

  /// `overworld://place?...`, what the landing page opens.
  static Uri appLink(Geo at, {String? name}) => Uri(scheme: scheme, host: 'place', queryParameters: _params(at, name));

  // ------------------------------------------------------------------ export

  static String _ll(Geo at) => '${at.lat.toStringAsFixed(6)},${at.lng.toStringAsFixed(6)}';

  /// Google's documented cross-platform Maps URL: opens the Google Maps app
  /// when installed, the website otherwise. Coordinates keep the exact spot.
  static Uri googleMaps(Geo at) => Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': _ll(at)});

  static Uri googleDirections(Geo at) => Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': _ll(at)});

  static Uri appleMaps(Geo at, {String? name}) =>
      Uri.https('maps.apple.com', '/', {'ll': _ll(at), if (name != null && name.trim().isNotEmpty) 'q': name.trim()});

  static Uri openStreetMap(Geo at) => Uri.parse(
    'https://www.openstreetmap.org/?mlat=${at.lat.toStringAsFixed(6)}&mlon=${at.lng.toStringAsFixed(6)}'
    '#map=17/${at.lat.toStringAsFixed(6)}/${at.lng.toStringAsFixed(6)}',
  );

  /// Standard Android "open in a maps app" URI.
  static Uri geo(Geo at, {String? name}) {
    final label = name == null || name.trim().isEmpty ? '' : '(${Uri.encodeComponent(name.trim())})';
    return Uri.parse('geo:${_ll(at)}?q=${_ll(at)}$label');
  }

  // ------------------------------------------------------------------ import

  static final _urlInText = RegExp(
    r'''(?:https?://|geo:|google\.navigation:|geo-navigation:|overworld://)[^\s<>"']+''',
    caseSensitive: false,
  );

  /// Finds a place link inside shared text ("Times Square\nhttps://maps.app.goo.gl/..."),
  /// falling back to the text itself (a bare link or "lat, lng").
  static GeoUri? findInText(String text) {
    for (final m in _urlInText.allMatches(text)) {
      final g = parse(m[0]!.replaceAll(RegExp(r'[.,;:!?)\]]+$'), ''));
      if (g != null) return g;
    }
    return parse(text) ?? _coordinates(text);
  }

  /// "40.758, -73.9855" typed or pasted on its own.
  static GeoUri? _coordinates(String text) {
    final p = _pair(text.trim());
    return p != null && RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$').hasMatch(text) ? GeoUri(point: p) : null;
  }

  /// Parses any supported link (or a bare URL pasted as text). Null when the
  /// text isn't a place link.
  static GeoUri? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    try {
      if (lower.startsWith('geo:')) return GeoUri.parse(text);
      if (lower.startsWith('google.navigation:')) return _googleNavigation(text);
      if (lower.startsWith('geo-navigation:')) return _geoNavigation(text);
      final uri = Uri.tryParse(lower.startsWith('http') || lower.contains('://') ? text : 'https://$text');
      if (uri == null) return null;
      if (uri.scheme == scheme) return _overworld(uri);
      if (uri.scheme != 'https' && uri.scheme != 'http') return null;
      final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final path = uri.path;
      // Short and opaque links: the place is only known after fetching them.
      if (host == 'maps.app.goo.gl' ||
          host == 'share.google' ||
          host == 'g.page' ||
          (host == 'goo.gl' && path.startsWith('/maps')) ||
          (host == 'g.co' && path.startsWith('/kgs'))) {
        return GeoUri(unresolved: uri.replace(scheme: 'https'));
      }
      if (host == 'openstreetmap.org' || host == 'osm.org') return _osm(uri);
      if (host == 'maps.apple.com') return _apple(uri);
      if (host == 'waze.com' || host == 'ul.waze.com') return _waze(uri);
      if (host == 'maps.google.com' || ((host == 'google.com' || host.startsWith('google.')) && path.startsWith('/maps'))) {
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
    if (a == 0 && b == 0) return null;
    return Geo(a, b);
  }

  static String? _label(String? s) {
    final t = s?.replaceAll('+', ' ').trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 160 ? t.substring(0, 160) : t;
  }

  /// "lat,lng" at the start of one parameter.
  static Geo? _pair(String? s) {
    final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(s ?? '');
    return m == null ? null : _point(m[1], m[2]);
  }

  /// A destination value: "lat,lng" or free text.
  static GeoUri? _target(String? value, {bool navigate = false, String? label}) {
    final v = value?.replaceAll('+', ' ').trim();
    if (v == null || v.isEmpty) return null;
    final p = _pair(v);
    if (p != null && RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$').hasMatch(v)) {
      return GeoUri(point: p, label: label, navigate: navigate);
    }
    final q = _label(v);
    return q == null ? null : GeoUri(query: q, label: label, navigate: navigate);
  }

  static GeoUri? _overworld(Uri u) {
    final q = u.queryParameters;
    final p = _point(q['lat'], q['lng']);
    if (p == null) return null;
    return GeoUri(point: p, label: _label(q['n']), navigate: u.host == 'navigate' || q['navigate'] == '1');
  }

  /// `google.navigation:q=48.85,2.29&mode=d` (Android navigation intent).
  static GeoUri? _googleNavigation(String raw) {
    final body = raw.substring(raw.indexOf(':') + 1).replaceFirst(RegExp(r'^/*'), '').replaceFirst('?', '');
    final params = Uri.splitQueryString(body);
    final ll = params['ll'];
    if (ll != null) return _target(ll, navigate: true);
    return _target(params['q'], navigate: true);
  }

  /// Apple's default-navigation-app scheme:
  /// `geo-navigation:///directions?destination=...` and `/place?coordinate=...|address=...`.
  static GeoUri? _geoNavigation(String raw) {
    final u = Uri.parse(raw);
    final action = (u.host.isNotEmpty ? u.host : u.pathSegments.where((s) => s.isNotEmpty).firstOrNull ?? '').toLowerCase();
    final q = u.queryParameters;
    if (action == 'directions') return _target(q['destination'], navigate: true);
    if (action == 'place') return _target(q['coordinate']) ?? _target(q['address']);
    return _target(q['destination'], navigate: true) ?? _target(q['coordinate']) ?? _target(q['address']);
  }

  static GeoUri? _osm(Uri u) {
    final q = u.queryParameters;
    // /directions?route=lat,lng;lat,lng
    final route = q['route'];
    if (u.path.startsWith('/directions') && route != null) {
      final stops = route.split(';');
      final g = _target(stops.last, navigate: true);
      if (g != null) return g;
    }
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
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();

    // Directions: ?api=1&destination=, ?daddr=, /maps/dir/Origin/Destination/@...
    final dest = q['destination'] ?? q['daddr'];
    if (dest != null) return _target(dest.split(' to:').last, navigate: true);
    final dirIdx = segs.indexOf('dir');
    if (dirIdx >= 0) {
      final stops = segs.skip(dirIdx + 1).where((s) => !s.startsWith('@') && !s.startsWith('data=') && s != 'am=t').toList();
      final pin = _dataPins(u.path).lastOrNull;
      if (pin != null) return GeoUri(point: pin, label: stops.isEmpty ? null : _label(stops.last), navigate: true);
      if (stops.isNotEmpty) return _target(stops.last, navigate: true);
    }

    // A place's own pin (!3dLAT!4dLNG) beats the camera position (@lat,lng).
    final placeIdx = segs.indexOf('place');
    final placeSeg = placeIdx >= 0 && placeIdx + 1 < segs.length && !segs[placeIdx + 1].startsWith('@') ? segs[placeIdx + 1] : null;
    final namedPoint = placeSeg == null ? null : _target(placeSeg);
    final name = namedPoint?.point == null ? _label(placeSeg) : null;
    final pin = _dataPins(u.path).firstOrNull;
    if (pin != null) return GeoUri(point: pin, label: name);
    if (namedPoint?.point != null) return namedPoint;

    // ?q=lat,lng / ?query=lat,lng / ?ll=lat,lng (+ text q as the label)
    final text = _label(q['q'] ?? q['query']);
    for (final k in ['q', 'query', 'll', 'center', 'sll']) {
      final p = _pair(q[k]);
      if (p != null) return GeoUri(point: p, label: _pair(text) == null ? text : null);
    }
    final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(u.path);
    final camera = at == null ? null : _point(at[1], at[2]);
    if (camera != null && name != null) return GeoUri(point: camera, label: name);

    final searchIdx = segs.indexOf('search');
    final searchedSeg = searchIdx >= 0 && searchIdx + 1 < segs.length && !segs[searchIdx + 1].startsWith('@') ? segs[searchIdx + 1] : null;
    final searchedPoint = _target(searchedSeg);
    if (searchedPoint?.point != null) return searchedPoint;
    final searched = _label(searchedSeg);
    final query = text ?? name ?? searched;
    if (query != null) return GeoUri(query: query);
    // Opaque place ids (?cid=, ?ftid=) need the page.
    if (q.containsKey('cid') || q.containsKey('ftid')) return GeoUri(unresolved: u.replace(scheme: 'https'));
    if (camera != null) return GeoUri(point: camera);
    return null;
  }

  static Iterable<Geo> _dataPins(String path) sync* {
    for (final m in RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').allMatches(path)) {
      final p = _point(m[1], m[2]);
      if (p != null) yield p;
    }
  }

  static GeoUri? _apple(Uri u) {
    final q = u.queryParameters;
    final name = _label(q['q'] ?? q['name']);
    final daddr = q['daddr'] ?? q['destination'];
    if (daddr != null) return _target(daddr, navigate: true, label: _pair(daddr) != null ? name : null);
    for (final k in ['ll', 'coordinate', 'sll']) {
      final p = _pair(q[k]);
      if (p != null) return GeoUri(point: p, label: name);
    }
    final query = name ?? _label(q['address']);
    return query == null ? null : GeoUri(query: query);
  }

  /// `waze.com/ul?ll=..&navigate=yes`, `waze.com/ul?q=...`, `waze.com/ul/h{geohash}`,
  /// `waze.com/live-map/directions?to=ll.lat,lng`
  static GeoUri? _waze(Uri u) {
    final q = u.queryParameters;
    final navigate = q['navigate'] == 'yes' || u.path.contains('directions');
    final to = q['to'];
    if (to != null) {
      final g = _target(to.replaceFirst(RegExp(r'^(ll|place)\.'), ''), navigate: true);
      if (g != null) return g;
    }
    final ll = _pair(q['ll'] ?? q['latlng']);
    if (ll != null) return GeoUri(point: ll, navigate: navigate);
    final hash = RegExp(r'/ul/h([0-9b-hjkmnp-z]{4,12})', caseSensitive: false).firstMatch(u.path);
    if (hash != null) {
      final p = decodeGeohash(hash[1]!.toLowerCase());
      if (p != null) return GeoUri(point: p, navigate: navigate);
    }
    final query = _label(q['q']);
    return query == null ? null : GeoUri(query: query, navigate: navigate);
  }

  /// Standard base-32 geohash to the centre of its cell.
  static Geo? decodeGeohash(String hash) {
    const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';
    var latLo = -90.0, latHi = 90.0, lngLo = -180.0, lngHi = 180.0;
    var even = true;
    for (final ch in hash.split('')) {
      final v = alphabet.indexOf(ch);
      if (v < 0) return null;
      for (var bit = 4; bit >= 0; bit--) {
        final on = (v >> bit) & 1 == 1;
        if (even) {
          final mid = (lngLo + lngHi) / 2;
          on ? lngLo = mid : lngHi = mid;
        } else {
          final mid = (latLo + latHi) / 2;
          on ? latLo = mid : latHi = mid;
        }
        even = !even;
      }
    }
    return _point(((latLo + latHi) / 2).toString(), ((lngLo + lngHi) / 2).toString());
  }
}
