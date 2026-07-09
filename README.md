<div align="center">

# 🧹 sysclean

### One TUI to clean, audit, and manage your Linux box

*Services · Docker · Flatpak · Disk · Startup · Shell RC — visible in one menu, deleted with one confirmation.*

[![Version](https://img.shields.io/badge/version-0.1.0-6366f1?style=flat-square)](https://github.com/lora-sys/sysclean/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/lora-sys/sysclean/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/lora-sys/sysclean/actions)
[![Platform](https://img.shields.io/badge/platform-Linux-22c55e?style=flat-square)](#-requirements)
[![Shell](https://img.shields.io/badge/shell-bash_4.0%2B-4eaa25?style=flat-square)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-f59e0b?style=flat-square)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-41%2F41-22c55e?style=flat-square)](#-testing)
[![Downloads](https://img.shields.io/github/downloads/lora-sys/sysclean/total?style=flat-square)](https://github.com/lora-sys/sysclean/releases)

```
sysclean 主菜单
─────────────────────────────────────────
 1) ⚙️  服务管理 (systemd)     ← 200+ 服务一屏全显
 2) 🐳 Docker 管理             ← 容器 / 镜像 / 卷 / 网络
 3) 📦 Flatpak 管理            ← apps + runtimes
 4) 💾 磁盘清理               ← caches, builds, trash, journal
 5) 🚀 启动项 & Shell RC       ← autostart, timers, RC issues
 6) 🩺 系统诊断 & 扫描报告      ← 11 节报告
 7) 🧹 一键安全清理
─────────────────────────────────────────
```

</div>

---

## 🎯 Why sysclean?

Your Linux desktop is full of hidden junk: orphaned Docker images, dormant `venv`s, broken systemd units, leftover Flatpak runtimes. You *know* it's there, but finding and removing it takes 10 different commands.

**sysclean** gives you one menu to see everything, check what's safe to delete, and act — with explicit confirmations on every destructive action. **Never silent, never surprising.**

| Pain point | Without sysclean | With sysclean |
|---|---|---|
| "Where did my disk go?" | `du -sh /*` then `find` and pray | `sysclean --scan` |
| "Which services are running?" | `systemctl list-units` × N | `sysclean` → Services |
| "What Docker images are orphans?" | `docker images` + manual check | `sysclean` → Docker → Orphan |
| "Which `.venv` can I delete?" | Manual inspection of each repo | `sysclean` → Disk → Build artifacts |
| "Is anything hardcoded in my shellrc?" | grep + manual review | `sysclean` → RC issues |

---

## ✨ Features

- 🔧 **Service manager** — every systemd unit (system + user), with start/stop/enable/disable + log view + failed-state reset
- 🐳 **Docker manager** — containers / images / volumes / networks, with selective deletion and orphan detection
- 📦 **Flatpak manager** — apps + runtimes, with reverse-dependency check
- 💾 **Disk cleanup** — caches, build artifacts (`venv` / `node_modules` / `target` / `dist`), package manager caches, trash, journal
- 🚀 **Startup audit** — autostart entries, systemd timers, cron, shell RC issues (duplicate aliases, hardcoded keys)
- 🩺 **System scan** — 11-section plain-text report, pipe-friendly, `--scan` for scripts
- 🛡 **Non-destructive** — every action requires `[y/N]` confirmation; `--dry-run` mode; whitelist/blacklist
- 🎨 **3 UI modes** — `whiptail` (TUI), `dialog`, plain text (auto-fallback for non-TTY environments)
- ⚡ **Zero dependencies for core** — just `bash` + standard Unix tools

---

## 📦 Installation

### 🚀 Option 1: pacman (Arch / CachyOS / Manjaro) — **recommended**

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install-pacman.sh | sudo bash
```

This one-liner:
1. Adds the `[lora-sys]` repo to `/etc/pacman.conf`
2. Runs `pacman -Sy` to sync
3. Runs `pacman -S sysclean` to install

After that, manage with standard pacman:

```bash
pacman -Syu sysclean    # update
pacman -Rns sysclean    # remove (and unused deps)
pacman -Qi sysclean    # info
```

Repo: **https://lora-sys.github.io/sysclean**

### ⚡ Option 2: One-liner (any Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
```

Installs to `~/.local/bin/sysclean` + `~/.local/share/sysclean/lib/`. No root required.

### 🔧 Option 3: Manual / from source

```bash
git clone https://github.com/lora-sys/sysclean.git
cd sysclean
make install              # → ~/.local (no sudo)
sudo make install-system  # → /usr/local (system-wide)
```

### 🐳 Option 4: Docker (no install)

```bash
docker run --rm -it --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /run/systemd:/run/systemd:ro \
  ghcr.io/lora-sys/sysclean:latest
```

*(coming soon — the container image is planned, not yet built)*

---

## 🚀 Usage

```bash
sysclean              # Launch interactive TUI
sysclean --scan       # Full system report (text, pipe-friendly)
sysclean --help       # Show all options
sysclean --version    # Show version
```

### CLI flags

| Flag | Short | Description |
|---|---|---|
| `--scan` | | Run full system scan, output plain text |
| `--menu` | | Launch TUI (default if no flag) |
| `--dry-run` | `-n` | Preview without executing |
| `--yes` | `-y` | Skip `[y/N]` confirmations (use carefully) |
| `--noninteract` | | Force non-interactive mode |
| `--version` | `-V` | Print version and exit |
| `--help` | `-h` | Print help and exit |

### Example: `sysclean --scan`

```text
═══════════════════════════════════════════════════════════
  sysclean v0.1.0 — System Scan
═══════════════════════════════════════════════════════════

─── 1. 系统资源 ───
/dev/nvme0n1p7  341G  127G  210G  38% /home
Mem:            23Gi  12Gi  8.4Gi ...

─── 2. 系统服务 (system) ───  ─── 3. 用户服务 ───
  running: 31, failed: 0           running: 35, failed: 0

─── 4. Docker ───
Images          18   2   9.14GB   4.28GB reclaimable (46%)
Containers      2    1   ...

─── 5. Flatpak ───  ─── 6. 顶级磁盘占用 ───
  apps: 11  runtimes: 10   /home/lora/repos  49G
                                 /home/lora/桌面   2.1G
─── 7. 缓存大小 ───              /home/lora/文档   2.0G
  4.5G  /home/lora/.cache         ...
─── 8. 回收站 ───
  0     (empty)

─── 9. 日志占用 ───  ─── 10. systemd 计时器 ───
  47M                       snapper-cleanup.timer ...
                            shadow.timer ...

─── 11. Shell RC 异常 ───
  ⚠ /home/lora/.zshrc:190  duplicate alias "clean"
  ⚠ /home/lora/.zshrc:200  hardcoded key: MINIMAX_API_KEY=sk-cp-...

═══════════════════════════════════════════════════════════
扫描完成。运行 'sysclean' 进入交互模式。
```

---

## 🎨 TUI walkthrough

```
─── 服务管理 ───                       ─── Docker 管理 ───
  1) ▶ 活跃服务 (32)                    1) 📦 容器 (1 运行 / 2 总)
  2) ✗ 失败服务 (0)                    2) 🖼️  镜像 (18 总)
  3) 🔍 浏览所有服务 (200+)              3) 💾 数据卷 (4 总)
  4) 📜 重置所有 failed 状态            4) 🌐 网络 (6 总)
  5) 🩺 检测可疑服务                   5) 🧹 一键清理孤儿
  0) 返回                              7) 🔍 查看孤儿镜像

─── 磁盘清理 ───                       ─── 启动项 & Shell RC ───
  1) Home top dirs (TOP 30)             1) 🚀 用户 autostart (0)
  2) ~/.cache subdirs                   2) ⏰ systemd 计时器 (10)
  5) Build artifacts                    3) 📋 cron 任务 (0)
  7) Trash                              4) 📝 Shell rc 异常
  8) Journal logs (vacuum)               0) 返回
```

Every menu:
- **Lists** what's there with sizes/counts
- **Checkboxes** for multi-select (whiptail)
- **`[y/N]`** confirmation before anything destructive
- **`ESC`** to cancel at any time

---

## 📋 Requirements

### Required
| Tool | Why |
|---|---|
| `bash` ≥ 4.0 | Core scripting |
| `systemctl` | Service management (systemd-based distros) |
| `jq` | State persistence (`~/.config/sysclean/state.json`) |

### Optional (auto-skipped if missing)
| Tool | What it enables |
|---|---|
| `whiptail` | TUI mode (falls back to `dialog` or text) |
| `dialog` | Alternative TUI |
| `docker` | Docker manager menu |
| `flatpak` | Flatpak manager menu |
| `sudo` | System-level service operations |

When `whiptail` is unavailable OR stdin is not a TTY (CI, scripts), the tool automatically uses plain text mode. **It works everywhere.**

---

## ⚙️ Configuration

`~/.config/sysclean/`:

| File | Purpose |
|---|---|
| `state.json` | Whitelist / blacklist / preferences |
| `history.log` | Last 50 actions |
| `sysclean.log` | Verbose log |

Whitelist services you never want interrupted:

```bash
sysclean → 9) Settings → 2) Add service to whitelist
```

Or directly edit `state.json`:

```json
{
  "whitelist": ["docker", "sshd", "NetworkManager"],
  "blacklist": []
}
```

---

## 🛡 Safety guarantees

- ✅ Every destructive action requires explicit `[y/N]` confirmation
- ✅ `--dry-run` previews without acting
- ✅ Whitelist protects services from "stop" prompts
- ✅ Trash contents shown before permanent deletion
- ✅ No project files touched without explicit selection
- ✅ `sudo` only required for system-level unit operations
- ✅ All file operations use absolute paths
- ✅ All variables quoted; `set -euo pipefail` everywhere

---

## 🧪 Testing

```bash
make test              # quick test
bash tests/local-ci.sh # full CI-equivalent (4 stages)
```

Coverage: **41/41 tests pass**

- ✅ **4/4** CI stages (lint, UI, CLI, E2E)
- ✅ **12/12** UI primitives (msg, yesno, input, checklist, menu, gauge, clear, info, error, to_bytes, human, has)
- ✅ **3/3** CLI modes (--version, --help, --scan)
- ✅ **26/26** TUI menu paths (all main menu sub-menus)

CI runs on every push — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

---

## 🤝 Contributing

PRs welcome! See **[CONTRIBUTING.md](CONTRIBUTING.md)** for:
- Development setup
- How to add a new menu path (5-step process)
- Code style (bash 4.0+, 2-space indent, quoted vars, etc.)
- How to write tests
- Bug report / feature request templates

---

## 📁 Project structure

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
├── tests/                 # Test scripts
│   ├── test_ui.sh         # UI primitive tests
│   ├── test_e2e.sh        # End-to-end menu tests
│   └── local-ci.sh        # Local CI runner (mirrors GitHub Actions)
├── install.sh             # One-liner installer (user-local)
├── install-pacman.sh      # One-liner installer (pacman repo)
├── uninstall.sh           # Uninstaller
├── Makefile               # install / test / lint
├── .github/workflows/ci.yml
├── README.md              # You are here
├── README.zh-CN.md        # 中文文档
├── CHANGELOG.md
└── LICENSE                # MIT
```

---

## 🗺 Roadmap

- [x] **v0.1.0** — core services, Docker, Flatpak, disk, startup, RC
- [ ] **v0.2.0** — Snap manager, Brew manager, system snapshots
- [ ] **v0.3.0** — Plugin system for custom scanners
- [ ] **v1.0.0** — Stable API, AUR submission (if maintainer access granted), community translations

---

## 📜 License

[MIT](LICENSE) © 2026 lora-sys

---

## 🌐 Links

| | |
|---|---|
| 📦 **pacman repo** | https://lora-sys.github.io/sysclean |
| 🐙 **GitHub** | https://github.com/lora-sys/sysclean |
| 📋 **Releases** | https://github.com/lora-sys/sysclean/releases |
| 🐛 **Issues** | https://github.com/lora-sys/sysclean/issues |
| 📝 **Changelog** | [CHANGELOG.md](CHANGELOG.md) |
| 🇨🇳 **中文文档** | [README.zh-CN.md](README.zh-CN.md) |

---

<sub>Made with 🧹 for the Linux desktop. Not affiliated with Arch Linux, Docker, or Flatpak.</sub>
