#!/usr/bin/env bash
set -eu
set -o pipefail 2>/dev/null || true

RAW_BASE="https://raw.githubusercontent.com/louisong1021-ux/rui/main"

# 固定配置
DISK="/dev/sda"
USERNAME="rui"
HOSTNAME="arch-test"
TZ="America/Los_Angeles"
ROOTPW="root"
USERPW="123456"

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少命令: $1"; exit 1; }; }

need curl
need python

# archinstall 必须存在（官方 ISO 一般自带）
if ! command -v archinstall >/dev/null 2>&1; then
  echo "缺少 archinstall。请使用官方 Arch ISO，或先执行：pacman -Sy --noconfirm archinstall"
  exit 1
fi

# 必须 UEFI
if [[ ! -d /sys/firmware/efi ]]; then
  echo "❌ 当前不是 UEFI 启动，请在 BIOS/虚拟机中选择 UEFI 启动 ISO"
  exit 1
fi

echo "⚠️ 即将清空磁盘: $DISK"
lsblk
read -r -p "输入 YES 确认清盘: " ok
[[ "$ok" == "YES" ]] || { echo "已取消"; exit 1; }

# 下载 config
curl -fsSL "$RAW_BASE/config.json" -o /root/config.json

# 强制补丁（/dev/sda + XFCE + zh_CN.UTF-8 + 必要包）
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

# XFCE（兼容写法）
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

# 强制磁盘为 /dev/sda（替换任何出现的 /dev/sda 或 /dev/nvme0n1）
txt=json.dumps(d)
txt=re.sub(r'"/dev/(nvme0n1|sda)"','"/dev/sda"',txt)
d=json.loads(txt)

with open(p,"w",encoding="utf-8") as f:
    json.dump(d,f,indent=2,ensure_ascii=False)

print("✅ config.json 已锁定：/dev/sda + XFCE + zh_CN.UTF-8 + 必要包")
PY

# 生成 creds（测试用）
python - <<PY
import crypt, json
salt=crypt.mksalt(crypt.METHOD_SHA512)
creds={
  "root_enc_password": crypt.crypt("${ROOTPW}", salt),
  "users":[{"username":"${USERNAME}","enc_password":crypt.crypt("${USERPW}", salt),"sudo":True}]
}
open("/root/creds.json","w").write(json.dumps(creds,indent=2))
print("✅ creds.json 已生成")
PY

# 开装
archinstall --config /root/config.json --creds /root/creds.json --silent

echo "🎉 安装完成，系统即将重启"
reboot
