#!/usr/bin/env bash
set -euo pipefail

# ================== 精简版 post.sh（仅三件套 + Chrome） ==================
# - Chrome
# - Orchis-Light (GTK)
# - Tela-grey-light (Icons)
# - Bibata-Modern-Classic (Cursor)
# 不装 GNOME 扩展，不改 dconf，只准备资源。
# ========================================================================

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

need bash
need sudo
need pacman
need git

# 必须是普通用户执行（不要用 root 跑）
if [[ "$(id -u)" -eq 0 ]]; then
  die "请用普通用户运行（例如 rui），不要用 root 运行。"
fi

# 一次性获取 sudo（避免中途超时导致安装失败）
echo "===== 需要 sudo 权限以安装软件包 ====="
sudo -v

echo "===== 更新 pacman 数据库（不全系统升级）====="
sudo pacman -Sy --noconfirm

echo "===== 安装基础依赖（AUR 构建所需）====="
sudo pacman -S --needed --noconfirm base-devel git

# 安装 yay（若不存在）
if ! command -v yay >/dev/null 2>&1; then
  echo "===== 安装 AUR helper：yay ====="
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
fi

echo "===== 通过 AUR 安装 Chrome + 三件套（精简）====="
# 说明：
# - google-chrome：Chrome
# - orchis-theme：Orchis GTK 主题（包含 light 变体）
# - tela-icon-theme：Tela 图标主题（包含 grey-light 变体）
# - bibata-cursor-theme：Bibata 光标（包含 Modern Classic 变体）
yay -S --needed --noconfirm \
  google-chrome \
  orchis-theme \
  tela-icon-theme \
  bibata-cursor-theme

echo
echo "✅ 安装完成（未强制应用外观）"
echo
echo "下一步：打开 GNOME Tweaks → 外观（Appearance）选择："
echo "  - 光标：Bibata-Modern-Classic"
echo "  - 图标：Tela-grey-light"
echo "  - 应用程序：Orchis-Light"
echo
echo "可选：如果你刚安装了主题/图标但 Tweaks 没刷新，注销再登录一次即可。"
