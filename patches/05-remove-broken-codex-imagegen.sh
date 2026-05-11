#!/usr/bin/env bash
# Patch 05 — Filter broken cx/gpt-image-2 from Codex provider's image catalog
#
# Problem: When 9router fetches Codex's model list from
#   https://chatgpt.com/backend-api/codex/models
# the response includes "gpt-image-2". Codex exposes it server-side, but it
# returns HTTP 400 for ChatGPT-account users:
#   "The 'gpt-image-2' model is not supported when using Codex with a
#    ChatGPT account."
#
# Result: 9router admin UI shows cx/gpt-image-2 under
#   Media Providers > Text to Image > OpenAI Codex
# but every generation request fails. Confusing for users.
#
# Real `gpt-image-2` access requires a direct OpenAI API key (handled by
# patch 06 which adds gpt-image-2 to the openai provider's image catalog).
#
# Fix: In parseCodexModels(), filter out any model whose id is
# exactly "gpt-image-2" (or starts with it for snapshots like
# gpt-image-2-2026-04-21). Codex's working image models (gpt-5.4-image,
# gpt-5.3-image, gpt-5.2-image) come from a different code path
# (open-sse/config/providerModels.js) and are NOT affected by this filter.
#
# Affected files:
#   - src/app/api/providers/[id]/models/route.js
#
# Idempotent.

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="src/app/api/providers/[id]/models/route.js"
MARKER="// patches/05-remove-broken-codex-imagegen.sh"

if grep -qF "$MARKER" "$FILE"; then
  echo "[05-remove-broken-codex-imagegen] Already applied — skipping."
  exit 0
fi

python3 <<'PYEOF'
import pathlib, sys

path = pathlib.Path("src/app/api/providers/[id]/models/route.js")
src = path.read_text()

old = """const parseCodexModels = (data) => appendCodexReviewModels(parseOpenAIStyleModels(data));"""

new = """// patches/05-remove-broken-codex-imagegen.sh — drop unusable cx/gpt-image-2.
// Codex's upstream model list includes gpt-image-2 but it returns HTTP 400
// for ChatGPT-account users ("not supported when using Codex with a ChatGPT
// account"). Users with a direct OpenAI API key should use openai/gpt-image-2
// instead (added by patch 06). Working Codex image models (gpt-5.X-image)
// come from open-sse/config/providerModels.js and bypass this filter.
const isUnsupportedCodexImageModel = (model) => {
  const id = String(model?.id || model?.slug || model?.model || model?.name || "").toLowerCase();
  return id === "gpt-image-2" || id.startsWith("gpt-image-2-");
};
const parseCodexModels = (data) => appendCodexReviewModels(
  parseOpenAIStyleModels(data).filter((model) => !isUnsupportedCodexImageModel(model))
);"""

if old not in src:
    print(f"[05-remove-broken-codex-imagegen] FAILED: pattern not found in {path}", file=sys.stderr)
    print("File contents around parseCodexModels:", file=sys.stderr)
    idx = src.find("parseCodexModels")
    if idx >= 0:
        print(src[max(0, idx-200):idx+400], file=sys.stderr)
    sys.exit(1)

path.write_text(src.replace(old, new, 1))
print("[05-remove-broken-codex-imagegen] Applied.")
PYEOF
