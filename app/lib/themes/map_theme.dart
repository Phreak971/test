import 'dart:ui' show Color;

/// Colours for one rendered variant (light or dark) of a map theme.
class MapPalette {
  const MapPalette({
    required this.land,
    required this.landAlt,
    required this.park,
    required this.water,
    required this.building,
    required this.motorway,
    required this.major,
    required this.minor,
    required this.casing,
    required this.label,
    required this.labelHalo,
    required this.poiFill,
    required this.poiGlyph,
    required this.poiStroke,
    required this.route,
    required this.routeCasing,
    required this.hudPanel,
    required this.hudText,
    required this.accent,
    int? waterLine,
    int? buildingLine,
    int? path,
    int? rail,
    int? roadLabel,
    int? roadLabelHalo,
  }) : waterLine = waterLine ?? water,
       buildingLine = buildingLine ?? building,
       path = path ?? minor,
       rail = rail ?? casing,
       roadLabel = roadLabel ?? label,
       roadLabelHalo = roadLabelHalo ?? labelHalo;

  final int land;
  final int landAlt;
  final int park;
  final int water;
  final int waterLine;
  final int building;
  final int buildingLine;
  final int motorway;
  final int major;
  final int minor;
  final int path;
  final int rail;
  final int casing;
  final int label;
  final int labelHalo;
  final int roadLabel;
  final int roadLabelHalo;
  final int poiFill;
  final int poiGlyph;
  final int poiStroke;
  final int route;
  final int routeCasing;

  /// Overlay UI chrome tinted to the theme.
  final int hudPanel;
  final int hudText;
  final int accent;

  bool get isDark => Color(land).computeLuminance() < 0.25;

  /// Generates the opposite light/dark variant: neutrals flip lightness, hues
  /// and accents are preserved so the theme stays recognisable, then key
  /// pairs are nudged until they meet minimum contrast.
  MapPalette inverted() {
    final toDark = !isDark;
    int flip(int c, {double minL = 0.08, double maxL = 0.92}) {
      final hsl = _Hsl.from(c);
      return hsl.withLightness((1 - hsl.l).clamp(minL, maxL)).toArgb();
    }

    int ground(int c) {
      final hsl = _Hsl.from(c);
      final l = 1 - hsl.l;
      return hsl.withLightness(toDark ? l.clamp(0.06, 0.2) : l.clamp(0.8, 0.94)).toArgb();
    }

    int soften(int c, double l) => _Hsl.from(c).withLightness(l).toArgb();
    final newLand = ground(land);
    // Chrome must follow the map: a "dark" variant always gets dark panels.
    final panelHsl = _Hsl.from(hudPanel);
    final panelAlreadyDark = Color(hudPanel | 0xFF000000).computeLuminance() < 0.2;
    final keepPanel = toDark && panelAlreadyDark;
    final newPanel = keepPanel
        ? hudPanel
        : panelHsl.withLightness(toDark ? panelHsl.l.clamp(0.08, 0.16) : (1 - panelHsl.l).clamp(0.9, 0.95)).toArgb();
    // Labels that already read well on the new land keep the theme's look.
    final keepLabels = contrastRatio(label, newLand) >= 4.5 && contrastRatio(label, labelHalo) >= 3;
    final newLabelHalo = flip(labelHalo);
    final newRoadHalo = flip(roadLabelHalo);
    return MapPalette(
      land: newLand,
      landAlt: ground(landAlt),
      park: ensureContrast(toDark ? soften(park, 0.18) : soften(park, 0.72), newLand, 1.3),
      water: ensureContrast(toDark ? soften(water, 0.2) : soften(water, 0.68), newLand, 1.4),
      waterLine: toDark ? soften(waterLine, 0.32) : soften(waterLine, 0.5),
      building: ground(building),
      buildingLine: flip(buildingLine),
      motorway: ensureContrast(toDark ? soften(motorway, 0.62) : soften(motorway, 0.45), newLand, 2.5),
      major: ensureContrast(flip(major, minL: 0.35, maxL: 0.9), newLand, 2.0),
      minor: ensureContrast(flip(minor, minL: 0.3, maxL: 0.95), newLand, 1.5),
      path: flip(path, minL: 0.3, maxL: 0.85),
      rail: flip(rail, minL: 0.3, maxL: 0.7),
      casing: flip(casing),
      label: keepLabels ? label : ensureContrast(flip(label), newLabelHalo, 4.5),
      labelHalo: keepLabels ? labelHalo : newLabelHalo,
      roadLabel: keepLabels ? roadLabel : ensureContrast(flip(roadLabel), newRoadHalo, 4.5),
      roadLabelHalo: keepLabels ? roadLabelHalo : newRoadHalo,
      poiFill: poiFill,
      poiGlyph: poiGlyph,
      poiStroke: poiStroke,
      route: ensureContrast(route, newLand, 2.5),
      routeCasing: routeCasing,
      hudPanel: newPanel,
      hudText: keepPanel ? hudText : ensureContrast(flip(hudText), newPanel, 7),
      accent: accent,
    );
  }
}

double contrastRatio(int a, int b) {
  final la = Color(a | 0xFF000000).computeLuminance();
  final lb = Color(b | 0xFF000000).computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Moves [fg]'s lightness away from [bg] until the WCAG contrast ratio is at
/// least [min]; falls back to black or white.
int ensureContrast(int fg, int bg, double min) {
  if (contrastRatio(fg, bg) >= min) return fg;
  final bgDark = Color(bg | 0xFF000000).computeLuminance() < 0.18;
  final hsl = _Hsl.from(fg);
  for (var i = 1; i <= 20; i++) {
    final l = bgDark ? hsl.l + (1 - hsl.l) * i / 20 : hsl.l * (1 - i / 20);
    final c = hsl.withLightness(l).toArgb();
    if (contrastRatio(c, bg) >= min) return c;
  }
  return bgDark ? 0xFFFFFFFF : 0xFF000000;
}

class _Hsl {
  const _Hsl(this.a, this.h, this.s, this.l);

  final int a;
  final double h, s, l;

  factory _Hsl.from(int argb) {
    final a = (argb >> 24) & 0xFF;
    final r = ((argb >> 16) & 0xFF) / 255, g = ((argb >> 8) & 0xFF) / 255, b = (argb & 0xFF) / 255;
    final max = [r, g, b].reduce((x, y) => x > y ? x : y);
    final min = [r, g, b].reduce((x, y) => x < y ? x : y);
    final l = (max + min) / 2;
    if (max == min) return _Hsl(a, 0, 0, l);
    final d = max - min;
    final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    double h;
    if (max == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (max == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return _Hsl(a, h / 6, s, l);
  }

  _Hsl withLightness(double nl) => _Hsl(a, h, s, nl);

  int toArgb() {
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    int c(double v) => (v * 255).round().clamp(0, 255);
    return (a << 24) | (c(r) << 16) | (c(g) << 8) | c(b);
  }
}

enum PoiShape { glyph, circle, square, hexagon, diamond, pixel, shield }

enum PuckShape { arrow, chevron, orb, block, star, compass }

/// Full-screen effect drawn above the map to sell the game look.
enum MapOverlay { none, scanlines, parchment, vignette, grid, pixelGrid, neon, starfield, hologram, embers, mist, candlelight }

enum MapVariant { light, dark }

final _invertedCache = <String, MapPalette>{};

class MapTheme {
  const MapTheme({
    required this.id,
    required this.name,
    required this.tagline,
    required this.base,
    required this.baseVariant,
    required this.poiShape,
    required this.puck,
    this.alt,
    this.overlay = MapOverlay.none,
    this.uppercaseLabels = false,
    this.italicLabels = false,
    this.labelLetterSpacing = 0.0,
    this.roadWidth = 1.0,
    this.dashedMinorRoads = false,
    this.extrudeBuildings = false,
    this.blockyBuildings = false,
    this.poiDensity = 2,
    this.hudCorner = 14,
    this.genre = '',
  });

  final String id;
  final String name;
  final String tagline;

  /// Hand-tuned palette for [baseVariant]; the other variant is derived.
  final MapPalette base;

  /// Hand-tuned palette for the other variant; derived from [base] if null.
  final MapPalette? alt;
  final MapVariant baseVariant;
  final PoiShape poiShape;
  final PuckShape puck;
  final MapOverlay overlay;
  final bool uppercaseLabels;
  final bool italicLabels;
  final double labelLetterSpacing;
  final double roadWidth;
  final bool dashedMinorRoads;
  final bool extrudeBuildings;

  /// Quantise extrusion heights into chunky steps.
  final bool blockyBuildings;

  /// 1 = sparse POIs, 3 = dense.
  final int poiDensity;
  final double hudCorner;

  /// Short genre word used in onboarding chips.
  final String genre;

  MapPalette palette(MapVariant v) => v == baseVariant ? base : (alt ?? (_invertedCache[id] ??= base.inverted()));

  String styleKey(MapVariant v) => '$id:${v.name}';
}
