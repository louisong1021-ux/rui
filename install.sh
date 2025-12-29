#!/usr/bin/env bash
set -euo pipefail

# ================= 固定配置（骨架） =================
# 磁盘 DISK 将在脚本开始时交互选择，不在这里写死
HOSTNAME="arch-test"
USERNAME="rui"

TZ="America/Los_Angeles"
LOCALE="zh_CN.UTF-8"
KEYMAP="us"

# 测试用密码（你说公开仓库不介意泄露）
ROOTPW="root"
USERPW="123456"

ESP_SIZE="512MiB"
SWAP_SIZE="2GiB"         # 设为 0GiB 可禁用 swap
# ===================================================

die(){ echo -e "\033[31m❌ $*\033[0m" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

for c in lsblk sgdisk mkfs.fat mkfs.ext4 mount pacstrap genfstab arch-chroot timedatectl; do
  need "$c"
done

[[ -d /sys/firmware/efi ]] || die "必须使用 UEFI 启动（/sys/firmware/efi 不存在）"

# NVMe 分区名需要带 p：/dev/nvme0n1p1；SATA 则是 /dev/sda1
part() {
  local disk="$1" n="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    echo "${disk}p${n}"
  else
    echo "${disk}${n}"
  fi
}

# ================= 运行环境选择 =================
echo
echo "请选择安装环境："
echo "  1) 真机（Physical Machine，例如 XPS 8930）"
echo "  2) VMware 虚拟机"
echo
read -r -p "请输入 1 或 2: " INSTALL_ENV < /dev/tty
case "$INSTALL_ENV" in
  1) ENV_TYPE="physical"; echo "✔ 已选择：真机安装" ;;
  2) ENV_TYPE="vmware";  echo "✔ 已选择：VMware 虚拟机安装" ;;
  *) die "无效选择，必须输入 1 或 2" ;;
esac
echo

# ================= 自动列出磁盘并选择 =================
echo "===== 检测到的可用磁盘（将被清空，请谨慎选择）====="
# 仅列出磁盘（TYPE=disk），排除 loop/rom
mapfile -t DISKS < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}')

((${#DISKS[@]} > 0)) || die "未检测到可用磁盘"

for i in "${!DISKS[@]}"; do
  name="${DISKS[$i]}"
  size="$(lsblk -dn -o SIZE "/dev/$name" | head -n1)"
  model="$(lsblk -dn -o MODEL "/dev/$name" | head -n1)"
  tran="$(lsblk -dn -o TRAN "/dev/$name" 2>/dev/null | head -n1 || true)"
  echo "  [$i] /dev/${name}   size=${size}   model=${model:-unknown}   tran=${tran:-unknown}"
done

echo
read -r -p "请输入磁盘编号进行安装（例如 0）： " DISK_IDX < /dev/tty
[[ "$DISK_IDX" =~ ^[0-9]+$ ]] || die "请输入数字编号"
(( DISK_IDX >= 0 && DISK_IDX < ${#DISKS[@]} )) || die "编号超出范围"

DISK="/dev/${DISKS[$DISK_IDX]}"
[[ -b "$DISK" ]] || die "磁盘不存在：$DISK"

echo
echo "你选择的目标磁盘是：$DISK"
lsblk "$DISK"
echo
read -r -p "输入 YES 确认清空并安装到 ${DISK}: " ok < /dev/tty
[[ "$ok" == "YES" ]] || die "已取消"

# 时间同步
timedatectl set-ntp true || true

# 卸载旧挂载/交换
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# ================= 分区 =================
echo "===== 分区中（GPT + EFI）====="
sgdisk --zap-all "${DISK}"
sgdisk -o "${DISK}"
sgdisk -n 1:0:+"${ESP_SIZE}" -t 1:ef00 -c 1:"EFI" "${DISK}"

if [[ "${SWAP_SIZE}" != "0" && "${SWAP_SIZE}" != "0GiB" ]]; then
  sgdisk -n 2:0:+"${SWAP_SIZE}" -t 2:8200 -c 2:"SWAP" "${DISK}"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "${DISK}"
  ESP="$(part "$DISK" 1)"; SWP="$(part "$DISK" 2)"; ROOT="$(part "$DISK" 3)"
else
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "${DISK}"
  ESP="$(part "$DISK" 1)"; SWP=""; ROOT="$(part "$DISK" 2)"
fi

echo "EFI : $ESP"
echo "SWAP: ${SWP:-<none>}"
echo "ROOT: $ROOT"

# ================= 格式化 =================
echo "===== 格式化中 ====="
mkfs.fat -F32 "${ESP}"
mkfs.ext4 -F "${ROOT}"
if [[ -n "${SWP}" ]]; then
  mkswap "${SWP}"
  swapon "${SWP}"
fi

# ================= 挂载 =================
echo "===== 挂载中 ====="
mount "${ROOT}" /mnt
mkdir -p /mnt/boot
mount "${ESP}" /mnt/boot

# ================= 安装包列表（按环境切换） =================
BASE_PKGS=(
  base linux linux-firmware
  grub efibootmgr
  networkmanager sudo vim git
  gnome gdm gnome-tweaks extension-manager
  fcitx5 fcitx5-im fcitx5-chinese-addons
  noto-fonts noto-fonts-cjk ttf-dejavu ttf-liberation
  pipewire pipewire-alsa pipewire-pulse wireplumber
  bluez bluez-utils
  base-devel
)

# 真机：Intel 微码（XPS 8930 适用）
if [[ "$ENV_TYPE" == "physical" ]]; then
  BASE_PKGS+=(intel-ucode)
fi

# VMware：VMware 工具
if [[ "$ENV_TYPE" == "vmware" ]]; then
  BASE_PKGS+=(open-vm-tools)
fi

echo "===== pacstrap 安装系统（${ENV_TYPE}）====="
pacstrap -K /mnt "${BASE_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# ================= chroot 配置 =================
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
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "root:${ROOTPW}" | chpasswd
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USERPW}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 启用服务
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable bluetooth

# 真机建议：SSD TRIM
if [[ "${ENV_TYPE}" == "physical" ]]; then
  systemctl enable fstrim.timer
fi

# VMware：启用 vmtoolsd
if [[ "${ENV_TYPE}" == "vmware" ]]; then
  systemctl enable vmtoolsd
fi

# 输入法环境变量（Wayland/X11 都通用）
cat > /etc/environment <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# 写入安装环境标记（便于排查）
echo "${ENV_TYPE}" > /etc/arch-install-env

# 安装 GRUB（UEFI）
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

echo
echo "✅ 安装完成（环境：${ENV_TYPE}；磁盘：${DISK}）：即将卸载并重启"
umount -R /mnt
reboot
