// QA: core math, formatters, deep-link parsing and network parsers with
// malformed input. `// BUG:` tests are expected to fail until fixed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/geo_uri.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/routing_service.dart';
import 'package:overworld/data/search_service.dart';

Map<String, dynamic> _osrm() => jsonDecode(File('test/fixtures/qa_osrm_berlin_potsdam.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('geo', () {
    test('distance/bearing across the antimeridian are short and sane', () {
      const a = Geo(-16.8, 179.999), b = Geo(-16.8, -179.999);
      expect(distanceM(a, b), closeTo(213, 5));
      expect(bearingDeg(a, b), closeTo(90, 0.5));
      expect(angleDelta(350, 10), 20);
      expect(angleDelta(10, 350), -20);
      expect(angleDelta(0, 180), 180);
      expect(angleDelta(0, -180), 180);
    });

    test('distance at the poles and identical points', () {
      expect(distanceM(const Geo(90, 0), const Geo(90, 120)), closeTo(0, 1e-6));
      expect(distanceM(const Geo(1, 1), const Geo(1, 1)), 0);
      expect(bearingDeg(const Geo(1, 1), const Geo(1, 1)).isFinite, isTrue);
      expect(distanceM(const Geo(0, 0), const Geo(0, 180)), closeTo(20015114, 2000));
    });

    // BUG: bounds() uses plain min/max longitude, so a route crossing the
    // antimeridian yields a box spanning ~360° and fitPoints() zooms the map
    // out to the whole world.
    test('bounds of points straddling the antimeridian is narrow', () {
      final (sw, ne) = bounds(const [Geo(-16.8, 179.99), Geo(-16.7, -179.99)]);
      var span = ne.lng - sw.lng;
      if (span < 0) span += 360;
      expect(span, lessThan(1), reason: 'sw=$sw ne=$ne');
    });

    // BUG: a truncated/corrupted polyline throws RangeError from
    // codeUnitAt instead of failing gracefully (it propagates out of
    // parseOsrmRoute as a non-NoRouteException).
    test('decodePolyline on a truncated string does not throw RangeError', () {
      // "_p~iF~ps|U" is (38.5, -120.2); cut it after the latitude.
      expect(() => decodePolyline('_p~iF'), returnsNormally);
    });

    test('decodePolyline roundtrips the real fixture at precision 6 and stays in range', () {
      final j = _osrm();
      final pts = decodePolyline((j['routes'] as List).first['geometry'] as String, precision: 6);
      expect(pts.first.lat, closeTo(52.516, 0.01));
      for (final p in pts) {
        expect(p.lat.abs(), lessThanOrEqualTo(90));
        expect(p.lng.abs(), lessThanOrEqualTo(180));
      }
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('units', () {
    test('metric boundaries', () {
      expect(formatDistance(0, DistanceUnit.metric), '0 m');
      expect(formatDistance(2.4, DistanceUnit.metric), '0 m');
      expect(formatDistance(97.6, DistanceUnit.metric), '100 m');
      expect(formatDistance(994, DistanceUnit.metric), '990 m');
      expect(formatDistance(995, DistanceUnit.metric), '1 km');
      expect(formatDistance(999.99, DistanceUnit.metric), '1 km');
      expect(formatDistance(1000, DistanceUnit.metric), '1.0 km');
      expect(formatDistance(123456789, DistanceUnit.metric), '123457 km');
    });

    test('imperial boundaries', () {
      expect(formatDistance(0, DistanceUnit.imperial), '0 ft');
      expect(formatDistance(160, DistanceUnit.imperial), '520 ft');
      expect(formatDistance(161, DistanceUnit.imperial), '0.1 mi');
      expect(formatDistance(-5, DistanceUnit.imperial), '0 ft');
      expect(formatDistance(double.nan, DistanceUnit.imperial), '0 ft');
    });

    // BUG (cosmetic): 9 950 m is formatted "10.0 km" while 10 000 m is "10 km"
    // (toStringAsFixed(1) rounds up across the <10 boundary). Same for miles.
    test('no "10.0" just below the 10-unit boundary', () {
      expect(formatDistance(9960, DistanceUnit.metric), '10 km');
      expect(formatDistance(9.97 * 1609.344, DistanceUnit.imperial), '10 mi');
    });

    // BUG: Infinity is not sanitised like NaN/negative: km.round() throws
    // UnsupportedError("Infinity or NaN toInt").
    test('formatDistance(Infinity) does not throw', () {
      expect(() => formatDistance(double.infinity, DistanceUnit.metric), returnsNormally);
      expect(() => formatDistance(double.infinity, DistanceUnit.imperial), returnsNormally);
    });

    // BUG: formatDuration has no NaN/Infinity guard at all:
    // (NaN / 60).round() throws UnsupportedError. Any NaN remainingS would
    // throw inside a widget build (NavBottomBar / RoutePreviewPanel).
    test('formatDuration(NaN / Infinity) does not throw', () {
      expect(() => formatDuration(double.nan), returnsNormally);
      expect(() => formatDuration(double.infinity), returnsNormally);
    });

    test('formatDuration edge cases', () {
      expect(formatDuration(-100), '<1 min');
      expect(formatDuration(29), '<1 min');
      expect(formatDuration(30), '1 min');
      expect(formatDuration(3570), '1 h');
      expect(formatDuration(3600 * 100 + 60), '100 h 1 min');
      expect(DistanceUnit.parse(null), DistanceUnit.metric);
      expect(DistanceUnit.parse('IMPERIAL'), DistanceUnit.metric);
    });
  });

  group('geo: deep links', () {
    test('accepted forms', () {
      expect(GeoUri.parse('geo:52.52,13.405')!.point, const Geo(52.52, 13.405));
      expect(GeoUri.parse('geo:52.52,13.405;u=35')!.point, const Geo(52.52, 13.405));
      expect(GeoUri.parse('geo:52.52,13.405,34.5')!.point, const Geo(52.52, 13.405));
      expect(GeoUri.parse('GEO:52.52,13.405')!.point, const Geo(52.52, 13.405));
      expect(GeoUri.parse('geo:52.52,13.405?z=12')!.point, const Geo(52.52, 13.405));
      final q = GeoUri.parse('geo:0,0?q=52.5,13.4(My%20Place)')!;
      expect(q.point, const Geo(52.5, 13.4));
      expect(q.label, 'My Place');
      expect(GeoUri.parse('geo:0,0?q=52.5,13.4()')!.label, isNull);
      expect(GeoUri.parse('geo:0,0?q=pizza+near+me')!.query, 'pizza near me');
      expect(GeoUri.parse('geo:0,0?q=Caf%C3%A9')!.query, 'Café');
    });

    test('rejected forms return null, never throw', () {
      for (final s in [
        '',
        'geo:',
        'geo:abc',
        'geo:91,0',
        'geo:0,181',
        'geo:NaN,NaN',
        'geo:Infinity,0',
        'geo:0,0',
        'http://maps.google.com/?q=1,2',
        'geo:0,0?q=',
        'geo:0,0?q=%20%20',
        'mailto:a@b.c',
      ]) {
        expect(() => GeoUri.parse(s), returnsNormally, reason: s);
        expect(GeoUri.parse(s), isNull, reason: s);
      }
    });

    test('out-of-range q coordinates fall back to a text query', () {
      expect(GeoUri.parse('geo:0,0?q=95,200')!.query, '95,200');
    });

    // BUG: malformed percent-encoding in ?q= makes Uri.queryParameters throw
    // (ArgumentError/FormatException) out of GeoUri.parse. In app.dart that
    // throws inside the AppLinks stream listener (uncaught async error).
    test('malformed percent-encoding does not throw', () {
      expect(() => GeoUri.parse('geo:0,0?q=%E0%A4%A'), returnsNormally);
      expect(() => GeoUri.parse('geo:0,0?q=100%'), returnsNormally);
    });

    test('very long query strings are handled', () {
      final long = 'a' * 20000;
      expect(GeoUri.parse('geo:0,0?q=$long')!.query!.length, 20000);
    });
  });

  group('OSRM parser with malformed JSON', () {
    test('real fixture parses; every step has a finite distance and duration', () {
      final r = parseOsrmRoute(_osrm());
      for (final s in r.steps) {
        expect(s.distanceM.isFinite && s.durationS.isFinite, isTrue);
      }
      expect(r.steps.first.kind.name, 'depart');
      expect(r.steps.last.kind.name, 'arrive');
    });

    test('error codes and missing routes raise NoRouteException', () {
      expect(() => parseOsrmRoute({'code': 'NoRoute'}), throwsA(isA<NoRouteException>()));
      expect(() => parseOsrmRoute({'code': 'Ok', 'routes': []}), throwsA(isA<NoRouteException>()));
      expect(() => parseOsrmRoute({}), throwsA(isA<NoRouteException>()));
      expect(() => parseOsrmRoute({'code': 'Ok'}), throwsA(isA<NoRouteException>()));
    });

    // BUG: structurally broken but "Ok" responses escape as TypeError /
    // RangeError instead of a domain exception, and a response with no
    // steps / empty geometry is ACCEPTED (and later crashes
    // NavigationEngine, see qa_navigation_engine_test).
    test('broken Ok responses raise NoRouteException (or are rejected)', () {
      final cases = <Map<String, dynamic>>[
        {
          'code': 'Ok',
          'routes': [
            {'geometry': 42, 'legs': [], 'distance': 1, 'duration': 1},
          ],
        },
        {
          'code': 'Ok',
          'routes': [
            {'geometry': '', 'legs': [], 'distance': 0, 'duration': 0},
          ],
        },
        {
          'code': 'Ok',
          'routes': [
            {'geometry': '_p~iF~ps|U_ulLnnqC', 'legs': null, 'distance': 1, 'duration': 1},
          ],
        },
        {
          'code': 'Ok',
          'routes': [
            {
              'geometry': '_p~iF~ps|U_ulLnnqC',
              'legs': [
                {'steps': []},
              ],
              'distance': 1,
              'duration': 1,
            },
          ],
        },
      ];
      for (final c in cases) {
        expect(() => parseOsrmRoute(c), throwsA(isA<NoRouteException>()), reason: jsonEncode(c));
      }
    });

    test('maneuver mapping covers every OSRM type/modifier without throwing', () {
      const types = [
        null,
        'turn',
        'new name',
        'depart',
        'arrive',
        'merge',
        'on ramp',
        'off ramp',
        'fork',
        'end of road',
        'continue',
        'roundabout',
        'rotary',
        'roundabout turn',
        'notification',
        'exit roundabout',
        'exit rotary',
        'use lane',
        'weird',
      ];
      const mods = [null, 'uturn', 'sharp right', 'right', 'slight right', 'straight', 'slight left', 'left', 'sharp left', 'bogus'];
      for (final t in types) {
        for (final m in mods) {
          expect(() => maneuverKind(t, m), returnsNormally);
        }
      }
    });
  });

  group('search parsers with malformed JSON', () {
    test('photon: tolerates missing pieces', () {
      expect(photonFeatureToPlace({}), isNull);
      expect(
        photonFeatureToPlace({
          'geometry': {
            'coordinates': [13.4],
          },
        }),
        isNull,
      );
      expect(
        photonFeatureToPlace({
          'geometry': {
            'coordinates': [13.4, 52.5],
          },
          'properties': {},
        }),
        isNull,
      );
      final p = photonFeatureToPlace({
        'geometry': {
          'coordinates': [13.4, 52.5],
        },
        'properties': {'street': 'Main', 'housenumber': '1'},
      });
      expect(p!.name, 'Main 1');
    });

    // BUG: one feature with a non-string field (e.g. numeric `name`, or
    // string coordinates) throws TypeError, which aborts the WHOLE
    // autocomplete call — the user sees "Search unavailable" instead of the
    // other valid results.
    test('photon: a feature with wrongly-typed fields is skipped, not thrown', () {
      expect(
        () => photonFeatureToPlace({
          'geometry': {
            'coordinates': [13.4, 52.5],
          },
          'properties': {'name': 42},
        }),
        returnsNormally,
      );
      expect(
        () => photonFeatureToPlace({
          'geometry': {
            'coordinates': ['13.4', '52.5'],
          },
          'properties': {'name': 'x'},
        }),
        returnsNormally,
      );
    });

    test('nominatim: tolerates missing / odd pieces', () {
      expect(nominatimToPlace({}), isNull);
      expect(nominatimToPlace({'lat': 'x', 'lon': '1'}), isNull);
      final p = nominatimToPlace({'lat': '52.5', 'lon': '13.4', 'display_name': 'A, B, C'});
      expect(p!.name, 'A');
      expect(p.address, 'A, B, C');
      final long = 'N' * 5000;
      expect(nominatimToPlace({'lat': 1, 'lon': 2, 'name': long})!.name.length, 5000);
    });
  });
}
