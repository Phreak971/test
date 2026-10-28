// QA: UI-level race conditions and state-loss bugs.
// `// BUG:` tests are expected to fail until fixed.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/state/providers.dart';
import 'package:overworld/ui/home/places_sheets.dart';
import 'package:overworld/ui/home/search_sheet.dart';

import 'helpers.dart';

/// Search fake whose autocomplete responses are released by the test.
class GatedSearch extends FakeSearch {
  final pending = <(String, Completer<List<Place>>)>[];

  @override
  Future<List<Place>> autocomplete(String query, {Geo? near, String lang = 'en', int limit = 12}) {
    queries.add(query);
    final c = Completer<List<Place>>();
    pending.add((query, c));
    return c.future;
  }
}

Future<GatedSearch> _pumpSearch(WidgetTester tester) async {
  final env = await makeEnv();
  final gated = GatedSearch();
  final patched = TestEnv(store: env.store, search: gated, speaker: env.speaker, location: env.location);
  await pumpApp(tester, patched, const Scaffold(body: SearchSheet(center: Geo(52.52, 13.4))));
  return gated;
}

const _other = Place(id: 'osm:N2', name: 'Pizza Palace', location: Geo(52.53, 13.41));

void main() {
  testWidgets('search: out-of-order responses — only the latest query is shown', (tester) async {
    final s = await _pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'pi');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.queries, ['pi', 'pizza']);
    s.pending[1].$2.complete(const [_other]);
    await tester.pump();
    s.pending[0].$2.complete(const [samplePlace]);
    await tester.pumpAndSettle();
    expect(find.text('Pizza Palace'), findsOneWidget);
    expect(find.text('Café Blue'), findsNothing);
  });

  testWidgets('search: debounce collapses fast typing into one request', (tester) async {
    final s = await _pumpSearch(tester);
    for (final q in ['p', 'pi', 'piz', 'pizz', 'pizza']) {
      await tester.enterText(find.byType(TextField), q);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.queries, ['pizza']);
    s.pending.single.$2.complete(const []);
    await tester.pumpAndSettle();
  });

  // BUG (P1): clearing the field (or typing <2 chars) resets the UI but does
  // not bump `_token`, so a request already in flight still lands and shows
  // stale results under an empty search box (and hides recents/categories).
  testWidgets('search: clearing the field discards the in-flight response', (tester) async {
    final s = await _pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.queries, ['cafe']);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    s.pending.single.$2.complete(const [samplePlace]);
    await tester.pumpAndSettle();
    expect(find.text('Café Blue'), findsNothing, reason: 'stale "cafe" results shown for an empty query');
    expect(find.text('Find nearby'.toUpperCase()), findsOneWidget);
  });

  testWidgets('search: closing the sheet while a request is in flight does not throw', (tester) async {
    final env = await makeEnv();
    final gated = GatedSearch();
    final patched = TestEnv(store: env.store, search: gated, speaker: env.speaker, location: env.location);
    await pumpApp(
      tester,
      patched,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: SearchSheet(center: Geo(0, 0))),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump(const Duration(milliseconds: 100)); // debounce pending
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    // The debounce may fire during the pop transition; its response then
    // lands after dispose and must be ignored (mounted check).
    for (final p in gated.pending) {
      p.$2.complete(const [samplePlace]);
    }
    await tester.pumpAndSettle();
    expect(find.byType(SearchSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // BUG (P1, user data): editing the home place, renaming it AND switching
  // "home" off saves the OLD name: PlaceEditorSheet._save first updates with
  // the new name, then calls update(e.copyWith(isHome: false, ...)) on the
  // ORIGINAL `e`, overwriting the rename.
  testWidgets('places: rename + unset home keeps the new name', (tester) async {
    final home = SavedPlace(
      id: 'h1',
      name: 'Home',
      location: const Geo(52.5, 13.4),
      icon: PlaceIcon.home,
      createdAt: DateTime(2025),
      isHome: true,
    );
    final env = await makeEnv(
      prefs: {
        'saved_places.v1': jsonEncode([home.toJson()]),
      },
    );
    final c = await pumpApp(tester, env, Scaffold(body: PlaceEditorSheet(existing: home)));
    await tester.enterText(find.byType(TextField), 'My Flat');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final saved = c.read(placesProvider).single;
    expect(saved.isHome, isFalse);
    expect(saved.icon, isNot(PlaceIcon.home));
    expect(saved.name, 'My Flat', reason: 'rename was overwritten by the un-home update');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('places: rename + set home keeps the new name and a single home', (tester) async {
    final a = SavedPlace(id: 'a', name: 'Old', location: const Geo(1, 1), icon: PlaceIcon.home, createdAt: DateTime(2025), isHome: true);
    final b = SavedPlace(id: 'b', name: 'Gym', location: const Geo(2, 2), icon: PlaceIcon.gym, createdAt: DateTime(2025));
    final env = await makeEnv(
      prefs: {
        'saved_places.v1': jsonEncode([a.toJson(), b.toJson()]),
      },
    );
    final c = await pumpApp(tester, env, Scaffold(body: PlaceEditorSheet(existing: b)));
    await tester.enterText(find.byType(TextField), 'New Home');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final places = c.read(placesProvider);
    expect(places.where((p) => p.isHome).single.id, 'b');
    expect(places.firstWhere((p) => p.id == 'b').name, 'New Home');
    expect(places.firstWhere((p) => p.id == 'a').icon, PlaceIcon.star);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
