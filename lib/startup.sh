# startup.sh - autostart, systemd timers, shell rc, cron

# === XDG autostart ===
scan_autostart() {
  ls -la "$HOME/.config/autostart" 2>/dev/null | tail -n +2 | \
    while read -r perms links owner group size month day time name; do
      [ -z "$name" ] || [ "$name" = "." ] || [ "$name" = ".." ] && continue
      local f="$HOME/.config/autostart/$name"
      local exec; exec=$(grep -E "^Exec=" "$f" 2>/dev/null | head -1)
      local hidden; hidden=$(grep -E "^Hidden=" "$f" 2>/dev/null | head -1)
      echo "$f|$exec|$hidden"
    done
}

# === System-wide autostart ===
scan_autostart_system() {
  ls -la /etc/xdg/autostart/ 2>/dev/null | tail -n +2 | \
    while read -r perms links owner group size month day time name; do
      [ -z "$name" ] || [ "$name" = "." ] || [ "$name" = "..""]" ] && continue
      local f="/etc/xdg/autostart/$name"
      local exec; exec=$(grep -E "^Exec=" "$f" 2>/dev/null | head -1)
      local hidden; hidden=$(grep -E "^Hidden=" "$f" 2>/dev/null | head -1)
      echo "$f|$exec|$hidden"
    done
}

# === Systemd timers ===
scan_systemd_timers() {
  # systemctl list-timers has variable column count due to PASSED being 1-3 tokens
  # Strategy: parse with awk, capturing last 2 cols (UNIT=*.timer, ACTIVATES=*.service)
  systemctl list-timers --no-pager --no-legend --all 2>/dev/null | awk '
    {
      # Last two non-empty fields are UNIT (.timer) and ACTIVATES (.service)
      unit = $(NF-1)
      activates = $NF
      if (unit !~ /\.timer$/) next
      # First 4 cols = NEXT date+time, then LEFT (1-2 cols), then LAST (4 cols), then PASSED (1-3 cols)
      # Just capture them all into a string for display
      next_run = $1 " " $2 " " $3 " " $4
      # LEFT is column 5 (and sometimes 6)
      left = $5 " " $6
      # Reconstruct by removing the last 2 fields (unit + activates) from line
      rest = ""
      for (i=1; i<=NF-2; i++) rest = rest " " $i
      sub(/^ /, "", rest)
      printf "timer|%s|%s\n", unit, rest
    }'
  
  systemctl --user list-timers --no-pager --no-legend --all 2>/dev/null | awk '
    {
      unit = $(NF-1)
      if (unit !~ /\.timer$/) next
      rest = ""
      for (i=1; i<=NF-2; i++) rest = rest " " $i
      sub(/^ /, "", rest)
      printf "user-timer|%s|%s\n", unit, rest
    }'
}

# === Cron jobs ===
scan_cron_user() {
  crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | \
    awk '{printf "user-cron|line-%d|%s\n", NR, $0}'
}
scan_cron_system() {
  cat /etc/crontab 2>/dev/null | grep -v '^#' | grep -v '^$' | \
    awk '{printf "system-cron|/etc/crontab|%s\n", $0}'
  for f in /etc/cron.d/*; do
    [ -f "$f" ] || continue
    grep -v '^#' "$f" 2>/dev/null | grep -v '^$' | \
      awk -v file="$f" '{printf "system-cron|%s|%s\n", file, $0}'
  done
}

# === Shell rc additions ===
# Detect non-trivial additions (not just comments or PS1)
scan_shell_rc() {
  local files=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.profile"
  )
  
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    local lineno=0
    while IFS= read -r line; do
      lineno=$((lineno+1))
      # Skip blanks and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # Note if it's an export, alias, or source
      if [[ "$line" =~ ^[[:space:]]*(export|alias|source|\.) ]] || \
         [[ "$line" =~ PATH= ]] || [[ "$line" =~ eval ]]; then
        printf 'rc|%s|%d|%s\n' "$f" "$lineno" "$(echo "$line" | head -c 80)"
      fi
    done < "$f"
  done
}

# === Suspect duplicate aliases / suspicious patterns ===
scan_shell_rc_issues() {
  local files=("$HOME/.bashrc" "$HOME/.zshrc")
  
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    # Find duplicate aliases (same name defined twice)
    awk '
      /^[[:space:]]*alias[[:space:]]+[a-zA-Z_][a-zA-Z0-9_-]*=/ {
        match($0, /alias[[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*)/, a)
        name=a[1]
        if (name && seen[name]++) print FILENAME ":" NR ": duplicate alias \"" name "\""
      }
    ' "$f"
    
    # Check for hardcoded API keys / tokens in export
    grep -nE "(export[[:space:]]+[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD|API)[A-Z_]*=)" "$f" 2>/dev/null | \
      head -5
  done
}

# === Action helpers ===
autostart_disable() {
  local f="$1"
  log_action "Disable autostart: $f"
  chmod 000 "$f" 2>&1 || true
  # Or move to disabled subfolder
  local dir; dir=$(dirname "$f")
  mkdir -p "$dir/disabled"
  mv "$f" "$dir/disabled/" 2>&1 || true
}
autostart_enable() {
  local f="$1"
  local dir; dir=$(dirname "$f")
  local name; name=$(basename "$f")
  if [ -f "$dir/disabled/$name" ]; then
    mv "$dir/disabled/$name" "$f" 2>&1
  fi
  chmod 644 "$f" 2>&1 || true
}
autostart_remove() {
  local f="$1"
  log_action "Remove autostart: $f"
  rm -f "$f" 2>&1
  rm -f "$(dirname "$f")/disabled/$(basename "$f")" 2>&1
}

# Timer control
timer_disable() {
  local timer="$1"
  log_action "Disable timer: $timer"
  if [[ "$timer" =~ \.timer$ ]]; then
    local svc="${timer%.timer}.service"
    systemctl disable --now "$timer" "$svc" 2>&1
  fi
}

# === Interactive ===
manage_startup() {
  while true; do
    ui_clear
    
    local autostart_count timers_count cron_count
    autostart_count=$(ls "$HOME/.config/autostart" 2>/dev/null | wc -l) || autostart_count=0
    timers_count=$(systemctl list-timers --no-pager --no-legend --all 2>/dev/null | wc -l) || timers_count=0
    cron_count=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l) || cron_count=0
    ui_menu "启动项管理" 14 60 6 \
      "启动配置" \
      "1" "🚀 用户 autostart ($autostart_count)" \
      "2" "⏰ systemd 计时器 ($timers_count)" \
      "3" "📋 cron 任务 ($cron_count)" \
      "4" "📝 Shell rc 异常检测 (重复 alias / 硬编码密钥)" \
      "0" "返回" \
     
    local choice="$REPLY"
    
    case "$choice" in
      1) _manage_autostart ;;
      2) _manage_timers ;;
      3) _manage_cron ;;
      4) _manage_rc_issues ;;
      0|"") return 0 ;;
    esac
  done
}

_manage_autostart() {
  local data; data=$(scan_autostart)
  [ -z "$data" ] && { ui_info "用户 autostart 为空"; return; }
  
  echo "用户 autostart 项："
  echo "$data" | awk -F'|' '{printf "  %s\n     exec: %s\n     hidden: %s\n", $1, $2, $3}'
  echo ""
  
  local args=()
  while IFS='|' read -r f exec hidden; do
    [ -z "$f" ] && continue
    args+=("$f" "$(basename "$f"): $(echo "$exec" | head -c 50)")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "autostart 项" 16 90 10 \
    "勾选要禁用的项（移到 disabled/ 子目录）" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  if ui_yesno "确认禁用这些 autostart?"; then
    for f in $chosen; do
      autostart_disable "$f"
    done
    ui_info "完成（已移到 ~/.config/autostart/disabled/）"
  fi
}

_manage_timers() {
  local data; data=$(scan_systemd_timers)
  [ -z "$data" ] && { ui_info "没有计时器"; return; }
  
  echo "当前计时器："
  echo "$data" | awk -F'|' '{printf "  %-30s next: %s\n", $2, $3}'
  echo ""
  
  local args=()
  while IFS='|' read -r kind unit next rel last; do
    [ -z "$unit" ] && continue
    args+=("$unit" "[$kind] next: $(echo "$next" | head -c 40)")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "systemd 计时器" 18 100 12 \
    "勾选要禁用的计时器" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  if ui_yesno "确认禁用这些计时器?"; then
    for t in $chosen; do
      timer_disable "$t"
    done
    ui_info "完成"
  fi
}

_manage_cron() {
  local user_data; user_data=$(scan_cron_user)
  local sys_data; sys_data=$(scan_cron_system)
  local data="$user_data"$'\n'"$sys_data"
  data=$(echo "$data" | grep .)
  
  [ -z "$data" ] && { ui_info "没有 cron 任务"; return; }
  
  ui_msg "$(echo "$data" | awk -F'|' '{printf "%s\n", $3}')" 20 80
  echo ""
  
  if ui_yesno "要编辑你的 crontab 吗? (crontab -e)"; then
    EDITOR="${EDITOR:-nano}" crontab -e
  fi
}

_manage_rc_issues() {
  local issues; issues=$(scan_shell_rc_issues)
  
  ui_clear
  echo "=== Shell RC 异常检测 ==="
  echo ""
  
  if [ -z "$issues" ]; then
    echo "✓ 没发现重复 alias 或硬编码密钥"
    echo ""
    echo "完整 rc 加载项（export/alias/source）："
    scan_shell_rc | awk -F'|' '{printf "  %s:%-3d  %s\n", $2, $3, $4}' | head -30
    ui_msg "$(scan_shell_rc | awk -F'|' '{printf "%s:%-3d  %s\n", $2, $3, $4}')" 24 100
  else
    echo "⚠️  发现以下问题："
    echo ""
    echo "$issues"
    ui_msg "$issues" 20 90
  fi
}
