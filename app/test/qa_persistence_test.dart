// QA: persistence corruption handling, settings/history/places invariants.
// `// BUG:` tests are expected to fail until fixed.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/repositories.dart';
import 'package:overworld/state/providers.dart';

import 'helpers.dart';

Future<(TestEnv, ProviderContainer)> _container([Map<String, Object> prefs = const {}]) async {
  final env = await makeEnv(prefs: prefs);
  final c = ProviderContainer(overrides: env.overrides);
  addTearDown(c.dispose);
  return (env, c);
}

Map<String, dynamic> _placeJson(String id, {bool home = false}) => SavedPlace(
  id: id,
  name: 'P $id',
  location: const Geo(52.5, 13.4),
  icon: home ? PlaceIcon.home : PlaceIcon.star,
  createdAt: DateTime(2025, 1, 1),
  isHome: home,
).toJson();

// The editor's icon picker excludes the home icon.
final _pickable = PlaceIcon.values.where((i) => i != PlaceIcon.home).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('corrupted SharedPreferences', () {
    test('corrupted settings/places/history blobs fall back to defaults', () async {
      final (env, c) = await _container({'settings.v1': '{not json', 'saved_places.v1': '[{"id": 1}]', 'search_history.v1': '"oops"'});
      expect(c.read(settingsProvider).themeId, 'palm_metro');
      expect(c.read(placesProvider), isEmpty);
      expect(c.read(historyProvider), isEmpty);
      expect(env.store.loadSettings().unit, DistanceUnit.metric);
    });

    // BUG (crash): loadEntitlement() has no try/catch. A corrupted
    // 'entitlement.v1' throws FormatException from EntitlementNotifier.build,
    // which OverworldApp.build watches on every launch -> app can't start,
    // and "Clean My Data" (clearUserData) throws too.
    test('corrupted entitlement blob does not throw', () async {
      final (env, c) = await _container({'entitlement.v1': '{"premium": tru'});
      expect(() => c.read(entitlementProvider), returnsNormally);
      expect(() => env.store.loadEntitlement(), returnsNormally);
      await expectLater(env.store.clearUserData(), completes);
    });

    test('entitlement blob with wrong value types does not throw', () async {
      final (env, _) = await _container({'entitlement.v1': '{"premium": "yes", "lifetime": 1}'});
      expect(() => env.store.loadEntitlement(), returnsNormally);
    });

    // BUG (crash): loadLastCamera() has no try/catch and force-casts every
    // field; HomeScreen.initState calls it, so a bad blob (or one missing
    // 'zoom') crashes the home screen on every launch.
    test('corrupted or partial last-camera blob returns null instead of throwing', () async {
      for (final raw in ['{bad', '{"lat": 1, "lng": 2}', '{"lat": "1", "lng": 2, "zoom": 3}', '[]']) {
        final (env, _) = await _container({'last_camera.v1': raw});
        expect(() => env.store.loadLastCamera(), returnsNormally, reason: raw);
      }
    });

    test('saveLastCamera with NaN throws synchronously (jsonEncode) — guard callers', () async {
      // Documents current behaviour: jsonEncode rejects NaN. HomeScreen's
      // _onCameraIdle would surface this as an unhandled async error.
      final (env, _) = await _container();
      expect(() => env.store.saveLastCamera(double.nan, 0, 10), throwsA(anything));
    });

    // BUG: a key holding a non-String value (e.g. written by an older build
    // or a native module with the same key) makes SharedPreferences.getString
    // throw TypeError OUTSIDE the try block of every load* method.
    test('non-string values under our keys do not throw', () async {
      final (env, _) = await _container({'settings.v1': 5, 'saved_places.v1': true, 'search_history.v1': 1.5});
      expect(() => env.store.loadSettings(), returnsNormally);
      expect(() => env.store.loadPlaces(), returnsNormally);
      expect(() => env.store.loadHistory(), returnsNormally);
    });

    // BUG: favoriteGenres is decoded with a lazy `.cast<String>()`, so a
    // non-string element passes loadSettings' try/catch and only throws
    // later — synchronously inside SettingsNotifier._set -> jsonEncode — so
    // EVERY settings change (theme, units, voice...) throws.
    test('bad favoriteGenres element does not break later settings changes', () async {
      final (_, c) = await _container({
        'settings.v1': jsonEncode({
          'themeId': 'palm_metro',
          'favoriteGenres': [1, 2],
        }),
      });
      expect(() => c.read(settingsProvider.notifier).setUnit(DistanceUnit.imperial), returnsNormally);
    });

    // BUG (data loss): one malformed record makes _decodeList return [] for
    // the whole list; the next savePlaces() then overwrites storage, so ALL
    // saved places are lost permanently.
    test('one malformed saved place does not wipe the other places', () async {
      final raw = jsonEncode([
        _placeJson('a'),
        {'id': 'b', 'name': 'broken'},
        _placeJson('c'),
      ]);
      final (env, _) = await _container({'saved_places.v1': raw});
      expect(env.store.loadPlaces().map((p) => p.id), ['a', 'c']);
    });
  });

  group('settings', () {
    test('json roundtrip preserves every field', () {
      const s = AppSettings(
        themeId: 'x',
        preferDark: true,
        unit: DistanceUnit.imperial,
        voiceId: 'ranger',
        voiceMuted: true,
        carLightThemeId: 'a',
        carDarkThemeId: 'b',
        carAlwaysDark: true,
        onboarded: true,
        favoriteGenres: ['retro', 'sci-fi'],
        heardFrom: 'tiktok',
        appIcon: 'neon',
      );
      final r = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(r.toJson(), s.toJson());
    });

    test('copyWith: preferDark closure can clear, other fields are kept', () {
      const s = AppSettings(preferDark: true, voiceId: 'ranger', favoriteGenres: ['a']);
      expect(s.copyWith(preferDark: () => null).preferDark, isNull);
      expect(s.copyWith(unit: DistanceUnit.imperial).preferDark, isTrue);
      expect(s.copyWith(unit: DistanceUnit.imperial).voiceId, 'ranger');
      expect(s.copyWith().toJson(), s.toJson());
    });

    test('fromJson ignores unknown keys and fills defaults', () {
      final s = AppSettings.fromJson({'zzz': 1, 'unit': 'furlongs'});
      expect(s.toJson(), const AppSettings().toJson());
    });

    test('notifier persists every change', () async {
      final (env, c) = await _container();
      final n = c.read(settingsProvider.notifier);
      n
        ..selectTheme('t1')
        ..setPreferDark(false)
        ..setUnit(DistanceUnit.imperial)
        ..setVoice('getaway')
        ..setVoiceMuted(true)
        ..setCarAlwaysDark(true)
        ..completeOnboarding(genres: ['g'], heardFrom: 'friend');
      await Future<void>.delayed(Duration.zero);
      expect(env.store.loadSettings().toJson(), c.read(settingsProvider).toJson());
    });
  });

  group('history', () {
    Place place(int i) => Place(id: 'osm:N$i', name: 'Place $i', location: Geo(52 + i / 1000, 13));

    test('caps at maxHistory, newest first, dedupes by id', () async {
      final (env, c) = await _container();
      final n = c.read(historyProvider.notifier);
      for (var i = 0; i < 35; i++) {
        n.record(place(i));
      }
      var h = c.read(historyProvider);
      expect(h, hasLength(LocalStore.maxHistory));
      expect(h.first.place.id, 'osm:N34');
      n.record(place(20));
      h = c.read(historyProvider);
      expect(h, hasLength(LocalStore.maxHistory));
      expect(h.first.place.id, 'osm:N20');
      expect(h.map((e) => e.place.id).toSet().length, h.length);
      await Future<void>.delayed(Duration.zero);
      expect(env.store.loadHistory().map((e) => e.place.id), h.map((e) => e.place.id));
      n.clear();
      expect(c.read(historyProvider), isEmpty);
      expect(env.store.loadHistory(), isEmpty);
    });

    test('very long names roundtrip', () async {
      final (env, c) = await _container();
      final long = 'Ä' * 10000;
      c.read(historyProvider.notifier).record(Place(id: 'x', name: long, location: const Geo(0, 0)));
      await Future<void>.delayed(Duration.zero);
      expect(env.store.loadHistory().single.place.name, long);
    });
  });

  group('places invariants (property-style, seeded)', () {
    for (final seed in [1, 2, 3, 4, 5, 42, 1337]) {
      test('random add/setHome/update/remove keeps <=1 home (seed $seed)', () async {
        final (env, c) = await _container();
        final n = c.read(placesProvider.notifier);
        final rnd = math.Random(seed);
        for (var step = 0; step < 400; step++) {
          final cur = c.read(placesProvider);
          switch (rnd.nextInt(6)) {
            case 0:
            case 1:
              n.add(
                name: rnd.nextBool() ? '  ' : 'P$step',
                location: Geo(rnd.nextDouble() * 180 - 90, rnd.nextDouble() * 360 - 180),
                icon: _pickable[rnd.nextInt(_pickable.length)],
                isHome: rnd.nextInt(4) == 0,
              );
            case 2:
              if (cur.isNotEmpty) n.setHome(cur[rnd.nextInt(cur.length)].id);
            case 3:
              if (cur.isNotEmpty) n.remove(cur[rnd.nextInt(cur.length)].id);
            case 4:
              // Same call shape as PlaceEditorSheet._save for a rename.
              if (cur.isNotEmpty) {
                final p = cur[rnd.nextInt(cur.length)];
                n.update(p.copyWith(name: 'R$step'));
              }
            case 5:
              n.remove('does-not-exist');
          }
          final s = c.read(placesProvider);
          final homes = s.where((p) => p.isHome).toList();
          expect(homes.length, lessThanOrEqualTo(1), reason: 'step $step');
          for (final h in homes) {
            expect(h.icon, PlaceIcon.home, reason: 'home must use the home icon');
          }
          for (final p in s.where((p) => !p.isHome)) {
            expect(p.icon, isNot(PlaceIcon.home), reason: 'non-home place kept the home icon (step $step)');
          }
          expect(s.map((p) => p.id).toSet().length, s.length);
          expect(s.every((p) => p.name.trim().isNotEmpty), isTrue);
          expect(c.read(homePlaceProvider)?.id, homes.firstOrNull?.id);
        }
        await Future<void>.delayed(Duration.zero);
        expect(env.store.loadPlaces().map((p) => p.toJson()).toList(), c.read(placesProvider).map((p) => p.toJson()).toList());
      });
    }

    test('state list is unmodifiable (no accidental in-place mutation)', () async {
      final (_, c) = await _container();
      c.read(placesProvider.notifier).add(name: 'a', location: const Geo(0, 0), icon: PlaceIcon.star);
      expect(() => c.read(placesProvider).add(c.read(placesProvider).first), throwsUnsupportedError);
    });
  });
}
