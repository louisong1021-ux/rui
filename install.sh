#!/usr/bin/env bash
set -eu
set -o pipefail 2>/dev/null || true

RAW_BASE="https://raw.githubusercontent.com/louisong1021-ux/rui/main"

# ===== 固定配置（测试用）=====
DISK="/dev/sda"
USERNAME="rui"
HOSTNAME="arch-test"
TZ="America/Los_Angeles"

# 测试密码（公开仓库测试用）
ROOTPW="root"
USERPW="123456"
# ============================

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少命令: $1"; exit 1; }; }

need curl

# 确保 archinstall 存在（官方 ISO 通常自带；没有就装）
if ! command -v archinstall >/dev/null 2>&1; then
  echo "未检测到 archinstall，尝试安装..."
  pacman -Sy --noconfirm archinstall >/dev/null
fi

if ! command -v archinstall >/dev/null 2>&1; then
  echo "仍然缺少 archinstall。请确认使用的是官方 Arch ISO。"
  exit 1
fi

# UEFI 检测
if [[ ! -d /sys/firmware/efi ]]; then
  echo "❌ 当前不是 UEFI 启动，请在 BIOS/虚拟机中选择 UEFI 启动 ISO"
  exit 1
fi

echo "⚠️ 即将清空磁盘: $DISK"
lsblk
read -r -p "输入 YES 确认清盘: " ok
[[ "$ok" == "YES" ]] || { echo "已取消"; exit 1; }

# 拉取 config.json（仓库里的这份必须是 UTF-8/LF）
curl -fsSL "$RAW_BASE/config.json" -o /root/config.json

# 生成 creds.json（明文密码，兼容新 Arch；不使用 crypt）
cat > /root/creds.json <<EOF
{
  "root_password": "${ROOTPW}",
  "users": [
    {
      "username": "${USERNAME}",
      "password": "${USERPW}",
      "sudo": true
    }
  ]
}
EOF

# 运行 archinstall：桌面/桌面环境用 CLI 参数（兼容新版 schema）
archinstall \
  --config /root/config.json \
  --creds /root/creds.json \
  --profile desktop \
  --desktop-environment xfce4 \
  --silent

echo "🎉 安装完成，系统即将重启"
reboot
