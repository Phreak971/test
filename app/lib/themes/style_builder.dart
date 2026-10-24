import 'dart:convert';

import 'map_theme.dart';

/// Source/layer ids the app writes into at runtime.
abstract final class AppLayers {
  static const routeSource = 'app-route';
  static const placesSource = 'app-places';
  static const pinSource = 'app-pin';
  static const userSource = 'app-user';
  static const destSource = 'app-dest';
  static const resultsSource = 'app-results';
  static const results = 'app-results';

  static const routeCasing = 'app-route-casing';
  static const routeLine = 'app-route-line';
  static const places = 'app-places';
  static const pin = 'app-pin';
  static const dest = 'app-dest';
  static const user = 'app-user';
  static const poi = 'poi-themed';

  /// Image names registered via `addImage`.
  static String poiIcon(String id) => 'poi-$id';
  static String placeIcon(String id) => 'place-$id';
  static const puck = 'puck';
  static const pinIcon = 'pin';
  static const destIcon = 'dest';
}

/// OpenMapTiles `poi.class` → our POI icon id. Anything unlisted gets `dot`.
const poiClassIcons = <String, String>{
  'restaurant': 'food',
  'fast_food': 'fastfood',
  'cafe': 'coffee',
  'ice_cream': 'coffee',
  'bakery': 'coffee',
  'bar': 'bar',
  'beer': 'bar',
  'alcohol_shop': 'bar',
  'shop': 'shop',
  'clothing_store': 'clothes',
  'grocery': 'grocery',
  'fuel': 'fuel',
  'charging_station': 'charging',
  'parking': 'parking',
  'lodging': 'hotel',
  'hospital': 'hospital',
  'doctor': 'hospital',
  'dentist': 'hospital',
  'pharmacy': 'pharmacy',
  'bank': 'bank',
  'atm': 'bank',
  'railway': 'rail',
  'bus': 'bus',
  'school': 'school',
  'college': 'school',
  'library': 'school',
  'park': 'park',
  'playground': 'park',
  'garden': 'park',
  'fitness': 'gym',
  'fitness_centre': 'gym',
  'sports': 'gym',
  'stadium': 'gym',
  'swimming': 'gym',
  'hairdresser': 'hair',
  'car': 'car',
  'cinema': 'cinema',
  'theatre': 'cinema',
  'museum': 'museum',
  'art_gallery': 'museum',
  'attraction': 'museum',
  'castle': 'museum',
  'aerialway': 'airport',
  'place_of_worship': 'worship',
};

/// Every POI icon id the style can reference.
const poiIconIds = <String>[
  'food',
  'fastfood',
  'coffee',
  'bar',
  'shop',
  'clothes',
  'grocery',
  'fuel',
  'charging',
  'parking',
  'hotel',
  'hospital',
  'pharmacy',
  'bank',
  'rail',
  'bus',
  'school',
  'park',
  'gym',
  'hair',
  'car',
  'cinema',
  'museum',
  'airport',
  'worship',
  'dot',
];

String hex(int argb) {
  final a = (argb >> 24) & 0xFF;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  if (a == 0xFF) return '#$rgb';
  return 'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},${(a / 255).toStringAsFixed(3)})';
}

const _emptyFc = {'type': 'FeatureCollection', 'features': <Object>[]};

class StyleBuilder {
  StyleBuilder({
    this.tileJsonUrl = 'https://tiles.openfreemap.org/planet',
    this.glyphsUrl = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
  });

  final String tileJsonUrl;
  final String glyphsUrl;

  String buildJson(MapTheme theme, MapVariant variant) => jsonEncode(build(theme, variant));

  Map<String, dynamic> build(MapTheme t, MapVariant variant) {
    final p = t.palette(variant);
    final w = t.roadWidth;
    final regular = [t.italicLabels ? 'Noto Sans Italic' : 'Noto Sans Regular'];
    final bold = [t.italicLabels ? 'Noto Sans Italic' : 'Noto Sans Bold'];
    final transform = t.uppercaseLabels ? 'uppercase' : 'none';
    final spacing = t.labelLetterSpacing;

    List<Object> roadWidth(double base) => [
      'interpolate',
      ['exponential', 1.5],
      ['zoom'],
      5,
      0.5 * base * w,
      12,
      1.2 * base * w,
      15,
      4 * base * w,
      18,
      18 * base * w,
      20,
      40 * base * w,
    ];

    Map<String, dynamic> roadLayer(
      String id,
      List<Object> classes,
      int color,
      double base, {
      bool casing = false,
      bool dashed = false,
      double minzoom = 5,
      bool tunnel = false,
    }) {
      return {
        'id': id,
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'minzoom': minzoom,
        'filter': [
          'all',
          [
            'match',
            ['get', 'class'],
            classes,
            true,
            false,
          ],
          if (tunnel)
            [
              '==',
              ['get', 'brunnel'],
              'tunnel',
            ]
          else
            [
              '!=',
              ['get', 'brunnel'],
              'tunnel',
            ],
        ],
        'layout': {'line-cap': dashed ? 'butt' : 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(color),
          'line-width': roadWidth(casing ? base * 1.45 : base),
          if (dashed) 'line-dasharray': [2, 1.2],
          if (tunnel) 'line-opacity': 0.5,
        },
      };
    }

    final majors = ['primary', 'secondary', 'tertiary', 'trunk'];
    final minors = ['minor', 'service', 'street', 'residential', 'living_street', 'unclassified'];

    final layers = <Map<String, dynamic>>[
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': hex(p.land)},
      },
      {
        'id': 'landuse-residential',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'landuse',
        'filter': [
          'match',
          ['get', 'class'],
          ['residential', 'suburb', 'neighbourhood', 'commercial', 'retail', 'industrial'],
          true,
          false,
        ],
        'paint': {'fill-color': hex(p.landAlt)},
      },
      {
        'id': 'landcover-green',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'landcover',
        'filter': [
          'match',
          ['get', 'class'],
          ['wood', 'grass', 'farmland', 'wetland'],
          true,
          false,
        ],
        'paint': {'fill-color': hex(p.park), 'fill-opacity': 0.7},
      },
      {
        'id': 'park',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'park',
        'paint': {'fill-color': hex(p.park)},
      },
      {
        'id': 'water',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'water',
        'filter': [
          '!=',
          ['get', 'brunnel'],
          'tunnel',
        ],
        'paint': {'fill-color': hex(p.water)},
      },
      {
        'id': 'water-edge',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'water',
        'minzoom': 11,
        'paint': {'line-color': hex(p.waterLine), 'line-width': 1.2, 'line-opacity': 0.8},
      },
      {
        'id': 'waterway',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'waterway',
        'paint': {
          'line-color': hex(p.water),
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            8,
            0.5,
            16,
            4,
          ],
        },
      },
      {
        'id': 'aeroway',
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': 'aeroway',
        'minzoom': 11,
        'paint': {'fill-color': hex(p.landAlt), 'fill-opacity': 0.8},
      },
      if (t.extrudeBuildings)
        {
          'id': 'building-3d',
          'type': 'fill-extrusion',
          'source': 'openmaptiles',
          'source-layer': 'building',
          'minzoom': 14,
          'paint': {
            'fill-extrusion-color': hex(p.building),
            'fill-extrusion-height': t.blockyBuildings
                ? [
                    '*',
                    6,
                    [
                      'ceil',
                      [
                        '/',
                        [
                          'coalesce',
                          ['get', 'render_height'],
                          6,
                        ],
                        6,
                      ],
                    ],
                  ]
                : [
                    'coalesce',
                    ['get', 'render_height'],
                    6,
                  ],
            'fill-extrusion-base': [
              'coalesce',
              ['get', 'render_min_height'],
              0,
            ],
            'fill-extrusion-opacity': 0.85,
          },
        }
      else ...[
        {
          'id': 'building',
          'type': 'fill',
          'source': 'openmaptiles',
          'source-layer': 'building',
          'minzoom': 13,
          'paint': {'fill-color': hex(p.building), 'fill-outline-color': hex(p.buildingLine)},
        },
      ],
      roadLayer('road-tunnel', [...majors, 'motorway', ...minors], p.minor, 0.7, tunnel: true, minzoom: 12),
      roadLayer('road-path', ['path', 'track'], p.path, 0.35, dashed: true, minzoom: 14),
      roadLayer('road-minor-casing', minors, p.casing, 0.7, casing: true, minzoom: 12),
      roadLayer('road-major-casing', majors, p.casing, 1.0, casing: true, minzoom: 8),
      roadLayer('road-motorway-casing', ['motorway'], p.casing, 1.25, casing: true, minzoom: 5),
      roadLayer('road-minor', minors, p.minor, 0.7, dashed: t.dashedMinorRoads, minzoom: 12),
      roadLayer('road-major', majors, p.major, 1.0, minzoom: 8),
      roadLayer('road-motorway', ['motorway'], p.motorway, 1.25, minzoom: 5),
      {
        'id': 'rail',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'transportation',
        'minzoom': 11,
        'filter': [
          'match',
          ['get', 'class'],
          ['rail', 'transit'],
          true,
          false,
        ],
        'paint': {
          'line-color': hex(p.rail),
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            0.6,
            18,
            2.5,
          ],
          'line-dasharray': [3, 2],
        },
      },
      {
        'id': 'boundary',
        'type': 'line',
        'source': 'openmaptiles',
        'source-layer': 'boundary',
        'filter': [
          '<=',
          ['get', 'admin_level'],
          4,
        ],
        'paint': {
          'line-color': hex(p.label),
          'line-opacity': 0.35,
          'line-dasharray': [4, 2],
          'line-width': 1,
        },
      },
      // App: route under labels so street names stay readable.
      {
        'id': AppLayers.routeCasing,
        'type': 'line',
        'source': AppLayers.routeSource,
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(p.routeCasing),
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            7,
            18,
            20,
          ],
        },
      },
      {
        'id': AppLayers.routeLine,
        'type': 'line',
        'source': AppLayers.routeSource,
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': hex(p.route),
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            4,
            18,
            13,
          ],
        },
      },
      {
        'id': 'road-label',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'transportation_name',
        'minzoom': 13,
        'filter': [
          'match',
          ['get', 'class'],
          ['motorway', ...majors, ...minors],
          true,
          false,
        ],
        'layout': {
          'symbol-placement': 'line',
          'text-field': [
            'coalesce',
            ['get', 'name:latin'],
            ['get', 'name'],
          ],
          'text-font': regular,
          'text-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            13,
            10,
            18,
            14,
          ],
          'text-transform': transform,
          'text-letter-spacing': spacing,
          'text-max-angle': 30,
        },
        'paint': {'text-color': hex(p.roadLabel), 'text-halo-color': hex(p.roadLabelHalo), 'text-halo-width': 1.6},
      },
      {
        'id': 'water-label',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'water_name',
        'layout': {
          'text-field': [
            'coalesce',
            ['get', 'name:latin'],
            ['get', 'name'],
          ],
          'text-font': ['Noto Sans Italic'],
          'text-size': 13,
          'text-letter-spacing': 0.1,
        },
        'paint': {'text-color': hex(p.waterLine), 'text-halo-color': hex(p.water), 'text-halo-width': 1},
      },
      {
        'id': AppLayers.poi,
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'poi',
        'minzoom': 14,
        'filter': [
          '<=',
          ['get', 'rank'],
          8 + t.poiDensity * 8,
        ],
        'layout': {
          'icon-image': [
            'concat',
            'poi-',
            [
              'match',
              ['get', 'class'],
              ...poiClassIcons.entries.expand((e) => [e.key, e.value]),
              'dot',
            ],
          ],
          'icon-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            14,
            0.55,
            18,
            0.8,
          ],
          'icon-allow-overlap': false,
          'icon-padding': 4,
          'text-field': [
            'step',
            ['zoom'],
            '',
            17,
            [
              'coalesce',
              ['get', 'name:latin'],
              ['get', 'name'],
            ],
          ],
          'text-font': regular,
          'text-size': 11,
          'text-offset': [0, 1.4],
          'text-anchor': 'top',
          'text-optional': true,
          'text-transform': transform,
        },
        'paint': {'text-color': hex(p.label), 'text-halo-color': hex(p.labelHalo), 'text-halo-width': 1.4},
      },
      {
        'id': 'place-label',
        'type': 'symbol',
        'source': 'openmaptiles',
        'source-layer': 'place',
        'filter': [
          'match',
          ['get', 'class'],
          ['city', 'town', 'village', 'suburb', 'neighbourhood', 'quarter'],
          true,
          false,
        ],
        'layout': {
          'text-field': [
            'coalesce',
            ['get', 'name:latin'],
            ['get', 'name'],
          ],
          'text-font': bold,
          // One zoom interpolation with per-class sizes at each stop (the
          // style spec allows only a single zoom curve per expression).
          'text-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            6,
            [
              'match',
              ['get', 'class'],
              'city',
              13,
              'town',
              10,
              9,
            ],
            11,
            [
              'match',
              ['get', 'class'],
              'city',
              18,
              'town',
              14,
              10,
            ],
            14,
            [
              'match',
              ['get', 'class'],
              'city',
              22,
              'town',
              18,
              13,
            ],
            16,
            [
              'match',
              ['get', 'class'],
              'city',
              24,
              'town',
              20,
              14,
            ],
          ],
          'text-transform': transform,
          'text-letter-spacing': spacing + 0.04,
          'text-max-width': 8,
        },
        'paint': {'text-color': hex(p.label), 'text-halo-color': hex(p.labelHalo), 'text-halo-width': 2},
      },
      // App overlay symbols, always on top.
      {
        'id': AppLayers.results,
        'type': 'symbol',
        'source': AppLayers.resultsSource,
        'layout': {
          'icon-image': [
            'concat',
            'poi-',
            ['get', 'icon'],
          ],
          'icon-size': 0.8,
          'icon-allow-overlap': true,
          'text-field': [
            'step',
            ['zoom'],
            '',
            14,
            ['get', 'name'],
          ],
          'text-font': bold,
          'text-size': 11,
          'text-offset': [0, 1.5],
          'text-anchor': 'top',
          'text-optional': true,
        },
        'paint': {'text-color': hex(p.label), 'text-halo-color': hex(p.labelHalo), 'text-halo-width': 1.6},
      },
      {
        'id': AppLayers.places,
        'type': 'symbol',
        'source': AppLayers.placesSource,
        'layout': {
          'icon-image': [
            'concat',
            'place-',
            ['get', 'icon'],
          ],
          'icon-size': 0.75,
          'icon-allow-overlap': true,
          'icon-anchor': 'bottom',
          'text-field': ['get', 'name'],
          'text-font': bold,
          'text-size': 12,
          'text-offset': [0, 0.3],
          'text-anchor': 'top',
          'text-optional': true,
        },
        'paint': {'text-color': hex(p.label), 'text-halo-color': hex(p.labelHalo), 'text-halo-width': 1.6},
      },
      {
        'id': AppLayers.dest,
        'type': 'symbol',
        'source': AppLayers.destSource,
        'layout': {'icon-image': AppLayers.destIcon, 'icon-size': 0.8, 'icon-allow-overlap': true, 'icon-anchor': 'bottom'},
      },
      {
        'id': AppLayers.pin,
        'type': 'symbol',
        'source': AppLayers.pinSource,
        'layout': {'icon-image': AppLayers.pinIcon, 'icon-size': 0.8, 'icon-allow-overlap': true, 'icon-anchor': 'bottom'},
      },
      {
        'id': AppLayers.user,
        'type': 'symbol',
        'source': AppLayers.userSource,
        'layout': {
          'icon-image': AppLayers.puck,
          'icon-size': 0.6,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          'icon-rotate': ['get', 'bearing'],
          'icon-rotation-alignment': 'map',
          'icon-pitch-alignment': 'map',
        },
      },
    ];

    return {
      'version': 8,
      'name': '${t.name} (${variant.name})',
      'metadata': {'overworld:theme': t.id, 'overworld:variant': variant.name},
      'glyphs': glyphsUrl,
      'sources': {
        'openmaptiles': {'type': 'vector', 'url': tileJsonUrl},
        for (final id in [
          AppLayers.routeSource,
          AppLayers.placesSource,
          AppLayers.pinSource,
          AppLayers.userSource,
          AppLayers.destSource,
          AppLayers.resultsSource,
        ])
          id: {'type': 'geojson', 'data': _emptyFc},
      },
      'layers': layers,
    };
  }
}
