# Arch 测试机一键安装（UEFI + /dev/sda + XFCE + 中文）

⚠️ 警告：脚本会清空整块磁盘 **/dev/sda**

## 固定内容
- 磁盘：/dev/sda（wipe）
- 桌面：XFCE
- 语言：zh_CN.UTF-8
- 默认安装：open-vm-tools / sudo / networkmanager / 中文字体
- 测试密码：
  - root: root
  - rui: 123456
- 自动重启

## 使用方法（Arch 官方 ISO，UEFI 启动，联网后）
```bash
curl -fsSL https://raw.githubusercontent.com/louisong1021-ux/rui/main/install.sh -o install.sh && bash install.sh
