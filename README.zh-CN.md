# sysclean

> Linux 全局系统清理与管理 TUI 工具 — 服务、Docker、Flatpak、磁盘、启动项，一个菜单全搞定。

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

## 为什么做 sysclean？

现代 Linux 桌面系统很容易堆积垃圾：孤儿 Docker 镜像、沉睡的 `venv`、坏掉的 systemd unit、残留的 Flatpak runtime。`sysclean` 把所有这些放一个菜单里展示和操作，**每一次删除都要明确确认**，绝不静默清理。

## 功能

- **服务管理** — 列出所有 systemd 单元（system + user），启动/停止/启用/禁用，查看日志
- **Docker 管理** — 容器/镜像/卷/网络的列删，一键清理孤儿
- **Flatpak 管理** — apps + runtimes，带反向依赖检查
- **磁盘清理** — 缓存、构建残留（`venv`/`node_modules`/`target`）、包管理器缓存、回收站、journal
- **启动项 & RC 审计** — autostart、systemd 计时器、cron、shell RC 异常（重复 alias、硬编码密钥）
- **非破坏性** — 每次操作都要 `[y/N]` 确认；dry-run 模式；白名单/黑名单
- **3 种 UI 模式** — `whiptail`（TUI）、`dialog`、纯文本（自动降级）
- **CLI 模式** — `sysclean --scan` 方便脚本

## 安装

### AUR（Arch / CachyOS / Manjaro）

```bash
yay -S sysclean
```

### 一键安装（任何 Linux）

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
```

装到 `~/.local/bin/sysclean` 和 `~/.local/share/sysclean/lib/`。

### 手动

```bash
git clone https://github.com/lora-sys/sysclean.git
cd sysclean
make install           # 装到 ~/.local
sudo make install-system   # 装到 /usr/local
```

## 用法

```bash
sysclean              # 启动 TUI
sysclean --scan       # 完整系统报告（纯文本）
sysclean --help       # 所有选项
```

### TUI 走查

```
sysclean 主菜单
  1) ⚙️  服务管理 (systemd)        ← 200+ 服务全可见
  2) 🐳 Docker 管理               ← 容器/镜像/卷/网络
  3) 📦 Flatpak 管理               ← apps + runtimes
  4) 💾 磁盘清理                  ← 缓存、构建残留、回收站、journal
  5) 🚀 启动项 & Shell RC          ← autostart、计时器、cron、RC 异常
  6) 🩺 系统诊断 & 扫描报告       ← 完整系统审计
  7) 🧹 一键安全清理（保守）       ← 回收站、journal、缓存 — 不动项目文件
  8) 📜 查看操作历史
  9) ⚙️  设置（白名单/黑名单）
  0) 退出
```

### `--scan` 输出示例

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

## 依赖

- `bash` ≥ 4.0
- `whiptail`（推荐）或 `dialog`（会自动降级到纯文本）
- `systemctl`（systemd 发行版）
- `docker`（可选，Docker 菜单需要）
- `flatpak`（可选，Flatpak 菜单需要）
- `jq`（用于状态持久化）
- `sudo`（系统级操作需要）

## 配置

`~/.config/sysclean/`
- `state.json` — 白名单/黑名单/偏好
- `history.log` — 操作历史（最近 50 条）
- `sysclean.log` — 详细日志

## 安全性

- 每次破坏性操作都要 `[y/N]` 确认
- `--dry-run` 只看不执行
- 白名单（在设置里）保护服务不被"停用"
- 永久删除前显示回收站内容
- 未经显式选择不动项目文件

## 测试

```bash
make test    # 跑 tests/test_e2e.sh
```

25 条菜单路径 + UI 原语（msg、yesno、input、checklist、menu）全覆盖。

## 贡献

欢迎 PR。提交前跑 `make test`。

## 许可证

MIT — 见 [LICENSE](LICENSE)。

## 英文文档

[README.md](README.md)
