import 'dart:math' as math;

import '../core/geo.dart';
import '../core/http.dart';
import 'models.dart';

/// Place search backed by Photon (autocomplete, reverse) and Nominatim
/// (category / nearby, reverse fallback). Both are OpenStreetMap based.
class SearchService {
  SearchService({
    JsonClient? client,
    this.photonBase = 'https://photon.komoot.io',
    this.nominatimBase = 'https://nominatim.openstreetmap.org',
  }) : _client = client ?? JsonClient();

  final JsonClient _client;
  final String photonBase;
  final String nominatimBase;

  static const _photonLangs = {'en', 'de', 'fr', 'it'};

  /// Autocomplete biased to [near]. Results are ordered by relevance with a
  /// nudge toward closer matches.
  Future<List<Place>> autocomplete(String query, {Geo? near, String lang = 'en', int limit = 12}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.parse('$photonBase/api/').replace(
      queryParameters: {
        'q': q,
        'limit': '$limit',
        if (_photonLangs.contains(lang)) 'lang': lang,
        if (near != null) ...{
          'lat': near.lat.toStringAsFixed(5),
          'lon': near.lng.toStringAsFixed(5),
          'location_bias_scale': '0.4',
          'zoom': '12',
        },
      },
    );
    final json = await _client.getJson(uri) as Map<String, dynamic>;
    final features = (json['features'] as List? ?? const []).cast<Map<String, dynamic>>();
    final places = <Place>[];
    final seen = <String>{};
    for (final f in features) {
      final p = photonFeatureToPlace(f);
      if (p == null) continue;
      final key = '${p.name}|${p.location.lat.toStringAsFixed(4)}|${p.location.lng.toStringAsFixed(4)}';
      if (seen.add(key)) places.add(p);
    }
    return places;
  }

  /// Best-effort human name for a coordinate. Returns null when nothing is
  /// found (open sea, service down).
  Future<Place?> reverse(Geo at, {String lang = 'en'}) async {
    try {
      final uri = Uri.parse('$photonBase/reverse').replace(
        queryParameters: {
          'lat': at.lat.toStringAsFixed(6),
          'lon': at.lng.toStringAsFixed(6),
          'limit': '1',
          if (_photonLangs.contains(lang)) 'lang': lang,
        },
      );
      final json = await _client.getJson(uri) as Map<String, dynamic>;
      final features = (json['features'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (features.isNotEmpty) {
        final p = photonFeatureToPlace(features.first);
        if (p != null) return p;
      }
    } on ApiException {
      // fall through to Nominatim
    }
    final uri = Uri.parse('$nominatimBase/reverse').replace(
      queryParameters: {
        'lat': at.lat.toStringAsFixed(6),
        'lon': at.lng.toStringAsFixed(6),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': lang,
      },
    );
    final json = await _client.getJson(uri);
    if (json is! Map<String, dynamic> || json.containsKey('error')) return null;
    return nominatimToPlace(json);
  }

  /// Places of [category] around [center], nearest first. Nominatim ranks by
  /// importance inside the box, so search a small box first and widen only
  /// when it is sparse.
  Future<List<Place>> nearby(NearbyCategory category, Geo center, {String lang = 'en', double radiusM = 3000, int limit = 25}) async {
    var results = <Place>[];
    for (final r in [radiusM / 4, radiusM, radiusM * 3]) {
      results = await _nearbyIn(category, center, lang: lang, radiusM: r, limit: limit);
      if (results.length >= 8) break;
    }
    return results;
  }

  Future<List<Place>> _nearbyIn(
    NearbyCategory category,
    Geo center, {
    required String lang,
    required double radiusM,
    required int limit,
  }) async {
    final dLat = radiusM / 111320;
    final dLng = radiusM / (111320 * math.cos(center.lat * math.pi / 180)).abs().clamp(1e-6, double.infinity);
    final uri = Uri.parse('$nominatimBase/search').replace(
      queryParameters: {
        'amenity': category.osmValue,
        'format': 'jsonv2',
        'limit': '$limit',
        'bounded': '1',
        'viewbox': '${center.lng - dLng},${center.lat + dLat},${center.lng + dLng},${center.lat - dLat}',
        'addressdetails': '1',
        'extratags': '1',
        'accept-language': lang,
      },
    );
    final json = await _client.getJson(uri) as List;
    final places = json.cast<Map<String, dynamic>>().map(nominatimToPlace).whereType<Place>().toList();
    places.sort((a, b) => distanceM(center, a.location).compareTo(distanceM(center, b.location)));
    return places;
  }

  void dispose() => _client.close();
}

String _titleCase(String s) =>
    s.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

/// Parses one Photon GeoJSON feature; null when unusable. Exposed for tests.
Place? photonFeatureToPlace(Map<String, dynamic> f) {
  try {
    return _photon(f);
  } catch (_) {
    return null; // wrongly-typed fields: skip this feature, keep the rest
  }
}

Place? _photon(Map<String, dynamic> f) {
  final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
  final coords = ((f['geometry'] as Map?)?['coordinates'] as List?)?.cast<num>();
  if (coords == null || coords.length < 2) return null;
  final street = props['street'] as String?;
  final number = props['housenumber'] as String?;
  final city = (props['city'] ?? props['town'] ?? props['village'] ?? props['locality']) as String?;
  final line1 = [if (street != null) number != null ? '$street $number' : street].join();
  final name = (props['name'] as String?) ?? (line1.isNotEmpty ? line1 : city);
  if (name == null || name.isEmpty) return null;
  final parts = <String>[
    if (line1.isNotEmpty && line1 != name) line1,
    if (city != null && city != name) city,
    if (props['state'] is String && props['state'] != city) props['state'] as String,
    if (props['country'] is String) props['country'] as String,
  ];
  final osmKey = props['osm_key'] as String?;
  final osmValue = props['osm_value'] as String?;
  return Place(
    id: 'osm:${props['osm_type'] ?? ''}${props['osm_id'] ?? '${coords[1]},${coords[0]}'}',
    name: name,
    location: Geo(coords[1].toDouble(), coords[0].toDouble()),
    address: parts.isEmpty ? null : parts.join(', '),
    category: osmValue == null || const {'yes', 'house', 'residential'}.contains(osmValue) ? null : _titleCase(osmValue),
    osmKey: osmKey,
    osmValue: osmValue,
  );
}

/// Parses one Nominatim jsonv2 result; null when unusable. Exposed for tests.
Place? nominatimToPlace(Map<String, dynamic> j) {
  try {
    return _nominatim(j);
  } catch (_) {
    return null;
  }
}

Place? _nominatim(Map<String, dynamic> j) {
  final lat = double.tryParse('${j['lat']}');
  final lon = double.tryParse('${j['lon']}');
  if (lat == null || lon == null) return null;
  final addr = (j['address'] as Map?)?.cast<String, dynamic>() ?? const {};
  final extra = (j['extratags'] as Map?)?.cast<String, dynamic>() ?? const {};
  final road = addr['road'] as String?;
  final number = addr['house_number'] as String?;
  final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb']) as String?;
  final line1 = road == null ? null : (number == null ? road : '$road $number');
  final display = j['display_name'] as String?;
  final rawName = (j['name'] as String?)?.trim();
  final name = (rawName != null && rawName.isNotEmpty) ? rawName : (line1 ?? display?.split(',').first);
  if (name == null || name.isEmpty) return null;
  final type = j['type'] as String?;
  return Place(
    id: 'osm:${j['osm_type'] ?? ''}${j['osm_id'] ?? '$lat,$lon'}',
    name: name,
    location: Geo(lat, lon),
    address: [if (line1 != name) ?line1, ?city].join(', ').ifEmpty(display),
    category: type == null || type == 'yes' ? null : _titleCase(type),
    phone: (extra['phone'] ?? extra['contact:phone']) as String?,
    website: (extra['website'] ?? extra['contact:website']) as String?,
    social: _instagramUrl((extra['contact:instagram'] ?? extra['instagram']) as String?),
    osmKey: j['category'] as String?,
    osmValue: type,
  );
}

/// Normalises an OSM instagram tag (handle or URL) to a URL.
String? _instagramUrl(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final t = v.trim();
  if (t.startsWith('http')) return t;
  return 'https://instagram.com/${t.replaceFirst('@', '')}';
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
