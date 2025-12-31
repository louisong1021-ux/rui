#!/usr/bin/env bash
set -euo pipefail

# =====================================================
# Arch Linux (Ventoy same disk) + GNOME + zh_CN + Fcitx5/Rime
# Target: /dev/sde3 (EFI) + /dev/sde4 (ROOT)
# =====================================================

### ========= 固定目标 =========
DISK="/dev/sde"
ESP="${DISK}3"
ROOT="${DISK}4"
### ===========================

### ========= 基础配置 =========
HOSTNAME="arch-ventoy"
USERNAME="rui"
USER_GROUPS="wheel"

TZ="America/Los_Angeles"
LANG_PRIMARY="zh_CN.UTF-8"
LANG_FALLBACK="en_US.UTF-8"
KEYMAP="us"
### ===========================

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

# 关键：从 /dev/tty 读取输入，保证 curl | bash 也能交互
confirm_yes_or_exit() {
  local prompt="$1"
  local input=""

  echo
  echo "$prompt"
  echo "Type 'yes' to continue (lowercase only). Anything else will abort."
  echo -n "> "

  [[ -r /dev/tty ]] || die "No /dev/tty available; cannot read interactive input."
  read -r input < /dev/tty || true

  if [[ "$input" != "yes" ]]; then
    echo "Confirmation failed. Abort."
    exit 1
  fi
}

echo "== Arch + GNOME + zh_CN + Fcitx5/Rime installer =="

# -----------------------------------------------------
# 0. 必须在 Arch ISO Live 环境
# -----------------------------------------------------
[ -f /etc/arch-release ] || die "This script must be run from Arch Linux live ISO"

# -----------------------------------------------------
# 1. 必要命令检查
# -----------------------------------------------------
for c in lsblk wipefs mkfs.fat mkfs.ext4 mount umount pacstrap genfstab arch-chroot; do
  need "$c"
done

# -----------------------------------------------------
# 2. 第一次确认：破坏性操作提示（格式化前）
# -----------------------------------------------------
echo
echo "⚠️  WARNING"
echo "This script WILL ERASE the following partitions:"
echo "  - ${ESP}  (EFI)"
echo "  - ${ROOT} (ROOT)"
echo
echo "Ventoy partitions (${DISK}1, ${DISK}2) will NOT be touched."
confirm_yes_or_exit "First confirmation (before any disk write)."

# -----------------------------------------------------
# 3. 显示磁盘结构 + 第二次确认
# -----------------------------------------------------
echo
echo "Target disk layout:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "${DISK}" || die "Target disk not found"

confirm_yes_or_exit "Second confirmation: Is this the correct disk?"

# -----------------------------------------------------
# 4. 护栏检查（防误盘）
# -----------------------------------------------------
lsblk "${DISK}1" >/dev/null 2>&1 || die "Expected Ventoy partition ${DISK}1 not found"
lsblk "${DISK}2" >/dev/null 2>&1 || die "Expected Ventoy partition ${DISK}2 not found"
lsblk "$ESP" >/dev/null 2>&1 || die "ESP not found: $ESP"
lsblk "$ROOT" >/dev/null 2>&1 || die "ROOT not found: $ROOT"

ESP_SIZE=$(lsblk -bno SIZE "$ESP")
ROOT_SIZE=$(lsblk -bno SIZE "$ROOT")
(( ESP_SIZE >= 256*1024*1024 )) || die "ESP too small (<256MB)"
(( ROOT_SIZE >= 20*1024*1024*1024 )) || die "ROOT too small (<20GB)"

[ -z "$(lsblk -no MOUNTPOINT "$ESP")" ] || die "$ESP is mounted"
[ -z "$(lsblk -no MOUNTPOINT "$ROOT")" ] || die "$ROOT is mounted"

# -----------------------------------------------------
# 5. 格式化（真正开始破坏性操作）
# -----------------------------------------------------
echo "[1/8] Formatting ${ESP} and ${ROOT}..."
wipefs -af "$ESP"
wipefs -af "$ROOT"
mkfs.fat -F32 "$ESP"
mkfs.ext4 -F "$ROOT"

# -----------------------------------------------------
# 6. 挂载
# -----------------------------------------------------
echo "[2/8] Mounting..."
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$ESP" /mnt/boot

# -----------------------------------------------------
# 7. 安装系统 + 桌面 + 输入法
# -----------------------------------------------------
echo "[3/8] Installing base system, GNOME, input methods..."
pacstrap /mnt \
  base linux linux-firmware \
  grub efibootmgr \
  networkmanager sudo vim git \
  gnome gnome-extra gdm \
  xorg-xwayland \
  noto-fonts noto-fonts-cjk noto-fonts-emoji \
  fcitx5 fcitx5-gtk fcitx5-qt \
  fcitx5-configtool fcitx5-chinese-addons fcitx5-rime

# -----------------------------------------------------
# 8. fstab
# -----------------------------------------------------
echo "[4/8] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# -----------------------------------------------------
# 9. 系统配置（chroot）
# -----------------------------------------------------
echo "[5/8] Configuring system..."
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# timezone
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc

# locales
sed -i "s/^#${LANG_PRIMARY} UTF-8/${LANG_PRIMARY} UTF-8/" /etc/locale.gen || true
sed -i "s/^#${LANG_FALLBACK} UTF-8/${LANG_FALLBACK} UTF-8/" /etc/locale.gen || true
locale-gen
echo "LANG=${LANG_PRIMARY}" > /etc/locale.conf
echo "${KEYMAP}" > /etc/vconsole.conf

# hostname
echo "${HOSTNAME}" > /etc/hostname

# services
systemctl enable NetworkManager
systemctl enable gdm

# Wayland ensure enabled
sed -i 's/^#WaylandEnable/WaylandEnable/' /etc/gdm/custom.conf || true
grep -q '^WaylandEnable=true' /etc/gdm/custom.conf || echo 'WaylandEnable=true' >> /etc/gdm/custom.conf

# Fcitx env
cat > /etc/environment <<'ENV'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
ENV

# sudo: enable wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# user
id -u "${USERNAME}" >/dev/null 2>&1 || useradd -m -G "${USER_GROUPS}" -s /bin/bash "${USERNAME}"

# GDM autologin
sed -i 's/^#\s*AutomaticLoginEnable/AutomaticLoginEnable/' /etc/gdm/custom.conf || true
sed -i 's/^#\s*AutomaticLogin/AutomaticLogin/' /etc/gdm/custom.conf || true
grep -q '^AutomaticLoginEnable=' /etc/gdm/custom.conf || echo 'AutomaticLoginEnable=True' >> /etc/gdm/custom.conf
grep -q '^AutomaticLogin=' /etc/gdm/custom.conf || echo "AutomaticLogin=${USERNAME}" >> /etc/gdm/custom.conf

# GNOME input sources: avoid IBus interference (optional but stabilizes)
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-input-sources <<'DCONF'
[org/gnome/desktop/input-sources]
sources=[('xkb','us')]
DCONF
dconf update || true

# Fcitx5 profile: default IM = rime
USER_HOME="/home/${USERNAME}"
install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "\${USER_HOME}/.config/fcitx5"
cat > "\${USER_HOME}/.config/fcitx5/profile" <<'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=rime
Layout=

[GroupOrder]
0=Default
PROFILE
chown "${USERNAME}:${USERNAME}" "\${USER_HOME}/.config/fcitx5/profile"

# Fcitx5 UI (optional)
install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "\${USER_HOME}/.config/fcitx5/conf"
cat > "\${USER_HOME}/.config/fcitx5/conf/classicui.conf" <<'CONF'
Vertical Candidate List=False
WheelForPaging=True
Font="Sans 12"
MenuFont="Sans 11"
TrayFont="Sans 10"
UseInputMethodLangaugeToDisplayText=True
CONF
chown -R "${USERNAME}:${USERNAME}" "\${USER_HOME}/.config/fcitx5/conf"

# Rime: luna_pinyin_simp + Left Shift toggle
RIME_DIR="\${USER_HOME}/.local/share/fcitx5/rime"
install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "\${RIME_DIR}"

cat > "\${RIME_DIR}/default.custom.yaml" <<'RIME'
patch:
  schema_list:
    - schema: luna_pinyin_simp

  ascii_composer:
    switch_key:
      Shift_L: toggle
      Control_L: noop
      Control_R: noop
      Shift_R: commit_text

  key_binder:
    bindings:
      - { when: composing, accept: Shift_L, send: ToggleAsciiMode }

  "menu/page_size": 9
RIME

chown -R "${USERNAME}:${USERNAME}" "\${USER_HOME}/.local/share/fcitx5"

# Bootloader: GRUB UEFI removable (safe for Ventoy coexist)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchUSB --removable
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# -----------------------------------------------------
# 10. 设置密码（唯一人工步骤）
# -----------------------------------------------------
echo "[6/8] Set passwords..."
arch-chroot /mnt passwd
arch-chroot /mnt passwd "${USERNAME}"

# -----------------------------------------------------
# 11. 清理并结束
# -----------------------------------------------------
echo "[7/8] Cleanup..."
umount -R /mnt

echo "[8/8] DONE"
echo "Reboot and boot from the USB disk (UEFI)."
echo "If IME doesn't show on first login: logout/login once or run: fcitx5 -r"
