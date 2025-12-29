#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# post.sh
# 作用：
# 1) 安装 Google Chrome（AUR：google-chrome）
# 2) 安装 GNOME 美化所需的“资源”（主题 / 图标 / 光标 / 字体）
#
# 特点：
# - 不安装、不涉及任何 GNOME Shell 扩展
# - 只负责把“资源”准备好，具体美化由你手动完成
#
# 适用环境：
# - 已完成 Arch Linux + GNOME 安装
# - 以普通用户运行（脚本内部使用 sudo）
# ==========================================================

LOG="$HOME/post-install.log"
exec > >(tee -a "$LOG") 2>&1

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
note(){ echo -e "\033[36m==>\033[0m $*"; }
warn(){ echo -e "\033[33m⚠️  $*\033[0m"; }

# ---------------- 基础检查 ----------------
[[ "${EUID}" -ne 0 ]] || die "请使用普通用户运行该脚本（不要用 root）"
command -v sudo >/dev/null 2>&1 || die "系统缺少 sudo"
command -v pacman >/dev/null 2>&1 || die "未检测到 pacman（这不是 Arch？）"

# ---------------- 官方仓库软件 ----------------
# 工具 + 字体（不含任何 GNOME 扩展）
PACMAN_PKGS=(
  gnome-tweaks
  extension-manager
  gnome-browser-connector

  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji

  papirus-icon-theme
)

# ---------------- AUR 软件 ----------------
# Chrome + 美化资源（主题 / 图标 / 光标）
AUR_PKGS=(
  google-chrome
  orchis-theme
  whitesur-gtk-theme
  tela-icon-theme
  bibata-cursor-theme
)

OK=()
FAIL=()

install_pacman() {
  local pkg="$1"
  note "[pacman] 安装：$pkg"
  if sudo pacman -S --noconfirm --needed "$pkg"; then
    OK+=("$pkg")
  else
    FAIL+=("$pkg")
    warn "[pacman] 失败：$pkg"
  fi
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    note "yay 已存在，跳过安装"
    return
  fi

  note "安装 AUR helper：yay"
  sudo pacman -S --noconfirm --needed base-devel git

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp" || true' EXIT

  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)

  command -v yay >/dev/null 2>&1 || die "yay 安装失败"
  OK+=("yay")
}

install_aur() {
  local pkg="$1"
  note "[AUR] 安装：$pkg"
  if yay -S --noconfirm --needed "$pkg"; then
    OK+=("$pkg")
  else
    FAIL+=("$pkg")
    warn "[AUR] 失败：$pkg（AUR 上游或网络波动常见）"
    yay -Yc --noconfirm >/dev/null 2>&1 || true
  fi
}

# ---------------- 开始执行 ----------------
note "更新系统"
sudo pacman -Syu --noconfirm

note "安装官方仓库软件（工具 / 字体 / 图标）"
for p in "${PACMAN_PKGS[@]}"; do
  install_pacman "$p"
done

note "准备 AUR helper（yay）"
install_yay

note "安装 Chrome 与美化资源（AUR）"
for p in "${AUR_PKGS[@]}"; do
  install_aur "$p"
done

# ---------------- 结果汇总 ----------------
echo
note "执行完成，日志已保存到：$LOG"
echo

if ((${#FAIL[@]} > 0)); then
  warn "以下项目安装失败（不影响系统可用，可稍后重试）："
  printf ' - %s\n' "${FAIL[@]}"
else
  note "全部项目安装成功。"
fi

echo
note "接下来你可以这样做（纯手动美化，不走脚本）："
cat <<'EOF'
1) 注销并重新登录 GNOME（Wayland 下推荐）
2) 打开 “Tweaks（微调）”
   - 外观 → 应用程序：Orchis / WhiteSur
   - 外观 → 图标：Tela / Papirus
   - 外观 → 光标：Bibata
3) Chrome 已安装：在应用列表中搜索 “Google Chrome”
4) 若需要 GNOME 扩展，请自行打开 Extension Manager 安装（脚本不再处理）
EOF
