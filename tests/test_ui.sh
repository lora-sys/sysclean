#!/usr/bin/env bash
# UI primitive unit tests
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
PASS=0
FAIL=0

test_ui() {
  local name="$1" expected="$2" cmd="$3"
  local out=$(bash -c "
    source $LIB_DIR/common.sh
    source $LIB_DIR/ui.sh
    $cmd
  " 2>&1)
  
  if [[ "$out" == *"$expected"* ]]; then
    PASS=$((PASS+1))
    echo "  ✓ $name"
  else
    FAIL=$((FAIL+1))
    echo "  ✗ $name (expected: '$expected', got: '$out')"
  fi
}

echo "─── UI primitive tests ───"

# ui_msg
test_ui "ui_msg displays text" "Hello" 'ui_msg "Hello" 2>/dev/null | head -3'

# ui_input
test_ui "ui_input returns typed value" "typed" 'echo "typed" | ui_input "Enter" "" 2>/dev/null'

# ui_yesno - yes
test_ui "ui_yesno yes" "YES" 'if echo "y" | ui_yesno "?" 2>/dev/null; then echo YES; else echo NO; fi'

# ui_yesno - no  
test_ui "ui_yesno no" "NO" 'if echo "n" | ui_yesno "?" 2>/dev/null; then echo YES; else echo NO; fi'

# ui_menu picks option
test_ui "ui_menu picks 1" "REPLY=1" 'echo "1" | { ui_menu "T" 8 30 2 "?" "1" "A" "2" "B"; echo REPLY=$REPLY; } 2>/dev/null'

# ui_menu picks 2
test_ui "ui_menu picks 2" "REPLY=2" 'echo "2" | { ui_menu "T" 8 30 2 "?" "1" "A" "2" "B"; echo REPLY=$REPLY; } 2>/dev/null'

# ui_menu back
test_ui "ui_menu back returns 1" "rc=1" 'echo "0" | { ui_menu "T" 8 30 2 "?" "1" "A" "0" "B"; echo rc=$?; } 2>/dev/null'

# ui_checklist multi-select
test_ui "ui_checklist multi-select" "a" 'printf "1 3\n0\n" | { ui_checklist "T" 10 30 3 "?" "a" "Apple" "b" "Banana" "c" "Cherry"; } 2>/dev/null'

# ui_gauge
test_ui "ui_gauge progress" "50%" 'ui_gauge 5 10 "Test" 2>/dev/null | head -1'

# ui_clear
test_ui "ui_clear" "after" 'ui_clear; echo "after" 2>/dev/null'

# to_bytes / human
test_ui "to_bytes 1MB" "1048576" 'to_bytes "1M"'
test_ui "human 1.5G" "1.5 G" 'human 1610612736'

echo ""
echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -gt 0 ] && exit 1
exit 0
