#!/usr/bin/env bash
# Installs the Android reverse-engineering toolchain used by REA and the
# android-app-remake skill: Node 24 (REA needs >=22.23.4), JADX headless MCP
# JAR (REA's Android provider), standalone JADX CLI, and Apktool.
# Idempotent; safe to run on every session start.
set -euo pipefail

TOOLS="${REA_TOOLS_DIR:-$HOME/.local/share/rea}"
BIN="$HOME/.local/bin"
mkdir -p "$TOOLS/android" "$BIN"

JADX_MCP_VER=0.7.1
JADX_MCP_SHA=6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75
JADX_VER=1.5.3
APKTOOL_VER=2.12.1

log() { echo "[setup-android-re] $*" >&2; }

# Node >= 22.23.4 for rea-agents.
if ! "$TOOLS/node/bin/node" -v >/dev/null 2>&1; then
  log "installing Node 24 into $TOOLS/node"
  npm install --prefix "$TOOLS/node-pkg" --no-save --silent node@24 >/dev/null
  rm -rf "$TOOLS/node"
  mkdir -p "$TOOLS/node/bin"
  ln -sf "$TOOLS/node-pkg/node_modules/node/bin/node" "$TOOLS/node/bin/node"
fi

# REA CLI/MCP server, run with the newer Node.
if [ ! -d "$TOOLS/rea/node_modules/rea-agents" ]; then
  log "installing rea-agents"
  PATH="$TOOLS/node/bin:$PATH" npm install --prefix "$TOOLS/rea" --no-save --silent rea-agents@latest >/dev/null
fi
cat > "$BIN/rea" <<EOF
#!/usr/bin/env bash
export REA_JADX_MCP_JAR="\${REA_JADX_MCP_JAR:-$TOOLS/android/jadx-headless-mcp-$JADX_MCP_VER-all.jar}"
export REA_APKTOOL_COMMAND="\${REA_APKTOOL_COMMAND:-$BIN/apktool}"
exec "$TOOLS/node/bin/node" "$TOOLS/rea/node_modules/rea-agents/scripts/rea.mjs" "\$@"
EOF
chmod +x "$BIN/rea"

# JADX headless MCP JAR (pinned + verified, per REA docs/android-analysis.md).
JAR="$TOOLS/android/jadx-headless-mcp-$JADX_MCP_VER-all.jar"
if ! echo "$JADX_MCP_SHA  $JAR" | sha256sum -c - >/dev/null 2>&1; then
  log "downloading jadx-headless-mcp $JADX_MCP_VER"
  curl -fsSL -o "$JAR.tmp" "https://github.com/1013503897/jadx-headless-mcp/releases/download/v$JADX_MCP_VER/jadx-headless-mcp-$JADX_MCP_VER-all.jar"
  echo "$JADX_MCP_SHA  $JAR.tmp" | sha256sum -c - >/dev/null
  mv "$JAR.tmp" "$JAR"
fi

# Standalone JADX CLI for full-project source export.
if [ ! -x "$TOOLS/jadx/bin/jadx" ]; then
  log "downloading jadx $JADX_VER"
  curl -fsSL -o "$TOOLS/jadx.zip" "https://github.com/skylot/jadx/releases/download/v$JADX_VER/jadx-$JADX_VER.zip"
  rm -rf "$TOOLS/jadx" && unzip -q "$TOOLS/jadx.zip" -d "$TOOLS/jadx" && rm "$TOOLS/jadx.zip"
  chmod +x "$TOOLS/jadx/bin/"*
fi
ln -sf "$TOOLS/jadx/bin/jadx" "$BIN/jadx"

# Apktool for resources, manifest and smali.
if [ ! -f "$TOOLS/apktool.jar" ]; then
  log "downloading apktool $APKTOOL_VER"
  curl -fsSL -o "$TOOLS/apktool.jar" "https://github.com/iBotPeaches/Apktool/releases/download/v$APKTOOL_VER/apktool_$APKTOOL_VER.jar"
fi
cat > "$BIN/apktool" <<EOF
#!/usr/bin/env bash
exec java -jar "$TOOLS/apktool.jar" "\$@"
EOF
chmod +x "$BIN/apktool"

log "ready: rea, jadx, apktool in $BIN"
