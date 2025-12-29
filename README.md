# Arch Linux + GNOME 自动化安装脚本

一套 **两阶段（Two-Stage）** 的 Arch Linux 自动化安装方案，设计目标为：

- ✅ **稳定**：适配 Arch Linux 滚动更新策略  
- ✅ **可维护**：系统骨架与桌面美化彻底解耦  
- ✅ **通用性**：适用于真机与虚拟机（VMware）  
- ✅ **低侵入**：不强制任何 GNOME 扩展或外观偏好  

本项目强调 **“先把系统稳定装好，再由用户决定桌面体验”**。

---

## 脚本结构说明

本仓库包含 **两个脚本，必须按顺序执行**：

---

### 1️⃣ `install.sh` —— 系统骨架安装  
**运行环境：Arch Linux 官方 ISO（UEFI 模式）**

该脚本负责完成 **系统级安装与基础配置**，包括：

- Arch Linux 基础系统
- UEFI + GRUB 启动引导
- GNOME 桌面环境（GDM）
- 中文输入法框架（Fcitx5）
- PipeWire 音频系统
- 网络（NetworkManager）与蓝牙
- VMware 虚拟机支持
- GNOME Tweaks 与 Extension Manager（仅工具，不安装扩展）

**目标：系统可启动、可登录 GNOME、中文环境就绪**

---

### 2️⃣ `post.sh` —— 系统内后配置  
**运行环境：已安装系统，登录 GNOME 后，以普通用户执行**

该脚本用于安装 **非系统必需但常用的软件与资源**，包括：

- Google Chrome 浏览器
- GNOME 美化资源（主题 / 图标 / 光标 / 字体）
- AUR helper（`yay`，若系统中不存在）

⚠️ **该脚本不会：**
- 自动应用任何主题 / 图标 / 光标
- 安装或启用任何 GNOME Shell 扩展
- 修改 GNOME 设置或 dconf 配置

---

## 🚀 快速开始（一键复制）

# ===== Step 1: 在 Arch Linux ISO（UEFI 模式）中运行 =====

```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/install.sh | bash


---
# ===== Step 2: 系统安装完成并登录 GNOME 后运行 =====
---

```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/post.sh | bash
