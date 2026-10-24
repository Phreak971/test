import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/geo.dart';
import '../core/units.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/routing_service.dart';
import '../data/search_service.dart';
import '../purchases/purchases.dart';
import '../themes/map_theme.dart';
import '../themes/theme_catalog.dart';

/// Overridden in main() once SharedPreferences is ready.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('localStoreProvider'));

final searchServiceProvider = Provider<SearchService>((ref) {
  final s = SearchService();
  ref.onDispose(s.dispose);
  return s;
});

final routingServiceProvider = Provider<RoutingService>((ref) {
  final s = RoutingService();
  ref.onDispose(s.dispose);
  return s;
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final s = createPurchaseService();
  ref.onDispose(s.dispose);
  return s;
});

const _uuid = Uuid();
String newId() => _uuid.v4();

// ---------------------------------------------------------------------------
// Settings

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(localStoreProvider).loadSettings();

  void _set(AppSettings s) {
    state = s;
    unawaited(ref.read(localStoreProvider).saveSettings(s));
  }

  void selectTheme(String id) => _set(state.copyWith(themeId: id));
  void setPreferDark(bool? v) => _set(state.copyWith(preferDark: () => v));
  void setUnit(DistanceUnit u) => _set(state.copyWith(unit: u));
  void setVoice(String id) => _set(state.copyWith(voiceId: id));
  void setVoiceMuted(bool m) => _set(state.copyWith(voiceMuted: m));
  void setCarLight(String id) => _set(state.copyWith(carLightThemeId: id));
  void setCarDark(String id) => _set(state.copyWith(carDarkThemeId: id));
  void setCarAlwaysDark(bool v) => _set(state.copyWith(carAlwaysDark: v));
  void setAppIcon(String id) => _set(state.copyWith(appIcon: id));
  void completeOnboarding({List<String>? genres, String? heardFrom}) =>
      _set(state.copyWith(onboarded: true, favoriteGenres: genres, heardFrom: heardFrom));

  /// Re-reads after "Clean My Data".
  void reload() => state = ref.read(localStoreProvider).loadSettings();
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Selected theme + resolved variant.
final activeThemeProvider = Provider<({MapTheme theme, MapVariant variant})>((ref) {
  final s = ref.watch(settingsProvider);
  final theme = themeById(s.themeId);
  final variant = s.preferDark == null
      ? theme.baseVariant
      : (s.preferDark! ? MapVariant.dark : MapVariant.light);
  return (theme: theme, variant: variant);
});

// ---------------------------------------------------------------------------
// Entitlement

class EntitlementNotifier extends Notifier<Entitlement> {
  StreamSubscription<Entitlement>? _sub;

  @override
  Entitlement build() {
    final cached = ref.read(localStoreProvider).loadEntitlement();
    _sub?.cancel();
    _sub = ref.read(purchaseServiceProvider).entitlements.listen(grant);
    ref.onDispose(() => _sub?.cancel());
    return Entitlement(premium: cached.premium, lifetime: cached.lifetime);
  }

  void grant(Entitlement e) {
    final merged = Entitlement(premium: state.premium || e.premium, lifetime: state.lifetime || e.lifetime);
    state = merged;
    unawaited(ref.read(localStoreProvider).saveEntitlement(premium: merged.premium, lifetime: merged.lifetime));
  }
}

final entitlementProvider = NotifierProvider<EntitlementNotifier, Entitlement>(EntitlementNotifier.new);

/// True when [theme] can be used right now.
final themeUnlockedProvider = Provider.family<bool, String>((ref, themeId) {
  final t = themeById(themeId);
  return !t.isPremium || ref.watch(entitlementProvider).premium;
});

// ---------------------------------------------------------------------------
// Saved places

class PlacesNotifier extends Notifier<List<SavedPlace>> {
  @override
  List<SavedPlace> build() => ref.read(localStoreProvider).loadPlaces();

  void _set(List<SavedPlace> v) {
    state = List.unmodifiable(v);
    unawaited(ref.read(localStoreProvider).savePlaces(v));
  }

  SavedPlace? get home => state.where((p) => p.isHome).firstOrNull;

  SavedPlace add({required String name, required Geo location, required PlaceIcon icon, String? address, bool isHome = false}) {
    final place = SavedPlace(
      id: newId(),
      name: name.trim().isEmpty ? 'Saved place' : name.trim(),
      location: location,
      icon: isHome ? PlaceIcon.home : icon,
      createdAt: DateTime.now(),
      address: address,
      isHome: isHome,
    );
    final rest = isHome ? state.map((p) => p.isHome ? p.copyWith(isHome: false, icon: p.icon == PlaceIcon.home ? PlaceIcon.star : p.icon) : p) : state;
    _set([...rest, place]);
    return place;
  }

  void update(SavedPlace p) => _set([for (final x in state) x.id == p.id ? p : x]);

  void setHome(String id) => _set([
        for (final x in state)
          x.id == id
              ? x.copyWith(isHome: true, icon: PlaceIcon.home)
              : (x.isHome ? x.copyWith(isHome: false, icon: x.icon == PlaceIcon.home ? PlaceIcon.star : x.icon) : x),
      ]);

  void remove(String id) => _set(state.where((p) => p.id != id).toList());

  void reload() => state = ref.read(localStoreProvider).loadPlaces();
}

final placesProvider = NotifierProvider<PlacesNotifier, List<SavedPlace>>(PlacesNotifier.new);

final homePlaceProvider = Provider<SavedPlace?>((ref) => ref.watch(placesProvider).where((p) => p.isHome).firstOrNull);

// ---------------------------------------------------------------------------
// Search history

class HistoryNotifier extends Notifier<List<SearchHistoryEntry>> {
  @override
  List<SearchHistoryEntry> build() => ref.read(localStoreProvider).loadHistory();

  void record(Place p) {
    final next = [
      SearchHistoryEntry(place: p, at: DateTime.now()),
      ...state.where((e) => e.place.id != p.id),
    ].take(LocalStore.maxHistory).toList();
    state = next;
    unawaited(ref.read(localStoreProvider).saveHistory(next));
  }

  void clear() {
    state = const [];
    unawaited(ref.read(localStoreProvider).saveHistory(const []));
  }

  void reload() => state = ref.read(localStoreProvider).loadHistory();
}

final historyProvider = NotifierProvider<HistoryNotifier, List<SearchHistoryEntry>>(HistoryNotifier.new);

// ---------------------------------------------------------------------------
// Toasts

enum ToastKind { success, error, info }

class ToastMessage {
  ToastMessage(this.text, {this.kind = ToastKind.success}) : id = DateTime.now().microsecondsSinceEpoch;

  final String text;
  final ToastKind kind;
  final int id;
}

class ToastNotifier extends Notifier<ToastMessage?> {
  Timer? _t;

  @override
  ToastMessage? build() {
    ref.onDispose(() => _t?.cancel());
    return null;
  }

  void show(String text, {ToastKind kind = ToastKind.success}) {
    _t?.cancel();
    state = ToastMessage(text, kind: kind);
    _t = Timer(const Duration(milliseconds: 2600), () => state = null);
  }
}

final toastProvider = NotifierProvider<ToastNotifier, ToastMessage?>(ToastNotifier.new);

/// Remote "minimum supported version" for the force-update gate. In this
/// build it is configured at compile time; wire to a config endpoint later.
final minSupportedBuildProvider = Provider<int>((ref) => const int.fromEnvironment('MIN_BUILD', defaultValue: 0));

/// Exposed for widget tests that need deterministic time.
@visibleForTesting
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
