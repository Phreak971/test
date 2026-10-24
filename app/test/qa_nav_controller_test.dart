// QA: NavController ordering / race conditions (preview vs start vs cancel,
// reroute). `// BUG:` tests are expected to fail until fixed.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/routing_service.dart';
import 'package:overworld/nav/navigation_engine.dart';
import 'package:overworld/state/location.dart';
import 'package:overworld/state/nav_controller.dart';
import 'package:overworld/state/providers.dart';

import 'helpers.dart';
import 'qa_support.dart';

/// Routing fake whose responses are completed by the test.
class ScriptedRouting extends RoutingService {
  final calls = <({Geo from, Geo to, double? heading, Completer<RouteResult> c})>[];

  @override
  Future<RouteResult> route(Geo from, Geo to, {double? headingDeg}) {
    final c = Completer<RouteResult>();
    calls.add((from: from, to: to, heading: headingDeg, c: c));
    return c.future;
  }
}

const _start = Geo(52.52, 13.405);
final _placeA = Place(id: 'A', name: 'Alpha', location: offset(_start, 0, 2000));
final _placeB = Place(id: 'B', name: 'Bravo', location: offset(_start, 2000, 0));
final _routeA = syntheticRoute(_start, [(0, 0), (0, 2000)]);
final _routeB = syntheticRoute(_start, [(0, 0), (2000, 0)]);

Future<(TestEnv, ProviderContainer, ScriptedRouting)> _setup() async {
  final env = await makeEnv();
  final routing = ScriptedRouting();
  final c = ProviderContainer(overrides: [...env.overrides, routingServiceProvider.overrideWithValue(routing)]);
  addTearDown(c.dispose);
  c.read(navProvider); // build + listen
  await c.read(locationProvider.notifier).init();
  await Future<void>.delayed(Duration.zero);
  expect(c.read(locationProvider).position, isNotNull);
  return (env, c, routing);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preview: a slow earlier request never overwrites a newer one', () async {
    final (_, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    unawaited(nav.preview(_placeB));
    routing.calls[1].c.complete(_routeB);
    await _flush();
    routing.calls[0].c.complete(_routeA);
    await _flush();
    final s = c.read(navProvider) as NavPreview;
    expect(s.dest.id, 'B');
    expect(identical(s.route, _routeB), isTrue);
  });

  test('cancel while a preview is loading stays idle', () async {
    final (_, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    nav.cancel();
    routing.calls.single.c.complete(_routeA);
    await _flush();
    expect(c.read(navProvider), isA<NavIdle>());
  });

  test('preview error is reported and start() is a no-op without a route', () async {
    final (_, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    nav.start(); // still loading
    expect(c.read(navProvider), isA<NavPreview>());
    routing.calls.single.c.completeError(const NoRouteException('NoRoute'));
    await _flush();
    expect((c.read(navProvider) as NavPreview).error, 'no_route');
    nav.start();
    expect(c.read(navProvider), isA<NavPreview>());
  });

  test('start -> drive -> arrive: one arrival phrase, location leaves nav mode', () async {
    final (env, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    expect(c.read(navProvider), isA<NavActive>());
    for (final p in walkLine(_routeA.geometry, 15)) {
      nav.debugFeed(Fix(p, speedMps: 12));
      if (c.read(navProvider) is NavArrived) break;
    }
    expect(c.read(navProvider), isA<NavArrived>());
    nav.debugFeed(Fix(_routeA.geometry.last));
    final arrivals = env.speaker.spoken.where((s) => s.contains('arrived')).length;
    expect(arrivals, 1, reason: env.speaker.spoken.join(' | '));
  });

  test('reroute failure restores the active route and clears the rerouting flag', () async {
    final (_, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    final far = offset(_start, 400, 300);
    for (var i = 0; i < 3; i++) {
      nav.debugFeed(Fix(far, speedMps: 10));
    }
    expect((c.read(navProvider) as NavActive).rerouting, isTrue);
    // More off-route fixes while rerouting must not fire a second request.
    for (var i = 0; i < 5; i++) {
      nav.debugFeed(Fix(far, speedMps: 10));
    }
    expect(routing.calls.length, 2);
    routing.calls.last.c.completeError(Exception('offline'));
    await _flush();
    final s = c.read(navProvider) as NavActive;
    expect(s.rerouting, isFalse);
    expect(identical(s.route, _routeA), isTrue);
  });

  // BUG (P1): _reroute() only checks `state is NavActive` when the response
  // arrives. If the user ends navigation and starts a NEW one (to B) while a
  // reroute for the old trip (to A) is in flight, the stale response replaces
  // the new trip: destination silently switches back to A.
  test('a stale reroute response cannot hijack a newer navigation session', () async {
    final (_, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    final far = offset(_start, 400, 300);
    for (var i = 0; i < 3; i++) {
      nav.debugFeed(Fix(far, speedMps: 10));
    }
    final reroute = routing.calls.last;
    expect(reroute.to, _placeA.location);

    nav.cancel();
    unawaited(nav.preview(_placeB));
    routing.calls.last.c.complete(_routeB);
    await _flush();
    nav.start();
    expect((c.read(navProvider) as NavActive).dest.id, 'B');

    reroute.c.complete(syntheticRoute(far, [(0, 0), (0, 1500)]));
    await _flush();
    final s = c.read(navProvider) as NavActive;
    expect(s.dest.id, 'B', reason: 'old reroute response switched the destination back to A');
  });

  // BUG (P2): when the user is persistently off-road (car park, ferry,
  // private road) and OSRM keeps failing, every 8 s the controller speaks
  // "Rerouting" again and fires another request — no backoff and no
  // de-duplication of the announcement. (Uses real time: ~8.5 s.)
  test('persistent reroute failures are not re-announced every 8 seconds', () async {
    final (env, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    final far = offset(_start, 400, 300);
    for (var i = 0; i < 3; i++) {
      nav.debugFeed(Fix(far, speedMps: 3));
    }
    routing.calls.last.c.completeError(const NoRouteException('NoSegment'));
    await _flush();
    await Future<void>.delayed(const Duration(milliseconds: 8300));
    nav.debugFeed(Fix(far, speedMps: 3));
    if (routing.calls.length > 2) routing.calls.last.c.completeError(const NoRouteException('NoSegment'));
    await _flush();
    final announcements = env.speaker.spoken.where((s) => s == 'Rerouting').length;
    expect(announcements, 1, reason: 'spoken: ${env.speaker.spoken}; requests: ${routing.calls.length - 1}');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('muted voice: no speech at all during a full drive with reroute', () async {
    final (env, c, routing) = await _setup();
    c.read(settingsProvider.notifier).setVoiceMuted(true);
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    for (final p in walkLine(_routeA.geometry, 20)) {
      nav.debugFeed(Fix(p, speedMps: 12));
    }
    expect(env.speaker.spoken, isEmpty);
  });

  test('location source switches to navigation mode on start and back on cancel', () async {
    final (env, c, routing) = await _setup();
    final nav = c.read(navProvider.notifier);
    unawaited(nav.preview(_placeA));
    routing.calls.single.c.complete(_routeA);
    await _flush();
    nav.start();
    env.location.emit(Fix(_routeA.geometry[3], speedMps: 10));
    await _flush();
    expect((c.read(navProvider) as NavActive).progress, isNotNull);
    nav.cancel();
    expect(c.read(navProvider), isA<NavIdle>());
    expect(c.read(locationProvider).permission, LocPermission.granted);
  });
}
