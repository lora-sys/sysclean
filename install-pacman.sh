#!/usr/bin/env bash
# Install sysclean via personal pacman repo
# This script adds lora-sys repo to /etc/pacman.conf and installs sysclean
set -euo pipefail

REPO_NAME="lora-sys"
REPO_URL="https://lora-sys.github.io/sysclean"
CONF="/etc/pacman.conf"
MARKER="# >>> sysclean repo >>>"
CLOSER="# <<< sysclean repo <<<"

# Check if already added
if grep -q "$MARKER" "$CONF" 2>/dev/null; then
  echo "✓ Repo already configured in $CONF"
else
  echo "→ Adding $REPO_NAME repo to $CONF..."
  sudo tee -a "$CONF" >/dev/null << EOF

$MARKER
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = $REPO_URL
$CLOSER
EOF
  echo "  ✓ Added"
fi

echo "→ Syncing databases..."
sudo pacman -Sy

echo "→ Installing sysclean..."
sudo pacman -S --noconfirm sysclean

echo ""
echo "✓ Done! Run: sysclean --scan"
