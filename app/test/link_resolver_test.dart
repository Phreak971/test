import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/geo_uri.dart';
import 'package:overworld/core/http.dart';
import 'package:overworld/core/map_link.dart';
import 'package:overworld/data/link_resolver.dart';
import 'package:overworld/data/search_service.dart';

void main() {
  group('more link families', () {
    final cases = <String, (Geo?, String?, String?, bool)>{
      // Android navigation intent
      'google.navigation:q=48.8584,2.2945&mode=d': (const Geo(48.8584, 2.2945), null, null, true),
      'google.navigation:q=Eiffel+Tower,+Paris': (null, null, 'Eiffel Tower, Paris', true),
      // Apple default-navigation-app scheme
      'geo-navigation:///directions?source=Here&destination=48.8584,2.2945': (const Geo(48.8584, 2.2945), null, null, true),
      'geo-navigation:///place?coordinate=48.8584,2.2945': (const Geo(48.8584, 2.2945), null, null, false),
      'geo-navigation:///place?address=1%20Infinite%20Loop%20Cupertino': (null, null, '1 Infinite Loop Cupertino', false),
      // Google directions
      'https://www.google.com/maps/dir/?api=1&destination=48.8584,2.2945': (const Geo(48.8584, 2.2945), null, null, true),
      'https://maps.google.com/?saddr=Home&daddr=Louvre+Museum': (null, null, 'Louvre Museum', true),
      'https://www.google.com/maps/dir/My+Location/Louvre+Museum/@48.86,2.33,14z': (null, null, 'Louvre Museum', true),
      'https://www.google.com/maps/dir/A/B/@48.8,2.3,14z/data=!4m8!4m7!1m0!1m5!1m1!1s0x0:0x0!2m2!1d2.3376!2d48.8606!3e0': (
        null,
        null,
        'B',
        true,
      ),
      // Google place with only name + address (no coordinates in the URL)
      'https://www.google.com/maps/place/Volkspark+Hasenheide,+Columbiadamm+160,+12049+Berlin,+Germany/data=!4m2!3m1!1s0x47a8:0x922e': (
        null,
        null,
        'Volkspark Hasenheide, Columbiadamm 160, 12049 Berlin, Germany',
        false,
      ),
      'https://www.google.com/maps/search/39.920439,+116.331538?entry=tts': (const Geo(39.920439, 116.331538), null, null, false),
      'https://www.google.com/maps/place/42.578496,1.895566/data=!4m6!3m5!1s0!7e2!8m2!3d42.5784957!4d1.8955661': (
        const Geo(42.5784957, 1.8955661),
        null,
        null,
        false,
      ),
      'https://maps.google.com/?ll=40.758,-73.9855&q=Times+Square': (const Geo(40.758, -73.9855), 'Times Square', null, false),
      // Apple directions
      'https://maps.apple.com/?daddr=48.8584,2.2945&dirflg=d': (const Geo(48.8584, 2.2945), null, null, true),
      // Waze
      'https://waze.com/ul?ll=48.8584,2.2945&navigate=yes': (const Geo(48.8584, 2.2945), null, null, true),
      'https://www.waze.com/live-map/directions?to=ll.48.8584,2.2945': (const Geo(48.8584, 2.2945), null, null, true),
      'https://waze.com/ul?q=Louvre': (null, null, 'Louvre', false),
      // OSM directions
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=48.85,2.29;48.8606,2.3376': (
        const Geo(48.8606, 2.3376),
        null,
        null,
        true,
      ),
    };
    cases.forEach((url, want) {
      test(url, () {
        final g = MapLinks.parse(url)!;
        expect(g.unresolved, isNull);
        expect(g.point, want.$1);
        expect(g.label, want.$2);
        expect(g.query, want.$3);
        expect(g.navigate, want.$4);
      });
    });

    test('waze geohash links decode locally', () {
      final g = MapLinks.parse('https://waze.com/ul/hu09tunquc')!;
      expect(distanceM(g.point!, const Geo(48.8584, 2.2945)), lessThan(100));
    });

    test('short links are marked for resolving', () {
      for (final s in [
        'https://maps.app.goo.gl/2ZjYqkBPrcgeVoJS6',
        'https://goo.gl/maps/abcDEF',
        'https://share.google/diIxnYa8dIA6dZfpy',
        'https://g.co/kgs/91UYXud',
        'https://g.page/some-business',
        'https://maps.google.com/?cid=1234567890',
      ]) {
        expect(MapLinks.parse(s)!.unresolved, isNotNull, reason: s);
      }
    });

    test('finds the link inside shared text', () {
      final g = MapLinks.findInText('Volkspark Hasenheide\nColumbiadamm 160\nhttps://maps.app.goo.gl/2ZjYqkBPrcgeVoJS6.')!;
      expect(g.unresolved.toString(), 'https://maps.app.goo.gl/2ZjYqkBPrcgeVoJS6');
      expect(MapLinks.findInText('meet at 40.758, -73.9855')?.point, isNull);
      expect(MapLinks.findInText(' 40.758, -73.9855 ')!.point, const Geo(40.758, -73.9855));
    });
  });

  group('export links roundtrip', () {
    const at = Geo(48.858370, 2.294481);
    test('every exported link parses back to the same spot', () {
      for (final u in [
        MapLinks.googleMaps(at),
        MapLinks.googleDirections(at),
        MapLinks.appleMaps(at, name: 'Eiffel Tower'),
        MapLinks.openStreetMap(at),
        MapLinks.geo(at, name: 'Eiffel Tower'),
        MapLinks.appLink(at, name: 'Eiffel Tower'),
      ]) {
        final g = MapLinks.parse(u.toString())!;
        expect(distanceM(g.point!, at), lessThan(1), reason: '$u');
      }
      expect(MapLinks.parse(MapLinks.googleDirections(at).toString())!.navigate, isTrue);
      expect(MapLinks.googleMaps(at).toString(), 'https://www.google.com/maps/search/?api=1&query=48.858370%2C2.294481');
    });
  });

  group('resolver', () {
    LinkResolver make(Map<String, http.Response Function(http.Request)> routes) {
      final mock = MockClient((req) async {
        for (final e in routes.entries) {
          if (req.url.toString().startsWith(e.key)) return e.value(req);
        }
        return http.Response('not found', 404);
      });
      return LinkResolver(
        search: SearchService(client: JsonClient(client: mock)),
        client: mock,
      );
    }

    http.Response redirect(String to) => http.Response('', 302, headers: {'location': to});

    test('unwraps Android intent redirects', () async {
      final r = make({
        'https://maps.app.goo.gl/x': (_) => redirect(
          'intent://maps.app.goo.gl/x#Intent;package=com.google.android.gms;scheme=https;'
          'S.browser_fallback_url=https://www.google.com/maps/place/Spot/data%3D!4m2!3m1!8m2!3d10.5!4d20.25;end',
        ),
      });
      final g = await r.expand(Uri.parse('https://maps.app.goo.gl/x'));
      expect(g!.point, const Geo(10.5, 20.25));
      expect(g.label, 'Spot');
    });

    test('follows consent pages and multi-hop chains', () async {
      final r = make({
        'https://share.google/abc': (_) => redirect('https://www.google.com/share.google?q=abc'),
        'https://www.google.com/share.google': (_) => redirect(
          'https://consent.google.com/m?continue=${Uri.encodeComponent('https://www.google.com/search?q=Caf%C3%A9+Paari&kgmid=/g/1')}',
        ),
      });
      final g = await r.expand(Uri.parse('https://share.google/abc'));
      expect(g!.query, 'Café Paari');
    });

    test('reads coordinates from a page but ignores Google\'s default view', () {
      expect(LinkResolver.fromHtml('<meta content="https://maps.google.com/maps/api/staticmap?center=37.0625%2C-95.677068">'), isNull);
      expect(
        LinkResolver.fromHtml(r'x "https:\/\/www.google.com\/maps\/place\/A\/@1,2,3z\/data=!3d51.5!4d-0.12" y')!.point,
        const Geo(51.5, -0.12),
      );
      expect(LinkResolver.fromHtml('<meta content="Café X · Main St 1" property="og:title">')!.query, 'Café X, Main St 1');
    });

    test('dead links and network failures give null, not exceptions', () async {
      final r = make({'https://maps.app.goo.gl/dead': (_) => http.Response('gone', 404)});
      expect(await r.expand(Uri.parse('https://maps.app.goo.gl/dead')), isNull);
      final loop = make({'https://maps.app.goo.gl/loop': (_) => redirect('https://maps.app.goo.gl/loop')});
      expect(await loop.expand(Uri.parse('https://maps.app.goo.gl/loop')), isNull);
    });

    test('name + address places relax the geocoding query', () async {
      final asked = <String>[];
      final r = make({
        'https://nominatim.openstreetmap.org/search': (req) {
          final q = req.url.queryParameters['q']!;
          asked.add(q);
          if (q == 'Volkspark Hasenheide, Berlin') {
            return http.Response(
              jsonEncode([
                {
                  'lat': '52.4845',
                  'lon': '13.4167',
                  'name': 'Volkspark Hasenheide',
                  'display_name': 'Volkspark Hasenheide, Berlin',
                  'osm_id': 1,
                  'osm_type': 'way',
                },
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        },
      });
      final res = await r.resolve(const GeoUri(query: 'Volkspark Hasenheide, Columbiadamm 160, 12049 Berlin, Germany'));
      expect(asked, ['Volkspark Hasenheide, Columbiadamm 160, 12049 Berlin, Germany', 'Volkspark Hasenheide, Berlin']);
      expect(res!.place.name, 'Volkspark Hasenheide');
      expect(res.place.address, 'Columbiadamm 160, 12049 Berlin, Germany');
      expect(res.place.location, const Geo(52.4845, 13.4167));
    });

    test('navigate survives resolving', () async {
      final r = make({'https://maps.app.goo.gl/n': (_) => redirect('https://www.google.com/maps/search/1.5,+2.5')});
      final res = await r.resolve(GeoUri(unresolved: Uri.parse('https://maps.app.goo.gl/n')).withNavigate());
      expect(res!.navigate, isTrue);
      expect(res.place.location, const Geo(1.5, 2.5));
    });

    test('city heuristic', () {
      expect(LinkResolver.cityOf(['Volkspark', 'Columbiadamm 160', '12049 Berlin', 'Germany']), 'Berlin');
      expect(LinkResolver.cityOf(['RAI', 'Calea Victoriei 202 Bucureşti', 'Bucuresti 010098']), 'Bucuresti');
    });
  });
}
