import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/repositories.dart';
import 'package:overworld/data/search_service.dart';
import 'package:overworld/l10n/app_localizations.dart';
import 'package:overworld/nav/navigation_engine.dart';
import 'package:overworld/nav/tts.dart';
import 'package:overworld/nav/voice.dart';
import 'package:overworld/purchases/purchases.dart';
import 'package:overworld/state/location.dart';
import 'package:overworld/state/nav_controller.dart';
import 'package:overworld/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSearch extends SearchService {
  FakeSearch({this.results = const [], this.fail = false});

  List<Place> results;
  bool fail;
  final queries = <String>[];
  final categories = <NearbyCategory>[];

  @override
  Future<List<Place>> autocomplete(String query, {Geo? near, String lang = 'en', int limit = 12}) async {
    queries.add(query);
    if (fail) throw Exception('offline');
    return results;
  }

  @override
  Future<List<Place>> nearby(NearbyCategory category, Geo center, {String lang = 'en', double radiusM = 3000, int limit = 25}) async {
    categories.add(category);
    if (fail) throw Exception('offline');
    return results;
  }

  @override
  Future<Place?> reverse(Geo at, {String lang = 'en'}) async => null;
}

class SilentSpeaker implements Speaker {
  final spoken = <String>[];

  @override
  Future<void> speak(String text, VoicePersona persona, String langCode) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class FakeLocation implements LocationSource {
  FakeLocation({this.permission = LocPermission.granted, this.position = const Geo(52.52, 13.405)});

  LocPermission permission;
  Geo position;
  final _ctrl = StreamController<Fix>.broadcast();

  void emit(Fix f) => _ctrl.add(f);

  @override
  Future<LocPermission> check() async => permission;

  @override
  Future<LocPermission> request() async => permission = LocPermission.granted;

  @override
  Stream<Fix> watch({required bool navigating}) => _ctrl.stream;

  @override
  Future<Fix?> current() async => Fix(position);

  @override
  Future<void> openSettings() async {}
}

class TestEnv {
  TestEnv({required this.store, required this.search, required this.speaker, required this.purchases, required this.location});

  final LocalStore store;
  final FakeSearch search;
  final SilentSpeaker speaker;
  final FakePurchaseService purchases;
  final FakeLocation location;

  List<Override> get overrides => [
        localStoreProvider.overrideWithValue(store),
        searchServiceProvider.overrideWithValue(search),
        speakerProvider.overrideWithValue(speaker),
        purchaseServiceProvider.overrideWithValue(purchases),
        locationSourceProvider.overrideWithValue(location),
      ];
}

Future<TestEnv> makeEnv({Map<String, Object> prefs = const {}, List<Place> results = const []}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return TestEnv(
    store: LocalStore(sp),
    search: FakeSearch(results: results),
    speaker: SilentSpeaker(),
    purchases: FakePurchaseService(),
    location: FakeLocation(),
  );
}

/// Pumps [child] inside localization + a fresh provider container.
Future<ProviderContainer> pumpApp(WidgetTester tester, TestEnv env, Widget child, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: env.overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

const samplePlace = Place(id: 'osm:N1', name: 'Café Blue', location: Geo(52.521, 13.41), address: 'Main St 1, Berlin', category: 'Cafe', phone: '+49 30 1234');
