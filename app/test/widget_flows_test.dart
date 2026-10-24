import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/purchases/purchases.dart';
import 'package:overworld/state/providers.dart';
import 'package:overworld/ui/home/places_sheets.dart';
import 'package:overworld/ui/home/search_sheet.dart';
import 'package:overworld/ui/paywall/paywall_screen.dart';
import 'package:overworld/ui/settings/contact_screen.dart';
import 'package:overworld/ui/settings/settings_screen.dart';
import 'package:overworld/ui/settings/voice_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('search: typing queries the service and picking records history', (tester) async {
    final env = await makeEnv(results: const [samplePlace]);
    Object? popped;
    final c = await pumpApp(
      tester,
      env,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Object>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: SearchSheet(center: Geo(52.52, 13.4))),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Find nearby'.toUpperCase()), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(env.search.queries, ['cafe']);
    expect(find.text('Café Blue'), findsOneWidget);
    await tester.tap(find.text('Café Blue'));
    await tester.pumpAndSettle();
    expect(popped, isA<PickedPlace>());
    expect(c.read(historyProvider).single.place.id, samplePlace.id);
  });

  testWidgets('search: shows offline state and nearby categories', (tester) async {
    final env = await makeEnv();
    env.search.fail = true;
    await pumpApp(tester, env, const Scaffold(body: SearchSheet(center: Geo(52.52, 13.4))));
    await tester.tap(find.text('Coffee shops'));
    await tester.pumpAndSettle();
    expect(env.search.categories, [NearbyCategory.cafe]);
    expect(find.text('Search is unavailable right now.'), findsOneWidget);
    env.search.fail = false;
    env.search.results = const [];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing found nearby'), findsOneWidget);
  });

  testWidgets('places: save, set home, edit and delete', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, const Scaffold(body: PlaceEditorSheet(newPlace: samplePlace)));
    expect(find.text('Save location'), findsOneWidget);
    // Name is prefilled from the place.
    expect(find.widgetWithText(TextField, 'Café Blue'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = c.read(placesProvider);
    expect(saved, hasLength(1));
    expect(saved.single.isHome, isTrue);
    expect(saved.single.icon, PlaceIcon.home);
    expect(c.read(homePlaceProvider)?.id, saved.single.id);

    // A second home replaces the first.
    c.read(placesProvider.notifier).add(name: 'Office', location: const Geo(1, 1), icon: PlaceIcon.work, isHome: true);
    expect(c.read(placesProvider).where((p) => p.isHome), hasLength(1));
    expect(c.read(homePlaceProvider)?.name, 'Office');

    // Persisted.
    expect(env.store.loadPlaces(), hasLength(2));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('places: saved list empty state and delete with confirm', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, Scaffold(body: SavedPlacesSheet(onEdit: (_) {})));
    expect(find.text('No saved places yet'), findsOneWidget);
    c.read(placesProvider.notifier).add(name: 'Gym', location: const Geo(52.5, 13.4), icon: PlaceIcon.gym);
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    await tester.drag(find.text('Gym'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Gym”?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(c.read(placesProvider), isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('settings: unit toggle persists and shows a toast', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, const SettingsScreen());
    await tester.tap(find.text('Miles'));
    await tester.pump();
    expect(c.read(settingsProvider).unit, DistanceUnit.imperial);
    expect(env.store.loadSettings().unit, DistanceUnit.imperial);
    expect(find.text('Distance unit changed'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('settings: clean my data wipes places but keeps purchase', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, const SettingsScreen());
    c.read(placesProvider.notifier).add(name: 'X', location: const Geo(0, 1), icon: PlaceIcon.star);
    c.read(entitlementProvider.notifier).grant(const Entitlement(premium: true));
    await tester.scrollUntilVisible(find.text('Clean my data'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Clean my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete data'));
    await tester.pumpAndSettle();
    expect(c.read(placesProvider), isEmpty);
    expect(env.store.loadEntitlement().premium, isTrue);
    expect(c.read(settingsProvider).onboarded, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('paywall: buying yearly unlocks premium', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, const PaywallScreen());
    expect(find.text('Unlock every world'), findsOneWidget);
    expect(find.text('Best value'), findsOneWidget);
    // The CTA is pinned and visible without scrolling.
    // Yearly (default) has a trial, so the CTA says so.
    expect(find.text('Start free trial').hitTestable(), findsOneWidget);
    expect(find.textContaining('3-day free trial, then'), findsOneWidget);
    await tester.tap(find.text('Start free trial'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(c.read(entitlementProvider).premium, isTrue);
    expect(find.text('Welcome to Pro!'), findsOneWidget);
    expect(c.read(themeUnlockedProvider('neon_sprawl')), isTrue);
  });

  testWidgets('premium themes and voices are locked for free users', (tester) async {
    final env = await makeEnv();
    final c = await pumpApp(tester, env, const VoiceScreen());
    expect(c.read(themeUnlockedProvider('palm_metro')), isTrue);
    expect(c.read(themeUnlockedProvider('neon_sprawl')), isFalse);
    // Tapping a locked voice opens the paywall instead of selecting it.
    await tester.tap(find.text('Frontier Ranger'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock every world'), findsOneWidget);
    expect(c.read(settingsProvider).voiceId, 'classic');
  });

  testWidgets('contact: validation messages', (tester) async {
    final env = await makeEnv();
    await pumpApp(tester, env, const ContactScreen());
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Please fill in both fields.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'Hello');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('layouts survive the largest text size on a small phone', (tester) async {
    final env = await makeEnv();
    for (final screen in [const SettingsScreen(), const PaywallScreen(), const ContactScreen(), const VoiceScreen()]) {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, env, screen, size: const Size(320, 568));
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType} overflowed');
    }
  });
}
