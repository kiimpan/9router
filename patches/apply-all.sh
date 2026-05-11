#!/usr/bin/env bash
# Apply all kiimpan/9router fork patches.
#
# Usage:
#   bash patches/apply-all.sh
#
# Patches are idempotent — running this script multiple times is safe.
# Re-run after every `git pull upstream master` to re-apply our fixes
# on top of new upstream code. If any patch fails because upstream
# refactored the affected code, the failing script prints which file
# it couldn't patch — fix it manually and update the patch script.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "Applying kiimpan/9router fork patches…"
echo "Repo: $(pwd)"
echo "HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo '(not a git repo)')"
echo ""

for patch in patches/[0-9][0-9]-*.sh; do
  [ -f "$patch" ] || continue
  echo "→ Running $patch"
  bash "$patch"
  echo ""
done

echo "All patches applied."
echo ""
echo "Next steps:"
echo "  1. pnpm install"
echo "  2. pnpm run build"
echo "  3. PORT=20128 NEXT_PUBLIC_BASE_URL=http://localhost:20128 pnpm run start"
