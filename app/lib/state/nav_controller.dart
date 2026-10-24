import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../data/models.dart';
import '../data/routing_service.dart';
import '../nav/navigation_engine.dart';
import '../nav/tts.dart';
import '../nav/voice.dart';
import 'location.dart';
import 'providers.dart';

sealed class NavState {
  const NavState();
}

class NavIdle extends NavState {
  const NavIdle();
}

class NavPreview extends NavState {
  const NavPreview({required this.dest, this.route, this.loading = false, this.error});

  final Place dest;
  final RouteResult? route;
  final bool loading;

  /// 'no_location' | 'no_route' | 'network'
  final String? error;
}

class NavActive extends NavState {
  const NavActive({required this.dest, required this.route, required this.progress, this.rerouting = false});

  final Place dest;
  final RouteResult route;
  final NavProgress? progress;
  final bool rerouting;
}

class NavArrived extends NavState {
  const NavArrived(this.dest);

  final Place dest;
}

final speakerProvider = Provider<Speaker>((ref) => TtsSpeaker());

class NavController extends Notifier<NavState> {
  NavigationEngine? _engine;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  int _previewToken = 0;

  @override
  NavState build() {
    ref.listen(locationProvider, (prev, next) {
      final fix = next.fix;
      if (fix != null && !identical(fix, prev?.fix)) _onFix(fix);
    });
    return const NavIdle();
  }

  RoutingService get _routing => ref.read(routingServiceProvider);

  String get _lang => WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  /// Fetches a route from the current location to [dest].
  Future<void> preview(Place dest) async {
    final token = ++_previewToken;
    final from = ref.read(locationProvider).position;
    if (from == null) {
      state = NavPreview(dest: dest, error: 'no_location');
      return;
    }
    state = NavPreview(dest: dest, loading: true);
    try {
      final r = await _routing.route(from, dest.location);
      if (token != _previewToken) return;
      state = NavPreview(dest: dest, route: r);
    } on NoRouteException {
      if (token != _previewToken) return;
      state = NavPreview(dest: dest, error: 'no_route');
    } catch (_) {
      if (token != _previewToken) return;
      state = NavPreview(dest: dest, error: 'network');
    }
  }

  void start() {
    final s = state;
    if (s is! NavPreview || s.route == null) return;
    _engine = NavigationEngine(s.route!);
    ref.read(locationProvider.notifier).navigating = true;
    state = NavActive(dest: s.dest, route: s.route!, progress: null);
    final fix = ref.read(locationProvider).fix;
    if (fix != null) _onFix(fix);
  }

  void cancel() {
    _previewToken++;
    _engine = null;
    ref.read(locationProvider.notifier).navigating = false;
    unawaited(ref.read(speakerProvider).stop());
    state = const NavIdle();
  }

  /// For tests and the simulated QA build.
  @visibleForTesting
  void debugFeed(Fix fix) => _onFix(fix);

  void _onFix(Fix fix) {
    final s = state;
    final engine = _engine;
    if (s is! NavActive || engine == null) return;
    final p = engine.update(fix);
    if (p.arrived) {
      _speakCues(engine, p, fix);
      _engine = null;
      ref.read(locationProvider.notifier).navigating = false;
      state = NavArrived(s.dest);
      return;
    }
    if (p.offRoute && !s.rerouting && DateTime.now().difference(_lastReroute) > const Duration(seconds: 8)) {
      unawaited(_reroute(s, fix));
      return;
    }
    state = NavActive(dest: s.dest, route: s.route, progress: p, rerouting: s.rerouting);
    _speakCues(engine, p, fix);
  }

  Future<void> _reroute(NavActive s, Fix fix) async {
    _lastReroute = DateTime.now();
    state = NavActive(dest: s.dest, route: s.route, progress: s.progress, rerouting: true);
    _say(reroutePhrase(_persona, _lang));
    try {
      final r = await _routing.route(fix.position, s.dest.location, headingDeg: fix.headingDeg);
      if (state is! NavActive) return;
      _engine = NavigationEngine(r);
      state = NavActive(dest: s.dest, route: r, progress: null);
      _onFix(fix);
    } catch (_) {
      if (state is! NavActive) return;
      state = NavActive(dest: s.dest, route: s.route, progress: s.progress);
    }
  }

  VoicePersona get _persona => personaById(ref.read(settingsProvider).voiceId);

  void _speakCues(NavigationEngine engine, NavProgress p, Fix fix) {
    final cues = engine.cuesFor(p, speedMps: fix.speedMps);
    if (cues.isEmpty) return;
    // Only the most urgent cue matters if several are due at once.
    final cue = cues.last;
    final unit = ref.read(settingsProvider).unit;
    _say(phraseFor(cue, _persona, unit, _lang, seed: cue.stepIndex));
  }

  void _say(String text) {
    if (ref.read(settingsProvider).voiceMuted) return;
    unawaited(ref.read(speakerProvider).speak(text, _persona, _lang));
  }

  Geo? get destination => switch (state) {
        NavPreview(:final dest) || NavActive(:final dest) || NavArrived(:final dest) => dest.location,
        NavIdle() => null,
      };
}

final navProvider = NotifierProvider<NavController, NavState>(NavController.new);
