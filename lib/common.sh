# common.sh - shared utilities for sysclean
# Sourced by other modules; do not run directly.

set -o pipefail

# === Paths ===
SYSCLEAN_HOME="${SYSCLEAN_HOME:-$HOME/.local/share/sysclean}"
SYSCLEAN_LIB="$SYSCLEAN_HOME/lib"
SYSCLEAN_CONFIG="${SYSCLEAN_CONFIG:-$HOME/.config/sysclean}"
SYSCLEAN_STATE="$SYSCLEAN_CONFIG/state.json"
SYSCLEAN_HISTORY="$SYSCLEAN_CONFIG/history.log"
SYSCLEAN_BACKUPS="$SYSCLEAN_CONFIG/backups"
SYSCLEAN_LOG="$SYSCLEAN_CONFIG/sysclean.log"

mkdir -p "$SYSCLEAN_CONFIG" "$SYSCLEAN_BACKUPS"

# === State (key=value defaults) ===
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
VERBOSE="${VERBOSE:-0}"
NONINTERACTIVE="${NONINTERACTIVE:-0}"
START_TIME=$(date +%s)

# === Output ===
_log() {
  local level="$1"; shift
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s [%s] %s\n' "$ts" "$level" "$*" | tee -a "$SYSCLEAN_LOG" >&2
}
log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@" >&2; }
log_error() { _log "ERROR" "$@" >&2; }
log_ok()    { _log "OK"    "$@"; }
log_action(){ _log "ACTION" "$@"; }

die() { log_error "$@"; exit 1; }

# === Sizes ===
to_bytes() {
  # Parse "<number><unit>" where unit is K/M/G/T (case-insensitive) or empty
  local s="$1" num unit
  if [[ "$s" =~ ^([0-9]+(\.[0-9]+)?)([KMGTkmgt])?$ ]]; then
    num="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[3]^^}"
    case "$unit" in
      K) echo $(( ${num%.*} * 1024 )) ;;
      M) echo $(( ${num%.*} * 1024 * 1024 )) ;;
      G) echo $(( ${num%.*} * 1024 * 1024 * 1024 )) ;;
      T) echo $(( ${num%.*} * 1024 * 1024 * 1024 * 1024 )) ;;
      "") echo "${num%.*}" ;;
    esac
  else
    echo "0"
  fi
}

human() {
  # Convert bytes to human-readable (B, KB, MB, GB, TB)
  local b="${1:-0}"
  awk -v b="$b" 'BEGIN{
    split("B KB MB GB TB",u," ")
    i=1
    while(b>=1024 && i<5){b/=1024;i++}
    if (b == int(b)) printf "%d %s", b, u[i]
    else printf "%.1f %s", b, u[i]
  }'
}

# === JSON state ===
state_get() {  # key -> value
  local key="$1"
  [ -f "$SYSCLEAN_STATE" ] || { echo ""; return; }
  jq -r --arg k "$key" '.[$k] // ""' "$SYSCLEAN_STATE"
}
state_set() {  # key value
  local key="$1" value="$2"
  local tmp; tmp=$(mktemp)
  if [ -f "$SYSCLEAN_STATE" ]; then
    jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$SYSCLEAN_STATE" > "$tmp"
  else
    jq -n --arg k "$key" --arg v "$value" '{($k): $v}' > "$tmp"
  fi
  mv "$tmp" "$SYSCLEAN_STATE"
}
state_init() {
  if [ ! -f "$SYSCLEAN_STATE" ]; then
    jq -n '{
      version: 1,
      created: (now | todate),
      whitelist: [],
      blacklist: [],
      last_scan: null,
      pinned_services: []
    }' > "$SYSCLEAN_STATE"
  fi
}

# === Sudo ===
ensure_sudo() {  # refresh sudo timestamp; prompt for password if needed
  if [ "$NONINTERACTIVE" = "1" ]; then return 0; fi
  sudo -nv 2>/dev/null && return 0
  if command -v sudo >/dev/null 2>&1; then
    log_info "需要 sudo 权限（首次会提示输入密码）"
    sudo -v || die "sudo 验证失败"
    # Background refresh to keep timestamp alive
    ( while kill -0 $$ 2>/dev/null; do sudo -nv; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
  else
    die "需要 root 权限但 sudo 不可用"
  fi
}

# === Confirm ===
confirm() {  # prompt [default]
  local prompt="$1" def="${2:-n}"
  [ "$ASSUME_YES" = "1" ] && return 0
  [ "$NONINTERACTIVE" = "1" ] && return 1
  local yn; if [ "$def" = "y" ]; then yn="Y/n"; else yn="y/N"; fi
  local ans; read -rp "$prompt [$yn] " ans
  case "${ans:-$def}" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

# === Command exists ===
has() { command -v "$1" >/dev/null 2>&1; }

# === Truncate for display ===
trunc() {  # string width
  local s="$1" w="${2:-60}"
  if [ "${#s}" -le "$w" ]; then printf '%s' "$s"
  else printf '%s…' "${s:0:$((w-1))}"
  fi
}

# === Format duration ===
fmt_duration() {
  local s="$1"
  if [ "$s" -lt 60 ]; then echo "${s}s"
  elif [ "$s" -lt 3600 ]; then echo "$((s/60))m$((s%60))s"
  else echo "$((s/3600))h$((s%3600/60))m"
  fi
}

# === Sanity ===
require_root_or_user() {
  :  # Both root and user have appropriate paths
}

state_init
