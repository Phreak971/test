import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/units.dart';
import 'models.dart';

/// Persisted user settings.
class AppSettings {
  const AppSettings({
    this.themeId = 'palm_metro',
    this.preferDark,
    this.unit = DistanceUnit.metric,
    this.voiceId = 'classic',
    this.voiceMuted = false,
    this.carLightThemeId = 'palm_metro',
    this.carDarkThemeId = 'palm_metro',
    this.carAlwaysDark = false,
    this.onboarded = false,
    this.favoriteGenres = const [],
    this.heardFrom,
    this.appIcon = 'default',
    this.locationPromptDismissed = false,
    this.arrivals = 0,
  });

  final String themeId;

  /// null = use the theme's native variant.
  final bool? preferDark;
  final DistanceUnit unit;
  final String voiceId;
  final bool voiceMuted;
  final String carLightThemeId;
  final String carDarkThemeId;
  final bool carAlwaysDark;
  final bool onboarded;
  final List<String> favoriteGenres;
  final String? heardFrom;
  final String appIcon;

  /// User chose "continue without location"; don't nag on launch.
  final bool locationPromptDismissed;

  /// Completed trips (drives the store-review prompt timing).
  final int arrivals;

  AppSettings copyWith({
    String? themeId,
    bool? Function()? preferDark,
    DistanceUnit? unit,
    String? voiceId,
    bool? voiceMuted,
    String? carLightThemeId,
    String? carDarkThemeId,
    bool? carAlwaysDark,
    bool? onboarded,
    List<String>? favoriteGenres,
    String? heardFrom,
    String? appIcon,
    bool? locationPromptDismissed,
    int? arrivals,
  }) => AppSettings(
    themeId: themeId ?? this.themeId,
    preferDark: preferDark != null ? preferDark() : this.preferDark,
    unit: unit ?? this.unit,
    voiceId: voiceId ?? this.voiceId,
    voiceMuted: voiceMuted ?? this.voiceMuted,
    carLightThemeId: carLightThemeId ?? this.carLightThemeId,
    carDarkThemeId: carDarkThemeId ?? this.carDarkThemeId,
    carAlwaysDark: carAlwaysDark ?? this.carAlwaysDark,
    onboarded: onboarded ?? this.onboarded,
    favoriteGenres: favoriteGenres ?? this.favoriteGenres,
    heardFrom: heardFrom ?? this.heardFrom,
    appIcon: appIcon ?? this.appIcon,
    locationPromptDismissed: locationPromptDismissed ?? this.locationPromptDismissed,
    arrivals: arrivals ?? this.arrivals,
  );

  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'preferDark': preferDark,
    'unit': unit.name,
    'voiceId': voiceId,
    'voiceMuted': voiceMuted,
    'carLightThemeId': carLightThemeId,
    'carDarkThemeId': carDarkThemeId,
    'carAlwaysDark': carAlwaysDark,
    'onboarded': onboarded,
    'favoriteGenres': favoriteGenres,
    'heardFrom': heardFrom,
    'appIcon': appIcon,
    'locationPromptDismissed': locationPromptDismissed,
    'arrivals': arrivals,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    themeId: j['themeId'] as String? ?? 'palm_metro',
    preferDark: j['preferDark'] as bool?,
    unit: DistanceUnit.parse(j['unit'] as String?),
    voiceId: j['voiceId'] as String? ?? 'classic',
    voiceMuted: j['voiceMuted'] as bool? ?? false,
    carLightThemeId: j['carLightThemeId'] as String? ?? 'palm_metro',
    carDarkThemeId: j['carDarkThemeId'] as String? ?? 'palm_metro',
    carAlwaysDark: j['carAlwaysDark'] as bool? ?? false,
    onboarded: j['onboarded'] as bool? ?? false,
    favoriteGenres: (j['favoriteGenres'] as List?)?.whereType<String>().toList() ?? const [],
    heardFrom: j['heardFrom'] as String?,
    appIcon: j['appIcon'] as String? ?? 'default',
    locationPromptDismissed: j['locationPromptDismissed'] as bool? ?? false,
    arrivals: (j['arrivals'] as num?)?.toInt() ?? 0,
  );
}

/// All local persistence. One JSON blob per concern keeps migrations simple.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kSettings = 'settings.v1';
  static const _kPlaces = 'saved_places.v1';
  static const _kHistory = 'search_history.v1';
  static const _kEntitlement = 'entitlement.v1';
  static const _kLastCamera = 'last_camera.v1';

  static const maxHistory = 20;

  /// Reads a String pref without throwing on a foreign value type.
  String? _str(String key) {
    final v = _prefs.get(key);
    return v is String ? v : null;
  }

  AppSettings loadSettings() {
    final raw = _str(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) => _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  List<SavedPlace> loadPlaces() => _decodeList(_kPlaces, SavedPlace.fromJson);

  Future<void> savePlaces(List<SavedPlace> places) => _prefs.setString(_kPlaces, jsonEncode(places.map((e) => e.toJson()).toList()));

  List<SearchHistoryEntry> loadHistory() => _decodeList(_kHistory, SearchHistoryEntry.fromJson);

  Future<void> saveHistory(List<SearchHistoryEntry> h) =>
      _prefs.setString(_kHistory, jsonEncode(h.take(maxHistory).map((e) => e.toJson()).toList()));

  /// Cached entitlement so premium works offline; refreshed from the store.
  ({bool premium, bool lifetime}) loadEntitlement() {
    try {
      final j = jsonDecode(_str(_kEntitlement) ?? '{}');
      if (j is! Map) return (premium: false, lifetime: false);
      return (premium: j['premium'] == true, lifetime: j['lifetime'] == true);
    } catch (_) {
      return (premium: false, lifetime: false);
    }
  }

  Future<void> saveEntitlement({required bool premium, required bool lifetime}) =>
      _prefs.setString(_kEntitlement, jsonEncode({'premium': premium, 'lifetime': lifetime}));

  ({double lat, double lng, double zoom})? loadLastCamera() {
    try {
      final j = jsonDecode(_str(_kLastCamera) ?? 'null');
      if (j is! Map) return null;
      final lat = j['lat'], lng = j['lng'], zoom = j['zoom'];
      if (lat is! num || lng is! num || zoom is! num) return null;
      if (!lat.isFinite || !lng.isFinite || !zoom.isFinite || lat.abs() > 90 || lng.abs() > 180) return null;
      return (lat: lat.toDouble(), lng: lng.toDouble(), zoom: zoom.toDouble().clamp(1.0, 20.0));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastCamera(double lat, double lng, double zoom) =>
      _prefs.setString(_kLastCamera, jsonEncode({'lat': lat, 'lng': lng, 'zoom': zoom}));

  /// "Clean My Data": wipes places, history and preferences but keeps the
  /// cached entitlement so a paying user isn't locked out offline.
  Future<void> clearUserData() async {
    final ent = loadEntitlement();
    await _prefs.clear();
    await saveEntitlement(premium: ent.premium, lifetime: ent.lifetime);
  }

  /// Decodes each record independently so one corrupt entry can't wipe the
  /// rest (they would be lost on the next save).
  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _str(key);
    if (raw == null) return [];
    Object? list;
    try {
      list = jsonDecode(raw);
    } catch (_) {
      return [];
    }
    if (list is! List) return [];
    final out = <T>[];
    for (final e in list) {
      try {
        out.add(f((e as Map).cast<String, dynamic>()));
      } catch (_) {
        // Skip the bad record.
      }
    }
    return out;
  }
}
