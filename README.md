# Arch Linux + GNOME 自动化安装脚本（Two-Stage）

一套 **两阶段（Two-Stage）** 的 Arch Linux 自动化安装方案，专为：

- ✅ **真机（Dell XPS 8930 / Intel CPU + NVIDIA GTX）**
- ✅ **VMware 虚拟机**
- ✅ **长期主力桌面使用**

而设计。

本项目的核心理念是：

> **先把系统稳定、干净地装好，再由用户自行决定桌面与美化。**

---

## ✨ 设计目标

- ✅ 稳定：适配 Arch Linux 滚动更新
- ✅ 可维护：系统骨架 / 驱动 / 美化完全解耦
- ✅ 防误操作：磁盘交互选择 + 二次确认
- ✅ 通用性：同一套脚本支持真机与虚拟机
- ✅ 不强制任何 GNOME 外观或扩展

---

## 📦 脚本结构

本仓库包含 **三个脚本**，各司其职：

| 脚本 | 用途 |
|----|----|
| `install.sh` | 系统骨架安装（在 Arch ISO 中运行） |
| `post.sh` | 常用软件 + 美化资源下载（登录系统后运行） |
| `post-nvidia.sh` | NVIDIA GTX 显卡驱动安装（真机可选） |

---

## 1️⃣ install.sh —— 系统骨架安装

**运行环境：Arch Linux 官方 ISO（UEFI 模式）**

### install.sh 做什么

- 自动列出所有可用磁盘，让你选择安装目标
- UEFI + GPT 分区
- 安装 Arch Linux 基础系统
- 安装 GNOME 桌面（GDM）
- 配置中文环境（Fcitx5）
- PipeWire 音频
- 网络 / 蓝牙
- 真机 / VMware 分支优化

### install.sh 明确 **不做什么**

- ❌ 不安装任何主题 / 图标 / 光标
- ❌ 不安装任何 GNOME Shell 扩展
- ❌ 不安装 NVIDIA 驱动
- ❌ 不修改任何 GNOME 外观设置

> install.sh 的目标只有一个：  
> **系统可启动、可登录 GNOME、功能完整但外观干净**

---

### 👉 一键运行（在 Arch ISO 中）

## 🚀 快速开始（一键复制）

# ===== Step 1: 在 Arch Linux ISO（UEFI 模式）中运行 =====

```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/install.sh | bash
```
2️⃣ post.sh —— 常用软件 & 美化资源

运行环境：已安装系统，登录 GNOME 后，以普通用户执行

post.sh 做什么

安装 Google Chrome

安装 AUR helper（yay，如不存在）

下载你当前使用的美化资源（不自动应用）：

GTK 主题

图标主题

光标主题

字体

⚠️ post.sh 不会：

自动切换主题

自动启用扩展

修改 dconf / gsettings

所有外观选择，完全由你在 GNOME Tweaks 中手动完成。
# ===== Step 2: 系统安装完成并登录 GNOME 后运行 =====


```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/post.sh | bash
```

3️⃣ post-nvidia.sh —— NVIDIA GTX 显卡驱动（真机）

适用硬件：NVIDIA GTX 1070（Pascal 架构）

post-nvidia.sh 做什么

安装官方 NVIDIA 驱动（非 legacy）

安装 Vulkan / 32 位支持（Steam / Proton 兼容）

自动生成 initramfs

不强制 Wayland / Xorg（由用户选择）

👉 一键运行（真机可选）

# ===== Step 3: N显卡的驱动 =====

```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/post-nvidia.sh | bash
```
