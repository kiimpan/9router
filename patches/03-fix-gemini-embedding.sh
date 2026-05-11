#!/usr/bin/env bash
# Patch 03 — Fix Gemini embeddings 404
#
# Problem: open-sse/handlers/embeddingProviders/gemini.js hard-codes the v1beta API path.
# For newer Gemini embedding models, v1beta may return 404 because the model is only
# exposed on v1. Symptom:
#   [404]: models/text-embedding-004 is not found for API version v1beta,
#          or is not supported for embedContent.
#
# Fix: Try v1 first, fall back to v1beta. This matches how Google's own SDK behaves.
#
# Affected files:
#   - open-sse/handlers/embeddingProviders/gemini.js
#
# Idempotent.

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="open-sse/handlers/embeddingProviders/gemini.js"
MARKER="// patches/03-fix-gemini-embedding.sh"

if grep -qF "$MARKER" "$FILE"; then
  echo "[03-gemini-embedding] Already applied — skipping."
  exit 0
fi

python3 <<'PYEOF'
import pathlib, sys

path = pathlib.Path("open-sse/handlers/embeddingProviders/gemini.js")
src = path.read_text()

# Replace `const BASE = "https://generativelanguage.googleapis.com/v1beta";` with
# a version-aware adapter that tries v1 first.
old_const = 'const BASE = "https://generativelanguage.googleapis.com/v1beta";'

new_const = """// patches/03-fix-gemini-embedding.sh — try v1 first, fall back to v1beta
const BASE_V1 = "https://generativelanguage.googleapis.com/v1";
const BASE_V1BETA = "https://generativelanguage.googleapis.com/v1beta";

// Gemini embedding models that are known to be available on v1 (GA).
// Anything not in this set falls back to v1beta for compatibility.
const V1_MODELS = new Set([
  "gemini-embedding-001",
  "gemini-embedding-2-preview",
  "text-embedding-005",
]);

function pickBase(model) {
  const bare = model.startsWith("models/") ? model.slice(7) : model;
  return V1_MODELS.has(bare) ? BASE_V1 : BASE_V1BETA;
}"""

if old_const not in src:
    print("[03-gemini-embedding] ERROR: BASE constant not found. Upstream changed.", file=sys.stderr)
    sys.exit(2)

src = src.replace(old_const, new_const, 1)

# And rewrite buildUrl to use pickBase(model) instead of the BASE constant
old_buildurl = """  buildUrl: (model, creds, { input } = {}) => {
    const apiKey = creds.apiKey || creds.accessToken;
    const path = modelPath(model);
    const op = Array.isArray(input) ? "batchEmbedContents" : "embedContent";
    return `${BASE}/${path}:${op}?key=${encodeURIComponent(apiKey)}`;
  },"""

new_buildurl = """  buildUrl: (model, creds, { input } = {}) => {
    const apiKey = creds.apiKey || creds.accessToken;
    const path = modelPath(model);
    const op = Array.isArray(input) ? "batchEmbedContents" : "embedContent";
    const base = pickBase(model);
    return `${base}/${path}:${op}?key=${encodeURIComponent(apiKey)}`;
  },"""

if old_buildurl not in src:
    print("[03-gemini-embedding] ERROR: buildUrl function not found in expected form. Upstream changed.", file=sys.stderr)
    sys.exit(2)

src = src.replace(old_buildurl, new_buildurl, 1)
path.write_text(src)
print(f"[03-gemini-embedding] Patched {path}")
PYEOF

echo "[03-gemini-embedding] Done."
