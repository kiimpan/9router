#!/usr/bin/env bash
# Patch 02 — Fix Voyage AI embeddings request
#
# Problem: open-sse/handlers/embeddingsCore.js defaults encoding_format to "float"
# for ALL providers. Voyage AI's API only accepts "base64" and returns:
#   [400]: "Value 'float' supplied for argument 'encoding_format' is not valid
#         -- accepted values are 'base64'"
#
# Fix: When the upstream provider is voyage-ai, default to "base64" and decode
# base64 → float[] in the normalize step so OpenAI-compatible clients still get
# back float arrays as expected.
#
# Affected files:
#   - open-sse/handlers/embeddingsCore.js
#   - open-sse/handlers/embeddingProviders/openai.js
#
# Idempotent.

set -euo pipefail
cd "$(dirname "$0")/.."

CORE_FILE="open-sse/handlers/embeddingsCore.js"
ADAPTER_FILE="open-sse/handlers/embeddingProviders/openai.js"
MARKER="// patches/02-fix-voyage-encoding.sh"

if grep -qF "$MARKER" "$CORE_FILE" && grep -qF "$MARKER" "$ADAPTER_FILE"; then
  echo "[02-voyage-encoding] Already applied — skipping."
  exit 0
fi

python3 <<'PYEOF'
import re, pathlib, sys

# Step 1: embeddingsCore.js — make the encoding_format default provider-aware
core_path = pathlib.Path("open-sse/handlers/embeddingsCore.js")
core_src = core_path.read_text()

if "// patches/02-fix-voyage-encoding.sh" not in core_src:
    old = "    encoding_format: body.encoding_format || \"float\","
    new = (
        "    // patches/02-fix-voyage-encoding.sh — Voyage AI only accepts 'base64'\n"
        "    encoding_format: body.encoding_format || (provider === \"voyage-ai\" ? \"base64\" : \"float\"),"
    )
    if old not in core_src:
        print("[02-voyage-encoding] ERROR: encoding_format line not found in embeddingsCore.js. Upstream changed.", file=sys.stderr)
        sys.exit(2)
    core_src = core_src.replace(old, new, 1)
    core_path.write_text(core_src)
    print(f"[02-voyage-encoding] Patched {core_path}")
else:
    print(f"[02-voyage-encoding] {core_path} already patched")

# Step 2: openai.js adapter — when receiving base64 response from Voyage, decode to float[]
# so the OpenAI-compatible response shape is preserved for clients.
adapter_path = pathlib.Path("open-sse/handlers/embeddingProviders/openai.js")
adapter_src = adapter_path.read_text()

if "// patches/02-fix-voyage-encoding.sh" not in adapter_src:
    # Replace the normalize stub with a base64-aware decoder
    old_norm = "    normalize: (responseBody) => responseBody,"
    new_norm = """    // patches/02-fix-voyage-encoding.sh — decode base64 embeddings from Voyage back to float[]
    normalize: (responseBody) => {
      if (!responseBody || !Array.isArray(responseBody.data)) return responseBody;
      const needsDecode = responseBody.data.some(
        (d) => d && typeof d.embedding === "string"
      );
      if (!needsDecode) return responseBody;
      const decoded = responseBody.data.map((d) => {
        if (!d || typeof d.embedding !== "string") return d;
        // base64 → Float32Array → plain array
        const bin = Buffer.from(d.embedding, "base64");
        const f32 = new Float32Array(bin.buffer, bin.byteOffset, bin.byteLength / 4);
        return { ...d, embedding: Array.from(f32) };
      });
      return { ...responseBody, data: decoded };
    },"""
    if old_norm not in adapter_src:
        print("[02-voyage-encoding] ERROR: normalize stub not found in openai.js adapter. Upstream changed.", file=sys.stderr)
        sys.exit(2)
    adapter_src = adapter_src.replace(old_norm, new_norm, 1)
    adapter_path.write_text(adapter_src)
    print(f"[02-voyage-encoding] Patched {adapter_path}")
else:
    print(f"[02-voyage-encoding] {adapter_path} already patched")
PYEOF

echo "[02-voyage-encoding] Done."
