import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/geo.dart';
import '../core/geo_uri.dart';
import '../core/map_link.dart';
import 'models.dart';
import 'search_service.dart';

/// A link turned into a concrete place.
class ResolvedLink {
  const ResolvedLink(this.place, {this.navigate = false});

  final Place place;

  /// Start route preview instead of just showing the place.
  final bool navigate;
}

/// Turns any supported map link into a [Place]:
/// - short links (`maps.app.goo.gl`, `share.google`, `g.co/kgs`, `goo.gl/maps`)
///   are expanded by following their redirects (unwrapping Android
///   `intent://` fallbacks and consent pages);
/// - links that only name a place ("Name, Street 1, City") are geocoded,
///   relaxing the query step by step, because Google's place URLs often carry
///   no coordinates at all.
class LinkResolver {
  LinkResolver({required this.search, http.Client? client, this.timeout = const Duration(seconds: 8)}) : _http = client ?? http.Client();

  final SearchService search;
  final http.Client _http;
  final Duration timeout;

  /// Desktop UA: Google answers short links with a plain https redirect
  /// rather than an Android intent.
  static const _ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// Google's server-rendered default view (centre of the USA), not a place.
  static const _googleDefault = Geo(37.0625, -95.677068);

  Future<ResolvedLink?> resolve(GeoUri link, {Geo? near, String lang = 'en', String? pinnedName}) async {
    var g = link;
    if (g.unresolved != null) {
      final expanded = await expand(g.unresolved!);
      if (expanded == null) return null;
      g = link.navigate ? expanded.withNavigate() : expanded;
    }
    final at = g.point;
    if (at != null) {
      return ResolvedLink(
        Place(
          id: 'link:${at.lat.toStringAsFixed(6)},${at.lng.toStringAsFixed(6)}',
          name: g.label ?? pinnedName ?? '',
          location: at,
          isPinned: g.label == null,
        ),
        navigate: g.navigate,
      );
    }
    final q = g.query ?? g.label;
    if (q == null) return null;
    final p = await placeFor(q, near: near, lang: lang);
    return p == null ? null : ResolvedLink(p, navigate: g.navigate);
  }

  /// Follows a short link to the place it points at.
  Future<GeoUri?> expand(Uri start) async {
    if (kIsWeb) return null; // browsers can't read cross-origin redirects
    var u = start;
    for (var hop = 0; hop < 8; hop++) {
      final req = http.Request('GET', u)
        ..followRedirects = false
        ..headers['User-Agent'] = _ua
        ..headers['Accept-Language'] = 'en';
      final http.StreamedResponse res;
      try {
        res = await _http.send(req).timeout(timeout);
      } on Exception {
        return null;
      }
      final loc = res.headers['location'];
      if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
        unawaited(res.stream.drain<void>().catchError((_) {}));
        final next = nextHop(u, loc);
        if (next == null) return null;
        final g = fromUrl(next);
        if (g != null && g.unresolved == null) return g;
        u = next;
        continue;
      }
      if (res.statusCode == 200) {
        final body = await _readCapped(res.stream, 2 << 20);
        return fromHtml(body);
      }
      unawaited(res.stream.drain<void>().catchError((_) {}));
      return null;
    }
    return null;
  }

  /// Resolves one redirect target, unwrapping Android intents and consent
  /// interstitials. Exposed for tests.
  static Uri? nextHop(Uri from, String location) {
    final intent = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(location);
    if (location.startsWith('intent:')) {
      if (intent == null) return null;
      return Uri.tryParse(Uri.decodeComponent(intent[1]!));
    }
    final next = from.resolve(location);
    if (next.host.startsWith('consent.')) {
      final c = next.queryParameters['continue'];
      if (c != null) return Uri.tryParse(c);
    }
    return next;
  }

  /// What a redirect target tells us: a map link, or (for Google Search
  /// bounces from share.google / g.co) the searched place name.
  static GeoUri? fromUrl(Uri u) {
    final g = MapLinks.parse(u.toString());
    if (g != null) return g;
    if (u.host.contains('google.') && u.path == '/search') {
      final q = u.queryParameters['q']?.trim();
      if (q != null && q.isNotEmpty) return GeoUri(query: q);
    }
    return null;
  }

  /// Last resort: coordinates or a maps URL inside a fetched page.
  static GeoUri? fromHtml(String html) {
    final text = html.replaceAll(r'=', '=').replaceAll(r'&', '&').replaceAll(r'\/', '/');
    for (final m in RegExp(r'''https://(?:www\.)?google\.[a-z.]+/maps/[^"'\s<>\\]+''').allMatches(text)) {
      final g = MapLinks.parse(m[0]!);
      if (g?.point != null && distanceM(g!.point!, _googleDefault) > 1000) return g;
    }
    for (final re in [
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'center=(-?\d+\.\d+)%2C(-?\d+\.\d+)'),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
    ]) {
      for (final m in re.allMatches(text)) {
        final lat = double.parse(m[1]!), lng = double.parse(m[2]!);
        if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) continue;
        final p = Geo(lat, lng);
        if (distanceM(p, _googleDefault) > 1000) return GeoUri(point: p);
      }
    }
    final title = RegExp(r'<meta content="([^"]+)" property="og:title"').firstMatch(text)?[1];
    if (title != null && title != 'Google Maps') return GeoUri(query: title.split(' · ').join(', '));
    return null;
  }

  /// Geocodes "Name, Street 1, 12345 City, Country" robustly: full text,
  /// then name + city, then the address alone (keeping the name), then a
  /// nearby name search.
  Future<Place?> placeFor(String query, {Geo? near, String lang = 'en'}) async {
    final parts = query.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final name = parts.first;
    final address = parts.length > 1 ? parts.skip(1).join(', ') : null;
    Place named(Place p) => p.copyWith(name: name, address: address ?? p.address);

    final attempts = <Future<Place?> Function()>[
      () => search.geocode(query, lang: lang),
      if (parts.length > 1) () => search.geocode('$name, ${cityOf(parts)}', lang: lang),
      if (address != null) () => search.geocode(address, lang: lang),
      () async => (await search.autocomplete(query, near: near, lang: lang, limit: 1)).firstOrNull,
      if (parts.length > 1) () async => (await search.autocomplete(name, near: near, lang: lang, limit: 1)).firstOrNull,
    ];
    for (var i = 0; i < attempts.length; i++) {
      try {
        final p = await attempts[i]();
        if (p != null) return parts.length > 1 ? named(p) : p;
      } catch (_) {
        // Try the next, looser query.
      }
      // Nominatim's usage policy: at most one request per second.
      if (i < 2) await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    return null;
  }

  /// The locality: "Name, Street, 12049 Berlin, Germany" → "Berlin";
  /// "Name, Street 1 City, City 010098" → "City".
  static String cityOf(List<String> parts) {
    final candidate = parts.length >= 4 ? parts[parts.length - 2] : parts.last;
    final words = candidate.split(RegExp(r'\s+')).where((w) => !RegExp(r'\d').hasMatch(w)).join(' ').trim();
    return words.isEmpty ? candidate : words;
  }

  static Future<String> _readCapped(Stream<List<int>> stream, int maxBytes) async {
    final buf = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      buf.add(chunk);
      if (buf.length >= maxBytes) break;
    }
    return utf8.decode(buf.takeBytes(), allowMalformed: true);
  }

  void dispose() => _http.close();
}
