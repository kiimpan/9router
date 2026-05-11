#!/usr/bin/env bash
# Patch 01 — Fix web search/fetch routing
#
# Problem: /v1/models/web advertises model IDs like "tavily/search", "exa/fetch",
# but POST /v1/search with {"model":"tavily/search"} fails with
#   "Unknown provider: tavily/search"
# because resolveProviderId() in src/shared/constants/providers.js doesn't strip
# the /search or /fetch suffix before looking up the provider.
#
# Affected files:
#   - src/shared/constants/providers.js (resolveProviderId function)
#
# Idempotent: re-running this script after the patch is already applied is a no-op.

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="src/shared/constants/providers.js"
MARKER="// patches/01-fix-tavily-routing.sh"

if grep -qF "$MARKER" "$FILE"; then
  echo "[01-tavily-routing] Already applied — skipping."
  exit 0
fi

if [ ! -f "$FILE" ]; then
  echo "[01-tavily-routing] ERROR: $FILE not found. Wrong directory?" >&2
  exit 1
fi

# Replace the resolveProviderId function body so it strips trailing /search and /fetch suffixes
# before attempting alias resolution. This makes "tavily/search" → "tavily", "exa/fetch" → "exa", etc.
#
# We use a Python script for the AST-safe rewrite because the function body is small but
# embedded inside a JS file where sed/awk multi-line edits get fragile.

python3 <<'PYEOF'
import re, pathlib, sys

path = pathlib.Path("src/shared/constants/providers.js")
src = path.read_text()

# The original function looks like:
#   export function resolveProviderId(aliasOrId) {
#     const provider = getProviderByAlias(aliasOrId);
#     return provider?.id || aliasOrId;
#   }
pattern = re.compile(
    r"export function resolveProviderId\(aliasOrId\)\s*\{\s*\n"
    r"\s*const provider = getProviderByAlias\(aliasOrId\);\s*\n"
    r"\s*return provider\?\.id \|\| aliasOrId;\s*\n"
    r"\}",
    re.MULTILINE,
)

replacement = """// patches/01-fix-tavily-routing.sh — strip /search /fetch suffix before alias lookup
export function resolveProviderId(aliasOrId) {
  // 9router catalog (/v1/models/web) returns IDs like "tavily/search", "exa/fetch".
  // Routing handlers however expect bare provider IDs. Strip the suffix so both
  // long-form catalog IDs and bare provider names route correctly.
  let id = aliasOrId;
  if (typeof id === "string") {
    const m = id.match(/^([^/]+)\\/(search|fetch)$/);
    if (m) id = m[1];
  }
  const provider = getProviderByAlias(id);
  return provider?.id || id;
}"""

new_src, count = pattern.subn(replacement, src, count=1)
if count != 1:
    print("[01-tavily-routing] ERROR: could not locate resolveProviderId function. Upstream may have changed.", file=sys.stderr)
    sys.exit(2)

path.write_text(new_src)
print(f"[01-tavily-routing] Patched {path}")
PYEOF

echo "[01-tavily-routing] Done."
