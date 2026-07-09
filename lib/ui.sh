# ui.sh - UI abstractions with graceful fallback
# Tries: whiptail -> dialog -> plain text (auto-detected)

# Detect UI mode
_ui_mode() {
  if [ "${SYSCLEAN_UI:-}" ]; then echo "$SYSCLEAN_UI"; return; fi
  if [ "$NONINTERACTIVE" = "1" ]; then echo "text"; return; fi
  if [ -z "${TERM:-}" ] || [ "${TERM:-}" = "dumb" ]; then echo "text"; return; fi
  # whiptail needs BOTH stdin (input) and stdout (render) as TTYs
  if [ ! -t 0 ] || [ ! -t 1 ]; then echo "text"; return; fi
  if has whiptail; then echo "whiptail"; return; fi
  if has dialog; then echo "dialog"; return; fi
  echo "text"
}
UI_MODE=$(_ui_mode)

# === Top-level helpers ===
ui_title() {  # title
  case "$UI_MODE" in
    whiptail) whiptail --title "$1" --backtitle "sysclean" ;;
    dialog)   dialog   --title "$1" --backtitle "sysclean" ;;
  esac
}

ui_msg() {  # message [height] [width]
  local msg="$1" h="${2:-20}" w="${3:-70}"
  case "$UI_MODE" in
    whiptail) whiptail --title "提示" --msgbox "$msg" "$h" "$w";;
    dialog)   dialog   --title "提示" --msgbox "$msg" "$h" "$w";;
    text)     echo "─── 提示 ───"; echo "$msg"; echo "────────────"; read -rp "回车继续…";;
  esac
}

ui_info() { ui_msg "$@"; }

ui_error() {
  local msg="$1"
  case "$UI_MODE" in
    whiptail) whiptail --title "错误" --msgbox "✗ $msg" 10 60;;
    dialog)   dialog   --title "错误" --msgbox "✗ $msg" 10 60;;
    text)     log_error "$msg"; read -rp "回车继续…";;
  esac
}

ui_yesno() {  # question -> 0=yes, 1=no
  local q="$1" def="${2:-n}"
  case "$UI_MODE" in
    whiptail)
      local flags="--yesno"
      [ "$def" = "y" ] && flags="--defaultno"  # whiptail --defaultno = default No actually wait, --defaultno means default is No; --defaultyes means default is Yes
      # Simpler: always use --defaultno then add --yes-button --no-button
      whiptail --title "确认" --yesno "$q" 10 60
      return $?
      ;;
    dialog)
      dialog --title "确认" --yesno "$q" 10 60
      return $?
      ;;
    text)
      local yn="y/N"; [ "$def" = "y" ] && yn="Y/n"
      local ans; read -rp "$q [$yn] " ans
      case "${ans:-$def}" in y|Y|yes|YES) return 0;; *) return 1;; esac
      ;;
  esac
}

# === Menu ===
# Args: title, height, width, menu-height, prompt, item1, status1, item2, status2, ...
ui_menu() {
  case "$UI_MODE" in
    whiptail) whiptail --title "$1" --menu "$5" "$2" "$3" "$4" "${@:6}" 3>&1 1>&2 2>&3;;
    dialog)   dialog   --title "$1" --menu "$5" "$2" "$3" "$4" "${@:6}" 3>&1 1>&2 2>&3;;
    text)
      local title="$1" prompt="$5"; shift 5
      echo "─── $title ───"
      echo "$prompt"
      local i=1
      local -a keys=()
      local -a descs=()
      while [ $# -gt 0 ]; do
        keys+=("$1")
        descs+=("$2")
        shift 2
      done
      # Print all options
      for i in "${!keys[@]}"; do
        printf "  %3d) %s — %s\n" "$((i+1))" "${keys[$i]}" "${descs[$i]}"
      done
      printf "  0) 返回/取消\n"
      printf "选择 [0-%d]: " "${#keys[@]}"
      local ans
      if [ -t 0 ]; then
        read -r ans
      else
        # Read one line from stdin
        read -r ans || ans=""
      fi
      ans="${ans:-}"
      case "$ans" in
        0|"") return 1 ;;
        *)
          if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le "${#keys[@]}" ]; then
            REPLY="${keys[$((ans-1))]}"
            return 0
          fi
          echo "无效选择"
          return 1
          ;;
      esac
      ;;
  esac
}

# === Checklist (multi-select with ON/OFF state) ===
# Args: title, height, width, list-height, prompt, item1, status1, item2, status2, ...
# Result via stdout: space-separated chosen tags
ui_checklist() {
  case "$UI_MODE" in
    whiptail)
      whiptail --title "$1" --separate-output --checklist "$5" "$2" "$3" "$4" "${@:6}" 3>&1 1>&2 2>&3 | tr '\n' ' '
      ;;
    dialog)
      dialog --title "$1" --separate-output --checklist "$5" "$2" "$3" "$4" "${@:6}" 3>&1 1>&2 2>&3 | tr '\n' ' '
      ;;
    text)
      local title="$1" prompt="$5"; shift 5
      echo "─── $title ───"
      echo "$prompt"
      echo "(输入编号切换选择，空格分隔多个，空回车结束)"
      local -a tags=()
      local -a descs=()
      local -a sel=()
      while [ $# -gt 0 ]; do
        tags+=("$1")
        descs+=("$2")
        sel+=(0)
        shift 2
      done
      while true; do
        echo ""
        for i in "${!tags[@]}"; do
          local mark=" "
          [ "${sel[$i]}" = "1" ] && mark="✓"
          printf "  %3d) [%s] %s\n" "$((i+1))" "$mark" "${tags[$i]} — ${descs[$i]}"
        done
        printf "切换 (e.g. 1 3 5 / 0 结束): "
        local ans
        read -r ans
        ans="${ans:-0}"
        if [ "$ans" = "0" ] || [ -z "$ans" ]; then
          break
        fi
        # Toggle each number
        for num in $ans; do
          if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#tags[@]}" ]; then
            local idx=$((num-1))
            if [ "${sel[$idx]}" = "1" ]; then
              sel[$idx]=0
            else
              sel[$idx]=1
            fi
          fi
        done
      done
      local result=""
      for i in "${!tags[@]}"; do
        [ "${sel[$i]}" = "1" ] && result+="${tags[$i]} "
      done
      printf "%s\n" "$result"
      ;;
  esac
}

# === Inputbox ===
ui_input() {  # prompt default -> stdout
  local prompt="$1" def="${2:-}"
  case "$UI_MODE" in
    whiptail)
      whiptail --inputbox "$prompt" 8 60 "$def" 3>&1 1>&2 2>&3
      ;;
    dialog)
      dialog --inputbox "$prompt" 8 60 "$def" 3>&1 1>&2 2>&3
      ;;
    text)
      local ans; read -rp "$prompt [$def]: " ans
      echo "${ans:-$def}"
      ;;
  esac
}

# === Gauge (progress) ===
ui_gauge() {  # used; total; text
  local used="$1" total="$2" text="$3"
  case "$UI_MODE" in
    whiptail)
      local pct=0
      [ "$total" -gt 0 ] && pct=$((used * 100 / total))
      echo "XXX"
      echo "$pct"
      echo "$text"
      echo "XXX"
      ;;
    dialog)
      local pct=0
      [ "$total" -gt 0 ] && pct=$((used * 100 / total))
      echo "XXX"; echo "$pct"; echo "$text"; echo "XXX"
      ;;
    text)
      printf "\r  [%3d%%] %s" "$((total>0 ? used*100/total : 0))" "$text"
      ;;
  esac
}

ui_clear() { case "$UI_MODE" in whiptail) clear;; dialog) clear;; esac; }
