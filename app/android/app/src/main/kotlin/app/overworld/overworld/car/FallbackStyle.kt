package app.overworld.overworld.car

/**
 * Minimal style used until the phone has synced its themed styles (e.g. the
 * Flutter UI was never opened). Same OpenFreeMap tiles and the same `app-*`
 * GeoJSON sources as lib/themes/style_builder.dart, but no images/glyphs, so
 * overlays are drawn as circles.
 */
object FallbackStyle {
    fun json(dark: Boolean): String {
        val bg = if (dark) "#1b1f27" else "#eef0e6"
        val water = if (dark) "#22334d" else "#a9d3f0"
        val green = if (dark) "#1f2b22" else "#d6ebc8"
        val road = if (dark) "#3b4252" else "#ffffff"
        val roadCase = if (dark) "#11141a" else "#c9c9c0"
        val major = if (dark) "#59627a" else "#ffe7a3"
        val route = "#3d7bff"
        val empty = "{\"type\":\"geojson\",\"data\":{\"type\":\"FeatureCollection\",\"features\":[]}}"
        return """
{
  "version": 8,
  "name": "Overworld fallback",
  "sources": {
    "openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet"},
    "app-route": $empty,
    "app-places": $empty,
    "app-pin": $empty,
    "app-user": $empty,
    "app-dest": $empty
  },
  "layers": [
    {"id": "background", "type": "background", "paint": {"background-color": "$bg"}},
    {"id": "park", "type": "fill", "source": "openmaptiles", "source-layer": "park", "paint": {"fill-color": "$green"}},
    {"id": "landcover", "type": "fill", "source": "openmaptiles", "source-layer": "landcover",
      "filter": ["in", ["get", "class"], ["literal", ["wood", "grass"]]], "paint": {"fill-color": "$green", "fill-opacity": 0.6}},
    {"id": "water", "type": "fill", "source": "openmaptiles", "source-layer": "water", "paint": {"fill-color": "$water"}},
    {"id": "road-casing", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["in", ["get", "class"], ["literal", ["motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service"]]],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {"line-color": "$roadCase", "line-width": ["interpolate", ["exponential", 1.5], ["zoom"], 8, 1, 18, 22]}},
    {"id": "road", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["in", ["get", "class"], ["literal", ["motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service"]]],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": ["match", ["get", "class"], ["motorway", "trunk", "primary"], "$major", "$road"],
        "line-width": ["interpolate", ["exponential", 1.5], ["zoom"], 8, 0.5, 18, 18]}},
    {"id": "app-route-casing", "type": "line", "source": "app-route", "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {"line-color": "#1a3f99", "line-width": ["interpolate", ["linear"], ["zoom"], 10, 6, 18, 18]}},
    {"id": "app-route-line", "type": "line", "source": "app-route", "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {"line-color": "$route", "line-width": ["interpolate", ["linear"], ["zoom"], 10, 4, 18, 13]}},
    {"id": "app-places", "type": "circle", "source": "app-places",
      "paint": {"circle-radius": 7, "circle-color": "#f5b400", "circle-stroke-color": "#ffffff", "circle-stroke-width": 2}},
    {"id": "app-dest", "type": "circle", "source": "app-dest",
      "paint": {"circle-radius": 9, "circle-color": "#e53935", "circle-stroke-color": "#ffffff", "circle-stroke-width": 3}},
    {"id": "app-user", "type": "circle", "source": "app-user",
      "paint": {"circle-radius": 9, "circle-color": "$route", "circle-stroke-color": "#ffffff", "circle-stroke-width": 3,
        "circle-pitch-alignment": "map"}}
  ]
}
        """.trimIndent()
    }
}
