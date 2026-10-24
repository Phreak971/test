#!/usr/bin/env bash
# Launches the REA MCP server, installing the toolchain first if this is a fresh container.
set -euo pipefail
[ -x "$HOME/.local/bin/rea" ] || "$(dirname "$0")/setup-android-re.sh" >&2
exec "$HOME/.local/bin/rea" mcp
