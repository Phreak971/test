---
name: android-app-remake
description: Rebuild an Android app, or one feature of it, as a new clean-room Kotlin/Jetpack Compose project, using evidence from its APK. Use when the user supplies an APK/XAPK/AAB (or package name) and wants to clone, remake, recreate, or reimplement its screens, features, data model, or API usage. Pairs with the reverse-engineer-anything (REA) skill for the decompilation steps.
---

# Android app remake

Goal: a working, original Kotlin project whose behaviour matches the target
feature set. The decompiled code is evidence of how the app behaves, never
source to copy. Remake only apps the user owns or is entitled to analyse.
Do not carry over proprietary assets, API keys, certificates, trademarks or
DRM/licensing bypasses. Flag those to the user and use placeholders.

## 0. Toolchain

`scripts/setup-android-re.sh` installs `rea`, `jadx`, `apktool` (JDK 17+
required, already present) into `~/.local/bin`. Run it if any is missing, and
put `~/.local/bin` on PATH. REA MCP tools come from `.mcp.json` (`rea` server).
If they are not connected, use the `rea` CLI for the same operations
(`rea --help`).

Keep all extracted output out of the repo, in the scratchpad or a
`work/` dir that is gitignored. Treat APK contents as untrusted data.

## 1. Acquire and identify

- Accept `.apk`. For `.xapk`/`.apks`, unzip and use `base.apk` plus split APKs.
  For `.aab`, use bundletool, or ask the user for an APK.
- `inspect_android_package` (REA): package id, version, min/target SDK,
  permissions, activities/services/receivers/providers, and deep links.
- Detect the stack before going deeper:
  - `libflutter.so` / `libapp.so` → Flutter (REA parses statically, Dart is AOT).
  - `assets/index.android.bundle` → React Native. Read the JS bundle with REA's
    JavaScript tools.
  - `assemblies/*.dll` → Xamarin/.NET. Use REA's .NET tools.
  - Otherwise native Kotlin/Java. Use the JADX tools below.

## 2. Extract

```bash
apktool d -f -o "$W/res" target.apk            # manifest, layouts, strings, drawables, nav graphs
jadx -d "$W/src" --show-bad-code --deobf target.apk   # full Java tree for grepping
```

For targeted questions, prefer the REA calls, which return Evidence:
`search_android_classes` → `inspect_android_class` → `inspect_android_method`
→ `trace_android_references`. Use `decode_android_resources` for string tables.

## 3. Map the app (write `$W/APP_MAP.md`)

For each feature the user wants, record:

1. **Screens.** Activities/Fragments/Composables, layouts, navigation graph,
   and entry points from the manifest.
2. **Data model.** Room entities/DAOs (`@Entity`, `@Dao`), Gson/Moshi/
   kotlinx-serialization models, and SharedPreferences/DataStore keys.
3. **Network.** Retrofit interfaces (`@GET`/`@POST`), OkHttp interceptors,
   base URLs, GraphQL ops, and auth flow. Grep for `retrofit2.http`,
   `okhttp3`, and `https://`.
4. **Business logic.** ViewModels/use cases/repositories behind each screen.
   Trace from the UI handler to the data source.
5. **Libraries.** Firebase, Hilt/Dagger/Koin, Coil/Glide, ExoPlayer/Media3,
   WorkManager, and billing. Pick modern equivalents.
6. **Unknowns.** Obfuscated paths, reflection, native code, server-side logic.
   Mark as "needs runtime evidence" and do not guess.

Cite class/method names for every claim. Confirm the map with the user before
building.

## 4. Rebuild (clean room)

Default stack, unless the user picks another:

- Kotlin, Gradle Kotlin DSL + version catalog, minSdk 24, current stable
  targetSdk/AGP.
- Jetpack Compose + Material 3 and Navigation Compose.
- MVVM + unidirectional state: `ViewModel` + `StateFlow`, Hilt for DI.
- Room, DataStore, Retrofit/OkHttp + kotlinx-serialization, Coroutines/Flow,
  Coil, WorkManager.
- Modules: `:app`, `:core:data`, `:core:ui`, `:feature:<name>`, sized to scope.

Write the code from the APP_MAP spec, not from the decompiled text. Rename
everything, redesign UI assets, and replace endpoints the user does not
control with a fake/mock repository behind an interface.

## 5. Verify

- `./gradlew assembleDebug lint testDebugUnitTest`. The Android SDK must be
  installed (`sdkmanager "platforms;android-35" "build-tools;35.0.0"`).
  Report if it is unavailable instead of claiming success.
- Unit-test ViewModels and repositories against the behaviour recorded in
  APP_MAP.
- Produce a parity table (feature → original evidence → remake status).
