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
need python

# 官方 ISO 通常自带 archinstall；没有就装
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

# 拉取 config.json
curl -fsSL "$RAW_BASE/config.json" -o /root/config.json

# 强制修正配置：/dev/sda + XFCE + zh_CN.UTF-8 + 必要包
python - <<'PY'
import json, re

p="/root/config.json"
with open(p,"r",encoding="utf-8") as f:
    d=json.load(f)

REQUIRED_PKGS={
  "networkmanager",
  "sudo",
  "open-vm-tools",
  "noto-fonts",
  "noto-fonts-cjk"
}

# 基础信息
d["hostname"]="arch-test"
d["timezone"]="America/Los_Angeles"

# XFCE（兼容字段）
pc=d.get("profile_config",{})
pc["profile"]="desktop"
pc["desktop"]="xfce4"
d["profile_config"]=pc
d["profile"]="desktop"
d["desktop-environment"]="xfce4"
d["desktop_environment"]="xfce4"

# 必要包
pk=set(d.get("packages",[]))
pk |= REQUIRED_PKGS
d["packages"]=sorted(pk)

# 中文 locale
lc=d.get("locale_config",{})
lc["sys_lang"]="zh_CN.UTF-8"
lc["sys_enc"]="UTF-8"
lc["kb_layout"]="us"
d["locale_config"]=lc

# 强制磁盘为 /dev/sda
txt=json.dumps(d)
txt=re.sub(r'"/dev/(nvme0n1|sda)"','"/dev/sda"',txt)
d=json.loads(txt)

with open(p,"w",encoding="utf-8") as f:
    json.dump(d,f,indent=2,ensure_ascii=False)

print("✅ config.json 已锁定：/dev/sda + XFCE + zh_CN.UTF-8 + 必要包")
PY

# 生成 creds.json（不使用 Python crypt，兼容新 Arch）
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

# 全自动安装
archinstall --config /root/config.json --creds /root/creds.json --silent

echo "🎉 安装完成，系统即将重启"
reboot
