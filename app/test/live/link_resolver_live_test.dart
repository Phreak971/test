// Live check against real Google / OSM services. Not part of CI:
//   LIVE=1 flutter test test/live
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/map_link.dart';
import 'package:overworld/data/link_resolver.dart';
import 'package:overworld/data/search_service.dart';

void main() {
  final live = Platform.environment['LIVE'] == '1';
  final resolver = LinkResolver(search: SearchService());
  final cases = <String, (Geo, double)>{
    // short link -> /maps/place/Name,+Address/data=...1s0x... (no coordinates)
    'https://maps.app.goo.gl/2ZjYqkBPrcgeVoJS6': (const Geo(52.4845, 13.4167), 900),
    'https://maps.app.goo.gl/TmbeHMiLEfTBws9EA': (const Geo(44.4490, 26.0888), 400),
    // short link -> place with !3d!4d pin
    'https://maps.app.goo.gl/mBtbC6qXLK2baGTV9': (const Geo(34.59455, 133.75834), 30),
    'https://maps.app.goo.gl/Q6ZugPBVWvuiVb8e8': (const Geo(42.578496, 1.895566), 30),
    // short link -> /maps/search/lat,+lng
    'https://maps.app.goo.gl/FP3EV7tTUKYbmcVp7': (const Geo(39.920439, 116.331538), 30),
  };
  for (final e in cases.entries) {
    test(
      e.key,
      () async {
        final g = MapLinks.findInText('Look at this ${e.key} !')!;
        final r = await resolver.resolve(g, near: const Geo(52.52, 13.405));
        expect(r, isNotNull);
        final d = distanceM(r!.place.location, e.value.$1);
        // ignore: avoid_print
        print('${e.key} -> ${r.place.name} @ ${r.place.location} (${d.round()} m)');
        expect(d, lessThan(e.value.$2));
      },
      skip: !live,
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}
