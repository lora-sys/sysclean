# docker.sh - docker scanner + manager

has_docker() { has docker && docker info >/dev/null 2>&1; }

# === Scanners ===
# Output: type|id|name|size_or_status|extra
scan_docker_containers() {
  docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' 2>/dev/null | \
    awk -F'|' '{printf "container|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5}'
}

scan_docker_images() {
  docker images --format '{{.Repository}}:{{.Tag}}|{{.ID}}|{{.Size}}|{{.CreatedSince}}' 2>/dev/null | \
    awk -F'|' '{
      repo=$1
      # Build full repo:tag (handle <none>)
      printf "image|%s|%s|%s|%s\n", $2, repo, $3, $4
    }'
}

scan_docker_volumes() {
  docker volume ls --format '{{.Name}}|{{.Driver}}' 2>/dev/null | \
    awk -F'|' '{printf "volume|%s|%s|unknown|unknown\n", $1, $2}'
}

scan_docker_networks() {
  docker network ls --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null | \
    awk -F'|' '{printf "network|%s|%s|%s|%s\n", $1, $2, $3, $4}'
}

scan_docker_buildcache() {
  docker system df --format '{{.Type}}|{{.Total}}|{{.Active}}|{{.Size}}|{{.Reclaimable}}'
}

# === Action helpers ===
docker_rm_container() {
  local id="$1" force="${2:-}"
  docker rm ${force:+-f} "$id" 2>&1
}
docker_rm_image() {
  local id="$1"
  docker image rm "$id" 2>&1
}
docker_rm_volume() {
  local name="$1"
  docker volume rm "$name" 2>&1
}
docker_rm_network() {
  local id="$1"
  docker network rm "$id" 2>&1
}
docker_stop_container() {
  local id="$1"
  docker stop "$id" 2>&1
}
docker_start_container() {
  local id="$1"
  docker start "$id" 2>&1
}

# === Orphan detection ===
# Returns images that are NOT used by any (running or stopped) container
scan_docker_orphan_images() {
  local used; used=$(docker ps -a --format '{{.Image}}' 2>/dev/null | sort -u 2>/dev/null || echo)
  docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}' 2>/dev/null | \
    awk -F'|' -v used="$used" 'BEGIN{n=split(used,u,"\n")} {
      is_used=0
      for(i=1;i<=n;i++) if(u[i]==$2){is_used=1;break}
      if(!is_used && $2!="<none>:<none>") printf "image|%s|%s|orphan|%s\n", $1, $2, $3
    }'
}

# === Interactive ===
manage_docker() {
  if ! has_docker; then
    ui_info "Docker 未安装或不可用"
    return
  fi
  
  while true; do
    ui_clear
    
    # Quick stats
    local containers running stopped images volumes networks
    containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)
    running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
    images=$(docker images --format '{{.Repository}}' 2>/dev/null | wc -l)
    volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | wc -l)
    networks=$(docker network ls --format '{{.Name}}' 2>/dev/null | tail -n +2 | wc -l)
    
    local reclaimable
    reclaimable=$(docker system df 2>/dev/null | tail -1 | awk '{print $4}')
    
    ui_menu "Docker 管理" 20 70 11 \
      "Docker 资源管理" \
      "1" "📦 容器 ($running 运行 / $containers 总)" \
      "2" "🖼️  镜像 ($images 总)" \
      "3" "💾 数据卷 ($volumes 总)" \
      "4" "🌐 网络 ($networks 总)" \
      "5" "🧹 一键清理孤儿（容器+镜像+卷）" \
      "6" "📊 系统资源使用 (docker system df)" \
      "7" "🔍 查看孤儿镜像（容器未引用）" \
      "0" "返回" \
     
    local choice="$REPLY"
    
    case "$choice" in
      1) _manage_docker_containers ;;
      2) _manage_docker_images ;;
      3) _manage_docker_volumes ;;
      4) _manage_docker_networks ;;
      5) _docker_cleanup_wizard ;;
      6) ui_msg "$(docker system df -v 2>&1)" 35 100 ;;
      7) _show_orphan_images ;;
      0|"") return 0 ;;
    esac
  done
}

_manage_docker_containers() {
  local data; data=$(scan_docker_containers)
  [ -z "$data" ] && { ui_info "没有容器"; return; }
  
  while true; do
    ui_clear
    local args=()
    while IFS='|' read -r id name image status ports; do
      [ -z "$id" ] && continue
      args+=("$id" "[$status] $name ($image)")
    done <<< "$data"
    args+=("__back__" "← 返回")
    
    ui_menu "Docker 容器" 22 90 16 \
      "选择容器操作" "${args[@]}"
    local sel="$REPLY"
    [ "$sel" = "__back__" ] || [ -z "$sel" ] && return
    
    _docker_container_action "$sel"
    # Refresh
    data=$(scan_docker_containers)
  done
}

_docker_container_action() {
  local id="$1"
  local name image status
  name=$(docker ps -a --format '{{.Names}}' --filter "id=$id" 2>/dev/null)
  image=$(docker ps -a --format '{{.Image}}' --filter "id=$id" 2>/dev/null)
  status=$(docker ps -a --format '{{.Status}}' --filter "id=$id" 2>/dev/null)
  
  while true; do
    ui_clear
    echo "容器: $name ($image)"
    echo "ID: $id"
    echo "状态: $status"
    echo ""
    
    local is_running=$([ "${status%% *}" = "Up" ] && echo 1 || echo 0)
    
    ui_menu "操作: $name" 14 60 6 \
      "选择" \
      $([ "$is_running" = "0" ] && echo "1" "▶  启动" || echo "1" "■  停止") \
      "2" "↻  重启" \
      "3" "🗑️  删除 (--force)" \
      "4" "📋  inspect (元数据)" \
      "5" "📜  日志 (last 50 lines)" \
      "0" "← 返回" \
     
    local op="$REPLY"
    
    case "$op" in
      1)
        if [ "$is_running" = "0" ]; then
          docker_start_container "$id"
          ui_info "已启动"
        else
          docker_stop_container "$id"
          ui_info "已停止"
        fi
        status=$(docker ps -a --format '{{.Status}}' --filter "id=$id" 2>/dev/null)
        ;;
      2) docker_stop_container "$id" && docker_start_container "$id"; ui_info "已重启";;
      3) if ui_yesno "确认强制删除容器 '$name'? (镜像保留)"; then
           docker_rm_container "$id" --force
           log_ok "已删除 $name"
           return
         fi;;
      4) docker inspect "$id" > /tmp/c.json 2>&1
         ui_msg "$(head -80 /tmp/c.json)" 35 90;;
      5) docker logs --tail 50 "$id" > /tmp/c.log 2>&1
         ui_msg "$(cat /tmp/c.log)" 30 90;;
      0|"") return ;;
    esac
  done
}

_manage_docker_images() {
  local data; data=$(scan_docker_images)
  [ -z "$data" ] && { ui_info "没有镜像"; return; }
  
  local args=()
  while IFS='|' read -r id repo size created; do
    [ -z "$id" ] && continue
    args+=("$id" "[$size] $repo")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "Docker 镜像 (空格多选删除)" 22 90 16 \
    "勾选要删除的镜像，回车确认" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  local list=$(echo "$chosen" | tr ' ' '\n' | grep . | sed 's|^|  • |')
  if ui_yesno "确认删除以下镜像?\n\n$list\n\n(失败将因被容器引用)"; then
    for id in $chosen; do
      log_action "删除镜像 $id"
      docker_rm_image "$id" && log_ok "已删除" || log_warn "删除失败（可能被引用）"
    done
    ui_info "完成"
  fi
}

_manage_docker_volumes() {
  local data; data=$(scan_docker_volumes)
  [ -z "$data" ] && { ui_info "没有数据卷"; return; }
  
  local args=()
  while IFS='|' read -r name driver; do
    [ -z "$name" ] && continue
    args+=("$name" "[$driver] $name")
  done <<< "$data"
  
  local chosen; chosen=$(ui_checklist "Docker 数据卷" 22 90 14 \
    "勾选要删除的卷（注意：数据不可恢复）" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  local list=$(echo "$chosen" | tr ' ' '\n' | grep . | sed 's|^|  • |')
  if ui_yesno "确认删除以下数据卷?\n\n$list"; then
    for name in $chosen; do
      log_action "删除卷 $name"
      docker_rm_volume "$name" && log_ok "已删除" || log_warn "删除失败"
    done
    ui_info "完成"
  fi
}

_manage_docker_networks() {
  local data; data=$(scan_docker_networks)
  [ -z "$data" ] && { ui_info "没有网络"; return; }
  
  local args=()
  while IFS='|' read -r id name driver scope; do
    [ -z "$id" ] && continue
    [ "$name" = "bridge" ] || [ "$name" = "host" ] || [ "$name" = "none" ] && continue  # skip built-ins
    args+=("$id" "[$driver/$scope] $name")
  done <<< "$data"
  
  [ -z "${args[*]:-}" ] && { ui_info "只有内置网络（bridge/host/none）"; return; }
  
  local chosen; chosen=$(ui_checklist "Docker 自定义网络" 22 90 14 \
    "勾选要删除的网络" "${args[@]}" 2>/dev/null)
  
  [ -z "$chosen" ] && return
  
  if ui_yesno "确认删除这些网络?"; then
    for id in $chosen; do
      docker_rm_network "$id" && log_ok "已删除 $id" || log_warn "失败（可能仍被引用）"
    done
    ui_info "完成"
  fi
}

# Cleanup wizard: aggressive prune
_docker_cleanup_wizard() {
  ui_clear
  echo "🧹 清理向导"
  echo ""
  echo "此操作将删除："
  echo "  - 所有已停止的容器"
  echo "  - 所有悬空镜像 (dangling)"
  echo "  - 所有悬空网络"
  echo "  - 所有构建缓存"
  echo ""
  echo "保留："
  echo "  - 正在运行的容器及其镜像"
  echo "  - 所有有名字的镜像（包括未使用）"
  echo "  - 所有数据卷"
  echo ""
  
  if ! ui_yesno "确认执行?"; then return; fi
  
  log_action "docker container prune"
  docker container prune -f 2>&1
  log_action "docker image prune (dangling)"
  docker image prune -f 2>&1
  log_action "docker network prune"
  docker network prune -f 2>&1
  log_action "docker builder prune"
  docker builder prune -f 2>&1
  
  ui_info "✓ 清理完成"
}

_show_orphan_images() {
  local data; data=$(scan_docker_orphan_images)
  [ -z "$data" ] && { ui_info "没有孤儿镜像"; return; }
  
  local listing
  listing=$(echo "$data" | awk -F'|' '$1=="image"{printf "  %-55s %s\n", $3, $4}')
  
  echo "$listing"
  echo ""
  if ui_yesno "立即删除所有孤儿镜像?"; then
    echo "$data" | while IFS='|' read -r type id name extra; do
      [ -z "$id" ] && continue
      docker_rm_image "$id" && log_ok "已删 $name"
    done
    ui_info "完成"
  fi
}
