# kiimpan/9router — Personal Fork

A personal fork of [decolua/9router](https://github.com/decolua/9router) with bug fixes applied locally. **Not intended for upstream contribution.** This exists only so I can run a patched 9router until the upstream maintainer fixes the bugs (or until I sync them in).

## Why a fork?

Upstream 9router ships pre-compiled Next.js bundles via npm (`9router@x.y.z`). The bundle has several bugs that prevent embeddings + web search + image generation from working as documented. The original source is open (`decolua/9router`, MIT), so we fork, patch from source, and run our own build.

## Patches

Located in `patches/`. Each script is idempotent (safe to re-run). Patches add a sentinel comment `// patches/NN-name.sh` to each modified file so detection is reliable.

| # | Script | Fixes | Source file(s) |
|---|---|---|---|
| 01 | `01-fix-tavily-routing.sh` | `Unknown provider: tavily/search` — routing handler rejects long-form catalog IDs | `src/shared/constants/providers.js` |
| 02 | `02-fix-voyage-encoding.sh` | Voyage AI embeddings 400: `encoding_format 'float' not valid -- accepted values are 'base64'` | `open-sse/handlers/embeddingsCore.js`, `open-sse/handlers/embeddingProviders/openai.js` |
| 03 | `03-fix-gemini-embedding.sh` | Gemini embeddings 404 on `v1beta` for GA models | `open-sse/handlers/embeddingProviders/gemini.js` |
| 04 | `04-fix-nanobanana-baseurl.sh` | Stale `/v1/chat/completions` baseUrl in nanobanana provider config (causes 404 if any fallback path hits it) | `open-sse/config/providers.js` |

## Apply patches

```bash
bash patches/apply-all.sh
```

Re-running is a no-op if patches are already applied.

## Build + run

```bash
pnpm install
pnpm run build
PORT=20128 NEXT_PUBLIC_BASE_URL=http://localhost:20128 pnpm run start
```

## Swap from npm-installed 9router to fork

The npm package `9router@*` installs a global CLI that runs a compiled bundle. To switch to our fork build:

```bash
bash patches/swap-to-fork.sh
```

This script:
- Builds the fork (if not built).
- Generates `~/9router/start-fork.sh` that runs our build with the same port + state dir as upstream.
- Updates `~/.config/autostart/9router.desktop` to point at the fork launcher (with backup).
- Prints instructions for stopping the old 9router.

Your existing config (`~/.9router/`) is untouched and gets picked up by the fork seamlessly.

## Sync from upstream

When `decolua/9router` releases a new version:

```bash
git fetch upstream
git merge upstream/master
bash patches/apply-all.sh
pnpm install
pnpm run build
```

If a patch script fails (because upstream refactored the code we patched), it prints which file is affected. Open the patch script, update the `python3` heredoc to match the new code shape, re-run.

## Not bugs (these are admin config issues you fix in the UI, not the source)

When you see Stability AI or HuggingFace returning errors like:

```
"Incorrect API key provided: hf_zEbCE***...HBXk. You can find your API key at
 https://platform.openai.com/account/api-keys."
```

The OpenAI-platform error message is a tell — the connection's credential is **typed as OpenAI** in admin, so requests are routed to OpenAI's endpoint instead of HF/Stability's. Fix: in `http://localhost:20128/dashboard`, delete the broken connection, re-add it via the correct provider tile (HuggingFace tile / Stability AI tile), paste the provider's API key.

## Not server bugs, just provider limits

- `gemini/*-image` returning 429 → Gemini free-tier quota exhausted. Add billing or use a different image provider.
- `cx/gpt-5.*-image` returning "not supported when using Codex with a ChatGPT account" → ChatGPT accounts need Plus/Pro tier with image-gen entitlement.

## License

MIT, inherited from upstream.
