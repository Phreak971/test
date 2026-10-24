import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/geo.dart';
import '../../data/models.dart';
import '../../themes/icon_painter.dart';
import '../../themes/map_theme.dart';
import '../../themes/style_builder.dart';

LatLng toLatLng(Geo g) => LatLng(g.lat, g.lng);
Geo toGeo(LatLng l) => Geo(l.latitude, l.longitude);

/// Imperative handle used by screens to drive the map.
class GameMapController {
  MapLibreMapController? _c;
  _GameMapState? _state;

  bool get ready => _c != null;

  Future<void> flyTo(Geo target, {double? zoom, double? bearing, double? tilt, Duration duration = const Duration(milliseconds: 900)}) async {
    final c = _c;
    if (c == null) return;
    final pos = c.cameraPosition;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: toLatLng(target),
        zoom: zoom ?? math.max(pos?.zoom ?? 15, 15),
        bearing: bearing ?? pos?.bearing ?? 0,
        tilt: tilt ?? pos?.tilt ?? 0,
      )),
      duration: duration,
    );
  }

  Future<void> fitPoints(List<Geo> points, {EdgeInsets padding = const EdgeInsets.fromLTRB(60, 140, 60, 320)}) async {
    final c = _c;
    if (c == null || points.isEmpty) return;
    if (points.length == 1) return flyTo(points.first, zoom: 15);
    final (sw, ne) = bounds(points);
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: toLatLng(sw), northeast: toLatLng(ne)),
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> resetNorth() async {
    final c = _c;
    final pos = c?.cameraPosition;
    if (c == null || pos == null) return;
    await c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos.target, zoom: pos.zoom)));
  }

  CameraPosition? get camera => _c?.cameraPosition;

  Future<Geo?> visibleCenter() async {
    final pos = _c?.cameraPosition;
    return pos == null ? null : toGeo(pos.target);
  }

  void _attach(_GameMapState s, MapLibreMapController c) {
    _state = s;
    _c = c;
  }

  void _detach() {
    _state = null;
    _c = null;
  }

  /// Forces the overlay sources to be re-sent (after a style reload).
  void refresh() => _state?._pushAll();
}

/// Snapshot of everything the app draws on top of the base style.
class MapOverlayData {
  const MapOverlayData({
    this.user,
    this.userBearing = 0,
    this.places = const [],
    this.pin,
    this.dest,
    this.route,
    this.routeTraveledM = 0,
  });

  final Geo? user;
  final double userBearing;
  final List<SavedPlace> places;
  final Geo? pin;
  final Geo? dest;
  final List<Geo>? route;
  final double routeTraveledM;
}

class GameMap extends StatefulWidget {
  const GameMap({
    super.key,
    required this.controller,
    required this.theme,
    required this.variant,
    required this.overlay,
    required this.initialCenter,
    this.initialZoom = 14,
    this.onTap,
    this.onFeatureTap,
    this.onLongPress,
    this.onCameraIdle,
    this.onUserGesture,
    this.interactive = true,
  });

  final GameMapController controller;
  final MapTheme theme;
  final MapVariant variant;
  final MapOverlayData overlay;
  final Geo initialCenter;
  final double initialZoom;
  final ValueChanged<Geo>? onTap;

  /// Tap on a saved place or a themed POI: (layer id, feature properties, where).
  final void Function(String layer, Map<String, dynamic> props, Geo at)? onFeatureTap;
  final ValueChanged<Geo>? onLongPress;
  final VoidCallback? onCameraIdle;

  /// Called when the user pans the map (used to break follow mode).
  final VoidCallback? onUserGesture;
  final bool interactive;

  @override
  State<GameMap> createState() => _GameMapState();
}

class _GameMapState extends State<GameMap> {
  static final _builder = StyleBuilder();
  static final _imageCache = <String, Map<String, Uint8List>>{};

  MapLibreMapController? _c;
  late String _style;
  bool _styleReady = false;
  String? _loadedKey;
  bool _cameraMoving = false;

  String get _key => widget.theme.styleKey(widget.variant);

  @override
  void initState() {
    super.initState();
    _style = _builder.buildJson(widget.theme, widget.variant);
  }

  @override
  void didUpdateWidget(GameMap old) {
    super.didUpdateWidget(old);
    if (old.theme.id != widget.theme.id || old.variant != widget.variant) {
      setState(() {
        _styleReady = false;
        _style = _builder.buildJson(widget.theme, widget.variant);
      });
    } else if (_styleReady) {
      _pushDiff(old.overlay, widget.overlay);
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    super.dispose();
  }

  Future<Map<String, Uint8List>> _images() async {
    final key = _key;
    final cached = _imageCache[key];
    if (cached != null) return cached;
    final painter = ThemeIconPainter(widget.theme, widget.theme.palette(widget.variant));
    final imgs = await painter.all(poiIds: poiIconIds);
    _imageCache[key] = imgs;
    return imgs;
  }

  Future<void> _onStyleLoaded() async {
    final c = _c;
    if (c == null) return;
    final key = _key;
    final imgs = await _images();
    if (!mounted || key != _key) return;
    for (final e in imgs.entries) {
      try {
        await c.addImage(e.key, e.value);
      } catch (_) {
        // Image may already exist after a hot style swap.
      }
    }
    _styleReady = true;
    _loadedKey = key;
    await _pushAll();
  }

  Future<void> _pushAll() async {
    if (!_styleReady) return;
    final o = widget.overlay;
    await Future.wait([
      _set(AppLayers.userSource, _userFc(o)),
      _set(AppLayers.placesSource, _placesFc(o.places)),
      _set(AppLayers.pinSource, _pointFc(o.pin)),
      _set(AppLayers.destSource, _pointFc(o.dest)),
      _set(AppLayers.routeSource, _routeFc(o.route)),
    ]);
  }

  Future<void> _pushDiff(MapOverlayData a, MapOverlayData b) async {
    final jobs = <Future<void>>[];
    if (a.user != b.user || a.userBearing != b.userBearing) jobs.add(_set(AppLayers.userSource, _userFc(b)));
    if (!identical(a.places, b.places)) jobs.add(_set(AppLayers.placesSource, _placesFc(b.places)));
    if (a.pin != b.pin) jobs.add(_set(AppLayers.pinSource, _pointFc(b.pin)));
    if (a.dest != b.dest) jobs.add(_set(AppLayers.destSource, _pointFc(b.dest)));
    if (!identical(a.route, b.route)) jobs.add(_set(AppLayers.routeSource, _routeFc(b.route)));
    await Future.wait(jobs);
  }

  Future<void> _set(String source, Map<String, dynamic> fc) async {
    final c = _c;
    if (c == null || !_styleReady) return;
    try {
      await c.setGeoJsonSource(source, fc);
    } catch (e) {
      debugPrint('setGeoJsonSource($source) failed: $e');
    }
  }

  static Map<String, dynamic> _fc(List<Map<String, dynamic>> features) => {'type': 'FeatureCollection', 'features': features};

  static Map<String, dynamic> _point(Geo g, [Map<String, dynamic> props = const {}]) => {
        'type': 'Feature',
        'properties': props,
        'geometry': {'type': 'Point', 'coordinates': g.lngLat},
      };

  Map<String, dynamic> _userFc(MapOverlayData o) =>
      _fc([if (o.user != null) _point(o.user!, {'bearing': o.userBearing})]);

  Map<String, dynamic> _placesFc(List<SavedPlace> places) => _fc([
        for (final p in places) _point(p.location, {'id': p.id, 'name': p.name, 'icon': p.icon.name}),
      ]);

  Map<String, dynamic> _pointFc(Geo? g) => _fc([if (g != null) _point(g)]);

  Map<String, dynamic> _routeFc(List<Geo>? line) => _fc([
        if (line != null && line.length >= 2)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {'type': 'LineString', 'coordinates': [for (final g in line) g.lngLat]},
          },
      ]);

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      key: ValueKey('map-${widget.theme.id}'),
      styleString: _style,
      initialCameraPosition: CameraPosition(target: toLatLng(widget.initialCenter), zoom: widget.initialZoom),
      onMapCreated: (c) {
        _c = c;
        widget.controller._attach(this, c);
        c.addListener(_onControllerChange);
      },
      onStyleLoadedCallback: () {
        _styleReady = false;
        unawaited(_onStyleLoaded());
      },
      onMapClick: (point, ll) => unawaited(_handleTap(point, ll)),
      onMapLongClick: widget.onLongPress == null ? null : (_, ll) => widget.onLongPress!(toGeo(ll)),
      onCameraIdle: () {
        _cameraMoving = false;
        widget.onCameraIdle?.call();
      },
      trackCameraPosition: true,
      compassEnabled: false,
      rotateGesturesEnabled: widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: widget.interactive,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: const math.Point(8, 92),
      myLocationEnabled: false,
    );
  }

  Future<void> _handleTap(math.Point<double> point, LatLng ll) async {
    final c = _c;
    if (c != null && _styleReady && widget.onFeatureTap != null) {
      try {
        final hits = await c.queryRenderedFeaturesInRect(
          Rect.fromCenter(center: Offset(point.x, point.y), width: 36, height: 36),
          [AppLayers.places, AppLayers.poi],
          null,
        );
        for (final h in hits) {
          final f = (h as Map).cast<String, dynamic>();
          final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
          final layer = props.containsKey('icon') && props.containsKey('id') ? AppLayers.places : AppLayers.poi;
          final geom = (f['geometry'] as Map?)?.cast<String, dynamic>();
          final coords = (geom?['coordinates'] as List?)?.cast<num>();
          final at = coords != null && coords.length >= 2 ? Geo(coords[1].toDouble(), coords[0].toDouble()) : toGeo(ll);
          if (layer == AppLayers.places || (props['name'] is String && (props['name'] as String).isNotEmpty)) {
            widget.onFeatureTap!(layer, props, at);
            return;
          }
        }
      } catch (e) {
        debugPrint('feature query failed: $e');
      }
    }
    widget.onTap?.call(toGeo(ll));
  }

  void _onControllerChange() {
    final c = _c;
    if (c == null) return;
    if (c.isCameraMoving && !_cameraMoving) {
      _cameraMoving = true;
      widget.onUserGesture?.call();
    }
  }

  /// For debugging: which style is currently loaded.
  String? get loadedKey => _loadedKey;
}
