# flatpak.sh - flatpak scanner + manager

has_flatpak() { has flatpak; }

scan_flatpak_apps() {
  flatpak list --app --columns=name,ref,size,version 2>/dev/null | \
    awk -F'\t' '{printf "app|%s|%s|%s|%s\n", $2, $1, $3, $4}'
}

scan_flatpak_runtimes() {
  flatpak list --runtime --columns=name,ref,size,version 2>/dev/null | \
    awk -F'\t' '{printf "runtime|%s|%s|%s|%s\n", $2, $1, $3, $4}'
}

# Find runtimes not referenced by any app
scan_flatpak_orphan_runtimes() {
  local apps; apps=$(flatpak list --app --columns=ref 2>/dev/null || echo)
  flatpak list --runtime --columns=ref 2>/dev/null | while read -r ref; do
    [ -z "$ref" ] && continue
    # Strip arch and version to get runtime base
    base=$(echo "$ref" | awk -F'/' '{print $1"/"$2"/"$3"/"$4}')
    if ! echo "$apps" | grep -qF "$base"; then
      echo "orphan|$ref"
    fi
  done
}

manage_flatpak() {
  if ! has_flatpak; then
    ui_info "Flatpak 未安装"
    return
  fi
  
  while true; do
    ui_clear
    
    local apps runtimes
    apps=$(flatpak list --app --columns=ref 2>/dev/null | wc -l)
    runtimes=$(flatpak list --runtime --columns=ref 2>/dev/null | wc -l)
    
    ui_menu "Flatpak 管理" 14 60 6 \
      "Flatpak 资源管理" \
      "1" "📦 Apps ($apps)" \
      "2" "🔧 Runtimes ($runtimes)" \
      "3" "🧹 一键清理孤儿运行时 + --unused" \
      "4" "♻️  repair (修复)" \
      "0" "返回" \
     
    local choice="$REPLY"
    
    case "$choice" in
      1) _manage_flatpak_apps ;;
      2) _manage_flatpak_runtimes ;;
      3) _flatpak_cleanup ;;
      4) flatpak repair 2>&1 | tee /tmp/fp.log
         ui_msg "$(tail -20 /tmp/fp.log)" 20 80;;
      0|"") return 0 ;;
    esac
  done
}

_manage_flatpak_apps() {
  local data; data=$(scan_flatpak_apps)
  [ -z "$data" ] && { ui_info "没有安装 app"; return; }
  
  local args=()
  while IFS='|' read -r type ref name size ver; do
    [ -z "$ref" ] && continue
    args+=("$ref" "$name ($size)")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "Flatpak Apps" 22 90 16 \
    "勾选要卸载的 app" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  local list=$(echo "$chosen" | tr ' ' '\n' | grep . | sed 's|^|  • |')
  if ui_yesno "确认卸载以下 app?\n\n$list"; then
    for ref in $chosen; do
      log_action "卸载 $ref"
      flatpak uninstall -y "$ref" 2>&1 | tail -3
    done
    ui_info "完成"
  fi
}

_manage_flatpak_runtimes() {
  local data; data=$(scan_flatpak_runtimes)
  [ -z "$data" ] && { ui_info "没有 runtime"; return; }
  
  local args=()
  while IFS='|' read -r type ref name size ver; do
    [ -z "$ref" ] && continue
    args+=("$ref" "$name ($size)")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "Flatpak Runtimes" 22 90 14 \
    "勾选要移除的 runtime（被 app 引用的会失败）" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  if ui_yesno "确认移除这些 runtime?"; then
    flatpak uninstall --runtime -y $chosen 2>&1 | tail -5
    ui_info "完成"
  fi
}

_flatpak_cleanup() {
  ui_clear
  echo "🧹 Flatpak 清理"
  echo ""
  echo "将执行："
  echo "  1. flatpak uninstall --unused  (移除未被任何 app 引用的运行时)"
  echo "  2. flatpak repair  (修复)"
  echo ""
  
  if ui_yesno "继续?"; then
    log_action "flatpak uninstall --unused"
    flatpak uninstall --unused -y 2>&1
    log_action "flatpak repair --user"
    flatpak repair --user 2>&1 | tail -5
    ui_info "✓ 完成"
  fi
}
