# Contributing to sysclean

Thanks for your interest in improving sysclean! This document covers everything you need to send a PR that gets merged quickly.

## 📋 Quick links

- 🐛 [Bug reports](https://github.com/lora-sys/sysclean/issues/new?template=bug.md)
- 💡 [Feature requests](https://github.com/lora-sys/sysclean/issues/new?template=feature.md)
- 📖 [README.md](README.md) | [README.zh-CN.md](README.zh-CN.md)
- 📝 [CHANGELOG.md](CHANGELOG.md)
- 🧪 [Test scripts](tests/)

## 🛠 Development setup

```bash
# 1. Fork and clone
git clone https://github.com/<you>/sysclean.git
cd sysclean

# 2. Make changes
# ... edit lib/*.sh, sysclean, or tests/*.sh

# 3. Run local CI (must pass before pushing)
bash tests/local-ci.sh

# 4. Commit and push
git commit -m "Add: <description>"
git push origin <branch>

# 5. Open a PR on GitHub
```

**Test in a real TTY:** `sysclean` (interactive)
**Test in clean env:** `bash tests/local-ci.sh` (4 stages, 41 tests)
**Test GitHub CI locally:** [act](https://github.com/nektos/act) — `act`

## 🏗 Project structure

```
sysclean/
├── sysclean               # Main entry script (~300 lines)
├── lib/                   # Modules (~1700 lines total)
│   ├── common.sh          # utilities, logging, state, sudo
│   ├── ui.sh              # whiptail/dialog/text UI primitives
│   ├── services.sh        # systemd service scanner + manager
│   ├── docker.sh          # containers, images, volumes, networks
│   ├── flatpak.sh         # apps, runtimes
│   ├── disk.sh            # caches, builds, trash, journal, large files
│   └── startup.sh         # autostart, timers, cron, RC issues
├── tests/
│   ├── test_ui.sh         # UI primitive tests
│   ├── test_e2e.sh        # End-to-end TUI menu tests
│   └── local-ci.sh        # Local CI runner (mirrors GitHub Actions)
├── install.sh             # One-liner installer (user-local)
├── install-pacman.sh      # One-liner installer (pacman repo)
├── uninstall.sh           # Uninstaller
├── Makefile               # install / test / lint
└── .github/workflows/ci.yml
```

## 📝 Adding a new menu path

Most contributions add a new menu option. Here's the step-by-step:

### 1. Add a scanner function

Pick the right `lib/*.sh` file (or add a new one for a new subsystem). A scanner returns pipe-delimited records:

```bash
# In lib/example.sh
scan_examples() {
  local data
  data=$(some_command --format 'name|value|extra')
  echo "$data" | while IFS='|' read -r name value extra; do
    [ -z "$name" ] && continue
    echo "$name|$value|example"
  done
}
```

### 2. Add a `manage_*` function

This function provides the TUI logic for the menu:

```bash
manage_examples() {
  while true; do
    ui_clear
    local data; data=$(scan_examples)
    [ -z "$data" ] && { ui_info "No examples found"; return; }
    
    local args=()
    while IFS='|' read -r name value extra; do
      [ -z "$name" ] && continue
      args+=("$name" "[$value] $extra")
    done <<< "$data"
    
    local chosen
    chosen=$(ui_checklist "Examples" 20 80 10 "Select examples" "${args[@]}" 2>/dev/null)
    [ -z "$chosen" ] && return
    
    if ui_yesno "Delete selected examples?"; then
      for name in $chosen; do
        # do_something "$name"
      done
      ui_info "Done"
    fi
  done
}
```

### 3. Add the menu item

In `sysclean`, find `do_menu()` and add a new case:

```bash
ui_menu "sysclean 主菜单" 24 70 14 \
  "选择功能模块" \
  "1" "⚙️  服务管理 (systemd)" \
  "2" "🐳 Docker 管理" \
  "3" "📦 Flatpak 管理" \
  "4" "💾 磁盘清理" \
  "5" "🚀 启动项 & Shell RC" \
  "6" "🩺 系统诊断 & 扫描报告" \
  "7" "🧹 一键安全清理（保守）" \
  "8" "📜 查看操作历史" \
  "9" "⚙️  设置（白名单/黑名单）" \
  "10" "🎯 Examples" \    # ← new item
  "0" "退出" \

# ... in the case statement:
10) manage_examples ;;    # ← new case
```

### 4. Add a test case

In `tests/test_e2e.sh`, add a `test_with_pty` call:

```bash
test_with_pty "Examples menu" "10
0
0" 5
```

### 5. Update CHANGELOG.md

Add an entry under "Unreleased" or the next version.

### 6. Run the tests

```bash
bash tests/local-ci.sh
# Must show: ✓ All tests passed + ✓ All steps green - safe to push
```

## 🎨 Code style

### Bash conventions

| Rule | Why |
|---|---|
| `#!/usr/bin/env bash` shebang | Portable |
| `set -euo pipefail` at top | Fail fast, no unset vars, surface pipeline errors |
| 2-space indent, no tabs | Consistent |
| `snake_case` for functions and vars | Idiomatic bash |
| `UPPERCASE` for env vars and globals | Distinguish from locals |
| Quote all variables: `"$var"` not `$var` | Handle spaces, prevent globbing |
| `local` for all function-internal vars | Avoid polluting global scope |
| Functions return via stdout, not `return` strings | Composability |

### Good

```bash
my_func() {
  local input="$1"
  local result
  result=$(echo "$input" | tr 'a-z' 'A-Z')
  echo "$result"
}

output=$(my_func "hello")
```

### Bad

```bash
myFunc() {
  result=`echo $input | tr a-z A-Z`
  echo $result
}
```

### Error handling

- **Always** use `2>/dev/null` for commands whose stderr is expected noise
- **Never** suppress stdout — the user wants to see the output
- Use `|| true` or `|| var=default` to prevent `set -e` from killing the script
- Use `[[ ]]` for tests; `[ ]` is for POSIX compat (we target bash 4.0+)
- Always check `[[ -d "$path" ]]` before `du -sh "$path"`

### Logging

Use the `log_*` functions from `lib/common.sh`:

```bash
log_info "Scanning docker images..."
log_warn "Docker not installed"
log_error "Cannot find lib dir"
log_ok "Cleanup complete"
log_action "Removing $path"
```

## 🧪 Testing guide

### What to test

Every new menu path needs a test in `tests/test_e2e.sh`. Every new UI primitive or scanner function needs a test in `tests/test_ui.sh`.

### How tests work

- `tests/test_e2e.sh` uses `pty.fork()` in Python to drive a real TTY
- Each `test_with_pty` call sends a sequence of keystrokes and verifies the output
- A test passes if the output has > 10 meaningful lines (heuristic for "menu rendered properly")

### Writing a test

```bash
# In tests/test_e2e.sh
test_with_pty "My new feature" "10
0
0" 5
```

Arguments:
- `name` — descriptive name
- `inputs` — newline-separated keystrokes (digits + Enter)
- `timeout` — seconds to wait for output

### What if a test is flaky?

- Increase timeout
- Add `sleep` in the test driver
- Use a different input sequence
- If truly flaky, mark with `# FLAKY:` comment and we can fix it later

## 🐛 Bug reports

Open an issue with:

1. **Title**: short, specific
2. **sysclean version**: `sysclean --version`
3. **OS + version**: `uname -a`, `cat /etc/os-release`
4. **Steps to reproduce**: minimal command sequence
5. **Expected vs actual behavior**
6. **Output**: copy-paste the relevant `~/.config/sysclean/sysclean.log` lines

## 💡 Feature requests

Open an issue with:

1. **Title**: short, specific
2. **Use case**: what problem does this solve
3. **Proposed solution**: how you imagine it working
4. **Alternatives considered**: other ways to address this
5. **Mockup** (optional): ASCII art of what the menu would look like

## 🌐 Translations

- Source: `README.md` (English)
- Add a new file: `README.<lang>.md` (e.g., `README.ja.md`)
- Add a link in `README.md` to your translation
- Translations are kept in sync manually — please open a PR when English changes

## 📜 License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
