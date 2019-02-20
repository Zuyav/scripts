#!/bin/sh

# https://dwz.cn/GmNKmjlP

# 磁盘分区
# ----------------------------------------
# sda - sda1 - 256MiB - EFI
#     - sda2 - 剩下的 - LVM
# ----------------------------------------
echo "----------------------------------------Begin to partition----------------------------------------"
echo "o
Y
n


+256M
ef00
n



8e00
w
Y
" | gdisk /dev/sda 2>>/dev/null

# 配置分区
# ----------------------------------------
# 用sda2构成一个卷组vg1
# 并建立在卷组上创建一个逻辑卷lv1
# 建立文件系统
# 挂载分区
# ----------------------------------------
echo "----------------------------------------Begin to configure partition----------------------------------------"
vgcreate vg1 /dev/sda2
lvcreate -l +100%FREE vg1 -n lv1
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/vg1/lv1
mkdir -p /mnt/boot/efi
echo "3 day zhi nei sha le you"
ls /mnt
read
mount /dev/vg1/lv1 /mnt
mount /dev/sda1 /mnt/boot/efi

# 配置镜像源
# ----------------------------------------
# pacman-contrib包提供了rankmirrors脚本
# 用来对镜像源排序，被排序的镜像源列表
# 来自官方的Pacman镜像列表生成器
# ----------------------------------------
echo "----------------------------------------Begin to setup mirrors----------------------------------------"
pacman -Sy pacman-contrib --noconfirm
curl -s "https://www.archlinux.org/mirrorlist/?country=CN&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors - > /etc/pacman.d/mirrorlist

# 安装基本系统
echo "----------------------------------------Begin to install system----------------------------------------"
pacstrap /mnt base

# 配置系统
# ----------------------------------------
# 生成fstab文件
# ----------------------------------------
echo "----------------------------------------Begin to configure system----------------------------------------"
genfstab -U /mnt >> /mnt/etc/fstab
