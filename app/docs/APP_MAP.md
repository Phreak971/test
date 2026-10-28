# Overworld: feature spec (clean-room remake)

Reference app: *Game Maps IRL* (com.retryapps.game.maps.irl, v2.3 APK, iOS v2.5 listing).
Evidence: Hermes bytecode v96 string table, Expo config, decompiled Android Auto
module (Kotlin), bundled resources, App Store listing.

Reference stack: React Native 0.8x / Expo SDK 55, Hermes, MobX stores,
@rnmapbox/maps + Mapbox Navigation SDK + Mapbox Search, gorhom bottom-sheet,
Reanimated, Skia, Superwall + RevenueCat paywall, Firebase, Mixpanel, Adjust,
androidx.car.app (Android Auto), CarPlay.

**Clean-room rule.** We reproduce behaviour, flows and feature set only. All map
themes, icons, characters, voices, copy and branding are original. No game
names, logos, characters, or celebrity likenesses (the reference uses several;
we deliberately do not).

## 1. Data model (from decompiled classes)

| Reference | Fields | Ours |
|---|---|---|
| `MapStyle` | id, name, styleURL, puckURL, isPremium, assetKey | `MapTheme` (id, name, light/dark style generated locally, puck painter, iconSet; every theme is free) |
| `TTSVoice` | id, name, photo, sortOrder | `VoicePersona` (id, name, avatar painter, pitch, rate, phrase pack) |
| `CustomMarker` | id, name, icon, lat, lng | `SavedPlace` (id, name, iconId, lat, lng, address, createdAt) |
| search history | query/place | `SearchHistoryEntry` |
| user prefs (`user/preferences`) | distance unit, selected style, voice, AA dark style | `Settings` (local) |

## 2. Screens and sheets (reference component → ours)

| Reference | Purpose | Status target |
|---|---|---|
| `BootstrapScreen` | Splash: logo on floating glowing POI icons, blue radial glow | `SplashScreen` |
| Onboarding (`OnboardingStore`) | get_started → favorite_game(s) (multi-select of 15) → hear_about_us (7 sources) → rating (store review prompt) → carplay / android_auto intro with **Listen Voice** sample → location_permission ("Ready to Go") → map select → paywall | `OnboardingFlow` |
| `MapSelectScreen` | Grid of map styles with preview, lock badge for premium, Continue/Start, premium button | `ThemePickerScreen` (no locks) |
| `HomeScreen` + `HomeOverlay` | Full-screen styled map; title badge (style name + [DARK]/[LIGHT]); right rail: search, style picker, nearby, saved places, home, recenter/follow, settings; compass; current-area label bottom-left; locked overlay "This Map is Locked" when premium style w/o entitlement | `HomeScreen` |
| `HomeMarkerLayer`, `MarkerStore`, `PreviewIconLayer`, `MinecraftTreeModelLayer` | Home pin, custom markers, preview pin, themed POI icons, 3D decoration | map layers |
| Search (`SearchStore`, `SearchService`) | Autocomplete (location-biased), search history (+ clear), **Find Nearby** categories, "no results" state | `SearchSheet` |
| `LocationSheet` / `LocationDetailSheet` | Place card: name, address, distance; actions Get Directions, Save, Call, Open website, social link, Share; "Pinned Location" for long-press pins; unknown location fallback | `PlaceSheet` |
| `LocationEditorSheet` | Name field ("Home, work, best burger"), icon picker, Save / Save changes / delete | `PlaceEditorSheet` |
| `SavedLocationsSheet` | List of saved places; empty state; tap → fly to; edit; delete | `SavedPlacesSheet` |
| `RoutePreviewSheet` | Route line + My Location → destination, duration (h/min), ETA/arrival, distance, Start Now, End Route | `RoutePreviewSheet` |
| Navigation (Mapbox Nav SDK) | Turn-by-turn: maneuver banner, remaining time/distance/arrival, follow camera, reroute, arrival, **custom character voice** guidance w/ mute | `NavigationScreen` |
| `LocationPermissionSheet` | Explain + allow, or continue without location | `LocationPermissionSheet` |
| `SettingsScreen` | Premium banner; App Icon; Distance Units (km/mi, toast); Android Auto settings; Rate us; Share; Join community; Contact us; Restore purchases; Privacy; Terms; Clean My Data | `SettingsScreen` (free & open-source banner in place of Premium; no Restore purchases) |
| `AndroidAutoSettingsScreen` | Light map style, dark map style, Always prefer dark mode, "currently active", updated toast | `CarSettingsScreen` |
| `IconChangeScreen` | Alternate app icons (6 in reference) | `AppIconScreen` |
| `ContactUsScreen` | Email + message, validation (empty / invalid email), success state (Freshdesk ticket in ref) | `ContactScreen` |
| Update gate | "Update Required" with Update / close (remote min version) | `UpdateGate` |
| Paywall (Superwall/RevenueCat) | Weekly / Monthly / Yearly (+offers) / Lifetime "Unlock All Maps"; free trial; restore; purchase success "congrats" | **Intentionally not recreated**: Overworld is free and open source, with every feature unlocked |
| Toasts | Added to Saved Places, distance unit changed, errors | `Toast` |
| Errors | coordinates not found, current location not found, something went wrong, purchase/restore errors | shared |

## 3. Car (Android Auto `MainCarSession` / CarPlay)
- Map surface rendered with selected style; light/dark style per car settings; always-prefer-dark.
- Screens: search (suggestions, history, categories), favorites (saved places, "add favorites from phone"), find nearby, choose a voice, Pro upgrade gate (`androidAutoRequiresPro`; not recreated, car navigation is free).
- Free-drive + active navigation with maneuvers, route preview from phone ("pending phone route preview"), custom TTS with audio focus (duck, pause on transient loss), mute toggle.
- Locale/unit change applies to car session.

## 4. Services (reference → ours)
| Concern | Reference | Ours |
|---|---|---|
| Tiles/styles | Mapbox + backend style JSON per game | OpenFreeMap vector tiles (OpenMapTiles schema) + locally generated MapLibre styles |
| Search / reverse | Mapbox Search Box + geocode v6 | Photon (komoot) autocomplete + reverse, Nominatim fallback |
| Nearby | Mapbox category search | Photon `osm_tag` category search around center |
| Routing / nav | Mapbox Directions + Navigator | OSRM (driving, steps, voice-ready maneuvers); on-device progress/reroute |
| Voice | server TTS per character | on-device TTS (`flutter_tts`) + persona pitch/rate + phrase packs |
| Purchases | RevenueCat + Superwall | None: no purchases, paywall or ads |
| Analytics | Mixpanel, Adjust, Firebase | none (intentionally) |

## 5. Nearby categories
Restaurants, Fast Food, Coffee Shops, Gas Station, Charging Station, Parking,
Hotels, Supermarket, Pharmacy, Hospital, Subway Stations, Bank.

## 6. Locales
en, fr, de, it, es, tr (matches App Store listing).

## 7. Permissions
Fine/coarse location, background location (foreground service during navigation),
notifications (nav service), internet, billing. No ad ID, no audio recording.
