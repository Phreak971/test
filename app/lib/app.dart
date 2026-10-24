import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'core/geo_uri.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'ui/home/home_screen.dart';
import 'ui/hud.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/onboarding/splash_screen.dart';

const buildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 1);

/// Pending deep link for the home screen to consume.
final pendingGeoLinkProvider = NotifierProvider<PendingGeoLink, GeoUri?>(PendingGeoLink.new);

class PendingGeoLink extends Notifier<GeoUri?> {
  @override
  GeoUri? build() => null;

  void set(GeoUri? v) => state = v;
}

class OverworldApp extends ConsumerStatefulWidget {
  const OverworldApp({super.key, this.skipSplash = false});

  final bool skipSplash;

  @override
  ConsumerState<OverworldApp> createState() => _OverworldAppState();
}

enum _Stage { splash, onboarding, home }

class _OverworldAppState extends ConsumerState<OverworldApp> {
  late _Stage _stage = widget.skipSplash ? _next() : _Stage.splash;
  StreamSubscription<Uri>? _links;

  _Stage _next() => ref.read(settingsProvider).onboarded ? _Stage.home : _Stage.onboarding;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _links = AppLinks().uriLinkStream.listen((uri) {
          final g = GeoUri.parse(uri.toString());
          if (g != null) ref.read(pendingGeoLinkProvider.notifier).set(g);
        }, onError: (Object _) {});
      } catch (_) {
        // Plugin unavailable (tests).
      }
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hud = ref.watch(hudProvider);
    final minBuild = ref.watch(minSupportedBuildProvider);
    final Widget home;
    if (buildNumber < minBuild) {
      home = const _UpdateRequired();
    } else {
      home = switch (_stage) {
        _Stage.splash => SplashScreen(onDone: () => setState(() => _stage = _next())),
        _Stage.onboarding => OnboardingFlow(onFinished: () => setState(() => _stage = _Stage.home)),
        _Stage.home => const HomeScreen(),
      };
    }
    return MaterialApp(
      title: 'Overworld',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(hud),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: home,
    );
  }
}

class _UpdateRequired extends ConsumerWidget {
  const _UpdateRequired();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_rounded, color: hud.accent, size: 72),
              const SizedBox(height: 16),
              Semantics(header: true, child: Text(l.updateTitle, style: displayStyle(hud, 26), textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Text(l.updateBody, style: TextStyle(color: hud.muted, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              PrimaryButton(
                hud: hud,
                label: l.updateCta,
                onPressed: () => launchUrl(isIOS ? AppConfig.appStoreUrl : AppConfig.playStoreUrl, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
