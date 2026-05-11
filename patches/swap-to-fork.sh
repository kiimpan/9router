#!/usr/bin/env bash
# Swap the running 9router (npm global install) to the patched fork build.
#
# Usage:
#   bash patches/swap-to-fork.sh
#
# This script:
#   1. Disables the autostart entry so the old npm-installed 9router stops respawning.
#   2. Builds the fork if not already built.
#   3. Generates a replacement start.sh in ~/9router/ that runs the patched fork.
#   4. Lets you choose whether to kill the running 9router now or on next reboot.
#
# Safe to run multiple times.
# Does NOT touch ~/.9router/ (your existing config, providers, API keys, DB).
# The fork uses the same HOME so it picks up your existing config seamlessly.

set -euo pipefail
FORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "9router fork swap script"
echo "  Fork dir:     $FORK_DIR"
echo "  Config dir:   $HOME/.9router/"
echo "  Launcher dir: $HOME/9router/"
echo ""

if [ ! -d "$FORK_DIR/.next" ]; then
  echo "Fork is not built yet."
  echo "Building now (this takes ~30s)..."
  ( cd "$FORK_DIR" && pnpm install && pnpm run build )
fi

NEW_LAUNCHER="$HOME/9router/start-fork.sh"
mkdir -p "$HOME/9router"

cat > "$NEW_LAUNCHER" <<EOF
#!/usr/bin/env bash
export NINEROUTER_URL="http://127.0.0.1:20128"
export NINEROUTER_KEY="\${NINEROUTER_KEY:-$(grep -oP 'NINEROUTER_KEY="\K[^"]+' "$HOME/9router/start.sh" 2>/dev/null || echo "")}"
exec env \\
  PORT=20128 \\
  HOSTNAME=127.0.0.1 \\
  NEXT_PUBLIC_BASE_URL=http://localhost:20128 \\
  pnpm --dir "$FORK_DIR" run start
EOF
chmod +x "$NEW_LAUNCHER"

echo "Created launcher: $NEW_LAUNCHER"
echo ""

DESKTOP="$HOME/.config/autostart/9router.desktop"
if [ -f "$DESKTOP" ]; then
  if grep -q "start-fork.sh" "$DESKTOP"; then
    echo "Autostart already points at the fork."
  else
    cp "$DESKTOP" "$DESKTOP.backup-$(date +%Y%m%d-%H%M%S)"
    # Replace Exec= line in-place
    python3 - "$DESKTOP" "$NEW_LAUNCHER" <<'PYEOF'
import sys, pathlib
desktop, new_exec = sys.argv[1], sys.argv[2]
p = pathlib.Path(desktop)
out = []
for line in p.read_text().splitlines():
    if line.startswith("Exec="):
        out.append(f"Exec={new_exec}")
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
print(f"Patched {desktop} to use {new_exec}")
PYEOF
  fi
else
  echo "WARNING: no autostart entry at $DESKTOP — fork will not auto-start on login."
fi

echo ""
echo "Done. The fork is ready to run."
echo ""
echo "To swap now (you'll lose ~5 seconds of 9router availability):"
echo "  1. Stop your current 9router (close its terminal or kill the npm-installed one)"
echo "  2. Run:   bash $NEW_LAUNCHER"
echo ""
echo "Or restart your system — the autostart entry now points at the fork."
echo ""
echo "To roll back to the upstream npm version:"
echo "  Restore the .desktop.backup-* file in $HOME/.config/autostart/"
