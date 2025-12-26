#!/usr/bin/env bash
# 使用 /usr/bin/env 来查找 bash，确保脚本可移植性

set -euo pipefail
# -e: 遇到任何命令返回非零退出码立即退出
# -u: 使用未定义变量时立即报错
# -o pipefail: 管道中任意命令失败，整个管道视为失败
# 这三项组合能让脚本更严谨、更安全，避免隐藏错误

# ===== 固定配置 =====
DISK="/dev/sda"              # 目标安装磁盘（警告：整个磁盘会被清空！）
HOSTNAME="arch-test"         # 主机名
USERNAME="rui"               # 要创建的普通用户名
TZ="America/Los_Angeles"     # 时区（可改为 Asia/Shanghai 等）
LOCALE="zh_CN.UTF-8"         # 系统语言环境
KEYMAP="us"                  # 控制台键盘布局（us 为美式键盘）
# 测试用密码（公开仓库：你已声明不介意泄露）
ROOTPW="root"                # root 账户明文密码（实际使用请改为安全密码）
USERPW="123456"              # 普通用户明文密码
# 分区大小（UEFI）
ESP_SIZE="512MiB"            # EFI 系统分区大小（FAT32）
SWAP_SIZE="2GiB"             # Swap 分区大小，设为 "0GiB" 或 "0" 表示不创建 swap
# ====================

# 定义错误退出函数
die(){ echo "❌ $*" >&2; exit 1; }

# 检查必要命令是否存在，不存在则报错退出
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }
need lsblk                   # 列出块设备
need sgdisk                  # GPT 分区工具（gptfdisk 包）
need mkfs.fat                # 制作 FAT32 文件系统
need mkfs.ext4               # 制作 ext4 文件系统
need mount                   # 挂载文件系统
need pacstrap                # 安装基础系统到指定目录
need genfstab                # 生成 fstab
need arch-chroot             # 进入新系统 chroot 环境

# 必须在 UEFI 模式下运行（Live 环境）
[[ -d /sys/firmware/efi ]] || die "当前不是 UEFI 启动（/sys/firmware/efi 不存在）"

echo "===== 即将清空磁盘: ${DISK} ====="
lsblk                        # 显示当前磁盘分区情况，便于用户确认
echo
read -r -p "输入 YES 确认清空 ${DISK}: " ok
[[ "$ok" == "YES" ]] || die "已取消"   # 安全确认，防止误操作

# 时间同步（网络正常情况下）
timedatectl set-ntp true || true       # 开启 NTP 自动同步时间，失败也不中断脚本

# 1) 清盘 + 创建 GPT 分区表 + 分区
umount -R /mnt 2>/dev/null || true     # 尝试卸载之前的挂载点
swapoff -a 2>/dev/null || true         # 关闭所有 swap
sgdisk --zap-all "${DISK}"             # 删除磁盘上所有分区表签名（彻底清盘）
sgdisk -o "${DISK}"                    # 创建新的 GPT 分区表

# 分区方案：
#   1: EFI 系统分区 (ef00)
#   2: Swap 分区（可选，类型 8200）
#   3: Root 分区（8300，Linux filesystem）
sgdisk -n 1:0:+${ESP_SIZE} -t 1:ef00 -c 1:"EFI" "${DISK}"   # 创建 EFI 分区

if [[ "${SWAP_SIZE}" != "0GiB" && "${SWAP_SIZE}" != "0" ]]; then
  # 有 swap 的情况：分区顺序 1=EFI, 2=SWAP, 3=ROOT
  sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"SWAP" "${DISK}"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP="${DISK}2"; ROOT="${DISK}3"
else
  # 无 swap 的情况：分区顺序 1=EFI, 2=ROOT
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP=""; ROOT="${DISK}2"
fi

# 2) 格式化分区
mkfs.fat -F32 "${ESP}"                 # EFI 分区格式化为 FAT32
mkfs.ext4 -F "${ROOT}"                 # Root 分区格式化为 ext4（-F 强制不询问）
if [[ -n "${SWP}" ]]; then
  mkswap "${SWP}"                      # 创建 swap
  swapon "${SWP}"                      # 立即启用 swap（可选，但有助于后续安装大包）
fi

# 3) 挂载分区
mount "${ROOT}" /mnt                   # 挂载 root 到 /mnt
mkdir -p /mnt/boot                     # 创建 boot 目录
mount "${ESP}" /mnt/boot               # 挂载 EFI 分区到 /mnt/boot

# 4) 安装基础系统及常用软件包
pacstrap -K /mnt \
  base linux linux-firmware \          # 核心系统、内核、固件
  networkmanager sudo vim git \        # 网络管理、sudo、编辑器、git
  grub efibootmgr \                    # UEFI 引导：GRUB 和 EFI 管理工具
  xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \  # XFCE 桌面环境 + 显示管理器
  open-vm-tools \                      # VMware 虚拟机工具（共享文件夹、剪贴板等）
  noto-fonts noto-fonts-cjk            # Google Noto 字体（中英文显示更美观）

# 5) 生成 fstab（使用 UUID，更加可靠）
genfstab -U /mnt >> /mnt/etc/fstab

# 6) 进入新系统（chroot）进行配置
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
# 设置时区
ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
hwclock --systohc                       # 将系统时间写入硬件时钟

# 配置 locale（语言环境）
sed -i 's/^#${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen || true
locale-gen                              # 生成 locale
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf   # 控制台键盘布局

# 设置主机名和 hosts 文件
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# 设置 root 密码（明文）
echo "root:${ROOTPW}" | chpasswd

# 创建普通用户并设置密码
useradd -m -G wheel -s /bin/bash ${USERNAME}   # -m 创建家目录，加入 wheel 组
echo "${USERNAME}:${USERPW}" | chpasswd
# 启用 wheel 组 sudo 无密码（实际生产建议改为 NOPASSWD 或保留密码）
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 启用必要服务
systemctl enable NetworkManager         # 网络管理
systemctl enable lightdm                # 图形登录管理器
systemctl enable vmtoolsd               # VMware 工具服务

# 安装 GRUB 引导（UEFI）
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg    # 生成 grub 配置
CHROOT
# chroot 配置结束

# 7) 完成安装
echo
echo "✅ 安装完成：即将卸载并重启"
umount -R /mnt                          # 递归卸载 /mnt 下所有挂载点
reboot                                  # 直接重启进入新系统
