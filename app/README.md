# Overworld

Your real-world map, restyled as 15 original video-game-genre worlds, with
search, saved places, turn-by-turn navigation, character voices, CarPlay and
Android Auto. Flutter app for **Android and iOS** (web build used for QA).

Free and open source: every map, voice, icon and feature is unlocked. There
are no purchases, subscriptions, paywalls or ads.

Clean-room remake: behaviour and feature set were derived from analysing a
reference app (see [`docs/APP_MAP.md`](docs/APP_MAP.md)); all themes, icons,
characters, voices, copy and branding here are original.

## Quick start

```bash
../scripts/setup-flutter.sh           # Flutter 3.47.8 + Android SDK (idempotent)
flutter pub get && flutter gen-l10n
flutter run                           # device / emulator
flutter test                          # unit + widget tests
flutter build apk --release           # Android
flutter build ios --release           # iOS (on macOS)
```

`--dart-define` options: `BUILD_NUMBER`, `MIN_BUILD` (force-update gate), `PRIVACY_URL`,
`TERMS_URL`, `COMMUNITY_URL`, `SUPPORT_EMAIL`, `APP_STORE_ID`.

## Architecture

| Area | Where |
|---|---|
| Map themes (palettes, light/dark derivation, contrast enforcement) | `lib/themes/map_theme.dart`, `theme_catalog.dart` |
| MapLibre style generation over OpenFreeMap vector tiles | `lib/themes/style_builder.dart` |
| Themed POI icons, puck, pins (painted at runtime) | `lib/themes/icon_painter.dart` |
| Map widget + overlays (route, places, puck, effects) | `lib/ui/map/` |
| Search / reverse / nearby (Photon + Nominatim) | `lib/data/search_service.dart` |
| Routing (OSRM) | `lib/data/routing_service.dart` |
| Turn-by-turn engine (snapping, progress, reroute, arrival, cues) | `lib/nav/navigation_engine.dart` |
| Voice personas + phrases (6 languages) + TTS | `lib/nav/voice.dart`, `tts.dart` |
| State (Riverpod) | `lib/state/` |
| Screens | `lib/ui/**` |
| Car bridge (phone → CarPlay / Android Auto) | `lib/car/car_bridge.dart` |
| CarPlay (Swift) | `ios/Runner/Car*.swift` |
| Android Auto (Kotlin) | `android/app/src/main/kotlin/.../car/` |

## Services & production notes

The defaults use free public OpenStreetMap services, which have usage
policies and rate limits. Before launch, point these at your own or a paid
host: OpenFreeMap tiles (self-host or a commercial tile host), Photon /
Nominatim (self-host or a geocoding provider), OSRM (self-host). Attribution
to OpenStreetMap contributors is shown on the map and must stay.

**CarPlay** requires Apple's CarPlay *navigation* entitlement
(`com.apple.developer.carplay-maps`) on your provisioning profile; device
builds won't sign until it's granted. **Android Auto** navigation apps must
pass Google's Android-for-Cars review.

## QA

- `flutter test`: geo maths, parsers (real API fixtures), navigation engine
  driven along a real route, voice phrases, all 30 styles + palette contrast,
  widget flows (search, places, settings, voices, contact, large text).
- Styles are checked with the official MapLibre validator in CI.
- `node tool/qa/shoot.js <out> [scenario]`: screenshots the web build in
  headless Chromium with seeded settings and fake GPS (`tool/qa/scenarios.js`).

## Icons

`python3 tool/gen_icons.py` regenerates all launcher icons (default + 5
alternates) for Android, iOS and in-app previews.
