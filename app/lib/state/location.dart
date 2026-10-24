import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../nav/navigation_engine.dart';

enum LocPermission { unknown, granted, denied, deniedForever, serviceOff }

class LocationState {
  const LocationState({this.permission = LocPermission.unknown, this.fix});

  final LocPermission permission;
  final Fix? fix;

  Geo? get position => fix?.position;

  LocationState copyWith({LocPermission? permission, Fix? fix}) =>
      LocationState(permission: permission ?? this.permission, fix: fix ?? this.fix);
}

/// Abstraction over the platform location API so tests and the web QA build
/// can inject a simulated route.
abstract class LocationSource {
  Future<LocPermission> check();
  Future<LocPermission> request();
  Stream<Fix> watch({required bool navigating});
  Future<Fix?> current();
  Future<void> openSettings();
}

class GeolocatorSource implements LocationSource {
  LocPermission _map(LocationPermission p) => switch (p) {
    LocationPermission.always || LocationPermission.whileInUse => LocPermission.granted,
    LocationPermission.deniedForever => LocPermission.deniedForever,
    LocationPermission.denied => LocPermission.denied,
    LocationPermission.unableToDetermine => LocPermission.unknown,
  };

  @override
  Future<LocPermission> check() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return LocPermission.serviceOff;
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocPermission> request() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return LocPermission.serviceOff;
    return _map(await Geolocator.requestPermission());
  }

  Fix _fix(Position p) => Fix(
    Geo(p.latitude, p.longitude),
    headingDeg: p.heading >= 0 && p.speed > 1 ? p.heading : null,
    speedMps: p.speed < 0 ? 0 : p.speed,
    accuracyM: p.accuracy,
    at: p.timestamp,
  );

  @override
  Stream<Fix> watch({required bool navigating}) {
    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: navigating ? 3 : 8,
        intervalDuration: const Duration(seconds: 1),
        // Keeps guidance alive with the screen off during navigation.
        foregroundNotificationConfig: navigating
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Overworld navigation',
                notificationText: 'Guiding you to your destination',
                enableWakeLock: true,
              )
            : null,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: navigating ? 3 : 8,
        pauseLocationUpdatesAutomatically: !navigating,
        showBackgroundLocationIndicator: navigating,
        allowBackgroundLocationUpdates: navigating,
      );
    } else {
      settings = LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: navigating ? 3 : 8);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(_fix);
  }

  @override
  Future<Fix?> current() async {
    try {
      final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
      if (last != null) return _fix(last);
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return _fix(p);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    // Not available on web; the sheet's caller pops regardless.
    if (kIsWeb) return;
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

final locationSourceProvider = Provider<LocationSource>((ref) => GeolocatorSource());

class LocationNotifier extends Notifier<LocationState> {
  StreamSubscription<Fix>? _sub;
  bool _navigating = false;

  @override
  LocationState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _restart?.cancel();
    });
    return const LocationState();
  }

  LocationSource get _src => ref.read(locationSourceProvider);

  /// Checks permission silently; starts tracking if already granted.
  Future<LocPermission> init() async {
    final p = await _src.check();
    state = state.copyWith(permission: p);
    if (p == LocPermission.granted) _start();
    return p;
  }

  Future<LocPermission> request() async {
    final p = await _src.request();
    state = state.copyWith(permission: p);
    if (p == LocPermission.granted) _start();
    return p;
  }

  Future<void> openSettings() => _src.openSettings();

  set navigating(bool v) {
    if (v == _navigating) return;
    _navigating = v;
    if (state.permission == LocPermission.granted) _start();
  }

  void _start() {
    _sub?.cancel();
    unawaited(
      _src.current().then((f) {
        if (f != null && state.fix == null) state = state.copyWith(fix: f);
      }),
    );
    _sub = _src
        .watch(navigating: _navigating)
        .listen(
          (f) => state = state.copyWith(fix: f),
          // Location service toggled / transient error: resubscribe shortly.
          onError: (Object _) => _scheduleRestart(),
          onDone: _scheduleRestart,
          cancelOnError: true,
        );
  }

  Timer? _restart;

  void _scheduleRestart() {
    _restart?.cancel();
    _restart = Timer(const Duration(seconds: 3), () async {
      final p = await _src.check();
      state = state.copyWith(permission: p);
      if (p == LocPermission.granted) _start();
    });
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);
