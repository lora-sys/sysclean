# Changelog

All notable changes to sysclean are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-07-09

### Added
- Service management (systemd system + user units): list, start, stop, enable, disable, view logs
- Docker manager: containers, images, volumes, networks with selective deletion
- Flatpak manager: apps + runtimes with `--unused` cleanup
- Disk cleanup: caches, build artifacts (venv/node_modules/target), pkg caches, trash, journal
- Startup audit: autostart entries, systemd timers, cron jobs, shell RC issues
- System scan mode (`sysclean --scan`) with 11-section report
- One-click safe cleanup (trash, journal, caches, thumbnails)
- TUI menu with 9 main categories
- 3 UI rendering modes: whiptail (TUI), dialog, plain text (auto-fallback)
- Whitelist/blacklist via `~/.config/sysclean/state.json`
- Action history logging
- Dry-run mode (`--dry-run`)
- Skip-confirmation mode (`--yes`)
- Bilingual docs (English + Chinese)
- AUR package (PKGBUILD)
- One-liner install script
- GitHub Actions CI

### Fixed
- `set -e` killing script on failed `crontab -l` (added `|| var=0` defaults)
- Merged key-description pairs in `services.sh` (causing `$2: unbound variable`)
- TTY detection for whiptail fallback to plain text
- `2>/dev/null` redirection swallowing whiptail output
- Double-newline in menu items from `|| echo 0` patterns

### Security
- Every destructive action requires explicit `[y/N]` confirmation
- Hardcoded API key detection in shell RC files
