#!/usr/bin/env bash
# sysclean uninstaller
set -euo pipefail

PREFIX="${1:-$HOME/.local}"
BIN="$PREFIX/bin/sysclean"
LIB="$PREFIX/share/sysclean"
CONF="$HOME/.config/sysclean"

echo "Removing sysclean from $PREFIX..."
[ -f "$BIN" ] && rm -v "$BIN" || echo "  (binary not found)"

if [ -d "$LIB" ]; then
  rm -rfv "$LIB"
else
  echo "  (lib not found)"
fi

echo ""
echo "Configuration kept at: $CONF"
echo "To also remove config (irreversible):"
echo "  rm -rf $CONF"
echo ""
echo "✓ sysclean uninstalled"
