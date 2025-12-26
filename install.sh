#!/usr/bin/env bash
set -e

RAW_BASE="https://raw.githubusercontent.com/louisong1021-ux/rui/main"

echo "==== Arch 自动安装（XFCE / sda）===="

# 确认 UEFI
if [[ ! -d /sys/firmware/efi ]]; then
  echo "❌ 当前不是 UEFI 启动，停止安装"
  exit 1
fi

lsblk
echo
read -r -p "⚠️ 将清空 /dev/sda，输入 YES 继续: " ok
[[ "$ok" == "YES" ]] || exit 1

# 拉配置
curl -fsSL "$RAW_BASE/config.json" -o /root/config.json

# 生成 creds.json（明文，兼容你当前 archinstall）
cat > /root/creds.json <<EOF
{
  "root_password": "root",
  "users": [
    {
      "username": "rui",
      "password": "123456",
      "sudo": true
    }
  ]
}
EOF

# 执行安装（不传 profile 参数）
archinstall \
  --config /root/config.json \
  --creds /root/creds.json \
  --silent

echo "🎉 安装完成，5 秒后重启"
sleep 5
reboot
