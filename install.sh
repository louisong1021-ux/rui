#!/usr/bin/env bash
set -euo pipefail

# ================= 固定配置（骨架）=================
DISK="/dev/sda"          # ⚠️ 目标磁盘（会被完全清空）
HOSTNAME="arch-test"
USERNAME="rui"

TZ="America/Los_Angeles"
LOCALE="zh_CN.UTF-8"
KEYMAP="us"

ROOTPW="root"
USERPW="123456"

ESP_SIZE="512MiB"
SWAP_SIZE="2GiB"         # 0GiB 表示不建 swap
# ================================================

# ================= 日志 =================
exec > >(tee -a /root/install.log) 2>&1
# ======================================

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

for c in lsblk sgdisk mkfs.fat mkfs.ext4 mount pacstrap genfstab arch-chroot timedatectl partprobe udevadm; do
  need "$c"
done

[[ -d /sys/firmware/efi ]] || die "必须使用 UEFI 启动（/sys/firmware/efi 不存在）"

# ================= 磁盘安全检查 =================
lsblk -d -o NAME,SIZE,MODEL,TRAN
echo
read -r -p "⚠️ 确认清空磁盘 ${DISK}（输入 YES 继续）: " ok < /dev/tty
[[ "$ok" == "YES" ]] || die "已取消"

lsblk -no TYPE "${DISK}" | grep -q disk || die "${DISK} 不是磁盘设备"
# ===============================================

# ================= 基础准备 =================
timedatectl set-ntp true || true
pacman -Sy --noconfirm archlinux-keyring

umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
# ===============================================

# ================= 分区（GPT / UEFI） =================
sgdisk --zap-all "${DISK}"
sgdisk -o "${DISK}"

sgdisk -n 1:0:+"${ESP_SIZE}" -t 1:ef00 -c 1:"EFI" "${DISK}"

if [[ "${SWAP_SIZE}" != "0" && "${SWAP_SIZE}" != "0GiB" ]]; then
  sgdisk -n 2:0:+"${SWAP_SIZE}" -t 2:8200 -c 2:"SWAP" "${DISK}"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP="${DISK}2"; ROOT="${DISK}3"
else
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP=""; ROOT="${DISK}2"
fi

partprobe "${DISK}" || true
udevadm settle || true
# =====================================================

# ================= 格式化 =================
mkfs.fat -F32 "${ESP}"
mkfs.ext4 -F "${ROOT}"
[[ -n "${SWP}" ]] && mkswap "${SWP}" && swapon "${SWP}"
# ==========================================

# ================= 挂载 =================
mount "${ROOT}" /mnt
mkdir -p /mnt/boot
mount "${ESP}" /mnt/boot
# =======================================

# ================= pacstrap（官方仓库骨架） =================
pacstrap -K /mnt \
  base linux linux-firmware \
  grub efibootmgr \
  networkmanager sudo vim git \
  gnome gdm gnome-tweaks \
  fcitx5 fcitx5-im fcitx5-chinese-addons \
  noto-fonts noto-fonts-cjk ttf-dejavu ttf-liberation \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  bluez bluez-utils \
  open-vm-tools \
  base-devel
# ============================================================

genfstab -U /mnt > /mnt/etc/fstab

# ================= chroot 基础配置 =================
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT

ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
hwclock --systohc

sed -i "s/^#\\(${LOCALE} UTF-8\\)/\\1/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "root:${ROOTPW}" | chpasswd
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USERPW}" | chpasswd

# sudoers（drop-in，安全）
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

# 服务
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable bluetooth
systemctl enable vmtoolsd

# 输入法环境变量
cat > /etc/environment <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg

# MOTD 提示
cat > /etc/motd <<'EOF'
✅ Arch 骨架系统安装完成
下一步（登录系统后执行）：
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/post.sh | bash
EOF

CHROOT
# =====================================================

umount -R /mnt
echo "✅ 安装完成，系统将重启"
reboot
