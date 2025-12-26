#!/usr/bin/env bash
set -euo pipefail

# ===== 固定配置 =====
DISK="/dev/sda"
HOSTNAME="arch-test"
USERNAME="rui"

TZ="America/Los_Angeles"
LOCALE="zh_CN.UTF-8"
KEYMAP="us"

# 测试用密码（公开仓库：你已声明不介意泄露）
ROOTPW="root"
USERPW="123456"

# 分区大小（UEFI）
ESP_SIZE="512MiB"     # EFI 分区
SWAP_SIZE="2GiB"      # 可改 0GiB 代表不建 swap
# ====================

die(){ echo "❌ $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

need lsblk
need sgdisk
need mkfs.fat
need mkfs.ext4
need mount
need pacstrap
need genfstab
need arch-chroot

# 必须 UEFI
[[ -d /sys/firmware/efi ]] || die "当前不是 UEFI 启动（/sys/firmware/efi 不存在）"

echo "===== 即将清空磁盘: ${DISK} ====="
lsblk
echo
read -r -p "输入 YES 确认清空 ${DISK}: " ok
[[ "$ok" == "YES" ]] || die "已取消"

# 时间同步（网络正常情况下）
timedatectl set-ntp true || true

# 1) 清盘 + GPT + 分区（sgdisk：最快、最稳）
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

sgdisk --zap-all "${DISK}"
sgdisk -o "${DISK}"

# 分区编号：1=EFI, 2=SWAP(可选), 3=ROOT
sgdisk -n 1:0:+${ESP_SIZE} -t 1:ef00 -c 1:"EFI" "${DISK}"

if [[ "${SWAP_SIZE}" != "0GiB" && "${SWAP_SIZE}" != "0" ]]; then
  sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"SWAP" "${DISK}"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP="${DISK}2"; ROOT="${DISK}3"
else
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP=""; ROOT="${DISK}2"
fi

# 2) 格式化
mkfs.fat -F32 "${ESP}"
mkfs.ext4 -F "${ROOT}"
if [[ -n "${SWP}" ]]; then
  mkswap "${SWP}"
  swapon "${SWP}"
fi

# 3) 挂载
mount "${ROOT}" /mnt
mkdir -p /mnt/boot
mount "${ESP}" /mnt/boot

# 4) 安装基础系统 + 必要包
# 说明：
# - base linux linux-firmware：基础
# - networkmanager sudo vim：联网、提权、编辑
# - grub efibootmgr：UEFI 引导（也可 systemd-boot，但这里用 grub 更通用）
# - xfce4 xfce4-goodies lightdm lightdm-gtk-greeter：桌面与登录管理器
# - open-vm-tools：VMware 工具
pacstrap -K /mnt \
  base linux linux-firmware \
  networkmanager sudo vim git \
  grub efibootmgr \
  xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \
  open-vm-tools \
  noto-fonts noto-fonts-cjk

# 5) fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6) chroot 配置（用 heredoc 一次性执行）
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
hwclock --systohc

# locale
sed -i 's/^#${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen || true
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# hostname & hosts
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# root 密码
echo "root:${ROOTPW}" | chpasswd

# 创建用户 + wheel + sudo
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USERPW}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 启用服务
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable vmtoolsd

# 安装 GRUB（UEFI）
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

# 7) 完成
echo
echo "✅ 安装完成：即将卸载并重启"
umount -R /mnt
reboot
