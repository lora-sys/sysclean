#!/usr/bin/env bash
# Local CI runner - mirrors .github/workflows/ci.yml exactly
# Run from project root: bash tests/local-ci.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# Use a CLEAN test HOME (simulates fresh CI)
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
trap 'rm -rf "$TEST_HOME"' EXIT

# Ensure required tools
need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ Missing: $1"; return 1; }; }
for t in bash whiptail jq systemctl docker python3; do
  need "$t" || true
done

echo "═══════════════════════════════════════════════"
echo "  Local CI runner (mirrors GitHub Actions)"
echo "  HOME: $TEST_HOME"
echo "  PWD:  $REPO_DIR"
echo "═══════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0
FAILED_TESTS=()

run_step() {
  local name="$1" cmd="$2"
  echo ""
  echo "─── $name ───"
  if bash -c "$cmd"; then
    echo "  ✓ PASS"
    PASS=$((PASS+1))
  else
    echo "  ✗ FAIL"
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
  fi
}

# === Step 1: Lint ===
run_step "Lint bash scripts" '
  for f in sysclean lib/*.sh tests/*.sh install.sh uninstall.sh install-pacman.sh; do
    if [ -f "$f" ]; then
      bash -n "$f" || { echo "  ✗ $f has syntax errors"; exit 1; }
    fi
  done
  echo "    (all scripts bash -n OK)"
'

# === Step 2: UI unit tests ===
run_step "UI unit tests" '
  bash tests/test_ui.sh
'

# === Step 3: CLI tests ===
run_step "CLI tests" '
  ./sysclean --version
  ./sysclean --help > /dev/null
  ./sysclean --scan > /tmp/scan_output.txt
  grep -q "───" /tmp/scan_output.txt
'

# === Step 4: E2E tests ===
run_step "E2E tests" '
  bash tests/test_e2e.sh
'

echo ""
echo "═══════════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed steps:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  ✗ $t"
  done
  exit 1
fi
echo "✓ All steps green - safe to push"
exit 0
