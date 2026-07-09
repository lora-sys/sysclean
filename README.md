# sysclean

> A global system cleanup and management TUI for Linux — service control, Docker, Flatpak, disk cleanup, startup audit, all in one place.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

## Why sysclean?

Modern Linux desktops accumulate cruft fast: orphaned Docker images, dormant `venv`s, broken systemd units, leftover Flatpak runtimes. `sysclean` gives you one menu to see everything and act — with explicit confirmations, never silent deletions.

## Features

- **Service management** — list every systemd unit (system + user), start/stop/enable/disable, view logs
- **Docker manager** — list/remove containers, images, volumes, networks; one-click orphan cleanup
- **Flatpak manager** — apps + runtimes, with reverse-dependency detection
- **Disk cleanup** — caches, build artifacts (`venv`/`node_modules`/`target`), package manager caches, trash, journal
- **Startup & RC audit** — autostart entries, systemd timers, cron, shell RC issues (duplicate aliases, hardcoded keys)
- **Non-destructive** — explicit `[y/N]` for every action; dry-run mode; whitelist/blacklist
- **3 UI modes** — `whiptail` (TUI), `dialog`, plain text (auto-fallback)
- **CLI mode** — `sysclean --scan` for scripting

## Installation

### AUR (Arch / CachyOS / Manjaro)

```bash
yay -S sysclean
```

### One-liner install (any Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
```

This installs to `~/.local/bin/sysclean` and `~/.local/share/sysclean/lib/`.

### Manual

```bash
git clone https://github.com/lora-sys/sysclean.git
cd sysclean
make install    # installs to ~/.local
# or
sudo make install-system    # installs to /usr/local
```

## Usage

```bash
sysclean              # Launch interactive TUI
sysclean --scan       # Full system report (text)
sysclean --help       # Show all options
```

### TUI walkthrough

```
sysclean 主菜单
  1) ⚙️  服务管理 (systemd)        ← 200+ services, all visible
  2) 🐳 Docker 管理               ← containers / images / volumes / networks
  3) 📦 Flatpak 管理               ← apps + runtimes
  4) 💾 磁盘清理                  ← caches, builds, trash, journal
  5) 🚀 启动项 & Shell RC          ← autostart, timers, cron, RC issues
  6) 🩺 系统诊断 & 扫描报告       ← full system audit
  7) 🧹 一键安全清理（保守）       ← trash, journal, caches — no project files
  8) 📜 查看操作历史
  9) ⚙️  设置（白名单/黑名单）
  0) 退出
```

### Example: --scan output

```
─── 1. 系统资源 ───
/dev/nvme0n1p7  341G  127G  210G  38% /home

─── 4. Docker ───
Images          18        2         9.138GB   4.276GB (46%)
Containers      2         1         4.096kB   0B (0%)

─── 11. Shell RC 异常 ───
  /home/lora/.zshrc:190: duplicate alias "clean"
  200:export MINIMAX_API_KEY="sk-cp-hiZMA6NUCxXap_tBed..."
```

## Requirements

- `bash` ≥ 4.0
- `whiptail` (recommended) or `dialog` (auto-falls back to plain text)
- `systemctl` (systemd-based distros)
- `docker` (optional, for Docker menu)
- `flatpak` (optional, for Flatpak menu)
- `jq` (for state persistence)
- `sudo` (for system-level operations)

## Configuration

`~/.config/sysclean/`
- `state.json` — whitelist / blacklist / preferences
- `history.log` — action history (last 50 entries)
- `sysclean.log` — verbose log

## Safety

- Every destructive action requires `[y/N]` confirmation
- `--dry-run` previews without acting
- Whitelist (in settings) protects services from "stop" prompts
- Trash contents shown before permanent deletion
- No project files touched without explicit selection

## Testing

```bash
make test    # runs tests/test_e2e.sh
```

All 25 menu paths + UI primitives (msg, yesno, input, checklist, menu) are covered.

## Contributing

PRs welcome. Run `make test` before submitting.

## License

MIT — see [LICENSE](LICENSE).

## See also

- 中文文档: [README.zh-CN.md](README.zh-CN.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
