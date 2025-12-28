# Arch Linux GNOME Automated Installer

这是一个用于 **UEFI 环境** 的 Arch Linux 自动化安装脚本，目标是一次性部署一套：

- Arch Linux 基础系统
- GNOME 桌面环境
- 完整中文支持
- 常用桌面与美化工具
- 适合虚拟机 / 测试环境的可维护方案

---

## ✨ 特性

- UEFI + GPT 自动分区
- GNOME + GDM 桌面
- Fcitx5 中文输入法（拼音）
- PipeWire 音频系统
- 蓝牙支持
- NTFS / exFAT 文件系统支持
- Google Chrome（AUR）
- GNOME 美化工具（不自动配置）
- VMware 虚拟机支持（open-vm-tools）

---

## 🖥 已安装内容概览

### 系统与引导
- base / linux / linux-firmware
- grub / efibootmgr

### 桌面
- gnome
- gdm
- gnome-tweaks
- gnome-shell-extensions
- dconf-editor

### 中文支持
- fcitx5
- fcitx5-im
- fcitx5-chinese-addons
- fcitx5-pinyin
- noto-fonts / noto-fonts-cjk

### 音频 / 多媒体
- pipewire
- wireplumber
- gstreamer 插件全集

### 文件系统
- ntfs-3g
- exfatprogs
- dosfstools

---

## 🎨 GNOME 美化（仅安装工具）

脚本 **只安装美化工具，不自动启用或配置**。

### GNOME 扩展（官方仓库）
- Dash to Dock（底部 Dock，可透明）
- Blur My Shell（顶部栏 / Dock 毛玻璃）

启用方式：
登录 GNOME → 打开 **Extensions** → 手动开启并调整参数。

### 主题 / 图标 / 光标（AUR）
- GTK 主题：WhiteSur / Orchis
- 图标：Tela / Papirus
- 光标：Bibata

使用 **GNOME Tweaks** 自行选择。

---

## 🌐 浏览器
- Google Chrome（AUR）

---

## 👤 默认账户（测试用）

⚠️ **仅适合虚拟机或测试环境**

- 用户名：`rui`
- 用户密码：`123456`
- root 密码：`root`

---

## ⚠️ 使用前须知

- 必须以 **UEFI 模式** 启动 Arch ISO
- 脚本会 **完全清空 `/dev/sda`**
- 需要正常联网
- AUR 软件存在一定风险，仅用于学习 / 测试

---

## 🚀 使用方法（单行命令）

```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/install.sh | bash


