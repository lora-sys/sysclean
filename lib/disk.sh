# disk.sh - disk space scanner + cleanup manager

scan_home_topdirs() {
  du -sh /home/lora/* 2>/dev/null | sort -hr | head -30 | \
    awk '{printf "%s|%s|topdir\n", $2, $1}'
}

scan_caches() {
  du -sh "$HOME/.cache"/* 2>/dev/null | sort -hr | head -20 | \
    while read -r size path; do
      echo "$path|$size|cache"
    done
}

scan_localshare() {
  du -sh "$HOME/.local/share"/* 2>/dev/null | sort -hr | head -20 | \
    while read -r size path; do
      echo "$path|$size|localshare"
    done
}

scan_configdirs() {
  du -sh "$HOME/.config"/* 2>/dev/null | sort -hr | head -20 | \
    while read -r size path; do
      echo "$path|$size|config"
    done
}

scan_build_artifacts() {
  local repos_root="/home/lora/repos"
  [ -d "$repos_root" ] || return

  # Look for venv directories but exclude node_modules subtrees
  find "$repos_root" -maxdepth 4 -type d \( -iname "venv" -o -iname ".venv" \) 2>/dev/null | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|venv"
    done
  # Also look for top-level env/ directories (not inside node_modules)
  find "$repos_root" -maxdepth 4 -type d \( -name "env" -o -name ".env" \) 2>/dev/null | \
    grep -v "/node_modules/" | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|venv"
    done

  find "$repos_root" -maxdepth 5 -type d -name "node_modules" 2>/dev/null | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|node_modules"
    done

  find "$repos_root" -maxdepth 5 -type d -name "target" 2>/dev/null | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|target"
    done

  find "$repos_root" -maxdepth 5 -type d -name "dist" 2>/dev/null | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|dist"
    done

  find "$repos_root" -maxdepth 6 -type d -name "__pycache__" 2>/dev/null | \
    while read -r d; do
      size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "0")
      echo "$d|$size|pycache"
    done
}

scan_pkg_caches() {
  if [ -d /var/cache/pacman/pkg ]; then
    local sz; sz=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || echo "0")
    echo "/var/cache/pacman/pkg|$sz|pacman"
  fi
  if [ -d "$HOME/.cache/yay" ]; then
    du -sh "$HOME/.cache/yay"/* 2>/dev/null | while read -r s p; do
      [ -d "$p" ] && echo "$p|$s|yay-pkg"
    done
  fi
  [ -d "$HOME/.cache/pip" ] && du -sh "$HOME/.cache/pip" 2>/dev/null | while read -r s p; do echo "$p|$s|pip"; done
  [ -d "$HOME/.npm" ] && du -sh "$HOME/.npm" 2>/dev/null | while read -r s p; do echo "$p|$s|npm"; done
  [ -d "$HOME/.cache/yarn" ] && du -sh "$HOME/.cache/yarn" 2>/dev/null | while read -r s p; do echo "$p|$s|yarn"; done
  [ -d "$HOME/.local/share/pnpm" ] && du -sh "$HOME/.local/share/pnpm" 2>/dev/null | while read -r s p; do echo "$p|$s|pnpm"; done
  [ -d "$HOME/.cargo/registry" ] && du -sh "$HOME/.cargo/registry" 2>/dev/null | while read -r s p; do echo "$p|$s|cargo"; done
  [ -d "$HOME/.cache/go-build" ] && du -sh "$HOME/.cache/go-build" 2>/dev/null | while read -r s p; do echo "$p|$s|go"; done
  [ -d "$HOME/.cache/uv" ] && du -sh "$HOME/.cache/uv" 2>/dev/null | while read -r s p; do echo "$p|$s|uv"; done
}

scan_trash() {
  local trash="$HOME/.local/share/Trash"
  [ -d "$trash/files" ] || return
  for item in "$trash/files"/*; do
    [ -e "$item" ] || continue
    local name; name=$(basename "$item")
    [ "$name" = "." ] || [ "$name" = ".." ] && continue
    local sz
    if [ -d "$item" ]; then
      sz=$(du -sh "$item" 2>/dev/null | cut -f1)
    else
      sz=$(ls -la "$item" 2>/dev/null | awk '{print $5}' | head -1)
      sz=$(human "$(to_bytes "${sz}B" 2>/dev/null || echo 0)")
    fi
    echo "$item|$sz|trash"
  done
}

scan_journal() {
  local usage; usage=$(journalctl --disk-usage 2>/dev/null | head -1)
  echo "/var/log/journal|$usage|journal"
}

scan_tmp() {
  local sz
  sz=$(du -sh /tmp 2>/dev/null | cut -f1)
  echo "/tmp|$sz|tmp"
  [ -d /var/tmp ] && {
    sz=$(du -sh /var/tmp 2>/dev/null | cut -f1)
    echo "/var/tmp|$sz|tmp"
  }
}

scan_large_files() {
  find /home/lora -maxdepth 4 -type f -size +100M 2>/dev/null | \
    while read -r f; do
      sz=$(du -sh "$f" 2>/dev/null | cut -f1)
      echo "$f|$sz|largefile"
    done | head -20
}

disk_rm_path() {
  local path="$1"
  log_action "rm -rf $path"
  rm -rf "$path" 2>&1
}

pacman_clean() {
  log_action "pacman -Sc"
  ensure_sudo
  sudo pacman -Sc --noconfirm 2>&1 | tail -5
}

journal_vacuum() {
  local days="${1:-7}"
  log_action "journalctl --vacuum-time=${days}d"
  ensure_sudo
  sudo journalctl --vacuum-time="${days}d" 2>&1 | tail -3
}

trash_empty() {
  log_action "Empty trash"
  # Use direct rm since gio may not work on all setups
  find "$HOME/.local/share/Trash/files" -mindepth 1 -delete 2>&1 || true
  find "$HOME/.local/share/Trash/info" -mindepth 1 -delete 2>&1 || true
  log_ok "Trash emptied"
}

manage_disk() {
  while true; do
    ui_clear
    local total used avail pct
    read -r total used avail pct <<< "$(df -h /home 2>/dev/null | tail -1 | awk '{print $2, $3, $4, $5}')"

    ui_menu "Disk Cleanup" 22 76 14 \
      "Disk: $used / $total ($pct) - Available $avail" \
      "1" "Home top dirs (TOP 30)" \
      "2" "~/.cache subdirs" \
      "3" "~/.local/share subdirs" \
      "4" "~/.config subdirs" \
      "5" "Build artifacts (venv/node_modules/target/dist)" \
      "6" "Package manager caches" \
      "7" "Trash" \
      "8" "Journal logs (vacuum)" \
      "9" "Large files (>100M) - read only" \
      "10" "One-click safe cleanup" \
      "0" "Back" \
     
    local choice="$REPLY"

    case "$choice" in
      1) _show_disk_table "Home topdirs" "$(scan_home_topdirs)" "topdir" ;;
      2) _show_disk_table "Cache" "$(scan_caches)" "cache" ;;
      3) _show_disk_table "Local share" "$(scan_localshare)" "localshare" ;;
      4) _show_disk_table "Config" "$(scan_configdirs)" "config" ;;
      5) _manage_build_artifacts ;;
      6) _manage_pkg_caches ;;
      7) _manage_trash ;;
      8) _manage_journal ;;
      9) _show_large_files ;;
      10) _safe_auto_cleanup ;;
      0|"") return 0 ;;
    esac
  done
}

_show_disk_table() {
  local title="$1" data="$2" label="$3"
  [ -z "$data" ] && { ui_info "No $label data"; return; }

  local args=()
  while IFS='|' read -r path size kind; do
    [ -z "$path" ] && continue
    args+=("$path" "[$kind] $size -- $(trunc "$path" 50)" "OFF")
  done <<< "$data"

  local chosen
  chosen=$(ui_checklist "$label (select to delete)" 22 110 16 \
    "Space to toggle, Enter to confirm" "${args[@]}" 2>/dev/null)

  [ -z "$chosen" ] && return

  local list=""
  for path in $chosen; do
    local s=$(echo "$data" | grep -F "|$path|" | cut -d'|' -f2)
    [ -z "$s" ] && s=$(echo "$data" | grep "^$path|" | cut -d'|' -f2)
    list+="$(printf '  %-10s %s\n' "$s" "$path")\n"
  done

  if ui_yesno "Delete these $label items?\n\n$(echo -e "$list")"; then
    for path in $chosen; do
      disk_rm_path "$path"
    done
    ui_info "Done"
  fi
}

_manage_build_artifacts() {
  local data; data=$(scan_build_artifacts)
  [ -z "$data" ] && { ui_info "No build artifacts found"; return; }

  local args=()
  while IFS='|' read -r path size kind; do
    [ -z "$path" ] && continue
    args+=("$path" "[$kind] $size -- $(basename "$(dirname "$path")")/$(basename "$path")" "OFF")
  done <<< "$data"

  local chosen
  chosen=$(ui_checklist "Build artifacts (regeneratable)" 24 110 20 \
    "Check items to delete (can be regenerated with: uv sync / bun install / cargo build)" "${args[@]}" 2>/dev/null)

  [ -z "$chosen" ] && return

  if ui_yesno "Delete these build artifacts?"; then
    for path in $chosen; do
      disk_rm_path "$path"
    done
    ui_info "Done"
  fi
}

_manage_pkg_caches() {
  local data; data=$(scan_pkg_caches)
  [ -z "$data" ] && { ui_info "No package caches found"; return; }

  local args=()
  while IFS='|' read -r path size kind; do
    [ -z "$path" ] && continue
    args+=("$path" "[$kind] $size -- $path" "OFF")
  done <<< "$data"

  local chosen
  chosen=$(ui_checklist "Package manager caches" 20 100 14 \
    "Check caches to clean (usually re-downloadable)" "${args[@]}" 2>/dev/null)

  [ -z "$chosen" ] && return

  if ui_yesno "Clean these caches?"; then
    for path in $chosen; do
      disk_rm_path "$path"
    done
    ui_info "Done"

    if ui_yesno "Also run sudo pacman -Sc (clean uninstalled package cache)?"; then
      pacman_clean
    fi
  fi
}

_manage_trash() {
  local data; data=$(scan_trash)
  [ -z "$data" ] && { ui_info "Trash is empty"; return; }

  local args=()
  while IFS='|' read -r path size kind; do
    [ -z "$path" ] && continue
    args+=("$path" "[$size] $(basename "$path")" "OFF")
  done <<< "$data"

  local chosen
  chosen=$(ui_checklist "Trash" 20 100 14 \
    "Check items to permanently delete" "${args[@]}" 2>/dev/null)

  [ -z "$chosen" ] && return

  if ui_yesno "Permanently delete these?"; then
    for path in $chosen; do
      log_action "Permanent delete: $path"
      rm -rf "$path" 2>&1
      local info="${path/\/files\//\/info\/}.trashinfo"
      rm -f "$info" 2>&1
    done
    ui_info "Done"
  fi
}

_manage_journal() {
  journalctl --disk-usage 2>&1 | head -1 > /tmp/j.txt
  ui_msg "$(cat /tmp/j.txt)\n\nChoose retention (older logs will be cleaned):" 12 60
  local days; days=$(ui_input "Days to keep (blank=7)" "7")
  [ -z "$days" ] && days=7
  if ui_yesno "Clean journal logs older than ${days} days?"; then
    journal_vacuum "$days"
    journalctl --disk-usage 2>&1 | head -1
    ui_info "Done"
  fi
}

_show_large_files() {
  local data; data=$(scan_large_files)
  [ -z "$data" ] && { ui_info "No files >100M found"; return; }
  local listing; listing=$(echo "$data" | awk -F'|' '{printf "%-10s %s\n", $2, $1}')
  ui_msg "$listing" 24 100
}

_safe_auto_cleanup() {
  ui_clear
  cat <<'BANNER'
ONE-CLICK SAFE CLEANUP

Will execute (will NOT delete project files):
  1. Empty trash
  2. Vacuum journal logs (keep 7 days)
  3. System pacman cache (-Sc)
  4. User package caches (pip, npm, yarn, pnpm - re-downloadable)
  5. Thumbnail cache
BANNER

  if ! ui_yesno "Confirm execution?"; then return; fi

  log_info "[1/5] Empty trash"
  trash_empty

  log_info "[2/5] Vacuum journal (7 days)"
  journal_vacuum 7

  log_info "[3/5] pacman -Sc"
  pacman_clean

  log_info "[4/5] User package caches"
  rm -rf "$HOME/.cache/pip"
  rm -rf "$HOME/.cache/yarn"
  rm -rf "$HOME/.cache/uv"
  rm -rf "$HOME/.npm"

  log_info "[5/5] Thumbnail caches"
  rm -rf "$HOME/.cache/thumbnails"
  rm -rf "$HOME/.thumbnails"

  df -h /home 2>/dev/null | tail -1
  ui_info "Done"
}
