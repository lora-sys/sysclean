#!/usr/bin/env bash
# E2E integration tests for sysclean
# Run: bash tests/test_e2e.sh
set -uo pipefail

SYSCLEAN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sysclean"
SYSCLEAN_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib"
TEST_LOG="$(dirname "${BASH_SOURCE[0]}")/test_e2e.log"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

PASS=0
FAIL=0
FAILED_TESTS=()

ANSI_ESCAPE='\x1b\[[?0-9;]*[a-zA-Z]'

run_test() {
  local name="$1" inputs="$2" timeout="${3:-15}"
  echo "  TEST: $name"
  
  local pid fd out=""
  exec 3>&1
  (
    exec 4>&3 3>&-  # save stdout
    {
      "$SYSCLEAN" 2>&1 &
      pid=$!
      
      # Send inputs with delays
      for input in $inputs; do
        sleep 0.8
        echo "$input" >&4
      done
      
      sleep "$timeout"
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    } 
  ) | sed -E "s/$ANSI_ESCAPE//g" > "$TEST_LOG" 2>&1
  
  local lines=$(wc -l < "$TEST_LOG")
  if [ "$lines" -gt 5 ]; then
    PASS=$((PASS+1))
    echo "    ✓ PASS ($lines lines)"
  else
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
    echo "    ✗ FAIL ($lines lines)"
  fi
}

# Need pty for interactive testing
test_with_pty() {
  local name="$1" inputs="$2" timeout="${3:-15}"
  echo "  TEST: $name (pty)"
  
  # Use Python to drive the pty
  local result=$(python3 << PYEOF
import pty, os, time, select, re, sys
ANSI = re.compile(r'\x1b[^a-zA-Z]*[a-zA-Z]')

pid, fd = pty.fork()
if pid == 0:
    env = os.environ.copy()
    env["TERM"] = "xterm-256color"
    env["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    os.execvpe("$SYSCLEAN", ["$SYSCLEAN"], env)
    sys.exit(1)

out = b""
inputs = """$inputs""".strip().split('\n')
i = 0
last_send = 0
start = time.time()
while time.time() - start < $timeout and i < len(inputs):
    r, _, _ = select.select([fd], [], [], 0.3)
    if r:
        try:
            chunk = os.read(fd, 16384)
            if chunk: out += chunk
        except OSError: break
    text = ANSI.sub('', out.decode("utf-8", errors="replace"))
    if "选择 [" in text and time.time() - last_send > 1.5:
        try:
            os.write(fd, (inputs[i] + "\n").encode())
            i += 1
            last_send = time.time()
        except OSError: break

time.sleep(0.5)
try: os.kill(pid, 9)
except: pass
try: os.waitpid(pid, 0)
except: pass

text = ANSI.sub('', out.decode("utf-8", errors="replace"))
lines = [l for l in text.split('\n') if l.strip() and not all(c in '\u2500\u2501|' for c in l)]
print(len(lines))
PYEOF
)
  
  if [ "$result" -gt 10 ]; then
    PASS=$((PASS+1))
    echo "    ✓ PASS ($result lines)"
  else
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name")
    echo "    ✗ FAIL ($result lines)"
  fi
}

echo ""
echo "═══════════════════════════════════════════════"
echo "  sysclean E2E tests"
echo "═══════════════════════════════════════════════"
echo ""

# CLI tests
echo "─── CLI tests ───"
out=$("$SYSCLEAN" --version 2>&1)
if [ "$out" = "sysclean 0.1.0" ]; then
  PASS=$((PASS+1))
  echo "  ✓ --version"
else
  FAIL=$((FAIL+1)); FAILED_TESTS+=("--version")
  echo "  ✗ --version (got: $out)"
fi

out=$("$SYSCLEAN" --help 2>&1 | wc -l)
if [ "$out" -gt 10 ]; then
  PASS=$((PASS+1))
  echo "  ✓ --help"
else
  FAIL=$((FAIL+1)); FAILED_TESTS+=("--help")
  echo "  ✗ --help (only $out lines)"
fi

out=$("$SYSCLEAN" --scan 2>&1 | grep -c "───")
if [ "$out" -ge 8 ]; then
  PASS=$((PASS+1))
  echo "  ✓ --scan ($out sections)"
else
  FAIL=$((FAIL+1)); FAILED_TESTS+=("--scan")
  echo "  ✗ --scan (only $out sections)"
fi

# TUI tests
echo ""
echo "─── TUI tests ───"

# Main menu shows
test_with_pty "Main menu" "0" 4

# Service management
test_with_pty "Service management" "1
0
0" 5

# Docker menu
test_with_pty "Docker menu" "2
0
0" 5

# Docker containers
test_with_pty "Docker containers" "2
1
0
0
0" 6

# Docker images
test_with_pty "Docker images" "2
2
0
0
0" 6

# Docker volumes
test_with_pty "Docker volumes" "2
3
0
0
0" 6

# Docker networks
test_with_pty "Docker networks" "2
4
0
0
0" 6

# Docker orphan (no delete)
test_with_pty "Docker orphan images (no)" "2
7
n
0
0" 8

# Flatpak apps
test_with_pty "Flatpak apps" "3
1
0
0
0" 6

# Flatpak runtimes
test_with_pty "Flatpak runtimes" "3
2
0
0
0" 6

# Disk - top dirs
test_with_pty "Disk top dirs" "4
1
0
0
0" 6

# Disk - cache
test_with_pty "Disk cache" "4
2
0
0
0" 6

# Disk - build artifacts
test_with_pty "Disk build artifacts" "4
5
0
0
0" 6

# Disk - trash
test_with_pty "Disk trash" "4
7
0
0
0" 6

# Disk - journal
test_with_pty "Disk journal" "4
8
0
0
0" 6

# Disk - large files
test_with_pty "Disk large files" "4
9
0
0
0" 6

# Startup - autostart
test_with_pty "Startup autostart" "5
1
0
0
0" 6

# Startup - timers
test_with_pty "Startup timers" "5
2
0
0
0" 6

# Startup - cron
test_with_pty "Startup cron" "5
3
n
0
0" 6

# Startup - RC
test_with_pty "Startup RC" "5
4
0
0
0" 6

# Settings
test_with_pty "Settings whitelist" "9
1
0
0" 5

# History
test_with_pty "History" "8
0
0" 4

# System scan via menu
test_with_pty "System scan via menu" "6
0
0" 12

# Summary
echo ""
echo "═══════════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════"
[ $FAIL -gt 0 ] && {
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done
  exit 1
}
echo "✓ All tests passed"
exit 0
