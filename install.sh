#!/usr/bin/env bash
# sysclean installer
# Usage: curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
# Or:    ./install.sh [prefix]  (default: ~/.local)
set -euo pipefail

REPO="${SYSCLEAN_REPO:-https://raw.githubusercontent.com/lora-sys/sysclean/main}"
PREFIX="${1:-$HOME/.local}"
VERSION="${SYSCLEAN_VERSION:-main}"

BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/share/sysclean/lib"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "╭──────────────────────────────────────────╮"
echo "│  sysclean installer                       │"
echo "╰──────────────────────────────────────────╯"
echo ""
echo "  Prefix:  $PREFIX"
echo "  Version: $VERSION"
echo "  Source:  $REPO"
echo ""

# Check prerequisites
echo "→ Checking prerequisites..."
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "  ✗ Missing: $1"; return 1; }; }
ok=1
need_cmd bash   || ok=0
need_cmd curl  || ok=0
need_cmd tput  || ok=0  # pretty output
[ $ok -eq 0 ] && { echo ""; echo "Please install missing prerequisites and retry."; exit 1; }
echo "  ✓ All prerequisites met"

# Optional checks
for opt in whiptail dialog docker flatpak systemctl jq; do
  if command -v "$opt" >/dev/null 2>&1; then
    echo "  ✓ Optional: $opt"
  fi
done

# Download
echo ""
echo "→ Downloading sysclean $VERSION..."
mkdir -p "$TMP_DIR"
curl -fsSL "$REPO/sysclean" -o "$TMP_DIR/sysclean" || {
  echo "  ✗ Failed to download sysclean"
  exit 1
}
for f in common ui services docker flatpak disk startup; do
  curl -fsSL "$REPO/lib/$f.sh" -o "$TMP_DIR/$f.sh" || {
    echo "  ✗ Failed to download lib/$f.sh"
    exit 1
  }
done
echo "  ✓ Downloaded"

# Install
echo ""
echo "→ Installing to $PREFIX..."
mkdir -p "$BIN_DIR" "$LIB_DIR"
install -m 755 "$TMP_DIR/sysclean" "$BIN_DIR/sysclean"
for f in common ui services docker flatpak disk startup; do
  install -m 644 "$TMP_DIR/$f.sh" "$LIB_DIR/$f.sh"
done
echo "  ✓ Installed: $BIN_DIR/sysclean"
echo "  ✓ Installed: $LIB_DIR/"

# Verify
echo ""
echo "→ Verifying installation..."
if "$BIN_DIR/sysclean" --version >/dev/null 2>&1; then
  echo "  ✓ sysclean is working: $("$BIN_DIR/sysclean" --version)"
else
  echo "  ✗ sysclean failed to start"
  exit 1
fi

# PATH check
echo ""
case ":$PATH:" in
  *":$BIN_DIR:"*) echo "  ✓ $BIN_DIR is in your PATH" ;;
  *)
    echo "  ⚠  $BIN_DIR is NOT in your PATH"
    echo ""
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
    echo "Or run sysclean with full path: $BIN_DIR/sysclean"
    ;;
esac

echo ""
echo "╭──────────────────────────────────────────╮"
echo "│  ✓ sysclean installed successfully!      │"
echo "╰──────────────────────────────────────────╯"
echo ""
echo "Quick start:"
echo "  sysclean           Launch interactive TUI"
echo "  sysclean --scan    Full system report"
echo "  sysclean --help    All options"
echo ""
echo "Uninstall: curl -fsSL $REPO/uninstall.sh | bash"
