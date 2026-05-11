#!/usr/bin/env bash
# Patch 04 — Fix stale nanobanana baseUrl
#
# Problem: open-sse/config/providers.js lists nanobanana with:
#   baseUrl: "https://api.nanobananaapi.ai/v1/chat/completions"
# This endpoint does not exist. The image adapter
# (open-sse/handlers/imageProviders/nanobanana.js) uses the correct image
# endpoint. But if any code path falls back to providers.js baseUrl for
# nanobanana, requests get a 404 from the nanobanana API ("path:/v1/chat/completions").
#
# Fix: Set the providers.js baseUrl to the correct image-gen endpoint and add a
# comment that nanobanana is image-only (no chat-completions support).
#
# Affected files:
#   - open-sse/config/providers.js
#
# Idempotent.

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="open-sse/config/providers.js"
MARKER="// patches/04-fix-nanobanana-baseurl.sh"

if grep -qF "$MARKER" "$FILE"; then
  echo "[04-nanobanana-baseurl] Already applied — skipping."
  exit 0
fi

python3 <<'PYEOF'
import pathlib, sys

path = pathlib.Path("open-sse/config/providers.js")
src = path.read_text()

old = """  nanobanana: {
    baseUrl: "https://api.nanobananaapi.ai/v1/chat/completions",
    format: "openai"
  },"""

new = """  nanobanana: {
    // patches/04-fix-nanobanana-baseurl.sh — nanobanana is image-only.
    // The previous baseUrl pointed at a non-existent /v1/chat/completions
    // path which returned 404 when any fallback code accidentally hit it.
    // The real image endpoint lives in open-sse/handlers/imageProviders/nanobanana.js.
    baseUrl: "https://api.nanobananaapi.ai/api/v1/nanobanana/generate",
    format: "openai"
  },"""

if old not in src:
    print("[04-nanobanana-baseurl] ERROR: nanobanana entry not found in expected form. Upstream changed.", file=sys.stderr)
    sys.exit(2)

src = src.replace(old, new, 1)
path.write_text(src)
print(f"[04-nanobanana-baseurl] Patched {path}")
PYEOF

echo "[04-nanobanana-baseurl] Done."
