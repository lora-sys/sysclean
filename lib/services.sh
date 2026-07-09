# services.sh - systemd service scanner + manager
# Handles both system and user services.

# === Scan ===
# Output: space-separated lines of "kind|name|state|enabled|substate"
scan_services_system() {
  systemctl list-unit-files --type=service --no-pager --no-legend --state=enabled,disabled,static,masked 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "system|%s|%s|%s|unknown\n", $1, tolower($2), $3}' | head -200
}
scan_services_system_active() {
  systemctl list-units --type=service --no-pager --no-legend --state=running 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "system|%s|running|enabled|%s\n", $1, $4}' | head -200
}
scan_services_user() {
  systemctl --user list-unit-files --type=service --no-pager --no-legend --state=enabled,disabled,static,masked 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "user|%s|%s|%s|unknown\n", $1, tolower($2), $3}' | head -200
}
scan_services_user_active() {
  systemctl --user list-units --type=service --no-pager --no-legend --state=running 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "user|%s|running|enabled|%s\n", $1, $4}' | head -200
}
scan_services_failed() {
  systemctl --user list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "user|%s|failed|%s|%s\n", $1, "unknown", $4}'
  systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | \
    awk '{gsub(/\.service$/,"",$1); printf "system|%s|failed|%s|%s\n", $1, "unknown", $4}'
}

# Combined scanner that returns ALL services with rich metadata
# Format: kind|name|active|sub|enabled|description
scan_services_all() {
  # System units: UNIT LOAD ACTIVE SUB DESCRIPTION
  while read -r unit load active sub desc_rest; do
    [[ "$unit" != *.service ]] && continue
    name="${unit%.service}"
    enabled=$(systemctl is-enabled "$unit" 2>/dev/null || echo unknown)
    [ -z "$enabled" ] && enabled="unknown"
    printf "system|%s|%s|%s|%s|%s\n" "$name" "$active" "$sub" "$enabled" "$desc_rest"
  done < <(systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null)

  # User units
  while read -r unit load active sub desc_rest; do
    [[ "$unit" != *.service ]] && continue
    name="${unit%.service}"
    enabled=$(systemctl --user is-enabled "$unit" 2>/dev/null || echo unknown)
    [ -z "$enabled" ] && enabled="unknown"
    printf "user|%s|%s|%s|%s|%s\n" "$name" "$active" "$sub" "$enabled" "$desc_rest"
  done < <(systemctl --user list-units --type=service --all --no-pager --no-legend 2>/dev/null)
}

# === Action helpers ===
service_start() {
  local kind="$1" name="$2"
  if [ "$kind" = "user" ]; then
    systemctl --user start "$name.service" 2>&1
  else
    ensure_sudo
    sudo systemctl start "$name.service" 2>&1
  fi
}
service_stop() {
  local kind="$1" name="$2"
  if [ "$kind" = "user" ]; then
    systemctl --user stop "$name.service" 2>&1
  else
    ensure_sudo
    sudo systemctl stop "$name.service" 2>&1
  fi
}
service_enable() {
  local kind="$1" name="$2"
  if [ "$kind" = "user" ]; then
    systemctl --user enable "$name.service" 2>&1
  else
    ensure_sudo
    sudo systemctl enable "$name.service" 2>&1
  fi
}
service_disable() {
  local kind="$1" name="$2"
  if [ "$kind" = "user" ]; then
    systemctl --user disable "$name.service" 2>&1
  else
    ensure_sudo
    sudo systemctl disable "$name.service" 2>&1
  fi
}
service_status() {
  local kind="$1" name="$2"
  if [ "$kind" = "user" ]; then
    systemctl --user status "$name.service" --no-pager -l 2>&1
  else
    systemctl status "$name.service" --no-pager -l 2>&1
  fi
}

# === Interactive: service manager ===
manage_services() {
  while true; do
    ui_clear
    # Snapshot current state
    local data; data=$(scan_services_all)
    
    # Stats
    local running stopping failed total
    running=$(echo "$data" | awk -F'|' '$3=="running"' | wc -l 2>/dev/null || echo 0)
    failed=$(echo "$data" | awk -F'|' '$3=="failed"' | wc -l 2>/dev/null || echo 0)
    total=$(echo "$data" | wc -l)
    
    ui_menu "服务管理" 22 76 12 \
      "选择要管理的服务类别" \
      "1" "▶ 活跃服务 ($running 个 running) — 可停止" \
      "2" "✗ 失败服务 ($failed 个 failed) — 可清理状态" \
      "3" "🔍 浏览所有服务 ($total 个) — 启动/停止/启用/禁用" \
      "4" "📜 重置所有 failed 状态" \
      "5" "🩺 检测可疑服务（自启动+未运行）" \
      "0" "返回" \
     
    local choice="$REPLY"
    
    case "$choice" in
      1) _manage_running_services "$data" ;;
      2) _manage_failed_services "$data" ;;
      3) _manage_browse_services "$data" ;;
      4) _reset_all_failed ;;
      5) _detect_suspicious_services "$data" ;;
      0|"") return 0 ;;
    esac
  done
}

# Helper: show running services, allow stopping
_manage_running_services() {
  local data="$1"
  local running; running=$(echo "$data" | awk -F'|' '$3=="running"' | sort)
  [ -z "$running" ] && { ui_info "没有正在运行的服务"; return; }
  
  # Build checklist args
  local args=()
  while IFS='|' read -r kind name state sub enabled desc; do
    [ -z "$name" ] && continue
    local label="$(trunc "$desc" 50)"
    args+=("$kind/$name[$kind] $labelOFF")
  done <<< "$running"
  
  local chosen; chosen=$(ui_checklist "选择要停止的服务" 22 90 16 \
    "空格切换，回车确认，ESC 取消${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  # Confirm
  local list=$(echo "$chosen" | tr ' ' '\n' | grep . | sed 's|^|  • |')
  if ui_yesno "确认停止以下服务?\n\n$list"; then
    echo "$chosen" | tr ' ' '\n' | while read -r item; do
      [ -z "$item" ] && continue
      local kind="${item%%/*}" name="${item#*/}"
      log_action "停止 $kind/$name"
      service_stop "$kind$name" && log_ok "已停止 $kind/$name"
    done
    ui_info "完成"
  fi
}

# Helper: show failed services, allow clearing status
_manage_failed_services() {
  local data="$1"
  local failed; failed=$(echo "$data" | awk -F'|' '$3=="failed"')
  [ -z "$failed" ] && { ui_info "没有失败的服务 ✓"; return; }
  
  echo "失败的服务："
  echo "$failed" | awk -F'|' '{printf "  %s | %s\n", $1, $2}'
  echo ""
  if ui_yesno "重置所有失败状态 (reset-failed)?"; then
    systemctl --user reset-failed 2>&1 || true
    sudo systemctl reset-failed 2>&1 || true
    ui_info "已重置失败状态"
  fi
}

# Helper: browse all services with filter
_manage_browse_services() {
  local data="$1"
  local filter; filter=$(ui_input "筛选关键字 (留空=全部)")
  local filtered; filtered=$(echo "$data" | grep -i "${filter}" || echo "$data")
  
  # Build selection menu (whiptail menu can show ~20 items at a time)
  while true; do
    ui_clear
    local args=()
    while IFS='|' read -r kind name state sub enabled desc; do
      [ -z "$name" ] && continue
      local label="$(printf '[%s|%s] %s' "$state$enabled$(trunc "$desc" 45)")"
      args+=("$kind/$name$label")
    done <<< "$filtered"
    
    # Add back option
    args+=("__back__← 返回")
    
    ui_menu "浏览所有服务 (筛选: ${filter:-全部})" 24 100 18 \
      "选择服务查看/操作${args[@]}"
    local sel="$REPLY"
    
    case "$sel" in
      __back__|"") return ;;
      *) _service_action_menu "$sel" ;;
    esac
  done
}

# Helper: per-service action menu
_service_action_menu() {
  local sel="$1"
  local kind="${sel%%/*}" name="${sel#*/}"
  local cur_state; cur_state=$(systemctl -${kind:0:1} is-active "$name" 2>/dev/null || systemctl is-active "$name" 2>/dev/null)
  local cur_enabled; cur_enabled=$(systemctl -${kind:0:1} is-enabled "$name" 2>/dev/null || systemctl is-enabled "$name" 2>/dev/null)
  
  while true; do
    ui_clear
    echo "服务: $kind/$name"
    echo "当前状态: $cur_state, 启动项: $cur_enabled"
    echo ""
    
    ui_menu "操作: $kind/$name" 16 60 8 \
      "选择操作" \
      "1▶  启动" \
      "2■  停止" \
      "3↻  重启" \
      "4✓  启用（开机启动）" \
      "5✗  禁用（禁止开机启动）" \
      "6📋  查看完整状态/status" \
      "7📜  查看日志 (last 30 lines)" \
      "0← 返回" \
     
    local op="$REPLY"
    
    case "$op" in
      1) service_start "$kind$name"; cur_state="active"; ui_info "已启动";;
      2) service_stop "$kind$name"; cur_state="inactive"; ui_info "已停止";;
      3) service_stop "$kind$name"; service_start "$kind$name"; ui_info "已重启";;
      4) service_enable "$kind$name"; cur_enabled="enabled"; ui_info "已启用";;
      5) service_disable "$kind$name"; cur_enabled="disabled"; ui_info "已禁用";;
      6) service_status "$kind$name" | head -40 > /tmp/svc-status.txt
         ui_msg "$(cat /tmp/svc-status.txt)" 40 80;;
      7) journalctl -u "$name.service" --no-pager -n 30 2>&1 > /tmp/svc-log.txt
         ui_msg "$(cat /tmp/svc-log.txt)" 40 100;;
      0|"") return ;;
    esac
  done
}

# Helper: reset all failed states
_reset_all_failed() {
  if ui_yesno "重置所有 systemd 失败状态?\n（仅清计数，不影响配置）"; then
    log_action "重置 user 失败状态"
    systemctl --user reset-failed 2>&1 || true
    log_action "重置 system 失败状态"
    sudo systemctl reset-failed 2>&1 || true
    log_ok "完成"
    ui_info "失败状态已重置"
  fi
}

# Helper: detect suspicious (enabled but not running) services
_detect_suspicious_services() {
  local data="$1"
  local suspicious; suspicious=$(echo "$data" | awk -F'|' '$4=="enabled" && $3!="running" && $3!="failed"' 2>/dev/null || echo "")
  [ -z "$suspicious" ] && { ui_info "没有可疑服务 ✓"; return; }
  
  echo "以下服务启用了开机自启但当前未运行（可能有问题）："
  echo "$suspicious" | awk -F'|' '{printf "  [%s] %s (%s)\n", $1, $2, $5}' | head -30
  ui_msg "$(echo "$suspicious" | awk -F'|' '{printf "[%s] %s - %s\n", $1, $2, $5}' | head -30)" 22 80
}
