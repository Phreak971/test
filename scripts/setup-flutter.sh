#!/usr/bin/env bash
# Installs Flutter (stable) and the Android SDK pieces needed to build/test the app.
# Idempotent. Puts flutter in ~/.local/share/flutter and the SDK in ~/.local/share/android-sdk.
set -euo pipefail

FLUTTER_VER="${FLUTTER_VER:-3.47.8}"
ROOT="$HOME/.local/share"
SDK="$ROOT/android-sdk"
CMDLINE_VER=13114758
mkdir -p "$ROOT" "$HOME/.local/bin"

log() { echo "[setup-flutter] $*" >&2; }

if [ ! -x "$ROOT/flutter/bin/flutter" ]; then
  log "downloading flutter $FLUTTER_VER"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VER}-stable.tar.xz" \
    | tar -xJ -C "$ROOT"
fi
git config --global --add safe.directory "$ROOT/flutter" || true
ln -sf "$ROOT/flutter/bin/flutter" "$HOME/.local/bin/flutter"
ln -sf "$ROOT/flutter/bin/dart" "$HOME/.local/bin/dart"

if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "downloading android cmdline-tools"
  mkdir -p "$SDK/cmdline-tools"
  curl -fsSL -o /tmp/cmdline.zip "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VER}_latest.zip"
  unzip -q -o /tmp/cmdline.zip -d "$SDK/cmdline-tools" && rm /tmp/cmdline.zip
  rm -rf "$SDK/cmdline-tools/latest" && mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
fi
export ANDROID_HOME="$SDK"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null || true
"$SDK/cmdline-tools/latest/bin/sdkmanager" --install "platform-tools" "platforms;android-36" "build-tools;36.0.0" >/dev/null

"$ROOT/flutter/bin/flutter" config --no-analytics --android-sdk "$SDK" >/dev/null
"$ROOT/flutter/bin/flutter" --disable-analytics >/dev/null 2>&1 || true
"$ROOT/flutter/bin/flutter" precache --android --linux >/dev/null
log "ready: $("$ROOT/flutter/bin/flutter" --version | head -1)"
