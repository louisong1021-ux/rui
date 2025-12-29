#!/usr/bin/env bash
set -euo pipefail

# ================== post.sh（精简极速版：Papirus） ==================
# 功能：
# - 安装 Google Chrome（AUR：google-chrome）
# - 安装浅色外观资源（不自动应用）：
#   - GTK：Orchis（推荐选 Orchis-Light）
#   - Icons：Papirus（推荐选 Papirus / Papirus-Light）
#   - Cursor：Bibata（推荐选 Bibata-Modern-Classic）
# 说明：
# - 不安装 GNOME 扩展，不修改 dconf/gsettings
# - Papirus 来自官方仓库，速度远快于 Tela
# ===================================================================

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

need sudo
need pacman
need git

# 必须普通用户执行
if [[ "$(id -u)" -eq 0 ]]; then
  die "请用普通用户运行（不要用 root）。"
fi

echo "===== 需要 sudo 权限以安装软件 ====="
sudo -v

echo "===== 更新 pacman 数据库（不全量升级）====="
sudo pacman -Sy --noconfirm

echo "===== 安装基础依赖（构建 AUR 需要）====="
sudo pacman -S --needed --noconfirm base-devel git

# 安装 yay（若不存在）
if ! command -v yay >/dev/null 2>&1; then
  echo "===== 安装 AUR helper：yay ====="
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
fi

# 工具函数：优先 pacman；pacman 没有再用 yay（AUR）
install_pkg() {
  local pkg="$1"
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    echo "===== pacman 安装：$pkg ====="
    sudo pacman -S --needed --noconfirm "$pkg"
  else
    echo "===== AUR 安装：$pkg ====="
    yay -S --needed --noconfirm "$pkg"
  fi
}

echo "===== 安装 Chrome（AUR：google-chrome）====="
# Chrome 基本只能 AUR：不会走 pacman
yay -S --needed --noconfirm google-chrome

echo "===== 安装图标主题（Papirus：官方仓库，快速）====="
sudo pacman -S --needed --noconfirm papirus-icon-theme

echo "===== 安装 GTK 主题（Orchis）====="
install_pkg orchis-theme

echo "===== 安装光标主题（Bibata）====="
install_pkg bibata-cursor-theme

echo
echo "✅ post.sh 完成：已安装 Chrome + Orchis + Papirus + Bibata（未强制应用）"
echo
echo "下一步：GNOME Tweaks → Appearance："
echo "  - Applications：Orchis-Light"
echo "  - Icons：Papirus 或 Papirus-Light"
echo "  - Cursor：Bibata-Modern-Classic"
echo
echo "如 Tweaks 没刷新：注销再登录一次即可。"
