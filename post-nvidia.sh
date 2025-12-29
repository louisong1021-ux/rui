#!/usr/bin/env bash
set -euo pipefail

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

need sudo
need pacman

if [[ "$(id -u)" -eq 0 ]]; then
  die "请用普通用户运行（不要用 root）。"
fi

echo "===== 需要 sudo 权限以安装 NVIDIA 驱动 ====="
sudo -v

echo "===== 检查显卡（期望：NVIDIA GTX 1070）====="
if command -v lspci >/dev/null 2>&1; then
  lspci | grep -iE "vga|3d|display" || true
fi

echo "===== 更新 pacman 数据库（不强制全系统升级）====="
sudo pacman -Sy --noconfirm

echo "===== 安装 NVIDIA 驱动（GTX 1070 / Pascal）====="
# Pascal 支持标准 nvidia 包（无需 legacy）
# - nvidia：与当前 linux 内核配套的预编译模块（最省事）
# - nvidia-utils：用户态库
# - lib32-nvidia-utils：32位库（Steam/Proton 常用）
# - nvidia-settings：图形化设置面板
# - vulkan-icd-loader & lib32-vulkan-icd-loader：Vulkan loader
sudo pacman -S --needed --noconfirm \
  nvidia nvidia-utils lib32-nvidia-utils \
  nvidia-settings \
  vulkan-icd-loader lib32-vulkan-icd-loader

echo "===== （推荐）安装基础图形诊断工具 ====="
sudo pacman -S --needed --noconfirm mesa-utils || true

echo "===== 生成 initramfs（确保重启后模块加载正确）====="
sudo mkinitcpio -P

echo
echo "✅ NVIDIA 驱动安装完成（GTX 1070）"
echo
echo "下一步建议："
echo "  1) 直接重启：sudo reboot"
echo "  2) 若 GNOME Wayland 不稳定：在登录界面点齿轮选择“GNOME on Xorg”"
echo
echo "可选检查命令（重启后执行）："
echo "  nvidia-smi"
echo "  glxinfo | grep -i 'OpenGL renderer'"
