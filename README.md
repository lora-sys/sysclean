<div align="center">

# 🧹 sysclean

### A global system cleanup and management TUI for Linux

*Service control · Docker · Flatpak · Disk · Startup audit — all in one menu.*

[![Version](https://img.shields.io/badge/version-0.1.0-6366f1?style=flat-square)](https://github.com/lora-sys/sysclean/releases)
[![Platform](https://img.shields.io/badge/platform-Linux-22c55e?style=flat-square)](#-requirements)
[![Shell](https://img.shields.io/badge/shell-bash-4eaa25?style=flat-square)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-f59e0b?style=flat-square)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-25%2F25-22c55e?style=flat-square)](#-testing)
[![CI](https://github.com/lora-sys/sysclean/actions/workflows/ci.yml/badge.svg)](https://github.com/lora-sys/sysclean/actions)

```text
sysclean 主菜单
  1) ⚙️  服务管理 (systemd)        ← 200+ services, all visible
  2) 🐳 Docker 管理               ← containers / images / volumes / networks
  3) 📦 Flatpak 管理               ← apps + runtimes
  4) 💾 磁盘清理                  ← caches, builds, trash, journal
  5) 🚀 启动项 & Shell RC          ← autostart, timers, cron, RC issues
  6) 🩺 系统诊断 & 扫描报告       ← full system audit
  7) 🧹 一键安全清理（保守）
```

</div>

---

## 🎯 Why sysclean?

Modern Linux desktops accumulate cruft fast: orphaned Docker images, dormant `venv`s, broken systemd units, leftover Flatpak runtimes. **sysclean gives you one menu to see everything and act — with explicit confirmations, never silent deletions.**

| Problem | Without sysclean | With sysclean |
|---|---|---|
| "Where did my disk go?" | `du -sh /*` then `find` | `sysclean --scan` |
| "Is this service running?" | `systemctl status` × N | `sysclean` → Services |
| "What Docker images are orphans?" | `docker images` + manual check | `sysclean` → Docker → Orphan |
| "Which `.venv` can I delete?" | Manual inspection of each repo | `sysclean` → Disk → Build artifacts |

---

## ✨ Features

- 🔧 **Service management** — every systemd unit (system + user), with start/stop/enable/disable + log view
- 🐳 **Docker manager** — containers / images / volumes / networks, with selective deletion
- 📦 **Flatpak manager** — apps + runtimes, with reverse-dependency detection
- 💾 **Disk cleanup** — caches, build artifacts (`venv` / `node_modules` / `target`), package caches, trash, journal
- 🚀 **Startup audit** — autostart entries, systemd timers, cron, shell RC issues (duplicate aliases, hardcoded keys)
- 🩺 **System scan** — 11-section report, plain text, ready for piping
- 🛡 **Non-destructive** — every action requires `[y/N]`; dry-run mode; whitelist/blacklist
- 🎨 **3 UI modes** — `whiptail` (TUI), `dialog`, plain text (auto-fallback for non-TTY)

---

## 📦 Installation

### Option 1: pacman (Arch / CachyOS / Manjaro) — **recommended**

Add the personal repo and install:

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install-pacman.sh | sudo bash
```

This adds `[lora-sys]` to `/etc/pacman.conf`, syncs, and installs `sysclean`. After that:

```bash
pacman -Syu sysclean    # update
pacman -Rns sysclean    # remove
```

**Or manually:**

```bash
# Add to /etc/pacman.conf:
#   [lora-sys]
#   SigLevel = Optional TrustAll
#   Server = https://lora-sys.github.io/sysclean

sudo pacman -Sy
sudo pacman -S sysclean
```

### Option 2: One-liner (any Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
```

Installs to `~/.local/bin/sysclean` and `~/.local/share/sysclean/lib/`.

### Option 3: Manual / from source

```bash
git clone https://github.com/lora-sys/sysclean.git
cd sysclean
make install              # installs to ~/.local
# or
sudo make install-system  # installs to /usr/local
```

---

## 🚀 Usage

```bash
sysclean              # Launch interactive TUI
sysclean --scan       # Full system report (text)
sysclean --help       # All options
sysclean --version    # Show version
```

### CLI flags

| Flag | Description |
|---|---|
| `--scan` | Run full system scan, output text report |
| `--menu` | Launch TUI (default) |
| `--dry-run` / `-n` | Preview without executing |
| `--yes` / `-y` | Skip confirmation prompts |
| `--noninteract` | Force non-interactive mode |
| `--version` / `-V` | Print version and exit |
| `--help` / `-h` | Print help and exit |

### Example: `--scan` output

```text
═══════════════════════════════════════════════════════════
  sysclean v0.1.0 — System Scan
═══════════════════════════════════════════════════════════

─── 1. 系统资源 ───
/dev/nvme0n1p7  341G  127G  210G  38% /home

─── 2. 系统服务 (system) ───
  running: 31, failed: 0

─── 4. Docker ───
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          18        2         9.138GB   4.276GB (46%)
Containers      2         1         4.096kB   0B (0%)

─── 11. Shell RC 异常 ───
  /home/lora/.zshrc:190: duplicate alias "clean"
  200:export MINIMAX_API_KEY="sk-cp-hiZMA6NUCxXap_tBed..."
```

---

## 📋 Requirements

| Required | Optional |
|---|---|
| `bash` ≥ 4.0 | `whiptail` (TUI mode) or `dialog` (fallback) |
| `systemctl` (systemd-based distros) | `docker` (for Docker menu) |
| `jq` (for state persistence) | `flatpak` (for Flatpak menu) |
| | `sudo` (for system-level operations) |

The tool auto-falls back to plain text mode if `whiptail` is unavailable or stdin is not a TTY.

---

## ⚙️ Configuration

Configuration lives in `~/.config/sysclean/`:

| File | Purpose |
|---|---|
| `state.json` | Whitelist / blacklist / preferences |
| `history.log` | Last 50 actions |
| `sysclean.log` | Verbose log |

Whitelist services you never want interrupted:

```bash
sysclean → 9) Settings → 2) Add service to whitelist
```

---

## 🛡 Safety

- Every destructive action requires explicit `[y/N]` confirmation
- `--dry-run` previews without acting
- Whitelist protects services from "stop" prompts
- Trash contents shown before permanent deletion
- No project files touched without explicit selection
- Service operations require `sudo` only for system-level units

---

## 🧪 Testing

```bash
make test    # runs tests/test_e2e.sh
```

Coverage:
- **25/25** TUI menu paths verified
- **12/12** UI primitives (msg, yesno, input, checklist, menu, gauge, clear, info, error)
- **3/3** CLI modes (--version, --help, --scan)

CI runs on every push: see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

---

## 🤝 Contributing

PRs welcome. Before submitting:
1. Run `make test` — all tests must pass
2. Follow the existing code style (bash 4.0+, `set -euo pipefail`, 2-space indent)
3. Update tests if adding new menu paths

## 📜 License

[MIT](LICENSE) © 2026 lora-sys

## 🌐 Links

- 📦 **pacman repo**: https://lora-sys.github.io/sysclean
- 🐙 **GitHub**: https://github.com/lora-sys/sysclean
- 🐛 **Issues**: https://github.com/lora-sys/sysclean/issues
- 📋 **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- 🇨🇳 **中文文档**: [README.zh-CN.md](README.zh-CN.md)

---

<sub>Made with ❤️ for the Linux desktop. Not affiliated with Arch Linux or any distribution.</sub>
