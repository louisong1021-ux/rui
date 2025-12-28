#!/usr/bin/env bash
set -euo pipefail

# ================= 基本配置 =================
DISK="/dev/sda"
HOSTNAME="arch-test"
USERNAME="rui"

TZ="America/Los_Angeles"
LOCALE="zh_CN.UTF-8"
KEYMAP="us"

# 测试密码（公开仓库允许）
ROOTPW="root"
USERPW="123456"

ESP_SIZE="512MiB"
SWAP_SIZE="2GiB"
# ============================================

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

for c in lsblk sgdisk mkfs.fat mkfs.ext4 mount pacstrap genfstab arch-chroot timedatectl; do
  need "$c"
done

[[ -d /sys/firmware/efi ]] || die "必须使用 UEFI 启动 Arch ISO"

echo "⚠️ 即将清空磁盘: ${DISK}"
lsblk
read -r -p "输入 YES 确认继续: " ok < /dev/tty
[[ "$ok" == "YES" ]] || die "已取消"

timedatectl set-ntp true || true
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# ================= 分区 =================
sgdisk --zap-all "${DISK}"
sgdisk -o "${DISK}"
sgdisk -n 1:0:+"${ESP_SIZE}" -t 1:ef00 -c 1:"EFI" "${DISK}"

if [[ "${SWAP_SIZE}" != "0" && "${SWAP_SIZE}" != "0GiB" ]]; then
  sgdisk -n 2:0:+"${SWAP_SIZE}" -t 2:8200 -c 2:"SWAP" "${DISK}"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "${DISK}"
  ESP="${DISK}1"; SWP="${DISK}2"; ROOT="${DISK}3"
else
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "${DISK}"
  ESP="${DISK}1"; ROOT="${DISK}2"; SWP=""
fi

mkfs.fat -F32 "${ESP}"
mkfs.ext4 -F "${ROOT}"
[[ -n "${SWP}" ]] && mkswap "${SWP}" && swapon "${SWP}"

mount "${ROOT}" /mnt
mkdir -p /mnt/boot
mount "${ESP}" /mnt/boot

# ================= 安装系统 =================
pacstrap -K /mnt \
  base linux linux-firmware \
  grub efibootmgr \
  networkmanager sudo vim git \
  gnome gdm gnome-tweaks \
  dconf-editor gnome-themes-extra gnome-backgrounds \
  gnome-shell-extensions gnome-browser-connector \
  gnome-shell-extension-dash-to-dock \
  gnome-shell-extension-blur-my-shell \
  fcitx5 fcitx5-im fcitx5-chinese-addons fcitx5-pinyin \
  noto-fonts noto-fonts-cjk ttf-dejavu ttf-liberation ttf-jetbrains-mono \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly \
  bluez bluez-utils \
  wl-clipboard gnome-screenshot \
  ntfs-3g exfatprogs dosfstools \
  open-vm-tools \
  base-devel

genfstab -U /mnt >> /mnt/etc/fstab

# ================= chroot 配置 =================
arch-chroot /mnt /bin/bash <<CHROOT
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
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USERPW}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

systemctl enable NetworkManager
systemctl enable gdm
systemctl enable vmtoolsd
systemctl enable bluetooth

cat > /etc/environment <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg

cd /opt
git clone https://aur.archlinux.org/yay.git
chown -R ${USERNAME}:${USERNAME} yay
sudo -u ${USERNAME} bash -lc 'cd /opt/yay && makepkg -si --noconfirm'

sudo -u ${USERNAME} yay -S --noconfirm --needed \
  google-chrome \
  whitesur-gtk-theme orchis-theme \
  tela-icon-theme papirus-icon-theme \
  bibata-cursor-theme
CHROOT

umount -R /mnt
reboot
