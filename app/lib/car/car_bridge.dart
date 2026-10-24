import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../nav/voice.dart';
import '../state/providers.dart';
import '../themes/icon_painter.dart';
import '../themes/map_theme.dart';
import '../themes/style_builder.dart';
import '../themes/theme_catalog.dart';

/// Phone → car (Android Auto / CarPlay) bridge.
///
/// The car UIs are native (androidx.car.app on Android, CarPlay templates on
/// iOS) and must work even when the Flutter UI was never opened, so the phone
/// pushes a self-contained snapshot that native code persists:
///
/// `sync` arguments (all keys always present):
///   lightStyle, darkStyle : String  MapLibre style JSON for the car map
///   lightIcons, darkIcons : `Map<String, Uint8List>` image name → PNG for the
///                           style (poi-*, puck, pin, dest, place-*)
///   alwaysDark            : bool
///   premium               : bool    car navigation requires Pro
///   unit                  : 'metric' | 'imperial'
///   locale                : 'en' | 'fr' | 'de' | 'it' | 'es' | 'tr'
///   voice                 : {id, name, pitch, rate}
///   muted                 : bool
///   places                : [{id, name, lat, lng, address?, isHome}]
///   history               : [{name, lat, lng, address?}]
///
/// `previewRoute` arguments: {name, lat, lng, address?}. Shows a route
/// preview on the car screen when connected.
class CarBridge {
  CarBridge([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('overworld/car');

  final MethodChannel _channel;
  String? _lastDigest;

  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> sync(Map<String, Object?> payload) async {
    if (!supported) return;
    final digest = _digest(payload);
    if (digest == _lastDigest) return;
    try {
      await _channel.invokeMethod<void>('sync', payload);
      _lastDigest = digest;
    } on MissingPluginException {
      // Native side not present (e.g. tests); nothing to do.
    } on PlatformException catch (e) {
      debugPrint('car sync failed: $e');
    }
  }

  Future<void> previewRoute(Place dest) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('previewRoute', {
        'name': dest.name,
        'lat': dest.location.lat,
        'lng': dest.location.lng,
        'address': dest.address,
      });
    } on MissingPluginException {
      // ignore
    } on PlatformException catch (e) {
      debugPrint('car preview failed: $e');
    }
  }

  String _digest(Map<String, Object?> p) {
    final shallow = Map.of(p)
      ..remove('lightIcons')
      ..remove('darkIcons');
    return jsonEncode(shallow);
  }
}

final carBridgeProvider = Provider<CarBridge>((ref) => CarBridge());

Future<Map<String, Uint8List>> _icons(MapTheme t, MapVariant v) => ThemeIconPainter(t, t.palette(v)).all(poiIds: poiIconIds);

/// Builds the sync payload from current app state.
Future<Map<String, Object?>> buildCarPayload(Ref ref) async {
  final s = ref.read(settingsProvider);
  final places = ref.read(placesProvider);
  final history = ref.read(historyProvider);
  final premium = ref.read(entitlementProvider).premium;
  final light = themeById(s.carLightThemeId);
  final dark = themeById(s.carDarkThemeId);
  final builder = StyleBuilder();
  final voice = personaById(s.voiceId);
  return {
    'lightStyle': builder.buildJson(light, MapVariant.light),
    'darkStyle': builder.buildJson(dark, MapVariant.dark),
    'lightIcons': await _icons(light, MapVariant.light),
    'darkIcons': await _icons(dark, MapVariant.dark),
    'alwaysDark': s.carAlwaysDark,
    'premium': premium,
    'unit': s.unit.name,
    'locale': PlatformDispatcher.instance.locale.languageCode,
    'voice': {'id': voice.id, 'name': voice.name, 'pitch': voice.pitch, 'rate': voice.rate},
    'muted': s.voiceMuted,
    'places': [
      for (final p in places)
        {'id': p.id, 'name': p.name, 'lat': p.location.lat, 'lng': p.location.lng, 'address': p.address, 'isHome': p.isHome},
    ],
    'history': [
      for (final h in history.take(10))
        {'name': h.place.name, 'lat': h.place.location.lat, 'lng': h.place.location.lng, 'address': h.place.address},
    ],
  };
}

/// Keeps the car snapshot fresh whenever relevant state changes.
final carSyncProvider = Provider<void>((ref) {
  ref.watch(settingsProvider);
  ref.watch(placesProvider);
  ref.watch(historyProvider);
  ref.watch(entitlementProvider);
  if (!CarBridge.supported) return;
  final bridge = ref.read(carBridgeProvider);
  Timer? debounce;
  debounce = Timer(const Duration(milliseconds: 800), () async {
    await bridge.sync(await buildCarPayload(ref));
  });
  ref.onDispose(() => debounce?.cancel());
});
