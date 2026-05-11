#!/usr/bin/env bash
# Patch 06 — Add gpt-image-2 to OpenAI provider's image model catalog
#
# Problem: OpenAI released gpt-image-2 in April 2026 as their flagship image
# model (official docs: developers.openai.com/api/docs/models/gpt-image-2).
# It uses the standard POST /v1/images/generations endpoint, returns base64
# in data[0].b64_json, supports flexible WIDTHxHEIGHT sizes up to 3840px.
#
# 9router's openai provider catalog currently only lists:
#   - gpt-image-1
#   - dall-e-3
#   - dall-e-2
# So users can't select gpt-image-2 from the admin dashboard when configuring
# an OpenAI image connection.
#
# Param choices for the new catalog entry — gpt-image-2 differs from gpt-image-1:
#   - input_fidelity: NOT configurable (omitted)
#   - background=transparent: NOT supported (kept for non-transparent values)
#   - response_format: gpt-image-2 only returns b64_json (so omitted; use output_format)
# Unsupported params sent by clients still get a clean 400 from upstream API.
#
# Affected files:
#   - open-sse/config/providerModels.js
#
# Idempotent.

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="open-sse/config/providerModels.js"
MARKER="// patches/06-add-gpt-image-2-to-openai.sh"

if grep -qF "$MARKER" "$FILE"; then
  echo "[06-add-gpt-image-2-to-openai] Already applied — skipping."
  exit 0
fi

python3 <<'PYEOF'
import pathlib, sys

path = pathlib.Path("open-sse/config/providerModels.js")
src = path.read_text()

old = """    // Image models
    { id: "gpt-image-1", name: "GPT Image 1", type: "image", params: ["n", "size", "quality", "response_format"] },
    { id: "dall-e-3", name: "DALL-E 3", type: "image", params: ["size", "quality", "style", "response_format"] },
    { id: "dall-e-2", name: "DALL-E 2", type: "image", params: ["n", "size", "response_format"] },"""

new = """    // Image models
    // patches/06-add-gpt-image-2-to-openai.sh — added gpt-image-2 (OpenAI Apr 2026).
    { id: "gpt-image-2", name: "GPT Image 2", type: "image", params: ["n", "size", "quality", "background", "output_format"] },
    { id: "gpt-image-1", name: "GPT Image 1", type: "image", params: ["n", "size", "quality", "response_format"] },
    { id: "dall-e-3", name: "DALL-E 3", type: "image", params: ["size", "quality", "style", "response_format"] },
    { id: "dall-e-2", name: "DALL-E 2", type: "image", params: ["n", "size", "response_format"] },"""

if old not in src:
    print(f"[06-add-gpt-image-2-to-openai] FAILED: pattern not found in {path}", file=sys.stderr)
    print("File contents around openai image models:", file=sys.stderr)
    idx = src.find("gpt-image-1")
    if idx >= 0:
        print(src[max(0, idx-200):idx+600], file=sys.stderr)
    sys.exit(1)

path.write_text(src.replace(old, new, 1))
print("[06-add-gpt-image-2-to-openai] Applied.")
PYEOF
