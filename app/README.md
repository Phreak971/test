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

**Shared place links.** Sharing a place sends an Overworld link
(`SHARE_BASE_URL`, default `https://phreak971.github.io/test/p/?lat=..&lng=..&n=..`)
instead of an OpenStreetMap one, because only a domain we control can send
people into the app:

1. The landing page (`/docs/p/index.html`, served by GitHub Pages) hands the
   place to the app: on Android with an `intent://` URL that comes back to the
   page if the app isn't installed, and on iOS with an "Open in Overworld"
   button (`overworld://place?...`). Without the app it shows the place on an
   OpenStreetMap embed with OpenStreetMap / Google / Apple Maps buttons.
2. **Verified links skip the browser entirely.** Android App Links need
   `/.well-known/assetlinks.json` at the *domain root*, with the SHA-256 of
   the key that signs the APK. iOS Universal Links need
   `/.well-known/apple-app-site-association` (replace `TEAMID`) and the
   Associated Domains capability. A GitHub *project* page (`/test/`) is not a
   domain root, so give Pages a custom domain, then set it in
   `-Poverworld.shareHost=… -Poverworld.sharePathPrefix=/p`,
   `SHARE_LINK_HOST` (`ios/Flutter/*.xcconfig`) and `--dart-define=SHARE_BASE_URL=…`.
3. Incoming OpenStreetMap, Google Maps, Apple Maps and `geo:` links open the
   app too (Android "Open with", or always once allowed under Settings → Open
   map links in Overworld). Pasting any of them, or `lat, lng`, into search
   jumps to the spot.

**Default maps app & link porting.**

- *Android:* Overworld handles `geo:`, `google.navigation:` and map links from
  Google Maps (incl. `maps.app.goo.gl`, `share.google`, `goo.gl/maps`), Apple
  Maps, Waze and OpenStreetMap. Pick it with "Always" in the chooser to make it
  the default maps app. Google Maps owns its own links, so on phones with
  Google Maps installed use its **Share → Open in Overworld** (share target),
  or allow the domains in Settings → Default maps app.
- *iOS:* registered as a navigation app (`com.apple.developer.navigation-app`
  entitlement + `geo-navigation://`), selectable under Settings → Apps →
  Default Apps → Navigation in the EU (iOS 18.4+) and Japan (iOS 26.2+). The
  provisioning profile needs that capability. Elsewhere: paste links in search.
- `LinkResolver` expands short links by following redirects (unwrapping
  Android `intent://` fallbacks and consent pages) and geocodes Google place
  URLs that carry only "Name, Address" (full text → name + city → address →
  nearby name). `LIVE=1 flutter test test/live --run-skipped` checks real links.
- Export: Share → Overworld / Google Maps (`/maps/search/?api=1&query=lat,lng`,
  Google's documented cross-platform URL) / Apple Maps / OpenStreetMap link or
  coordinates; the place sheet also has Open in Google/Apple Maps and Copy
  Google Maps link.

**Enable the site:** repository Settings → Pages → *Deploy from a branch* →
pick the branch and the `/docs` folder. It also serves the privacy policy and
terms the app links to.

**Release signing.** Release builds use `android/key.properties`
(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) or the
`OVERWORLD_KEYSTORE*` / `OVERWORLD_KEY_*` environment variables, and fall
back to the debug key. Use one stable key so installs update in place and so
`assetlinks.json` can name it (`keytool -list -v -keystore … | grep SHA256`).

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
