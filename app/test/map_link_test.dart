import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/map_link.dart';

void main() {
  final links = MapLinks(Uri.parse('https://phreak971.github.io/test/p/'));
  const here = Geo(40.758, -73.9855);

  group('share links', () {
    test('roundtrip with name', () {
      final url = links.shareLink(here, name: "Joe's Pizza & Café");
      expect(url.toString(), startsWith('https://phreak971.github.io/test/p/?lat=40.75800&lng=-73.98550&n='));
      final back = MapLinks.parse(url.toString())!;
      expect(back.point, const Geo(40.758, -73.9855));
      expect(back.label, "Joe's Pizza & Café");
    });

    test('pinned places share without a name', () {
      final url = links.shareLink(here);
      expect(url.queryParameters.containsKey('n'), isFalse);
      expect(MapLinks.parse(url.toString())!.label, isNull);
    });

    test('app scheme link from the landing page', () {
      final g = MapLinks.parse(MapLinks.appLink(here, name: 'Spot').toString())!;
      expect(g.point, const Geo(40.758, -73.9855));
      expect(g.label, 'Spot');
      expect(MapLinks.parse('overworld://place?lat=91&lng=0'), isNull);
      expect(MapLinks.parse('overworld://place?lat=abc&lng=0'), isNull);
    });

    test('a custom share domain still parses', () {
      expect(MapLinks.parse('https://maps.example.org/p/?lat=1.5&lng=2.5&n=X')!.point, const Geo(1.5, 2.5));
    });
  });

  group('other services', () {
    final cases = <String, (Geo?, String?, String?)>{
      // OpenStreetMap
      'https://www.openstreetmap.org/?mlat=40.758000&mlon=-73.985500#map=17/40.758000/-73.985500': (here, null, null),
      'https://www.openstreetmap.org/#map=15/52.5200/13.4050': (const Geo(52.52, 13.405), null, null),
      'https://osm.org/?mlat=48.8584&mlon=2.2945': (const Geo(48.8584, 2.2945), null, null),
      'https://www.openstreetmap.org/search?query=Eiffel%20Tower': (null, null, 'Eiffel Tower'),
      // Google Maps
      'https://maps.google.com/?q=40.758,-73.9855': (here, null, null),
      'https://www.google.com/maps/search/?api=1&query=40.758,-73.9855': (here, null, null),
      'https://www.google.com/maps/place/Times+Square/@40.758,-73.9855,17z': (here, 'Times Square', null),
      'https://www.google.com/maps/place/Times+Square/@40.7,-73.9,15z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d40.758!4d-73.9855': (
        here,
        'Times Square',
        null,
      ),
      'https://www.google.com/maps/@40.758,-73.9855,15z': (here, null, null),
      'https://www.google.co.uk/maps/@51.5,-0.12,12z': (const Geo(51.5, -0.12), null, null),
      'https://maps.google.com/?q=pizza+near+me': (null, null, 'pizza near me'),
      'https://www.google.com/maps/search/coffee/': (null, null, 'coffee'),
      'https://www.google.com/maps/dir/?api=1&destination=40.758,-73.9855': (here, null, null),
      // Apple Maps
      'https://maps.apple.com/?ll=40.758,-73.9855&q=Times%20Square': (here, 'Times Square', null),
      'https://maps.apple.com/?q=Central%20Park': (null, null, 'Central Park'),
      'https://maps.apple.com/?address=1%20Infinite%20Loop': (null, null, '1 Infinite Loop'),
      // geo:
      'geo:40.758,-73.9855': (here, null, null),
      'geo:0,0?q=40.758,-73.9855(Times Square)': (here, 'Times Square', null),
    };
    cases.forEach((url, want) {
      test(url, () {
        final g = MapLinks.parse(url)!;
        expect(g.point, want.$1);
        expect(g.label, want.$2);
        expect(g.query, want.$3);
      });
    });

    test('links pasted without a scheme', () {
      expect(MapLinks.parse('maps.google.com/?q=40.758,-73.9855')!.point, here);
      expect(MapLinks.parse('  www.openstreetmap.org/?mlat=40.758&mlon=-73.9855  ')!.point, here);
    });
  });

  test('rejects text and unrelated links without throwing', () {
    for (final s in [
      '',
      'pizza',
      'https://example.com/',
      'https://www.google.com/search?q=maps',
      'https://www.openstreetmap.org/',
      'mailto:a@b.c',
      'https://maps.google.com/?q=%E0%A4%A',
      'overworld://other',
      'https://www.openstreetmap.org/?mlat=999&mlon=0',
    ]) {
      expect(() => MapLinks.parse(s), returnsNormally, reason: s);
      expect(MapLinks.parse(s)?.point, isNull, reason: s);
    }
  });
}
