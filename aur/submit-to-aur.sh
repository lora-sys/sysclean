#!/usr/bin/env bash
# Submit sysclean to AUR
# Prereq: Add ~/.ssh/id_ed25519.pub to https://aur.archlinux.org/account/lora-sys/edit
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUR_DIR="${AUR_DIR:-$HOME/aur-packages/sysclean}"

echo "╭──────────────────────────────────────────╮"
echo "│  AUR submission: sysclean                │"
echo "╰──────────────────────────────────────────╯"
echo ""

# 1. Verify SSH access
echo "→ Testing AUR SSH access..."
if ! ssh -T -o ConnectTimeout=5 aur@aur.archlinux.org 2>&1 | grep -q "Welcome to AUR"; then
  echo "  ✗ SSH key not registered with AUR"
  echo ""
  echo "  Please add this key to https://aur.archlinux.org/account/lora-sys/edit:"
  echo ""
  cat ~/.ssh/id_ed25519.pub | sed 's/^/    /'
  echo ""
  echo "  Then re-run this script."
  exit 1
fi
echo "  ✓ SSH access OK"

# 2. Clone AUR repo
echo ""
echo "→ Cloning AUR repo..."
mkdir -p "$(dirname "$AUR_DIR")"
if [ -d "$AUR_DIR" ]; then
  cd "$AUR_DIR"
  git pull origin master
else
  git clone ssh://aur@aur.archlinux.org/sysclean.git "$AUR_DIR"
  cd "$AUR_DIR"
fi

# 3. Copy files
echo ""
echo "→ Copying PKGBUILD + .SRCINFO..."
cp "$REPO_DIR/aur/PKGBUILD" .
cp "$REPO_DIR/aur/.SRCINFO" .

# 4. Update .SRCINFO from PKGBUILD (if updpkgsums available)
if command -v updpkgsums >/dev/null; then
  echo "→ Updating source checksums with updpkgsums..."
  updpkgsums || true
fi

# 5. Stage and commit
echo ""
echo "→ Committing..."
git add PKGBUILD .SRCINFO
git status
git -c user.name="lora-sys" \
    -c user.email="3526039967@qq.com" \
    commit -m "Initial upload: sysclean v0.1.0

Global system cleanup and management TUI for Linux.
- Service management (systemd)
- Docker / Flatpak managers
- Disk cleanup, startup audit
- 3 UI modes (whiptail/dialog/text)
- See https://github.com/lora-sys/sysclean for full details"

# 6. Push
echo ""
echo "→ Pushing to AUR..."
git push origin master

echo ""
echo "╭──────────────────────────────────────────╮"
echo "│  ✓ Submitted to AUR!                     │"
echo "╰──────────────────────────────────────────╯"
echo ""
echo "  Visit: https://aur.archlinux.org/packages/sysclean"
echo ""
echo "  Note: AUR package moderation happens manually."
echo "  It may take a few hours to appear in search results."
