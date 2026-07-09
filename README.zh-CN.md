<div align="center">

# 🧹 sysclean

### 一个 TUI 清理、审计、管理你的 Linux 桌面

*服务 · Docker · Flatpak · 磁盘 · 启动项 · Shell RC — 一个菜单全看见，删之前问一遍。*

[![Version](https://img.shields.io/badge/version-0.1.0-6366f1?style=flat-square)](https://github.com/lora-sys/sysclean/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/lora-sys/sysclean/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/lora-sys/sysclean/actions)
[![Platform](https://img.shields.io/badge/platform-Linux-22c55e?style=flat-square)](#-依赖)
[![Shell](https://img.shields.io/badge/shell-bash_4.0%2B-4eaa25?style=flat-square)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-f59e0b?style=flat-square)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-41%2F41-22c55e?style=flat-square)](#-测试)
[![Downloads](https://img.shields.io/github/downloads/lora-sys/sysclean/total?style=flat-square)](https://github.com/lora-sys/sysclean/releases)

```
sysclean 主菜单
─────────────────────────────────────────
 1) ⚙️  服务管理 (systemd)     ← 200+ 服务一屏全显
 2) 🐳 Docker 管理             ← 容器 / 镜像 / 卷 / 网络
 3) 📦 Flatpak 管理            ← apps + runtimes
 4) 💾 磁盘清理               ← 缓存、构建残留、回收站、日志
 5) 🚀 启动项 & Shell RC       ← autostart、计时器、RC 异常
 6) 🩺 系统诊断 & 扫描报告      ← 11 节报告
 7) 🧹 一键安全清理
─────────────────────────────────────────
```

</div>

---

## 🎯 为什么做 sysclean？

你的 Linux 桌面藏着一堆垃圾：孤儿 Docker 镜像、沉睡的 `venv`、坏掉的 systemd unit、残留的 Flatpak runtime。你*知道*它在那，但找出并删掉得敲 10 个不同的命令。

**sysclean** 给你一个菜单看见所有东西，看哪些能安全删，然后**每次删除都明确问你**。**绝不静默，绝不意外。**

| 痛点 | 不用 sysclean | 用 sysclean |
|---|---|---|
| "磁盘去哪了？" | `du -sh /*` 然后 `find` 求神拜佛 | `sysclean --scan` |
| "哪些服务在跑？" | `systemctl list-units` × N | `sysclean` → 服务管理 |
| "哪些 Docker 镜像是孤儿？" | `docker images` 手动对比 | `sysclean` → Docker → 孤儿 |
| "哪些 `.venv` 能删？" | 手动检查每个 repo | `sysclean` → 磁盘 → 构建残留 |
| "shellrc 里有没有硬编码密钥？" | grep + 人工审 | `sysclean` → RC 异常 |

---

## ✨ 功能

- 🔧 **服务管理** — 所有 systemd unit（system + user），启动/停止/启用/禁用 + 日志查看 + 失败状态重置
- 🐳 **Docker 管理** — 容器/镜像/卷/网络，选择性删除，孤儿检测
- 📦 **Flatpak 管理** — apps + runtimes，反向依赖检查
- 💾 **磁盘清理** — 缓存、构建残留（`venv` / `node_modules` / `target` / `dist`）、包管理器缓存、回收站、日志
- 🚀 **启动项审计** — autostart、systemd 计时器、cron、shell RC 异常（重复 alias、硬编码密钥）
- 🩺 **系统扫描** — 11 节纯文本报告，可管道， `--scan` 适合脚本
- 🛡 **非破坏性** — 每次操作都要 `[y/N]` 确认；`--dry-run` 模式；白名单/黑名单
- 🎨 **3 种 UI 模式** — `whiptail` (TUI)、`dialog`、纯文本（非 TTY 环境自动降级）
- ⚡ **核心零依赖** — 只需要 `bash` + 标准 Unix 工具

---

## 📦 安装

### 🚀 方式 1：pacman（Arch / CachyOS / Manjaro）— **推荐**

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install-pacman.sh | sudo bash
```

这一行：
1. 把 `[lora-sys]` 仓加到 `/etc/pacman.conf`
2. 跑 `pacman -Sy` 同步
3. 跑 `pacman -S sysclean` 装

之后用标准 pacman 管理：

```bash
pacman -Syu sysclean    # 更新
pacman -Rns sysclean    # 卸载（连带无用依赖）
pacman -Qi sysclean    # 信息
```

仓地址：**https://lora-sys.github.io/sysclean**

### ⚡ 方式 2：一行安装（任何 Linux）

```bash
curl -fsSL https://raw.githubusercontent.com/lora-sys/sysclean/main/install.sh | bash
```

装到 `~/.local/bin/sysclean` + `~/.local/share/sysclean/lib/`，不需要 root。

### 🔧 方式 3：手动 / 源码

```bash
git clone https://github.com/lora-sys/sysclean.git
cd sysclean
make install              # → ~/.local（无需 sudo）
sudo make install-system  # → /usr/local（系统级）
```

---

## 🚀 用法

```bash
sysclean              # 启动交互 TUI
sysclean --scan       # 完整系统报告（纯文本，可管道）
sysclean --help       # 所有选项
sysclean --version    # 显示版本
```

### CLI 参数

| 参数 | 简写 | 说明 |
|---|---|---|
| `--scan` | | 跑完整系统扫描，输出纯文本 |
| `--menu` | | 启动 TUI（无参数时默认） |
| `--dry-run` | `-n` | 预览不执行 |
| `--yes` | `-y` | 跳过 `[y/N]` 确认（慎用） |
| `--noninteract` | | 强制非交互模式 |
| `--version` | `-V` | 打印版本并退出 |
| `--help` | `-h` | 打印帮助并退出 |

### `sysclean --scan` 输出示例

```text
═══════════════════════════════════════════════════════════
  sysclean v0.1.0 — System Scan
═══════════════════════════════════════════════════════════

─── 1. 系统资源 ───
/dev/nvme0n1p7  341G  127G  210G  38% /home
Mem:            23Gi  12Gi  8.4Gi ...

─── 2. 系统服务 (system) ───  ─── 3. 用户服务 ───
  running: 31, failed: 0           running: 35, failed: 0

─── 4. Docker ───
Images          18   2   9.14GB   4.28GB reclaimable (46%)
Containers      2    1   ...

─── 5. Flatpak ───  ─── 6. 顶级磁盘占用 ───
  apps: 11  runtimes: 10   /home/lora/repos  49G
                                 /home/lora/桌面   2.1G
─── 7. 缓存大小 ───              /home/lora/文档   2.0G
  4.5G  /home/lora/.cache         ...
─── 8. 回收站 ───
  0     (empty)

─── 9. 日志占用 ───  ─── 10. systemd 计时器 ───
  47M                       snapper-cleanup.timer ...
                            shadow.timer ...

─── 11. Shell RC 异常 ───
  ⚠ /home/lora/.zshrc:190  duplicate alias "clean"
  ⚠ /home/lora/.zshrc:200  hardcoded key: MINIMAX_API_KEY=sk-cp-...

═══════════════════════════════════════════════════════════
扫描完成。运行 'sysclean' 进入交互模式。
```

---

## 🎨 TUI 走查

```
─── 服务管理 ───                       ─── Docker 管理 ───
  1) ▶ 活跃服务 (32)                    1) 📦 容器 (1 运行 / 2 总)
  2) ✗ 失败服务 (0)                    2) 🖼️  镜像 (18 总)
  3) 🔍 浏览所有服务 (200+)              3) 💾 数据卷 (4 总)
  4) 📜 重置所有 failed 状态            4) 🌐 网络 (6 总)
  5) 🩺 检测可疑服务                   5) 🧹 一键清理孤儿
  0) 返回                              7) 🔍 查看孤儿镜像

─── 磁盘清理 ───                       ─── 启动项 & Shell RC ───
  1) Home top dirs (TOP 30)             1) 🚀 用户 autostart (0)
  2) ~/.cache subdirs                   2) ⏰ systemd 计时器 (10)
  5) Build artifacts                    3) 📋 cron 任务 (0)
  7) Trash                              4) 📝 Shell rc 异常
  8) Journal logs (vacuum)               0) 返回
```

每个菜单：
- **列出** 内容，带大小/数量
- **复选框** 多选（whiptail）
- **`[y/N]`** 确认才执行破坏性操作
- **`ESC`** 随时取消

---

## 📋 依赖

### 必需
| 工具 | 用途 |
|---|---|
| `bash` ≥ 4.0 | 核心脚本 |
| `systemctl` | 服务管理（systemd 发行版） |
| `jq` | 状态持久化（`~/.config/sysclean/state.json`） |

### 可选（缺失自动跳过）
| 工具 | 启用功能 |
|---|---|
| `whiptail` | TUI 模式（降级到 `dialog` 或文本） |
| `dialog` | 备选 TUI |
| `docker` | Docker 管理菜单 |
| `flatpak` | Flatpak 管理菜单 |
| `sudo` | 系统级服务操作 |

`whiptail` 不可用或 stdin 不是 TTY 时（CI、脚本），工具自动用纯文本模式。**到处都能用。**

---

## ⚙️ 配置

`~/.config/sysclean/`：

| 文件 | 用途 |
|---|---|
| `state.json` | 白名单/黑名单/偏好 |
| `history.log` | 最近 50 条操作 |
| `sysclean.log` | 详细日志 |

白名单你不想被打扰的服务：

```bash
sysclean → 9) 设置 → 2) 添加服务到白名单
```

或直接编辑 `state.json`：

```json
{
  "whitelist": ["docker", "sshd", "NetworkManager"],
  "blacklist": []
}
```

---

## 🛡 安全保障

- ✅ 每次破坏性操作都要明确 `[y/N]` 确认
- ✅ `--dry-run` 预览不执行
- ✅ 白名单保护服务不被"停用"
- ✅ 永久删除前显示回收站内容
- ✅ 不动项目文件除非显式选择
- ✅ `sudo` 仅用于系统级 unit 操作
- ✅ 文件操作都用绝对路径
- ✅ 所有变量都加引号；处处 `set -euo pipefail`

---

## 🧪 测试

```bash
make test              # 快速测试
bash tests/local-ci.sh # 完整 CI 等价（4 阶段）
```

覆盖率：**41/41 测试通过**

- ✅ **4/4** CI 阶段（lint、UI、CLI、E2E）
- ✅ **12/12** UI 原语（msg、yesno、input、checklist、menu、gauge、clear、info、error、to_bytes、human、has）
- ✅ **3/3** CLI 模式（--version、--help、--scan）
- ✅ **26/26** TUI 菜单路径（所有主菜单子菜单）

每次 push 都跑 CI — 见 [`.github/workflows/ci.yml`](.github/workflows/ci.yml)。

---

## 🤝 贡献

欢迎 PR！详见 **[CONTRIBUTING.md](CONTRIBUTING.md)**：
- 开发环境搭建
- 如何加新菜单路径（5 步流程）
- 代码风格（bash 4.0+、2 空格缩进、变量加引号等）
- 如何写测试
- Bug 报告 / 功能请求模板

---

## 📁 项目结构

```
sysclean/
├── sysclean               # 主入口脚本（~300 行）
├── lib/                   # 模块（共 ~1700 行）
│   ├── common.sh          # 工具、日志、状态、sudo
│   ├── ui.sh              # whiptail/dialog/text UI 原语
│   ├── services.sh        # systemd 服务扫描 + 管理
│   ├── docker.sh          # 容器、镜像、卷、网络
│   ├── flatpak.sh         # apps、runtimes
│   ├── disk.sh            # 缓存、构建残留、回收站、日志、大文件
│   └── startup.sh         # autostart、计时器、cron、RC 异常
├── tests/                 # 测试脚本
│   ├── test_ui.sh         # UI 原语测试
│   ├── test_e2e.sh        # 端到端菜单测试
│   └── local-ci.sh        # 本地 CI 跑（同 GitHub Actions）
├── install.sh             # 一行安装（用户本地）
├── install-pacman.sh      # 一行安装（pacman 仓）
├── uninstall.sh           # 卸载
├── Makefile               # install / test / lint
├── .github/workflows/ci.yml
├── README.md              # 你在这里
├── README.zh-CN.md        # 中文文档（你刚看完）
├── CHANGELOG.md
└── LICENSE                # MIT
```

---

## 🗺 路线图

- [x] **v0.1.0** — 核心服务、Docker、Flatpak、磁盘、启动项、RC
- [ ] **v0.2.0** — Snap 管理、Brew 管理、系统快照
- [ ] **v0.3.0** — 自定义扫描器插件系统
- [ ] **v1.0.0** — 稳定 API、AUR 提交（如获得维护者权限）、社区翻译

---

## 📜 许可证

[MIT](LICENSE) © 2026 lora-sys

---

## 🌐 链接

| | |
|---|---|
| 📦 **pacman 仓** | https://lora-sys.github.io/sysclean |
| 🐙 **GitHub** | https://github.com/lora-sys/sysclean |
| 📋 **发布** | https://github.com/lora-sys/sysclean/releases |
| 🐛 **Issue** | https://github.com/lora-sys/sysclean/issues |
| 📝 **更新日志** | [CHANGELOG.md](CHANGELOG.md) |
| 🇬🇧 **English** | [README.md](README.md) |

---

<sub>用 🧹 为 Linux 桌面打造。与 Arch Linux、Docker、Flatpak 无关。</sub>
